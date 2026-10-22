import 'package:flutter/material.dart';
import 'app_colors.dart';

class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;
  final double defaultRateToUSD; // Relative conversion baseline

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
    required this.defaultRateToUSD,
  });
}

class AppConstants {
  AppConstants._();

  static const String appName = 'SplitWise Smart';

  static const List<CurrencyInfo> supportedCurrencies = [
    CurrencyInfo(code: 'USD', symbol: '\$', name: 'US Dollar', defaultRateToUSD: 1.0),
    CurrencyInfo(code: 'EUR', symbol: '€', name: 'Euro', defaultRateToUSD: 1.08),
    CurrencyInfo(code: 'EGP', symbol: 'E£', name: 'Egyptian Pound', defaultRateToUSD: 0.021),
    CurrencyInfo(code: 'GBP', symbol: '£', name: 'British Pound', defaultRateToUSD: 1.28),
    CurrencyInfo(code: 'AED', symbol: 'AED', name: 'UAE Dirham', defaultRateToUSD: 0.27),
    CurrencyInfo(code: 'SAR', symbol: 'SAR', name: 'Saudi Riyal', defaultRateToUSD: 0.27),
    CurrencyInfo(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar', defaultRateToUSD: 0.73),
    CurrencyInfo(code: 'JPY', symbol: '¥', name: 'Japanese Yen', defaultRateToUSD: 0.0065),
  ];

  static CurrencyInfo getCurrency(String code) {
    return supportedCurrencies.firstWhere(
      (c) => c.code.toUpperCase() == code.toUpperCase(),
      orElse: () => const CurrencyInfo(code: 'USD', symbol: '\$', name: 'US Dollar', defaultRateToUSD: 1.0),
    );
  }

  // Predefined avatar color seeds for members
  static const List<Color> avatarColors = [
    Color(0xFF4F46E5), // Indigo
    Color(0xFF059669), // Emerald
    Color(0xFFD97706), // Amber
    Color(0xFFDC2626), // Red
    Color(0xFF7C3AED), // Violet
    Color(0xFF2563EB), // Blue
    Color(0xFFDB2777), // Pink
    Color(0xFF0891B2), // Cyan
    Color(0xFF4B5563), // Slate
  ];
}
