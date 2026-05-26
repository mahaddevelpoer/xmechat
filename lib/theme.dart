import 'package:flutter/material.dart';

const String kFontFamily = 'Segoe UI';

class AppColors {
  AppColors._();

  static const Color bg = Color(0xFFF7F7F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E2E2);
  static const Color accent = Color(0xFF1A7F4B);
  static const Color accentLight = Color(0xFFE8F5EE);
  static const Color sentBubble = Color(0xFFE8F5EE);
  static const Color recvBubble = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF5A5A5A);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color danger = Color(0xFFC62828);
  static const Color online = Color(0xFF1A7F4B);
  static const Color callBg = Color(0xFF0F2318);
}

class AppText {
  AppText._();

  static const TextStyle _base = TextStyle(fontFamily: kFontFamily);

  static TextStyle get heading => _base.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static TextStyle get panelTitle => _base.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle get name => _base.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle get message => _base.copyWith(fontSize: 13.5, fontWeight: FontWeight.w400, color: AppColors.textPrimary);
  static TextStyle get preview => _base.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary);
  static TextStyle get timestamp => _base.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textHint);
  static TextStyle get label => _base.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5);
  static TextStyle get button => _base.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white);
  static TextStyle get sectionHeader => _base.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent, letterSpacing: 0.8);
  static TextStyle get link => _base.copyWith(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w500);
  static TextStyle get chatHeaderName => _base.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle get callName => _base.copyWith(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white);
  static TextStyle get callTimer => _base.copyWith(fontFamily: 'Segoe UI', fontSize: 13, color: Colors.white70);
}

class AppSizes {
  AppSizes._();

  static const double iconRail = 56.0;
  static const double chatList = 320.0;
  static const double headerHeight = 56.0;
  static const double chatItemHeight = 68.0;
  static const double inputBarMinHeight = 60.0;
  static const double avatarList = 44.0;
  static const double avatarHeader = 36.0;
  static const double avatarCall = 100.0;
  static const double iconBtn = 36.0;
  static const double iconSize = 20.0;
  static const double radius = 6.0;
  static const double radiusSm = 4.0;
  static const double radiusMsg = 14.0;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: kFontFamily,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bg,
    dividerColor: AppColors.border,
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radius), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radius), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radius), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radius), borderSide: const BorderSide(color: AppColors.danger)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radius), borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
      hintStyle: AppText.timestamp,
      labelStyle: AppText.preview,
      isDense: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.border,
        disabledForegroundColor: AppColors.textHint,
        minimumSize: const Size(double.infinity, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusSm)),
        elevation: 0,
        textStyle: AppText.button,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accent,
        side: const BorderSide(color: AppColors.accent),
        minimumSize: const Size(double.infinity, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusSm)),
        textStyle: AppText.button.copyWith(color: AppColors.accent),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: AppText.link,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        minimumSize: const Size(AppSizes.iconBtn, AppSizes.iconBtn),
        iconSize: AppSizes.iconSize,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    iconTheme: const IconThemeData(color: AppColors.textSecondary, size: AppSizes.iconSize),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return AppColors.textHint;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.accent;
        return AppColors.border;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((_) => Colors.transparent),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.accent,
      thumbColor: AppColors.accent,
      inactiveTrackColor: AppColors.border,
      overlayColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: AppText.preview.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusSm)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(AppSizes.radiusSm)),
      textStyle: AppText.timestamp.copyWith(color: Colors.white),
      waitDuration: const Duration(milliseconds: 500),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
      titleTextStyle: AppText.panelTitle,
      contentTextStyle: AppText.message,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radius), side: const BorderSide(color: AppColors.border)),
      textStyle: AppText.message,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.accent;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: const BorderSide(color: AppColors.border, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.accent),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
  );

  static ThemeData get dark => light;
}
