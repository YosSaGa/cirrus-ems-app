import 'package:flutter/material.dart';

import '../services/language_service.dart';
import '../services/theme_service.dart';

/// Palette defining all semantic colors for a theme mode.
class AppThemePalette {
  const AppThemePalette({
    required this.brightness,
    required this.primary,
    required this.surface,
    required this.neutral,
    required this.secondary,
    required this.onNeutralMuted,
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.error,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.info,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.disabledForeground,
    required this.disabledBackground,
    required this.cardBorder,
    required this.textSecondary,
    required this.ambientGradientStart,
    required this.ambientGradientEnd,
    required this.bottomNavBubble,
    required this.bottomNavIcon,
    required this.timeActionForeground,
    required this.onNeutral,
    required this.roleBadgeBackground,
    required this.roleBadgeForeground,
    required this.roleBadgeIcon,
    required this.avatarBackground,
    required this.avatarForeground,
    required this.sideNavBackground,
    required this.splashBackground,
    required this.bottomNavShadow,
  });

  final Brightness brightness;
  final Color primary;
  final Color surface;
  final Color neutral;
  final Color secondary;
  final Color onNeutralMuted;
  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color error;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color info;
  final Color infoContainer;
  final Color onInfoContainer;
  final Color disabledForeground;
  final Color disabledBackground;
  final Color cardBorder;
  final Color textSecondary;
  final Color ambientGradientStart;
  final Color ambientGradientEnd;
  final Color bottomNavBubble;
  final Color bottomNavIcon;
  final Color timeActionForeground;
  final Color onNeutral;
  final Color roleBadgeBackground;
  final Color roleBadgeForeground;
  final Color roleBadgeIcon;
  final Color avatarBackground;
  final Color avatarForeground;
  final Color sideNavBackground;
  final Color splashBackground;
  final Color bottomNavShadow;

  /// Signature Cirrus theme: Navy 30% / Off-white 60% / Teal 10%
  static const AppThemePalette defaultPalette = AppThemePalette(
    brightness: Brightness.light,
    primary: Color(0xFFF3F6F7),
    surface: Color(0xFFFAFCFC),
    neutral: Color(0xFF102D40),
    secondary: Color(0xFF32D5C0),
    onNeutralMuted: Color(0xFFBED0D8),
    success: Color(0xFF187647),
    successContainer: Color(0xFFE3F6EA),
    onSuccessContainer: Color(0xFF14401E),
    warning: Color(0xFFA35B0A),
    warningContainer: Color(0xFFFEF1DC),
    onWarningContainer: Color(0xFF5C3300),
    error: Color(0xFFDC2626),
    errorContainer: Color(0xFFFDE8E8),
    onErrorContainer: Color(0xFF7A1212),
    info: Color(0xFF64748B),
    infoContainer: Color(0xFFEDF2F6),
    onInfoContainer: Color(0xFF32404D),
    disabledForeground: Color(0xFF6B7A86),
    disabledBackground: Color(0xFFE8EEF0),
    cardBorder: Color(0xFFDFE8EC),
    textSecondary: Color(0xFF536575),
    ambientGradientStart: Color(0xFF102D40),
    ambientGradientEnd: Color(0xFF183B52),
    bottomNavBubble: Color(0xFF102D40),
    bottomNavIcon: Color(0xFF32D5C0),
    timeActionForeground: Color(0xFF102D40),
    onNeutral: Colors.white,
    roleBadgeBackground: Color(0xFF102D40),
    roleBadgeForeground: Colors.white,
    roleBadgeIcon: Color(0xFF32D5C0),
    avatarBackground: Color(0xFF102D40),
    avatarForeground: Color(0xFF32D5C0),
    sideNavBackground: Color(0xFF102D40),
    splashBackground: Color(0xFF102D40),
    bottomNavShadow: Color(0x1F102D40),
  );

