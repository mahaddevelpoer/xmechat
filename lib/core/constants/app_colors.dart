import 'package:flutter/material.dart';

class AppColors {
  // ── Nova Design System ─────────────────────────────
  // Primary: Deep Indigo → Violet
  static const Color primary = Color(0xFF4A28B0);
  static const Color primaryLight = Color(0xFF7C5CFC);
  static const Color primaryDark = Color(0xFF2D1B69);

  // Accent: Vibrant Coral → Orange
  static const Color accent = Color(0xFFFF6B6B);
  static const Color accentLight = Color(0xFFFF8E53);
  static const Color accentSoft = Color(0xFFFFB088);

  // Gradients
  static const Gradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4A28B0), Color(0xFF7C5CFC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const Gradient accentGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const Gradient bgGradient = LinearGradient(
    colors: [Color(0xFFF8F6FF), Color(0xFFFFF5F3)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const Gradient darkBgGradient = LinearGradient(
    colors: [Color(0xFF0D0B1E), Color(0xFF1A1530)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Backgrounds
  static const Color bgPrimary = Color(0xFFF8F6FF);
  static const Color bgSecondary = Color(0xFFEEEAFF);
  static const Color bgSurface = Color(0xFFFFFFFF);
  static const Color chatBg = Color(0xFFF5F0FF);

  // Bubbles
  static const Color sentBubble = Color(0xFF4A28B0);
  static const Color sentBubbleLight = Color(0xFF7C5CFC);
  static const Color receivedBubble = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF1A1530);
  static const Color textSecondary = Color(0xFF6B6894);
  static const Color textHint = Color(0xFF9D9AB8);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Status
  static const Color online = Color(0xFF2ED573);
  static const Color away = Color(0xFFFFA502);
  static const Color busy = Color(0xFFFF6B6B);
  static const Color read = Color(0xFF7C5CFC);

  // Misc
  static const Color divider = Color(0xFFE8E5F0);
  static const Color error = Color(0xFFFF4757);
  static const Color success = Color(0xFF2ED573);
  static const Color warning = Color(0xFFFFA502);
  static const Color glassBg = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x2AFFFFFF);

  // ── Legacy aliases (backward compat) ───────────────
  static const Color primaryGreen = primary;
  static const Color accentGreen = primaryLight;
  static const Color lightGreen = sentBubble;

  // ── Dark Mode ──────────────────────────────────────
  static const Color darkBg = Color(0xFF0D0B1E);
  static const Color darkSurface = Color(0xFF1A1530);
  static const Color darkSurfaceLight = Color(0xFF252040);
  static const Color darkChatBg = Color(0xFF100D24);
  static const Color darkSentBubble = Color(0xFF4A28B0);
  static const Color darkReceivedBubble = Color(0xFF1A1530);
  static const Color darkText = Color(0xFFE8E5F0);
  static const Color darkTextSecondary = Color(0xFF9D9AB8);
  static const Color darkIcon = Color(0xFF7C78A0);
  static const Color darkDivider = Color(0xFF2A2545);
  static const Color darkGlassBg = Color(0x1AFFFFFF);
  static const Color darkGlassBorder = Color(0x2AFFFFFF);
}

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.bgPrimary,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.bgSurface,
      error: AppColors.error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: AppColors.primary,
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textHint,
      indicatorSize: TabBarIndicatorSize.tab,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.bgSurface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textHint,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textWhite,
      elevation: 4,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.textHint),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textWhite,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 0.5,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.bgSecondary,
      labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.bgSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    primaryColor: AppColors.primaryLight,
    scaffoldBackgroundColor: AppColors.darkBg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryLight,
      secondary: AppColors.accent,
      surface: AppColors.darkSurface,
      error: AppColors.error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.darkText,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.darkText,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: AppColors.primaryLight,
      labelColor: AppColors.primaryLight,
      unselectedLabelColor: AppColors.darkIcon,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: AppColors.primaryLight,
      unselectedItemColor: AppColors.darkIcon,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.darkIcon),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textWhite,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.darkDivider,
      thickness: 0.5,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
