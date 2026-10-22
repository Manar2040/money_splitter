import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../auth_user/providers/user_profile_provider.dart';
import '../../debt_simplification/algorithms/debt_simplifier.dart';
import '../../groups/models/group_member.dart';
import '../../groups/providers/group_provider.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../models/expense_split.dart';
import '../models/split_type.dart';
import '../providers/expense_provider.dart';

class AddEditExpenseScreen extends StatefulWidget {
  final String groupId;
  final Expense? existingExpense;
  final double? prefilledAmount;
  final String? prefilledTitle;
  final String? prefilledNotes;

  const AddEditExpenseScreen({
    super.key,
    required this.groupId,
    this.existingExpense,
    this.prefilledAmount,
    this.prefilledTitle,
    this.prefilledNotes,
  });

  @override
  State<AddEditExpenseScreen> createState() => _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends State<AddEditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _exchangeRateController = TextEditingController(text: '1.0');
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  ExpenseCategoryType _selectedCategory = ExpenseCategoryType.food;
  late String _expenseCurrency;

  // Paid By state
  bool _isMultiplePayers = false;
  String _singlePayerId = '';
  final Map<String, TextEditingController> _multiplePayerControllers = {};

  // Split state
  SplitType _splitType = SplitType.equal;
  final Set<String> _selectedMembersForEqual = {};
  final Map<String, TextEditingController> _exactAmountControllers = {};
  final Map<String, TextEditingController> _percentageControllers = {};
  final Map<String, TextEditingController> _sharesControllers = {};