  /// Pure White theme: Clean minimalist slate & pure crisp canvas
  static const AppThemePalette whitePalette = AppThemePalette(
    brightness: Brightness.light,
    primary: Color(0xFFFFFFFF),
    surface: Color(0xFFF8FAFC),
    neutral: Color(0xFF0F172A),
    secondary: Color(0xFF0EA5E9),
    onNeutralMuted: Color(0xFF94A3B8),
    success: Color(0xFF15803D),
    successContainer: Color(0xFFDCFCE7),
    onSuccessContainer: Color(0xFF14532D),
    warning: Color(0xFFB45309),
    warningContainer: Color(0xFFFEF3C7),
    onWarningContainer: Color(0xFF78350F),
    error: Color(0xFFDC2626),
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF7F1D1D),
    info: Color(0xFF64748B),
    infoContainer: Color(0xFFF1F5F9),
    onInfoContainer: Color(0xFF334155),
    disabledForeground: Color(0xFF94A3B8),
    disabledBackground: Color(0xFFF1F5F9),
    cardBorder: Color(0xFFE2E8F0),
    textSecondary: Color(0xFF64748B),
    ambientGradientStart: Color(0xFF0F172A),
    ambientGradientEnd: Color(0xFF1E293B),
    bottomNavBubble: Color(0xFF0F172A),
    bottomNavIcon: Color(0xFF0EA5E9),
    timeActionForeground: Color(0xFF0F172A),
    onNeutral: Colors.white,
    roleBadgeBackground: Color(0xFF0F172A),
    roleBadgeForeground: Colors.white,
    roleBadgeIcon: Color(0xFF0EA5E9),
    avatarBackground: Color(0xFF0F172A),
    avatarForeground: Color(0xFF0EA5E9),
    sideNavBackground: Color(0xFF0F172A),
    splashBackground: Color(0xFF0F172A),
    bottomNavShadow: Color(0x140F172A),
  );

  /// Obsidian Black theme: OLED deep pitch black & glowing neon teal
  static const AppThemePalette blackPalette = AppThemePalette(
    brightness: Brightness.dark,
    primary: Color(0xFF0B1118),
    surface: Color(0xFF151E28),
    neutral: Color(0xFFF1F5F9),
    secondary: Color(0xFF2DD4BF),
    onNeutralMuted: Color(0xFF64748B),
    success: Color(0xFF22C55E),
    successContainer: Color(0xFF143823),
    onSuccessContainer: Color(0xFF86EFAC),
    warning: Color(0xFFF59E0B),
    warningContainer: Color(0xFF3B2507),
    onWarningContainer: Color(0xFFFDE68A),
    error: Color(0xFFEF4444),
    errorContainer: Color(0xFF3B1212),
    onErrorContainer: Color(0xFFFCA5A5),
    info: Color(0xFF94A3B8),
    infoContainer: Color(0xFF1E293B),
    onInfoContainer: Color(0xFFCBD5E1),
    disabledForeground: Color(0xFF475569),
    disabledBackground: Color(0xFF1E293B),
    cardBorder: Color(0xFF223140),
    textSecondary: Color(0xFF94A3B8),
    ambientGradientStart: Color(0xFF141D26),
    ambientGradientEnd: Color(0xFF1D2936),
    bottomNavBubble: Color(0xFF2DD4BF),
    bottomNavIcon: Color(0xFF0B1118),
    timeActionForeground: Color(0xFF0B1118),
    onNeutral: Color(0xFF0B1118),
    roleBadgeBackground: Color(0xFF1E2D3D),
    roleBadgeForeground: Color(0xFFF1F5F9),
    roleBadgeIcon: Color(0xFF2DD4BF),
    avatarBackground: Color(0xFF141D26),
    avatarForeground: Color(0xFF2DD4BF),
    sideNavBackground: Color(0xFF151E28),
    splashBackground: Color(0xFF0B1118),
    bottomNavShadow: Color(0x66000000),
  );

  static AppThemePalette forMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.white:
        return whitePalette;
      case AppThemeMode.black:
        return blackPalette;
      case AppThemeMode.defaultTheme:
        return defaultPalette;
    }
  }
}

/// Shared Cirrus visual language.
///
/// Returns colors dynamically based on [ThemeService.currentMode].
class AppColors {
  AppColors._();

  static AppThemePalette get current =>
      AppThemePalette.forMode(ThemeService.currentMode);

