import '../../database/local_storage_service.dart';
import '../auth_user/models/user_profile.dart';
import '../expenses/models/expense.dart';
import '../expenses/models/expense_category.dart';
import '../expenses/models/expense_split.dart';
import '../expenses/models/split_type.dart';
import '../groups/models/group_member.dart';
import '../groups/models/trip_group.dart';

class MockSeedData {
  MockSeedData._();

  static const String currentUserId = 'user_me';

  static final GroupMember memberMe = const GroupMember(
    id: currentUserId,
    name: 'Omar',
    email: 'omar@splitwise.smart',
    phone: '+20 100 123 4567',
    colorSeedIndex: 0,
    isCurrentUser: true,
  );

  static final GroupMember memberSarah = const GroupMember(
    id: 'member_sarah',
    name: 'Sarah',
    email: 'sarah@splitwise.smart',
    phone: '+20 101 987 6543',
    colorSeedIndex: 1,
  );

  static final GroupMember memberKarim = const GroupMember(
    id: 'member_karim',
    name: 'Karim',
    email: 'karim@splitwise.smart',
    phone: '+20 102 333 4444',
    colorSeedIndex: 2,
  );

  static final GroupMember memberLaila = const GroupMember(
    id: 'member_laila',
    name: 'Laila',
    email: 'laila@splitwise.smart',
    phone: '+20 106 555 7777',
    colorSeedIndex: 4,
  );

  static final GroupMember memberYoussef = const GroupMember(
    id: 'member_youssef',
    name: 'Youssef',
    email: 'youssef@splitwise.smart',
    phone: '+20 109 888 9999',
    colorSeedIndex: 5,
  );

  static Future<void> loadSeedDataIfNeeded(LocalStorageService storage) async {
    final existingGroups = storage.getGroups();
    if (existingGroups.isNotEmpty) {
      // Already populated
      return;
    }

    await populateData(storage);
  }

