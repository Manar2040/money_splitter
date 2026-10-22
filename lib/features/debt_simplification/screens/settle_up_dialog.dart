import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../auth_user/providers/user_profile_provider.dart';
import '../../expenses/models/expense.dart';
import '../../expenses/providers/expense_provider.dart';
import '../../groups/models/group_member.dart';
import '../../groups/models/trip_group.dart';
import '../algorithms/debt_simplifier.dart';
import '../providers/settlement_provider.dart';

class SettleUpDialog extends StatefulWidget {
  final TripGroup group;
  final String? initialPayerId;
  final String? initialReceiverId;
  final double? initialAmount;
  final String? linkedExpenseId;

  const SettleUpDialog({
    super.key,
    required this.group,
    this.initialPayerId,
    this.initialReceiverId,
    this.initialAmount,
    this.linkedExpenseId,
  });

  @override
  State<SettleUpDialog> createState() => _SettleUpDialogState();
}

class _SettleUpDialogState extends State<SettleUpDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _rateController = TextEditingController(text: '1.0');

  late String _payerId;
  late String _receiverId;
  late String _settlementCurrency;
  bool _isFullSettlement = true;
  String? _selectedExpenseId;

  @override
  void initState() {
    super.initState();
    final currentUserId = context.read<UserProfileProvider>().currentUser.id;
    _settlementCurrency = widget.group.baseCurrency;
    _selectedExpenseId = widget.linkedExpenseId;

    if (widget.initialPayerId != null) {
      _payerId = widget.initialPayerId!;
      _receiverId = widget.initialReceiverId ??
          widget.group.members.firstWhere((m) => m.id != _payerId).id;
    } else {
      final currentExpenses = context.read<ExpenseProvider>().getExpensesForGroup(widget.group.id);
      final netBalances = DebtSimplifier.calculateNetBalances(
        members: widget.group.members,
        expenses: currentExpenses,
      );
      final userNet = netBalances[currentUserId] ?? 0.0;

      if (userNet > 0.005) {
        // Current user is owed money (Creditor), so receiver is current user!
        _receiverId = currentUserId;
        final debtors = widget.group.members.where((m) => (netBalances[m.id] ?? 0) < -0.005).toList()
          ..sort((a, b) => (netBalances[a.id] ?? 0).compareTo(netBalances[b.id] ?? 0));
        _payerId = debtors.isNotEmpty
            ? debtors.first.id
            : widget.group.members.firstWhere((m) => m.id != currentUserId).id;
      } else {
        // Current user owes money (Debtor), so payer is current user!
        _payerId = currentUserId;
        final creditors = widget.group.members.where((m) => (netBalances[m.id] ?? 0) > 0.005).toList()
          ..sort((a, b) => (netBalances[b.id] ?? 0).compareTo(netBalances[a.id] ?? 0));
        _receiverId = creditors.isNotEmpty
            ? creditors.first.id
            : widget.group.members.firstWhere((m) => m.id != currentUserId).id;
      }
    }

    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _amountController.text = widget.initialAmount!.toStringAsFixed(2);
    } else {
      // Auto-prefill the relevant debt amount
      final currentExpenses = context.read<ExpenseProvider>().getExpensesForGroup(widget.group.id);
      final netBalances = DebtSimplifier.calculateNetBalances(
        members: widget.group.members,
        expenses: currentExpenses,
      );
      final debtorBal = (netBalances[_payerId] ?? 0.0).abs();
      final creditorBal = (netBalances[_receiverId] ?? 0.0).abs();
      final suggestedAmt = min(debtorBal, creditorBal);
      if (suggestedAmt > 0.005) {
        _amountController.text = suggestedAmt.toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _submitSettlement() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payment amount.')),
      );
      return;
    }

    if (_payerId == _receiverId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payer and receiver cannot be the same person.')),
      );
      return;
    }

    final customRate = double.tryParse(_rateController.text.trim());
    final settlementProvider = context.read<SettlementProvider>();
    final expenseProvider = context.read<ExpenseProvider>();

    await settlementProvider.settleDebt(
      group: widget.group,
      payerId: _payerId,
      receiverId: _receiverId,
      amount: amount,
      expenseProvider: expenseProvider,
      settlementCurrency: _settlementCurrency,
      customExchangeRate: customRate,
      isFullSettlement: _isFullSettlement,
      linkedExpenseId: _selectedExpenseId,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settlement recorded! Balances cleanly updated.'),
          backgroundColor: AppColors.positive,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<UserProfileProvider>().currentUser.id;
    final isMultiCurrency = _settlementCurrency != widget.group.baseCurrency;
    final expenseProvider = context.watch<ExpenseProvider>();
    final groupExpenses = expenseProvider.getExpensesForGroup(widget.group.id).where((e) => !e.isSettlement).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.settledBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.handshake, color: AppColors.settled, size: 22),
          ),
          const SizedBox(width: 10),
          const Text('Record a Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payer Dropdown
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _payerId,
                decoration: const InputDecoration(
                  labelText: 'Who Paid? (Debtor)',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: widget.group.members.map((m) {
                  return DropdownMenuItem(
                    value: m.id,
                    child: Row(
                      children: [
                        AvatarWidget(name: m.cleanName, colorSeedIndex: m.colorSeedIndex, radius: 12),
                        const SizedBox(width: 8),
                        Expanded(child: Text(m.displayName(currentUserId), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _payerId = val);
                },
              ),
              const SizedBox(height: 10),

              // Receiver Dropdown
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _receiverId,
                decoration: const InputDecoration(
                  labelText: 'Paid To? (Creditor)',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: widget.group.members.map((m) {
                  return DropdownMenuItem(
                    value: m.id,
                    child: Row(
                      children: [
                        AvatarWidget(name: m.cleanName, colorSeedIndex: m.colorSeedIndex, radius: 12),
                        const SizedBox(width: 8),
                        Expanded(child: Text(m.displayName(currentUserId), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _receiverId = val);
                },
              ),
              const SizedBox(height: 10),

              // Amount & Currency Row
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      decoration: const InputDecoration(
                        labelText: 'Amount *',
                        prefixIcon: Icon(Icons.attach_money, size: 20),
                        hintText: '0.00',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _settlementCurrency,
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                      items: AppConstants.supportedCurrencies
                          .map((c) => DropdownMenuItem(
                                value: c.code,
                                child: Text(c.code, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _settlementCurrency = val;
                            final rate = CurrencyFormatter.convert(
                              amount: 1.0,
                              fromCurrency: _settlementCurrency,
                              toCurrency: widget.group.baseCurrency,
                            );
                            _rateController.text = rate.toStringAsFixed(4);
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),

              // Multi-currency exchange rate input if different currency
              if (isMultiCurrency) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _rateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Rate: 1 $_settlementCurrency = ? ${widget.group.baseCurrency}',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],

              const SizedBox(height: 6),

              // Zero-drift closure toggle
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Full Settlement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                subtitle: const Text('Eliminates currency conversion micro-dust and zeroes debt.', style: TextStyle(fontSize: 11)),
                value: _isFullSettlement,
                onChanged: (val) => setState(() => _isFullSettlement = val ?? true),
              ),

              // Optional Link to specific expense
              if (groupExpenses.isNotEmpty) ...[
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  value: _selectedExpenseId,
                  decoration: const InputDecoration(
                    labelText: 'Link to Expense (optional)',
                    hintText: 'Select bill being settled',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('General Debt Settlement', overflow: TextOverflow.ellipsis),
                    ),
                    ...groupExpenses.map((e) => DropdownMenuItem<String?>(
                          value: e.id,
                          child: Text(
                            '${e.title} (\$${e.baseAmount.toStringAsFixed(2)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (val) => setState(() => _selectedExpenseId = val),
                ),
              ],

              const SizedBox(height: 10),

              // Note Field
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Payment Note (optional)',
                  hintText: 'e.g. Paid in Cash / Revolut / InstaPay',
                  prefixIcon: Icon(Icons.note_alt_outlined, size: 20),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.settled,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _submitSettlement,
          child: const Text('Record Payment'),
        ),
      ],
    );
  }
}