  static Color get primary => current.primary;
  static Color get surface => current.surface;
  static Color get neutral => current.neutral;
  static Color get secondary => current.secondary;
  static Color get onNeutralMuted => current.onNeutralMuted;
  static Color get success => current.success;
  static Color get successContainer => current.successContainer;
  static Color get onSuccessContainer => current.onSuccessContainer;
  static Color get warning => current.warning;
  static Color get warningContainer => current.warningContainer;
  static Color get onWarningContainer => current.onWarningContainer;
  static Color get error => current.error;
  static Color get errorContainer => current.errorContainer;
  static Color get onErrorContainer => current.onErrorContainer;
  static Color get info => current.info;
  static Color get infoContainer => current.infoContainer;
  static Color get onInfoContainer => current.onInfoContainer;
  static Color get disabledForeground => current.disabledForeground;
  static Color get disabledBackground => current.disabledBackground;
  static Color get cardBorder => current.cardBorder;
  static Color get textSecondary => current.textSecondary;
  static Color get ambientGradientStart => current.ambientGradientStart;
  static Color get ambientGradientEnd => current.ambientGradientEnd;
  static Color get bottomNavBubble => current.bottomNavBubble;
  static Color get bottomNavIcon => current.bottomNavIcon;
  static Color get timeActionForeground => current.timeActionForeground;
  static Color get onNeutral => current.onNeutral;
  static Color get roleBadgeBackground => current.roleBadgeBackground;
  static Color get roleBadgeForeground => current.roleBadgeForeground;
  static Color get roleBadgeIcon => current.roleBadgeIcon;
  static Color get avatarBackground => current.avatarBackground;
  static Color get avatarForeground => current.avatarForeground;
  static Color get sideNavBackground => current.sideNavBackground;
  static Color get splashBackground => current.splashBackground;
  static Color get bottomNavShadow => current.bottomNavShadow;
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double hero = 48;
}

class AppRadius {
  AppRadius._();
  static const double pill = 999;
  static const double hero = 28;
  static const double surface = 24;
  static const double input = 16;
}

class AppBreakpoints {
  AppBreakpoints._();
  static const double tablet = 600;
  static const double desktop = 900;
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;
}

double appContentMaxWidth(BuildContext context) {
  if (AppBreakpoints.isDesktop(context)) return 640;
  if (AppBreakpoints.isTablet(context)) return 560;
  return double.infinity;
}

/// Bottom padding that clears the floating navigation bar on tab screens.
const double appBottomNavClearance = 112;

/// Same clearance, but desktop tabs use the side rail and need less room.
/// Includes bottom system gesture inset so scrolled content clears the
/// floating bubble of AppBottomNav when Scaffold.extendBody is true.
double appTabBottomPadding(BuildContext context) =>
    AppBreakpoints.isDesktop(context)
        ? AppSpacing.xxl
        : appBottomNavClearance + MediaQuery.paddingOf(context).bottom + 24;

List<BoxShadow> get appCtaShadow => [
  BoxShadow(
    color: AppColors.neutral.withValues(alpha: 0.06),
    blurRadius: 8,
    offset: const Offset(0, 2),
  ),
];

class AppTheme {
  AppTheme._();

  static ThemeData light() => forMode(
        ThemeService.currentMode,
        language: LanguageService.currentLanguage,
      );

