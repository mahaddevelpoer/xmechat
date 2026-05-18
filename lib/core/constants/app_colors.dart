import 'package:flutter/material.dart';

class AppColors {
  // WhatsApp Green Palette
  static const Color primaryGreen = Color(0xFF075E54);
  static const Color accentGreen = Color(0xFF25D366);
  static const Color lightGreen = Color(0xFFDCF8C6);
  static const Color tealGreen = Color(0xFF128C7E);

  // Background Colors
  static const Color bgPrimary = Color(0xFFFFFFFF);
  static const Color bgSecondary = Color(0xFFF0F2F5);
  static const Color chatBg = Color(0xFFECE5DD);

  // Chat Bubble Colors
  static const Color sentBubble = Color(0xFFDCF8C6);
  static const Color receivedBubble = Color(0xFFFFFFFF);
  static const Color sentBubbleDark = Color(0xFF005C4B);
  static const Color receivedBubbleDark = Color(0xFF1F2C34);

  // Text Colors
  static const Color textPrimary = Color(0xFF111B21);
  static const Color textSecondary = Color(0xFF667781);
  static const Color textHint = Color(0xFF8696A0);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Status Colors
  static const Color online = Color(0xFF25D366);
  static const Color typing = Color(0xFF25D366);
  static const Color read = Color(0xFF53BDEB);
  static const Color delivered = Color(0xFF667781);
  static const Color sent = Color(0xFF667781);

  // Dark Mode
  static const Color darkBg = Color(0xFF111B21);
  static const Color darkSurface = Color(0xFF1F2C34);
  static const Color darkAppBar = Color(0xFF1F2C34);
  static const Color darkDivider = Color(0xFF2A3942);
  static const Color darkInput = Color(0xFF2A3942);

  // Misc
  static const Color divider = Color(0xFFE9EDEF);
  static const Color error = Color(0xFFFF3B30);
  static const Color warning = Color(0xFFFF9500);
  static const Color star = Color(0xFFFFC107);
  static const Color voiceNote = Color(0xFF9E9E9E);
  static const Color shadow = Color(0x1A000000);
}

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    primaryColor: AppColors.primaryGreen,
    scaffoldBackgroundColor: AppColors.bgPrimary,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryGreen,
      secondary: AppColors.accentGreen,
      surface: AppColors.bgSecondary,
      error: AppColors.error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: AppColors.textWhite,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textWhite,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: AppColors.textWhite,
      labelColor: AppColors.textWhite,
      unselectedLabelColor: Color(0xB3FFFFFF),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accentGreen,
      foregroundColor: AppColors.textWhite,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(25),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.textHint),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        elevation: 0,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 0.5,
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    primaryColor: AppColors.tealGreen,
    scaffoldBackgroundColor: AppColors.darkBg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.tealGreen,
      secondary: AppColors.accentGreen,
      surface: AppColors.darkSurface,
      error: AppColors.error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkAppBar,
      foregroundColor: AppColors.textWhite,
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accentGreen,
      foregroundColor: AppColors.textWhite,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkInput,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(25),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.textHint),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
    ),
  );
}
