import 'package:flutter/material.dart';

class AppColors {
  // WhatsApp Desktop Light Theme Colors
  static const Color primaryGreen = Color(0xFF008069);
  static const Color accentGreen = Color(0xFF00A884);
  
  static const Color bgPrimary = Color(0xFFFFFFFF);
  static const Color bgSecondary = Color(0xFFF0F2F5); // WhatsApp Desktop header/input bar
  static const Color chatBg = Color(0xFFEFEAE2); // WhatsApp Desktop chat background
  
  static const Color sentBubble = Color(0xFFD9FDD3);
  static const Color receivedBubble = Color(0xFFFFFFFF);
  
  static const Color textPrimary = Color(0xFF111B21);
  static const Color textSecondary = Color(0xFF667781);
  static const Color textHint = Color(0xFF54656F); // Icons and hints
  static const Color textWhite = Color(0xFFFFFFFF);

  // Status Colors
  static const Color online = Color(0xFF25D366);
  static const Color read = Color(0xFF53BDEB);

  // Dark Mode
  static const Color darkBg = Color(0xFF111B21);
  static const Color darkSurface = Color(0xFF202C33);
  static const Color darkChatBg = Color(0xFF0B141A);
  static const Color darkSentBubble = Color(0xFF005C4B);
  static const Color darkReceivedBubble = Color(0xFF202C33);
  static const Color darkText = Color(0xFFE9EDEF);
  static const Color darkIcon = Color(0xFFAEBAC1);
  
  static const Color divider = Color(0xFFE9EDEF);
  static const Color error = Color(0xFFFF3B30);
  
  // Legacy aliases
  static const Color lightGreen = sentBubble;
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
      backgroundColor: AppColors.bgSecondary,
      foregroundColor: AppColors.textPrimary,
      iconTheme: IconThemeData(color: AppColors.textHint),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: AppColors.primaryGreen,
      labelColor: AppColors.primaryGreen,
      unselectedLabelColor: AppColors.textHint,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: AppColors.textWhite,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgPrimary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: const TextStyle(color: AppColors.textHint),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    primaryColor: AppColors.accentGreen,
    scaffoldBackgroundColor: AppColors.darkBg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accentGreen,
      secondary: AppColors.accentGreen,
      surface: AppColors.darkSurface,
      error: AppColors.error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      foregroundColor: AppColors.darkText,
      iconTheme: IconThemeData(color: AppColors.darkIcon),
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: const TextStyle(color: AppColors.darkIcon),
    ),
  );
}
