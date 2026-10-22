import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'database/local_storage_service.dart';
import 'features/auth_user/providers/user_profile_provider.dart';
import 'features/debt_simplification/providers/settlement_provider.dart';
import 'features/expenses/providers/expense_provider.dart';
import 'features/groups/providers/group_provider.dart';
import 'features/groups/screens/home_dashboard_screen.dart';
import 'features/seed_data/mock_seed_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize offline-first database
  final storage = LocalStorageService();
  await storage.init();

  // Preload rich demo data if first launch
  await MockSeedData.loadSeedDataIfNeeded(storage);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()..init()),
        ChangeNotifierProvider(create: (_) => GroupProvider()..init()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()..init()),
        ChangeNotifierProvider(create: (_) => SettlementProvider()),
      ],
      child: const SplitWiseSmartApp(),
    ),
  );
}

class SplitWiseSmartApp extends StatelessWidget {
  const SplitWiseSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'SplitWise Smart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const HomeDashboardScreen(),
    );
  }
}
