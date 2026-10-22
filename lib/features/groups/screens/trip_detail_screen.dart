import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/spending_donut_chart.dart';
import '../../auth_user/providers/user_profile_provider.dart';
import '../../debt_simplification/algorithms/debt_simplifier.dart';
import '../../debt_simplification/providers/settlement_provider.dart';
import '../../debt_simplification/screens/debt_resolution_screen.dart';
import '../../debt_simplification/screens/settle_up_dialog.dart';
import '../../expenses/models/expense.dart';
import '../../expenses/models/expense_category.dart';
import '../../expenses/providers/expense_provider.dart';
import '../../expenses/screens/add_edit_expense_screen.dart';
import '../../ocr_scanner/screens/receipt_scanner_screen.dart';
import '../models/group_member.dart';
import '../models/trip_group.dart';
import '../providers/group_provider.dart';
import 'create_edit_trip_screen.dart';

class TripDetailScreen extends StatefulWidget {
  final String groupId;

  const TripDetailScreen({super.key, required this.groupId});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final groupProvider = context.watch<GroupProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final userProfileProvider = context.watch<UserProfileProvider>();

    final group = groupProvider.getGroupById(widget.groupId);
    if (group == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Trip not found')),
      );
    }

    final currentUser = userProfileProvider.currentUser;
    final currentUserId = currentUser.id;
    final expenses = expenseProvider.getExpensesForGroup(group.id);
    final netBalances = DebtSimplifier.calculateNetBalances(
      members: group.members,
      expenses: expenses,
    );
    final totalSpend = expenseProvider.getTotalSpendForGroup(group.id);
    final userBalance = netBalances[currentUserId] ?? 0.0;
    final breakdown = expenseProvider.getCategoryBreakdown(group.id);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.name,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              'Viewing as: ${currentUser.name} • ${group.baseCurrency}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        actions: [
          // Member switcher modal (for testing)
          IconButton(
            tooltip: 'Switch Member Perspective',
            icon: const Icon(Icons.switch_account_outlined),
            onPressed: () => _showPerspectiveDialog(context, group),
          ),
          // Debt Graph Button
          IconButton(
            tooltip: 'Smart Debt Resolution',
            icon: const Icon(Icons.account_tree_outlined, color: AppColors.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DebtResolutionScreen(groupId: group.id),
                ),
              );
            },
          ),
          // Options Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateEditTripScreen(existingGroup: group),
                  ),
                );
              } else if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Trip?'),
                    content: Text('Are you sure you want to delete "${group.name}" and all its expenses?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.negative),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await groupProvider.deleteTrip(group.id);
                  Navigator.pop(context);
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit Trip Details')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete Trip', style: TextStyle(color: AppColors.negative)),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long, size: 20), text: 'Expenses'),
            Tab(icon: Icon(Icons.pie_chart, size: 20), text: 'Analytics'),
            Tab(icon: Icon(Icons.people_outline, size: 20), text: 'Members'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Quick Balance & Settle Strip
          _buildQuickActionHeader(
            context: context,
            group: group,
            userBalance: userBalance,
            currentUserName: currentUser.name,
            totalSpend: totalSpend,
            onSettleUp: () {
              showDialog(
                context: context,
                builder: (_) => SettleUpDialog(group: group),
              );
            },
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Expenses Tab
                _buildExpensesTab(context, group, expenses, currentUserId),
                // 2. Spending Analytics Tab
                _buildAnalyticsTab(context, group, breakdown, totalSpend),
                // 3. Members Tab
                _buildMembersTab(context, group, netBalances, currentUserId),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Scan Receipt OCR button
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReceiptScannerScreen(groupId: group.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.document_scanner_outlined, size: 20),
                  label: const Text('Scan Receipt'),
                ),
              ),
              const SizedBox(width: 12),
              // Add Expense button
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddEditExpenseScreen(groupId: group.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add Expense'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionHeader({
    required BuildContext context,
    required TripGroup group,
    required double userBalance,
    required String currentUserName,
    required double totalSpend,
    required VoidCallback onSettleUp,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isPositive = userBalance > 0.005;
    final isNegative = userBalance < -0.005;
    final statusColor = isPositive
        ? AppColors.positive
        : (isNegative ? AppColors.negative : AppColors.settled);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR NET BALANCE ($currentUserName)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    userBalance.abs() < 0.005
                        ? 'Settled up'
                        : CurrencyFormatter.format(
                            userBalance,
                            currencyCode: group.baseCurrency,
                            showSign: true,
                          ),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              // Settle Up Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.settled,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: onSettleUp,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Settle Up', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesTab(
    BuildContext context,
    TripGroup group,
    List<Expense> expenses,
    String currentUserId,
  ) {
    if (expenses.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.receipt_long,
        title: 'No Expenses Yet',
        description: 'Tap "Add Expense" or "Scan Receipt" to start logging group spending.',
        buttonLabel: 'Add First Expense',
        onButtonPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddEditExpenseScreen(groupId: group.id),
            ),
          );
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: expenses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final expense = expenses[index];
        final category = ExpenseCategory.fromType(expense.category);

        // Dynamically compute display title for settlements
        String displayTitle = expense.title;
        if (expense.isSettlement &&
            expense.settlementPayerId != null &&
            expense.settlementReceiverId != null) {
          final payer = group.members.firstWhere(
            (m) => m.id == expense.settlementPayerId,
            orElse: () => const GroupMember(id: '', name: 'Someone'),
          );
          final receiver = group.members.firstWhere(
            (m) => m.id == expense.settlementReceiverId,
            orElse: () => const GroupMember(id: '', name: 'Someone'),
          );
          final payerText = payer.id == currentUserId ? 'You' : payer.cleanName;
          final receiverText = receiver.id == currentUserId ? 'you' : receiver.cleanName;
          displayTitle = 'Settlement: $payerText paid $receiverText';
        } else {
          displayTitle = displayTitle.replaceAll(RegExp(r'\s*\(You\)', caseSensitive: false), '');
        }

        // Dynamically compute primary payer name subtitle
        String payerText = 'Multiple payers';
        if (expense.paidBy.length == 1) {
          final singlePayerId = expense.paidBy.keys.first;
          if (singlePayerId == currentUserId) {
            payerText = 'You paid';
          } else {
            final payer = group.members.firstWhere(
              (m) => m.id == singlePayerId,
              orElse: () => const GroupMember(id: 'unknown', name: 'Someone'),
            );
            payerText = '${payer.cleanName} paid';
          }
        }

        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: expense.isSettlement
                    ? AppColors.settledBg
                    : category.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                expense.isSettlement ? Icons.handshake : category.icon,
                color: expense.isSettlement ? AppColors.settled : category.color,
                size: 22,
              ),
            ),
            title: Text(
              displayTitle,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            subtitle: Row(
              children: [
                Text(
                  DateFormatter.formatShort(expense.date),
                  style: const TextStyle(fontSize: 12),
                ),
                const Text(' • '),
                Expanded(
                  child: Text(
                    payerText,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(expense.baseAmount, currencyCode: group.baseCurrency),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                if (expense.originalCurrency != group.baseCurrency)
                  Text(
                    '${expense.originalCurrency} ${expense.originalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                  ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditExpenseScreen(
                    groupId: group.id,
                    existingExpense: expense,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab(
    BuildContext context,
    TripGroup group,
    Map<ExpenseCategoryType, double> breakdown,
    double totalSpend,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SpendingDonutChart(
          breakdown: breakdown,
          currencyCode: group.baseCurrency,
        ),
        const SizedBox(height: 16),
        // Breakdown List
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Category Breakdown',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 12),
                ...breakdown.entries.map((entry) {
                  final cat = ExpenseCategory.fromType(entry.key);
                  final pct = totalSpend > 0 ? (entry.value / totalSpend) * 100 : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(cat.icon, size: 18, color: cat.color),
                        const SizedBox(width: 8),
                        Expanded(child: Text(cat.label)),
                        Text(
                          CurrencyFormatter.format(entry.value, currencyCode: group.baseCurrency),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${pct.toStringAsFixed(1)}%)',
                          style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMembersTab(
    BuildContext context,
    TripGroup group,
    Map<String, double> netBalances,
    String currentUserId,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Trip Members (${group.members.length})',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            TextButton.icon(
              onPressed: () => _showAddMemberDialog(context, group),
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Add Member'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...group.members.map((member) {
          final balance = netBalances[member.id] ?? 0.0;
          final isPositive = balance > 0.005;
          final isNegative = balance < -0.005;
          final isCurrent = member.id == currentUserId;

          return Card(
            child: ListTile(
              leading: AvatarWidget(
                name: member.cleanName,
                colorSeedIndex: member.colorSeedIndex,
                radius: 20,
              ),
              title: Row(
                children: [
                  Text(
                    member.cleanName,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w700,
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.positiveBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'You',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.positiveDark),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(member.email.isNotEmpty ? member.email : member.phone),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isPositive
                        ? 'gets back'
                        : (isNegative ? 'owes' : 'settled'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isPositive
                          ? AppColors.positive
                          : (isNegative ? AppColors.negative : AppColors.settled),
                    ),
                  ),
                  if (isPositive || isNegative)
                    Text(
                      CurrencyFormatter.format(balance.abs(), currencyCode: group.baseCurrency),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isPositive ? AppColors.positive : AppColors.negative,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showPerspectiveDialog(BuildContext context, TripGroup group) {
    final userProfileProvider = context.read<UserProfileProvider>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.switch_account, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Switch Member Perspective',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'View this trip from another member’s perspective to check their personal balance and who owes them:',
                style: TextStyle(fontSize: 13, color: AppColors.lightTextSecondary),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: group.members.map((member) {
                    final isCurrent = member.id == userProfileProvider.currentUser.id;
                    return ListTile(
                      leading: AvatarWidget(
                        name: member.cleanName,
                        colorSeedIndex: member.colorSeedIndex,
                        radius: 18,
                      ),
                      title: Text(
                        member.cleanName,
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(member.email.isNotEmpty ? member.email : 'Member'),
                      trailing: isCurrent
                          ? const Chip(
                              label: Text('Active (You)', style: TextStyle(fontSize: 11)),
                              backgroundColor: AppColors.positiveBg,
                            )
                          : null,
                      onTap: () async {
                        await userProfileProvider.switchActiveMemberPerspective(
                          memberId: member.id,
                          memberName: member.cleanName,
                          email: member.email,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddMemberDialog(BuildContext context, TripGroup group) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Member to Trip'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Member Name', hintText: 'e.g. Leila or Ziad'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email or Phone (optional)'),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                final newMember = GroupMember(
                  id: 'member_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  email: emailCtrl.text.trim(),
                  colorSeedIndex: group.members.length,
                );
                await context.read<GroupProvider>().addMember(group.id, newMember);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
