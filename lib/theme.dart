import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────
// COLORS
// ─────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  static const Color white       = Color(0xFFFFFFFF);
  static const Color bg          = Color(0xFFF5F5F5);
  static const Color panel       = Color(0xFFFFFFFF);
  static const Color border      = Color(0xFFE0E0E0);
  static const Color accent      = Color(0xFF2B7A0B);
  static const Color accentLight = Color(0xFFEBF5E6);
  static const Color sentMsg     = Color(0xFF3797F0);
  static const Color recvMsg     = Color(0xFFFFFFFF);
  static const Color textDark    = Color(0xFF1C1C1C);
  static const Color textWhite   = Color(0xFFFFFFFF);
  static const Color textGrey    = Color(0xFF666666);
  static const Color textHint    = Color(0xFFAAAAAA);
  static const Color danger      = Color(0xFFD32F2F);
  static const Color online      = Color(0xFF2B7A0B);

  // Sidebar
  static const Color sidebarBg     = Color(0xFF1E2A1C);
  static const Color sidebarIcon   = Color(0xFF9AB895);
  static const Color sidebarActive = Color(0xFF2B7A0B);

  // Utility
  static const Color shadow = Color(0x14000000);
  static const Color overlay = Color(0x80000000);
}

// ─────────────────────────────────────────────────────
// TEXT STYLES  (Plus Jakarta Sans via Google Fonts)
// ─────────────────────────────────────────────────────
class AppText {
  AppText._();

  static TextStyle _font({double? fontSize, FontWeight? fontWeight, Color? color, double? height}) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  /// 13px — standard body text
  static TextStyle get body => _font(fontSize: 13, color: AppColors.textDark, height: 1.4);

  /// 13px — grey secondary text
  static TextStyle get bodyGrey => _font(fontSize: 13, color: AppColors.textGrey, height: 1.4);

  /// 13px — hint/placeholder text
  static TextStyle get hint => _font(fontSize: 13, color: AppColors.textHint);

  /// 15px semi-bold — names / chat titles
  static TextStyle get name => _font(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark, height: 1.2);

  /// 11px — timestamps, badges
  static TextStyle get timestamp => _font(fontSize: 11, color: AppColors.textHint, height: 1.2);

  /// 11px grey — captions
  static TextStyle get caption => _font(fontSize: 11, color: AppColors.textGrey);

  /// 16px semi-bold — panel titles, section headers
  static TextStyle get title => _font(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark);

  /// 20px bold — screen/card headings
  static TextStyle get heading => _font(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark);

  /// Button label (white, 14px semi-bold)
  static TextStyle get button => _font(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.white);

  /// Accent colored link
  static TextStyle get link => _font(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w500);

  /// Helper to create custom text styles
  static TextStyle custom({double? fontSize, FontWeight? fontWeight, Color? color, double? height}) {
    return _font(fontSize: fontSize, fontWeight: fontWeight, color: color, height: height);
  }
}

// ─────────────────────────────────────────────────────
// DECORATION HELPERS
// ─────────────────────────────────────────────────────
class AppDeco {
  AppDeco._();

  /// Flat panel with border (no radius — for full-height panels)
  static BoxDecoration panel = const BoxDecoration(
    color: AppColors.panel,
  );

  /// Card with border, radius=8, subtle shadow
  static BoxDecoration card = BoxDecoration(
    color: AppColors.white,
    border: Border.all(color: AppColors.border),
    borderRadius: BorderRadius.circular(8),
    boxShadow: const [
      BoxShadow(
        color: AppColors.shadow,
        blurRadius: 4,
        offset: Offset(0, 1),
      ),
    ],
  );

  /// Input field container
  static BoxDecoration input = BoxDecoration(
    color: AppColors.white,
    border: Border.all(color: AppColors.border),
    borderRadius: BorderRadius.circular(6),
  );

  /// Focused input field container
  static BoxDecoration inputFocused = BoxDecoration(
    color: AppColors.white,
    border: Border.all(color: AppColors.accent, width: 1.5),
    borderRadius: BorderRadius.circular(6),
  );

  /// Sent message bubble — Instagram blue, compact
  static BoxDecoration sentBubble = BoxDecoration(
    color: AppColors.sentMsg,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: Color(0xFF2E7DC6), width: 0.5),
  );

  /// Received message bubble — white, subtle border
  static BoxDecoration recvBubble = BoxDecoration(
    color: AppColors.recvMsg,
    border: Border.all(color: AppColors.border, width: 0.5),
    borderRadius: BorderRadius.circular(14),
    boxShadow: const [
      BoxShadow(
        color: AppColors.shadow,
        blurRadius: 1.5,
        offset: Offset(0, 0.5),
      ),
    ],
  );

  /// Accent-filled button container
  static BoxDecoration accentButton = BoxDecoration(
    color: AppColors.accent,
    borderRadius: BorderRadius.circular(6),
  );

  /// Danger-filled button container
  static BoxDecoration dangerButton = BoxDecoration(
    color: AppColors.danger,
    borderRadius: BorderRadius.circular(6),
  );
}

// ─────────────────────────────────────────────────────
// SHARED SIZES
// ─────────────────────────────────────────────────────
class AppSizes {
  AppSizes._();

  static const double sidebarWidth  = 56.0;
  static const double chatListWidth = 320.0;
  static const double headerHeight  = 56.0;
  static const double inputBarHeight = 60.0;
  static const double avatarMd      = 40.0;
  static const double avatarLg      = 48.0;
  static const double avatarXl      = 96.0;
  static const double chatItemHeight = 64.0;
  static const double borderWidth    = 1.0;
  static const double radius         = 8.0;
  static const double radiusSm       = 6.0;
}

// ─────────────────────────────────────────────────────
// THEME DATA
// ─────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.accent,
      surface: AppColors.panel,
      onSurface: AppColors.textDark,
      error: AppColors.danger,
    ),
    dividerColor: AppColors.border,
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      hintStyle: AppText.hint,
      labelStyle: AppText.bodyGrey,
      isDense: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.border,
        disabledForegroundColor: AppColors.textHint,
        minimumSize: const Size(double.infinity, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        elevation: 0,
        textStyle: AppText.button,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accent,
        side: const BorderSide(color: AppColors.accent),
        minimumSize: const Size(double.infinity, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textGrey,
        highlightColor: AppColors.accentLight,
      ),
    ),
    iconTheme: const IconThemeData(
      color: AppColors.textGrey,
      size: 20,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.panel,
      foregroundColor: AppColors.textDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ),
      iconTheme: IconThemeData(color: AppColors.textGrey, size: 20),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 0,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.accent;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(AppColors.white),
      side: const BorderSide(color: AppColors.border, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.white;
        return AppColors.textHint;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.accent;
        return AppColors.border;
      }),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.accent,
      thumbColor: AppColors.accent,
      inactiveTrackColor: AppColors.border,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textDark,
      contentTextStyle: AppText.body.copyWith(color: AppColors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.textDark,
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: AppText.caption.copyWith(color: AppColors.white),
      waitDuration: const Duration(milliseconds: 500),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      titleTextStyle: AppText.title,
      contentTextStyle: AppText.body,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: AppColors.border),
      ),
      textStyle: AppText.body,
    ),
  );

  // The design is light-only per spec — dark returns same theme
  static ThemeData get dark => light;
}

// ─────────────────────────────────────────────────────
// CONVENIENCE EXTENSION — fade animation builder
// ─────────────────────────────────────────────────────
extension FadeRoute on Widget {
  Widget fadeIn(Animation<double> animation) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: this,
      );
}
