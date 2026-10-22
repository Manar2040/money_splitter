import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../auth_user/providers/user_profile_provider.dart';
import '../models/group_member.dart';
import '../models/trip_group.dart';
import '../providers/group_provider.dart';

class CreateEditTripScreen extends StatefulWidget {
  final TripGroup? existingGroup;

  const CreateEditTripScreen({super.key, this.existingGroup});

  @override
  State<CreateEditTripScreen> createState() => _CreateEditTripScreenState();
}

class _CreateEditTripScreenState extends State<CreateEditTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _newMemberController = TextEditingController();

  String _selectedCategory = 'Trip';
  String _selectedCurrency = 'USD';
  final List<GroupMember> _members = [];

  final List<String> _categories = ['Trip', 'Dining', 'House', 'Event', 'Project', 'Other'];

  @override
  void initState() {
    super.initState();
    if (widget.existingGroup != null) {
      final g = widget.existingGroup!;
      _nameController.text = g.name;
      _descController.text = g.description;
      _selectedCategory = g.category;
      _selectedCurrency = g.baseCurrency;
      _members.addAll(g.members);
    } else {
      // Auto-add current user
      final currentUser = context.read<UserProfileProvider>().currentUser;
      _members.add(
        GroupMember(
          id: currentUser.id,
          name: currentUser.name,
          email: currentUser.email,
          colorSeedIndex: 0,
          isCurrentUser: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _newMemberController.dispose();
    super.dispose();
  }

  void _addMember() {
    final name = _newMemberController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _members.add(
        GroupMember(
          id: 'member_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          colorSeedIndex: _members.length,
        ),
      );
      _newMemberController.clear();
    });
  }

  void _removeMember(int index) {
    if (_members[index].isCurrentUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot remove yourself from your trip.')),
      );
      return;
    }
    setState(() {
      _members.removeAt(index);
    });
  }

  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) return;
    if (_members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one member to the trip.')),
      );
      return;
    }

    final groupProvider = context.read<GroupProvider>();
    final isEditing = widget.existingGroup != null;

    final trip = TripGroup(
      id: widget.existingGroup?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      category: _selectedCategory,
      baseCurrency: _selectedCurrency,
      members: _members,
      createdAt: widget.existingGroup?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (isEditing) {
      await groupProvider.updateTrip(trip);
    } else {
      await groupProvider.createTrip(trip);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.existingGroup != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Trip' : 'New Trip / Group'),
        actions: [
          TextButton(
            onPressed: _saveTrip,
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Trip / Group Name *',
                hintText: 'e.g. Dahab Red Sea Trip or Weekend Dinner',
                prefixIcon: Icon(Icons.flight),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a name' : null,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g. 4-day diving vacation in South Sinai',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Category & Currency Pickers
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val ?? 'Trip'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Base Currency',
                      prefixIcon: Icon(Icons.monetization_on_outlined),
                    ),
                    items: AppConstants.supportedCurrencies
                        .map((c) => DropdownMenuItem(value: c.code, child: Text('${c.code} (${c.symbol})', overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCurrency = val ?? 'USD'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Members Header
            Text(
              'Trip Members (${_members.length})',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            // Add member input field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newMemberController,
                    decoration: const InputDecoration(
                      hintText: 'Add friend name (e.g. Sarah, Karim)',
                      prefixIcon: Icon(Icons.person_add_outlined),
                    ),
                    onSubmitted: (_) => _addMember(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addMember,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Members list
            ..._members.asMap().entries.map((entry) {
              final index = entry.key;
              final member = entry.value;

              return Card(
                child: ListTile(
                  leading: AvatarWidget(
                    name: member.name,
                    colorSeedIndex: member.colorSeedIndex,
                    radius: 18,
                  ),
                  title: Text(
                    member.name,
                    style: TextStyle(
                      fontWeight: member.isCurrentUser ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    member.isCurrentUser ? 'Trip Creator (You)' : (member.email.isNotEmpty ? member.email : 'Member'),
                  ),
                  trailing: member.isCurrentUser
                      ? const Chip(
                          label: Text('You', style: TextStyle(fontSize: 11)),
                          backgroundColor: AppColors.positiveBg,
                        )
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _removeMember(index),
                        ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
