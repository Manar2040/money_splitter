import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/avatar_widget.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../database/local_storage_service.dart';
import '../../auth_user/providers/user_profile_provider.dart';
import '../../debt_simplification/algorithms/debt_simplifier.dart';
import '../../debt_simplification/providers/settlement_provider.dart';
import '../../expenses/providers/expense_provider.dart';
import '../../seed_data/mock_seed_data.dart';
import '../models/trip_group.dart';
import '../providers/group_provider.dart';
import 'create_edit_trip_screen.dart';
import 'trip_detail_screen.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final userProfileProvider = context.watch<UserProfileProvider>();
    final groupProvider = context.watch<GroupProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final settlementProvider = context.watch<SettlementProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    final currentUser = userProfileProvider.currentUser;
    final groups = groupProvider.groups;

    // Calculate aggregated overall user balance across all groups
    final balanceSummary = settlementProvider.calculateOverallUserBalance(
      currentUserId: currentUser.id,
      groups: groups,
      expenseProvider: expenseProvider,
    );

    final double totalOwedToUser = balanceSummary['youAreOwed'] ?? 0.0;
    final double totalUserOwes = balanceSummary['youOwe'] ?? 0.0;
    final double netBalance = balanceSummary['net'] ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SplitWise Smart',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              'Viewing as: ${currentUser.name}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          // Member switcher modal (for multi-user testing)
          IconButton(
            tooltip: 'Switch Member Perspective',
            icon: const Icon(Icons.switch_account_outlined),
            onPressed: () => _showPerspectiveDialog(context),
          ),
          // Dark/Light Mode Toggle
          IconButton(
            tooltip: 'Toggle Theme',
            icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(),
          ),
          // Options Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'reset') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Reset Demo Data?'),
                    content: const Text('This will reset all trips and mock expenses back to default demo state.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await MockSeedData.populateData(LocalStorageService());
                  if (context.mounted) {
                    await groupProvider.init();
                    await expenseProvider.init();
                    await userProfileProvider.init();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Demo data restored successfully!')),
                    );
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt, size: 20, color: AppColors.negative),
                    SizedBox(width: 10),
                    Text('Restore Demo Data'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: groups.isEmpty
          ? EmptyStateWidget(
              icon: Icons.flight_takeoff,
              title: 'No Trips or Groups Yet',
              description: 'Create your first group trip or outing to start splitting expenses seamlessly.',
              buttonLabel: 'Create New Trip',
              onButtonPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateEditTripScreen()),
                );
              },
            )
          : RefreshIndicator(
              onRefresh: () async {
                await groupProvider.init();
                await expenseProvider.init();
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // --- User Balance Summary Card ---
                  _buildBalanceBanner(
                    context: context,
                    netBalance: netBalance,
                    youAreOwed: totalOwedToUser,
                    youOwe: totalUserOwes,
                    currencyCode: currentUser.defaultCurrency,
                  ),
                  const SizedBox(height: 24),

                  // --- Section Header: Groups ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Active Trips & Groups (${groups.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CreateEditTripScreen()),
                          );
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Trip'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // --- Group Cards List ---
                  ...groups.map((group) {
                    final groupExpenses = expenseProvider.getExpensesForGroup(group.id);
                    final netBalances = DebtSimplifier.calculateNetBalances(
                      members: group.members,
                      expenses: groupExpenses,
                    );
                    final userGroupNet = netBalances[currentUser.id] ?? 0.0;
                    final totalSpend = expenseProvider.getTotalSpendForGroup(group.id);

                    return _buildGroupCard(
                      context: context,
                      group: group,
                      userGroupNet: userGroupNet,
                      totalSpend: totalSpend,
                      onTap: () {
                        groupProvider.setActiveGroup(group.id);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TripDetailScreen(groupId: group.id),
                          ),
                        );
                      },
                    );
                  }),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Trip', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateEditTripScreen()),
          );
        },
      ),
    );
  }

  Widget _buildBalanceBanner({
    required BuildContext context,
    required double netBalance,
    required double youAreOwed,
    required double youOwe,
    required String currencyCode,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isPositive = netBalance > 0.005;
    final isNegative = netBalance < -0.005;

    final Color statusColor = isPositive
        ? AppColors.positive
        : (isNegative ? AppColors.negative : AppColors.settled);

    final String statusText = isPositive
        ? 'Overall, you are owed'
        : (isNegative ? 'Overall, you owe' : 'You are all settled up');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    statusColor.withOpacity(0.15),
                    const Color(0xFF1E293B),
                  ]
                : [
                    statusColor.withOpacity(0.08),
                    Colors.white,
                  ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  statusText.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: statusColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPositive ? 'CREDITOR' : (isNegative ? 'DEBTOR' : 'EVEN'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              CurrencyFormatter.format(netBalance.abs(), currencyCode: currencyCode),
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You are owed',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(youAreOwed, currencyCode: currencyCode),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.positive,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 32,
                  width: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You owe',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(youOwe, currencyCode: currencyCode),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.negative,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard({
    required BuildContext context,
    required TripGroup group,
    required double userGroupNet,
    required double totalSpend,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bool isPositive = userGroupNet > 0.005;
    final bool isNegative = userGroupNet < -0.005;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.luggage, color: AppColors.primary, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (group.description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              group.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Currency Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        group.baseCurrency,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Stack of member avatars
                Row(
                  children: [
                    SizedBox(
                      height: 28,
                      width: 24.0 * (group.members.length.clamp(1, 5)) + 12,
                      child: Stack(
                        children: List.generate(
                          group.members.take(5).length,
                          (index) => Positioned(
                            left: index * 20.0,
                            child: AvatarWidget(
                              name: group.members[index].cleanName,
                              colorSeedIndex: group.members[index].colorSeedIndex,
                              radius: 14,
                              showBorder: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '${group.members.length} members',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                    const Spacer(),
                    // User's balance status inside this group
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isPositive
                              ? 'You are owed'
                              : (isNegative ? 'You owe' : 'Settled up'),
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
                            CurrencyFormatter.format(userGroupNet.abs(), currencyCode: group.baseCurrency),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isPositive ? AppColors.positive : AppColors.negative,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPerspectiveDialog(BuildContext context) {
    final groupProvider = context.read<GroupProvider>();
    final userProfileProvider = context.read<UserProfileProvider>();

    // Collect all unique members across groups
    final Map<String, dynamic> allMembers = {};
    for (final g in groupProvider.groups) {
      for (final m in g.members) {
        allMembers[m.id] = m;
      }
    }

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
                    'Switch User Perspective',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Simulate the app as if you are another group member to review their individual balances and debts:',
                style: TextStyle(fontSize: 13, color: AppColors.lightTextSecondary),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: allMembers.values.map((member) {
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
                      subtitle: Text(member.email),
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
}