  static Future<void> populateData(LocalStorageService storage) async {
    await storage.clearAllData();

    // 1. User Profile
    final userProfile = UserProfile(
      id: currentUserId,
      name: memberMe.name,
      email: memberMe.email,
      defaultCurrency: 'USD',
    );
    await storage.saveUserProfile(userProfile);

    // 2. Group 1: Dahab Red Sea Adventure
    final dahabMembers = [memberMe, memberSarah, memberKarim, memberLaila];
    final dahabGroup = TripGroup(
      id: 'group_dahab',
      name: 'Dahab Red Sea Trip 🌊',
      description: 'Annual diving trip & coastal retreat in South Sinai',
      category: 'Trip',
      baseCurrency: 'USD',
      members: dahabMembers,
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      updatedAt: DateTime.now(),
      iconName: 'beach_access',
    );
    await storage.saveGroup(dahabGroup);

    // Group 1 Expenses
    final exp1 = Expense(
      id: 'dahab_exp_1',
      groupId: dahabGroup.id,
      title: 'Bedouin Chalet & Camp Lodge',
      originalAmount: 320.0,
      originalCurrency: 'USD',
      baseAmount: 320.0,
      category: ExpenseCategoryType.stay,
      date: DateTime.now().subtract(const Duration(days: 3, hours: 2)),
      paidBy: {memberSarah.id: 320.0},
      splits: [
        ExpenseSplit(memberId: memberMe.id, amount: 80.0),
        ExpenseSplit(memberId: memberSarah.id, amount: 80.0),
        ExpenseSplit(memberId: memberKarim.id, amount: 80.0),
        ExpenseSplit(memberId: memberLaila.id, amount: 80.0),
      ],
      splitType: SplitType.equal,
      notes: '3 nights booking confirmed online',
      createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 3, hours: 2)),
    );
    await storage.saveExpense(exp1);

    final exp2 = Expense(
      id: 'dahab_exp_2',
      groupId: dahabGroup.id,
      title: 'Ali Baba Seafood Grill',
      originalAmount: 124.50,
      originalCurrency: 'USD',
      baseAmount: 124.50,
      category: ExpenseCategoryType.food,
      date: DateTime.now().subtract(const Duration(days: 2, hours: 5)),
      paidBy: {memberMe.id: 124.50},
      splits: [
        ExpenseSplit(memberId: memberMe.id, amount: 31.14),
        ExpenseSplit(memberId: memberSarah.id, amount: 31.12),
        ExpenseSplit(memberId: memberKarim.id, amount: 31.12),
        ExpenseSplit(memberId: memberLaila.id, amount: 31.12),
      ],
      splitType: SplitType.equal,
      notes: 'Delicious grilled fish & fresh salads by the water',
      createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2, hours: 5)),
    );
    await storage.saveExpense(exp2);

    final exp3 = Expense(
      id: 'dahab_exp_3',
      groupId: dahabGroup.id,
      title: 'Blue Hole Snorkel & Speedboat',
      originalAmount: 160.0,
      originalCurrency: 'USD',
      baseAmount: 160.0,
      category: ExpenseCategoryType.activity,
      date: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
      paidBy: {memberKarim.id: 160.0},
      splits: [
        ExpenseSplit(memberId: memberMe.id, amount: 40.0),
        ExpenseSplit(memberId: memberSarah.id, amount: 40.0),
        ExpenseSplit(memberId: memberKarim.id, amount: 40.0),
        ExpenseSplit(memberId: memberLaila.id, amount: 40.0),
      ],
      splitType: SplitType.equal,
      notes: 'Guided reef safari + gear rental',
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
    );
    await storage.saveExpense(exp3);

    final exp4 = Expense(
      id: 'dahab_exp_4',
      groupId: dahabGroup.id,
      title: 'Highway Fuel & Suez Road Tolls',
      originalAmount: 58.20,
      originalCurrency: 'USD',
      baseAmount: 58.20,
      category: ExpenseCategoryType.transport,
      date: DateTime.now().subtract(const Duration(hours: 14)),
      paidBy: {memberMe.id: 58.20},
      splits: [
        ExpenseSplit(memberId: memberMe.id, amount: 14.55),
        ExpenseSplit(memberId: memberSarah.id, amount: 14.55),
        ExpenseSplit(memberId: memberKarim.id, amount: 14.55),
        ExpenseSplit(memberId: memberLaila.id, amount: 14.55),
      ],
      splitType: SplitType.equal,
      notes: 'Full tank at ChillOut + gate fees',
      createdAt: DateTime.now().subtract(const Duration(hours: 14)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 14)),
    );
    await storage.saveExpense(exp4);

    // Partial settlement in Group 1
    final settlement1 = Expense(
      id: 'dahab_settle_1',
      groupId: dahabGroup.id,
      title: 'Settlement: Karim paid Sarah \$40.00',
      originalAmount: 40.0,
      originalCurrency: 'USD',
      baseAmount: 40.0,
      category: ExpenseCategoryType.settlement,
      date: DateTime.now().subtract(const Duration(hours: 4)),
      paidBy: {memberKarim.id: 40.0},
      splits: [],
      isSettlement: true,
      settlementPayerId: memberKarim.id,
      settlementReceiverId: memberSarah.id,
      notes: 'InstaPay transfer towards chalet stay',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 4)),
    );
    await storage.saveExpense(settlement1);

    // 3. Group 2: Cairo Weekend Dinner
    final dinnerMembers = [memberMe, memberKarim, memberYoussef];
    final dinnerGroup = TripGroup(
      id: 'group_dinner',
      name: 'Weekend Dinners 🍕',
      description: 'Zamalek & Maadi casual food gatherings',
      category: 'Dining',
      baseCurrency: 'USD',
      members: dinnerMembers,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      updatedAt: DateTime.now(),
      iconName: 'restaurant',
    );
    await storage.saveGroup(dinnerGroup);

    final dinnerExp1 = Expense(
      id: 'dinner_exp_1',
      groupId: dinnerGroup.id,
      title: 'Trattoria Woodfired Pizza & Pasta',
      originalAmount: 78.0,
      originalCurrency: 'USD',
      baseAmount: 78.0,
      category: ExpenseCategoryType.food,
      date: DateTime.now().subtract(const Duration(days: 5)),
      paidBy: {memberMe.id: 78.0},
      splits: [
        ExpenseSplit(memberId: memberMe.id, amount: 26.0),
        ExpenseSplit(memberId: memberKarim.id, amount: 26.0),
        ExpenseSplit(memberId: memberYoussef.id, amount: 26.0),
      ],
      splitType: SplitType.equal,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    );
    await storage.saveExpense(dinnerExp1);

    final dinnerExp2 = Expense(
      id: 'dinner_exp_2',
      groupId: dinnerGroup.id,
      title: 'Artisanal Gelato & Specialty Coffee',
      originalAmount: 24.0,
      originalCurrency: 'USD',
      baseAmount: 24.0,
      category: ExpenseCategoryType.food,
      date: DateTime.now().subtract(const Duration(days: 2)),
      paidBy: {memberYoussef.id: 24.0},
      splits: [
        ExpenseSplit(memberId: memberMe.id, amount: 8.0),
        ExpenseSplit(memberId: memberKarim.id, amount: 8.0),
        ExpenseSplit(memberId: memberYoussef.id, amount: 8.0),
      ],
      splitType: SplitType.equal,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    );
    await storage.saveExpense(dinnerExp2);
  }
}
