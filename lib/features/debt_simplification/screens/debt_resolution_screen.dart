import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../auth_user/providers/user_profile_provider.dart';
import '../../expenses/providers/expense_provider.dart';
import '../../groups/models/group_member.dart';
import '../../groups/providers/group_provider.dart';
import '../algorithms/debt_simplifier.dart';
import '../algorithms/debt_transaction.dart';
import '../providers/settlement_provider.dart';
import 'settle_up_dialog.dart';

class DebtResolutionScreen extends StatelessWidget {
  final String groupId;

  const DebtResolutionScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final groupProvider = context.watch<GroupProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final settlementProvider = context.watch<SettlementProvider>();

    final group = groupProvider.getGroupById(groupId);
    if (group == null) {
      return Scaffold(body: const Center(child: Text('Group not found')));
    }

    final currentUserId = context.watch<UserProfileProvider>().currentUser.id;

    final expenses = expenseProvider.getExpensesForGroup(group.id);
    final netBalances = settlementProvider.getNetBalancesForGroup(
      group: group,
      expenses: expenses,
    );

    final transactions = settlementProvider.getDebtTransactions(
      group: group,
      expenses: expenses,
    );

    // Calculate direct debt count for comparison banner
    final directTransactions = DebtSimplifier.calculateDirectDebts(
      expenses: expenses,
      currencyCode: group.baseCurrency,
    );

    final simplifiedCount = DebtSimplifier.simplifyDebts(
      netBalances: netBalances,
      currencyCode: group.baseCurrency,
      expenses: expenses,
      members: group.members,
    ).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Debt Resolution'),
        actions: [
          // Settle Up Shortcut
          IconButton(
            tooltip: 'Settle Up',
            icon: const Icon(Icons.handshake_outlined),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => SettleUpDialog(group: group),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Algorithm Comparison & Toggle Banner ---
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: AppColors.primary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Debt Simplification',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      Switch(
                        value: settlementProvider.isSimplifiedView,
                        activeColor: AppColors.primary,
                        onChanged: (_) => settlementProvider.toggleSimplification(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    settlementProvider.isSimplifiedView
                        ? 'Greedy debt reduction enabled. Minimizes cash flow across the group so everyone settles with the fewest transactions.'
                        : 'Showing direct pairwise obligations without graph reduction.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Stats pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Direct Debts: ${directTransactions.length} payments',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const Icon(Icons.arrow_forward, size: 14, color: AppColors.primary),
                        Text(
                          'Simplified: $simplifiedCount payments',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // --- Debt Resolution Transactions ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Required Payments (${transactions.length})',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (transactions.isNotEmpty)
                Text(
                  settlementProvider.isSimplifiedView ? 'Optimized' : 'Direct',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (transactions.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.positive, size: 52),
                    const SizedBox(height: 12),
                    Text(
                      'Everyone is completely settled up!',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'There are no pending debts in this group.',
                      style: TextStyle(fontSize: 13, color: AppColors.lightTextSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            ...transactions.map((tx) {
              final debtor = group.members.firstWhere(
                (m) => m.id == tx.fromMemberId,
                orElse: () => GroupMember(id: tx.fromMemberId, name: 'Unknown'),
              );
              final creditor = group.members.firstWhere(
                (m) => m.id == tx.toMemberId,
                orElse: () => GroupMember(id: tx.toMemberId, name: 'Unknown'),
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Debtor Avatar
                      Column(
                        children: [
                          AvatarWidget(name: debtor.cleanName, colorSeedIndex: debtor.colorSeedIndex, radius: 18),
                          const SizedBox(height: 4),
                          Text(
                            debtor.displayName(currentUserId),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      // Arrow with Amount
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            children: [
                              Text(
                                'owes',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.negativeBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  CurrencyFormatter.format(tx.amount, currencyCode: tx.currencyCode),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.negativeDark,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primary),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Creditor Avatar
                      Column(
                        children: [
                          AvatarWidget(name: creditor.cleanName, colorSeedIndex: creditor.colorSeedIndex, radius: 18),
                          const SizedBox(height: 4),
                          Text(
                            creditor.displayName(currentUserId),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Quick Settle Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.settled,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => SettleUpDialog(
                              group: group,
                              initialPayerId: tx.fromMemberId,
                              initialReceiverId: tx.toMemberId,
                              initialAmount: tx.amount,
                            ),
                          );
                        },
                        child: const Text('Settle', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 24),

          // --- Individual Net Balances Breakdown Table ---
          Text(
            'Net Balance Summary',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: group.members.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final member = group.members[index];
                final balance = netBalances[member.id] ?? 0.0;
                final isPositive = balance > 0.005;
                final isNegative = balance < -0.005;

                return ListTile(
                  dense: true,
                  leading: AvatarWidget(
                    name: member.cleanName,
                    colorSeedIndex: member.colorSeedIndex,
                    radius: 14,
                  ),
                  title: Text(member.displayName(currentUserId), style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Text(
                    balance.abs() < 0.005
                        ? 'Settled (0.00)'
                        : CurrencyFormatter.format(
                            balance,
                            currencyCode: group.baseCurrency,
                            showSign: true,
                          ),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: isPositive
                          ? AppColors.positive
                          : (isNegative ? AppColors.negative : AppColors.settled),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
