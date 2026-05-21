import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════
// OBSIDIAN FLOW — Deep Space Design System
// A premium glassmorphic messenger UI
// ═══════════════════════════════════════════════════════════

class AppColors {
  // ── Surface Colors ────────────────────────────────────
  static const Color surface = Color(0xFF0b1326);
  static const Color surfaceDim = Color(0xFF0b1326);
  static const Color surfaceBright = Color(0xFF31394d);
  static const Color surfaceContainerLowest = Color(0xFF060e20);
  static const Color surfaceContainerLow = Color(0xFF131b2e);
  static const Color surfaceContainer = Color(0xFF171f33);
  static const Color surfaceContainerHigh = Color(0xFF222a3d);
  static const Color surfaceContainerHighest = Color(0xFF2d3449);
  static const Color surfaceVariant = Color(0xFF2d3449);

  static const Color onSurface = Color(0xFFdae2fd);
  static const Color onSurfaceVariant = Color(0xFFc1c8c7);
  static const Color inverseSurface = Color(0xFFdae2fd);
  static const Color inverseOnSurface = Color(0xFF283044);

  // ── Primary (Deep Teal) ───────────────────────────────
  static const Color primary = Color(0xFFaccdcc);
  static const Color onPrimary = Color(0xFF163535);
  static const Color primaryContainer = Color(0xFF0d2d2d);
  static const Color onPrimaryContainer = Color(0xFF769595);
  static const Color primaryFixed = Color(0xFFc8e9e8);
  static const Color primaryFixedDim = Color(0xFFaccdcc);
  static const Color onPrimaryFixed = Color(0xFF002020);
  static const Color onPrimaryFixedVariant = Color(0xFF2e4c4c);
  static const Color inversePrimary = Color(0xFF456463);

  // ── Secondary (Cyan/Teal Accent) ──────────────────────
  static const Color secondary = Color(0xFF4fdbc8);
  static const Color onSecondary = Color(0xFF003731);
  static const Color secondaryContainer = Color(0xFF04b4a2);
  static const Color onSecondaryContainer = Color(0xFF003f38);
  static const Color secondaryFixed = Color(0xFF71f8e4);
  static const Color secondaryFixedDim = Color(0xFF4fdbc8);
  static const Color onSecondaryFixed = Color(0xFF00201c);
  static const Color onSecondaryFixedVariant = Color(0xFF005048);

  // ── Tertiary (Rose) ───────────────────────────────────
  static const Color tertiary = Color(0xFFffb2b7);
  static const Color onTertiary = Color(0xFF67001b);
  static const Color tertiaryContainer = Color(0xFF580016);
  static const Color onTertiaryContainer = Color(0xFFff4d68);
  static const Color tertiaryFixed = Color(0xFFffdadb);
  static const Color tertiaryFixedDim = Color(0xFFffb2b7);
  static const Color onTertiaryFixed = Color(0xFF40000d);
  static const Color onTertiaryFixedVariant = Color(0xFF92002a);

  // ── Error ─────────────────────────────────────────────
  static const Color error = Color(0xFFffb4ab);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000a);
  static const Color onErrorContainer = Color(0xFFffdad6);

  // ── Outline ───────────────────────────────────────────
  static const Color outline = Color(0xFF8b9292);
  static const Color outlineVariant = Color(0xFF414848);

  // ── Background ─────────────────────────────────────────
  static const Color background = Color(0xFF0b1326);
  static const Color onBackground = Color(0xFFdae2fd);

  // ── Glassmorphism ─────────────────────────────────────
  static const Color glassBg = Color(0x992d3449);
  static const Color glassBorder = Color(0x1AFFFFFF);
  static const Color glassInnerGlow = Color(0x0DFFFFFF);

  // ── Legacy Aliases (backward compat) ──────────────────
  static const Color primaryGreen = primary;
  static const Color accentGreen = secondary;
  static const Color lightGreen = primary;
  static const Color bgPrimary = surface;
  static const Color bgSecondary = surfaceContainerLow;
  static const Color chatBg = surface;
  static const Color sentBubble = primary;
  static const Color receivedBubble = surfaceContainerHighest;
  static const Color textPrimary = onSurface;
  static const Color textSecondary = onSurfaceVariant;
  static const Color textHint = outline;
  static const Color textWhite = Colors.white;
  static const Color online = secondary;
  static const Color read = secondary;
  static const Color divider = outlineVariant;
  static const Color success = secondary;
  static const Color warning = tertiary;
  static const Color darkBg = surface;
  static const Color darkSurface = surfaceContainer;
  static const Color darkSurfaceLight = surfaceContainerHigh;
  static const Color darkChatBg = surface;
  static const Color darkSentBubble = primary;
  static const Color darkReceivedBubble = surfaceContainerHighest;
  static const Color darkText = onSurface;
  static const Color darkTextSecondary = onSurfaceVariant;
  static const Color darkIcon = outline;
  static const Color darkDivider = outlineVariant;
}

// ═══════════════════════════════════════════════════════════
// OBSIDIAN FLOW THEME
// ═══════════════════════════════════════════════════════════

class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.surface,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onTertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      inverseSurface: AppColors.inverseSurface,
      inversePrimary: AppColors.inversePrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.primary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFamily: 'Hanken Grotesk',
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: AppColors.secondary,
      labelColor: AppColors.secondary,
      unselectedLabelColor: AppColors.onSurfaceVariant,
      indicatorSize: TabBarIndicatorSize.tab,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceContainerLow,
      selectedItemColor: AppColors.secondary,
      unselectedItemColor: AppColors.onSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.secondary,
      foregroundColor: AppColors.onSecondary,
      elevation: 4,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceVariant.withAlpha(100),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: AppColors.secondary, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.outline),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.onSecondary,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Hanken Grotesk'),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.secondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.outlineVariant,
      thickness: 0.5,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceContainerHigh,
      labelStyle: const TextStyle(color: AppColors.onSurface, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.glassBg,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.secondary,
      inactiveTrackColor: AppColors.outlineVariant,
      thumbColor: AppColors.secondary,
      overlayColor: AppColors.secondary.withAlpha(30),
    ),
  );

  // Light theme maps to same dark scheme for consistency
  static ThemeData get light => dark;
}