  static ThemeData forMode(AppThemeMode mode, {AppLanguage? language}) {
    final palette = AppThemePalette.forMode(mode);
    final isThai = (language ?? LanguageService.currentLanguage) == AppLanguage.th;
    final primaryFont = isThai ? 'IBMPlexSansThai' : 'BebasNeue';
    final fallbackFonts = isThai
        ? const ['BebasNeue', 'Sarabun']
        : const ['IBMPlexSansThai', 'Sarabun'];
    final textTheme = _textTheme(palette, isThai: isThai).apply(
      fontFamily: primaryFont,
      fontFamilyFallback: fallbackFonts,
    );

    final colorScheme = ColorScheme(
      brightness: palette.brightness,
      primary: palette.neutral,
      onPrimary: palette.onNeutral,
      secondary: palette.secondary,
      onSecondary: palette.neutral,
      surface: palette.surface,
      onSurface: palette.neutral,
      onSurfaceVariant: palette.textSecondary,
      outline: palette.cardBorder,
      error: palette.error,
      onError: Colors.white,
      errorContainer: palette.errorContainer,
      onErrorContainer: palette.onErrorContainer,
    );

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.input)),
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.input),
      borderSide: BorderSide(color: palette.cardBorder),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: primaryFont,
      fontFamilyFallback: fallbackFonts,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.primary,
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SlideFadePageTransitionsBuilder(),
          TargetPlatform.iOS: _SlideFadePageTransitionsBuilder(),
          TargetPlatform.windows: _SlideFadePageTransitionsBuilder(),
          TargetPlatform.macOS: _SlideFadePageTransitionsBuilder(),
          TargetPlatform.linux: _SlideFadePageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.primary,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.neutral,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: palette.neutral),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.surface),
          side: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        side: BorderSide(color: palette.cardBorder),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      dividerTheme: DividerThemeData(
        color: palette.cardBorder,
        thickness: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.neutral,
          foregroundColor: palette.onNeutral,
          disabledBackgroundColor: palette.disabledBackground,
          disabledForegroundColor: palette.disabledForeground,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge,
          shape: controlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.neutral,
          side: BorderSide(color: palette.cardBorder),
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: textTheme.labelLarge,
          shape: controlShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.neutral,
          minimumSize: const Size(48, 48),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: palette.neutral, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: palette.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: palette.error, width: 1.5),
        ),
        labelStyle: textTheme.bodyMedium,
        floatingLabelStyle: textTheme.bodySmall,
        helperStyle: textTheme.bodySmall,
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: palette.neutral,
        unselectedLabelColor: palette.textSecondary,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.bodyMedium,
        indicatorColor: palette.secondary,
        dividerColor: palette.cardBorder,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.secondary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.neutral,
        selectionColor: palette.secondary.withValues(alpha: 0.25),
        selectionHandleColor: palette.neutral,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.neutral,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: palette.onNeutral,
        ),
        behavior: SnackBarBehavior.floating,
        shape: controlShape,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  static TextTheme _textTheme(
    AppThemePalette palette, {
    required bool isThai,
  }) {
    final ls = isThai ? 0.0 : 0.6;
    final lsLabelSmall = isThai ? 0.2 : 1.1;
    return TextTheme(
      displayLarge: TextStyle(letterSpacing: ls),
      displaySmall: TextStyle(letterSpacing: ls),
      headlineLarge: TextStyle(letterSpacing: ls),
      headlineMedium: TextStyle(letterSpacing: ls),
      titleSmall: TextStyle(letterSpacing: ls),
      displayMedium: TextStyle(
        fontSize: isThai ? 38 : 48,
        fontWeight: FontWeight.w700,
        color: palette.neutral,
        letterSpacing: ls,
        height: isThai ? 1.2 : null,
      ),
      headlineSmall: TextStyle(
        fontSize: isThai ? 21 : 26,
        fontWeight: FontWeight.w700,
        color: palette.neutral,
        letterSpacing: ls,
        height: isThai ? 1.35 : 1.3,
      ),
      titleLarge: TextStyle(
        fontSize: isThai ? 18 : 22,
        fontWeight: FontWeight.w700,
        color: palette.neutral,
        letterSpacing: ls,
        height: isThai ? 1.4 : 1.35,
      ),
      titleMedium: TextStyle(
        letterSpacing: ls,
        fontSize: isThai ? 15 : 16,
        fontWeight: FontWeight.w600,
        color: palette.neutral,
        height: isThai ? 1.45 : 1.4,
      ),
      labelSmall: TextStyle(
        fontSize: isThai ? 11 : 12,
        fontWeight: FontWeight.w700,
        color: palette.textSecondary,
        letterSpacing: lsLabelSmall,
        height: isThai ? 1.45 : 1.4,
      ),
      bodyLarge: TextStyle(
        letterSpacing: ls,
        fontSize: isThai ? 14.5 : 15,
        fontWeight: FontWeight.w500,
        color: palette.neutral,
        height: isThai ? 1.55 : 1.5,
      ),
      bodyMedium: TextStyle(
        letterSpacing: ls,
        fontSize: isThai ? 13.5 : 14,
        fontWeight: FontWeight.w400,
        color: palette.textSecondary,
        height: isThai ? 1.55 : 1.5,
      ),
      bodySmall: TextStyle(
        letterSpacing: ls,
        fontSize: isThai ? 12.5 : 13,
        fontWeight: FontWeight.w400,
        color: palette.textSecondary,
        height: isThai ? 1.5 : 1.45,
      ),
      labelLarge: TextStyle(
        letterSpacing: ls,
        fontSize: isThai ? 14 : 15,
        fontWeight: FontWeight.w600,
        height: isThai ? 1.35 : 1.3,
      ),
      labelMedium: TextStyle(
        letterSpacing: ls,
        fontSize: isThai ? 12 : 13,
        fontWeight: FontWeight.w600,
        color: palette.textSecondary,
        height: isThai ? 1.45 : 1.4,
      ),
    );
  }
}

class _SlideFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _SlideFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
