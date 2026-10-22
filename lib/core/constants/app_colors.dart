import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Palette - Modern Indigo & Emerald
  static const Color primary = Color(0xFF4F46E5); // Indigo 600
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF3730A3);

  // Financial Semantics
  static const Color positive = Color(0xFF10B981); // Emerald 500 (Owed to you / Credit)
  static const Color positiveDark = Color(0xFF047857);
  static const Color positiveBg = Color(0xFFECFDF5);
  static const Color positiveBgDark = Color(0xFF064E3B);

  static const Color negative = Color(0xFFF43F5E); // Rose 500 (You owe / Debt)
  static const Color negativeDark = Color(0xFFBE123C);
  static const Color negativeBg = Color(0xFFFFF1F2);
  static const Color negativeBgDark = Color(0xFF4C0519);

  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color warningBg = Color(0xFFFFFBEB);

  static const Color settled = Color(0xFF06B6D4); // Cyan 500
  static const Color settledBg = Color(0xFFECFEFF);

  // Light Neutrals (Slate)
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextMuted = Color(0xFF94A3B8);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightDivider = Color(0xFFF1F5F9);

  // Dark Neutrals (Zinc / Slate Deep)
  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkDivider = Color(0xFF1E293B);

  // Category Colors
  static const Color catFood = Color(0xFFF97316); // Orange
  static const Color catTransport = Color(0xFF0EA5E9); // Sky
  static const Color catStay = Color(0xFF8B5CF6); // Purple
  static const Color catActivity = Color(0xFFEC4899); // Pink
  static const Color catShopping = Color(0xFF14B8A6); // Teal
  static const Color catGroceries = Color(0xFF84CC16); // Lime
  static const Color catGeneral = Color(0xFF64748B); // Slate
}