  @override
  void initState() {
    super.initState();
    final group = context.read<GroupProvider>().getGroupById(widget.groupId);
    final baseCurrency = group?.baseCurrency ?? 'USD';
    _expenseCurrency = baseCurrency;

    // Initialize member controllers
    if (group != null) {
      for (final m in group.members) {
        _multiplePayerControllers[m.id] = TextEditingController(text: '0.00');
        _exactAmountControllers[m.id] = TextEditingController(text: '0.00');
        _percentageControllers[m.id] = TextEditingController(
          text: (100.0 / group.members.length).toStringAsFixed(1),
        );
        _sharesControllers[m.id] = TextEditingController(text: '1');
        _selectedMembersForEqual.add(m.id);
      }
      final currentUserId = context.read<UserProfileProvider>().currentUser.id;
      final userInGroup = group.members.any((m) => m.id == currentUserId);
      _singlePayerId = userInGroup ? currentUserId : group.members.first.id;
    }

    // Handle existing expense or prefilled data
    if (widget.existingExpense != null) {
      final exp = widget.existingExpense!;
      _titleController.text = exp.title;
      _amountController.text = exp.originalAmount.toStringAsFixed(2);
      _expenseCurrency = exp.originalCurrency;
      _exchangeRateController.text = exp.exchangeRate.toString();
      _selectedCategory = exp.category;
      _selectedDate = exp.date;
      _notesController.text = exp.notes;
      _splitType = exp.splitType;

      if (exp.paidBy.length > 1) {
        _isMultiplePayers = true;
        exp.paidBy.forEach((key, val) {
          if (_multiplePayerControllers.containsKey(key)) {
            _multiplePayerControllers[key]!.text = val.toStringAsFixed(2);
          }
        });
      } else if (exp.paidBy.isNotEmpty) {
        _isMultiplePayers = false;
        _singlePayerId = exp.paidBy.keys.first;
      }

      _selectedMembersForEqual.clear();
      for (final s in exp.splits) {
        _selectedMembersForEqual.add(s.memberId);
        if (_exactAmountControllers.containsKey(s.memberId)) {
          _exactAmountControllers[s.memberId]!.text = s.amount.toStringAsFixed(2);
        }
        if (_percentageControllers.containsKey(s.memberId)) {
          _percentageControllers[s.memberId]!.text = s.percentage.toStringAsFixed(1);
        }
        if (_sharesControllers.containsKey(s.memberId)) {
          _sharesControllers[s.memberId]!.text = s.shares.toStringAsFixed(0);
        }
      }
    } else {
      if (widget.prefilledAmount != null && widget.prefilledAmount! > 0) {
        _amountController.text = widget.prefilledAmount!.toStringAsFixed(2);
      }
      if (widget.prefilledTitle != null) {
        _titleController.text = widget.prefilledTitle!;
      }
      if (widget.prefilledNotes != null) {
        _notesController.text = widget.prefilledNotes!;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _exchangeRateController.dispose();
    _notesController.dispose();
    for (final c in _multiplePayerControllers.values) {
      c.dispose();
    }
    for (final c in _exactAmountControllers.values) {
      c.dispose();
    }
    for (final c in _percentageControllers.values) {
      c.dispose();
    }
    for (final c in _sharesControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _parsedOriginalAmount => double.tryParse(_amountController.text.trim()) ?? 0.0;
  double get _parsedExchangeRate => double.tryParse(_exchangeRateController.text.trim()) ?? 1.0;
  double get _calculatedBaseAmount => _parsedOriginalAmount * _parsedExchangeRate;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    final totalAmount = _parsedOriginalAmount;
    if (totalAmount <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid expense amount.')),
      );
      return;
    }

    final group = context.read<GroupProvider>().getGroupById(widget.groupId);
    if (group == null) return;

    // Validate Payers
    final Map<String, double> paidBy = {};
    if (!_isMultiplePayers) {
      paidBy[_singlePayerId] = totalAmount;
    } else {
      double sumPaid = 0.0;
      _multiplePayerControllers.forEach((mId, ctrl) {
        final amt = double.tryParse(ctrl.text.trim()) ?? 0.0;
        if (amt > 0.005) {
          paidBy[mId] = amt;
          sumPaid += amt;
        }
      });
      if ((sumPaid - totalAmount).abs() > 0.05) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sum of payments (\$${sumPaid.toStringAsFixed(2)}) does not match total amount (\$${totalAmount.toStringAsFixed(2)}).',
            ),
          ),
        );
        return;
      }
    }

    // Validate Splits
    final List<ExpenseSplit> splits = [];
    switch (_splitType) {
      case SplitType.equal:
        if (_selectedMembersForEqual.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select at least one person to split this with.')),
          );
          return;
        }
        final equalMap = DebtSimplifier.allocateEqualSplits(
          totalAmount,
          _selectedMembersForEqual.toList(),
        );
        equalMap.forEach((mId, splitAmt) {
          splits.add(ExpenseSplit(memberId: mId, amount: splitAmt));
        });
        break;

      case SplitType.exact:
        double sumSplits = 0.0;
        _exactAmountControllers.forEach((mId, ctrl) {
          final amt = double.tryParse(ctrl.text.trim()) ?? 0.0;
          if (amt > 0.005) {
            splits.add(ExpenseSplit(memberId: mId, amount: amt));
            sumSplits += amt;
          }
        });
        if ((sumSplits - totalAmount).abs() > 0.05) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sum of exact shares (\$${sumSplits.toStringAsFixed(2)}) must equal total (\$${totalAmount.toStringAsFixed(2)}).',
              ),
            ),
          );
          return;
        }
        break;

      case SplitType.percentage:
        double sumPct = 0.0;
        _percentageControllers.forEach((mId, ctrl) {
          final pct = double.tryParse(ctrl.text.trim()) ?? 0.0;
          if (pct > 0.005) {
            final splitAmt = (totalAmount * (pct / 100.0));
            splits.add(ExpenseSplit(memberId: mId, amount: splitAmt, percentage: pct));
            sumPct += pct;
          }
        });
        if ((sumPct - 100.0).abs() > 0.5) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Percentages must sum up to 100% (currently ${sumPct.toStringAsFixed(1)}%).'),
            ),
          );
          return;
        }
        break;

      case SplitType.shares:
        double totalShares = 0.0;
        _sharesControllers.forEach((mId, ctrl) {
          final s = double.tryParse(ctrl.text.trim()) ?? 0.0;
          totalShares += s;
        });
        if (totalShares <= 0.0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please assign at least 1 share.')),
          );
          return;
        }
        _sharesControllers.forEach((mId, ctrl) {
          final s = double.tryParse(ctrl.text.trim()) ?? 0.0;
          if (s > 0) {
            final amt = (s / totalShares) * totalAmount;
            splits.add(ExpenseSplit(memberId: mId, amount: amt, shares: s));
          }
        });
        break;
    }

    final expense = Expense(
      id: widget.existingExpense?.id ?? const Uuid().v4(),
      groupId: widget.groupId,
      title: _titleController.text.trim(),
      originalAmount: totalAmount,
      originalCurrency: _expenseCurrency,
      baseAmount: _calculatedBaseAmount,
      exchangeRate: _parsedExchangeRate,
      category: _selectedCategory,
      date: _selectedDate,
      paidBy: paidBy,
      splits: splits,
      splitType: _splitType,
      notes: _notesController.text.trim(),
      createdAt: widget.existingExpense?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final expenseProvider = context.read<ExpenseProvider>();
    if (widget.existingExpense != null) {
      await expenseProvider.updateExpense(expense);
    } else {
      await expenseProvider.addExpense(expense);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final group = context.watch<GroupProvider>().getGroupById(widget.groupId);
    if (group == null) {
      return Scaffold(body: const Center(child: Text('Group not found')));
    }

    final isMultiCurrency = _expenseCurrency != group.baseCurrency;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingExpense != null ? 'Edit Expense' : 'Add Expense'),
        actions: [
          if (widget.existingExpense != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.negative),
              onPressed: () async {
                final expenseProvider = context.read<ExpenseProvider>();
                final linked = expenseProvider.getLinkedSettlements(widget.existingExpense!.id);
                final warningText = linked.isNotEmpty
                    ? 'This expense has ${linked.length} linked settlement(s). Deleting it will also remove those payments to prevent ghost debt inversions.'
                    : 'Are you sure you want to delete this expense?';

                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Expense?'),
                    content: Text(warningText),
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
                  await expenseProvider.deleteExpense(
                    widget.existingExpense!.id,
                    deleteLinkedSettlements: true,
                  );
                  Navigator.pop(context);
                }
              },
            ),
          TextButton(
            onPressed: _saveExpense,
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Expense Description *',
                hintText: 'e.g. Seafood Dinner or Snorkeling Tour',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a description' : null,
            ),
            const SizedBox(height: 16),

            // Amount & Currency Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    decoration: const InputDecoration(
                      labelText: 'Amount *',
                      hintText: '0.00',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Enter amount';
                      if (double.tryParse(val) == null) return 'Invalid number';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _expenseCurrency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: AppConstants.supportedCurrencies
                        .map((c) => DropdownMenuItem(value: c.code, child: Text(c.code, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _expenseCurrency = val ?? group.baseCurrency;
                        // Auto-adjust exchange rate baseline
                        final rate = CurrencyFormatter.convert(
                          amount: 1.0,
                          fromCurrency: _expenseCurrency,
                          toCurrency: group.baseCurrency,
                        );
                        _exchangeRateController.text = rate.toStringAsFixed(4);
                      });
                    },
                  ),
                ),
              ],
            ),

            // If Multi-Currency: Display conversion card
            if (isMultiCurrency) ...[
              const SizedBox(height: 12),
              Card(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2F6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.currency_exchange, size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Converts to ${group.baseCurrency} ${_calculatedBaseAmount.toStringAsFixed(2)} at exchange rate:',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        child: TextFormField(
                          controller: _exchangeRateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Category Picker & Date
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ExpenseCategoryType>(
                    isExpanded: true,
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: ExpenseCategory.all
                        .where((c) => c.type != ExpenseCategoryType.settlement)
                        .map((cat) => DropdownMenuItem(
                              value: cat.type,
                              child: Row(
                                children: [
                                  Icon(cat.icon, size: 18, color: cat.color),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(cat.label, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val ?? ExpenseCategoryType.general),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        DateFormatter.formatShort(_selectedDate),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- Paid By Section ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Paid By',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _isMultiplePayers = !_isMultiplePayers),
                          child: Text(_isMultiplePayers ? 'Single Payer' : 'Multiple People'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!_isMultiplePayers) ...[
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _singlePayerId,
                        decoration: const InputDecoration(labelText: 'Who paid?'),
                        items: group.members.map((m) {
                          return DropdownMenuItem(
                            value: m.id,
                            child: Row(
                              children: [
                                AvatarWidget(name: m.name, colorSeedIndex: m.colorSeedIndex, radius: 12),
                                const SizedBox(width: 8),
                                Expanded(child: Text(m.displayName(context.read<UserProfileProvider>().currentUser.id), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _singlePayerId = val ?? group.members.first.id),
                      ),
                    ] else ...[
                      const Text(
                        'Enter amount paid by each person:',
                        style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                      ),
                      const SizedBox(height: 8),
                      ...group.members.map((m) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              AvatarWidget(name: m.name, colorSeedIndex: m.colorSeedIndex, radius: 14),
                              const SizedBox(width: 8),
                              Expanded(child: Text(m.name)),
                              SizedBox(
                                width: 100,
                                child: TextFormField(
                                  controller: _multiplePayerControllers[m.id],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    prefixText: '$_expenseCurrency ',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- Split Method Section ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Split Between',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    // Split Type Segmented Control
                    SegmentedButton<SplitType>(
                      segments: SplitType.values.map((type) {
                        return ButtonSegment(
                          value: type,
                          label: Text(type.shortName, style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      selected: {_splitType},
                      onSelectionChanged: (set) => setState(() => _splitType = set.first),
                    ),
                    const SizedBox(height: 16),

                    // Dynamic Split Views
                    if (_splitType == SplitType.equal) ...[
                      const Text(
                        'Select members who share this expense:',
                        style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                      ),
                      const SizedBox(height: 8),
                      ...group.members.map((m) {
                        final isSelected = _selectedMembersForEqual.contains(m.id);
                        final splitCount = _selectedMembersForEqual.length;
                        final perPerson = splitCount > 0 ? (_parsedOriginalAmount / splitCount) : 0.0;

                        return CheckboxListTile(
                          value: isSelected,
                          contentPadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              AvatarWidget(name: m.name, colorSeedIndex: m.colorSeedIndex, radius: 14),
                              const SizedBox(width: 8),
                              Text(m.name),
                            ],
                          ),
                          subtitle: isSelected
                              ? Text(
                                  CurrencyFormatter.format(perPerson, currencyCode: _expenseCurrency),
                                  style: const TextStyle(fontSize: 12, color: AppColors.positive),
                                )
                              : null,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedMembersForEqual.add(m.id);
                              } else {
                                if (_selectedMembersForEqual.length > 1) {
                                  _selectedMembersForEqual.remove(m.id);
                                }
                              }
                            });
                          },
                        );
                      }),
                    ] else if (_splitType == SplitType.exact) ...[
                      const Text(
                        'Enter exact amounts for each member:',
                        style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                      ),
                      const SizedBox(height: 8),
                      ...group.members.map((m) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              AvatarWidget(name: m.name, colorSeedIndex: m.colorSeedIndex, radius: 14),
                              const SizedBox(width: 8),
                              Expanded(child: Text(m.name)),
                              SizedBox(
                                width: 100,
                                child: TextFormField(
                                  controller: _exactAmountControllers[m.id],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    prefixText: '$_expenseCurrency ',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ] else if (_splitType == SplitType.percentage) ...[
                      const Text(
                        'Enter percentage share for each member (total 100%):',
                        style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                      ),
                      const SizedBox(height: 8),
                      ...group.members.map((m) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              AvatarWidget(name: m.name, colorSeedIndex: m.colorSeedIndex, radius: 14),
                              const SizedBox(width: 8),
                              Expanded(child: Text(m.name)),
                              SizedBox(
                                width: 80,
                                child: TextFormField(
                                  controller: _percentageControllers[m.id],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    suffixText: '%',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ] else if (_splitType == SplitType.shares) ...[
                      const Text(
                        'Enter share multiplier for each member (e.g. 1, 2, 3):',
                        style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                      ),
                      const SizedBox(height: 8),
                      ...group.members.map((m) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              AvatarWidget(name: m.name, colorSeedIndex: m.colorSeedIndex, radius: 14),
                              const SizedBox(width: 8),
                              Expanded(child: Text(m.name)),
                              SizedBox(
                                width: 70,
                                child: TextFormField(
                                  controller: _sharesControllers[m.id],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes & Details (optional)',
                hintText: 'e.g. Paid via Visa, invoice #402',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
