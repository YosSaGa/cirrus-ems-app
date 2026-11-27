import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available app themes.
enum AppThemeMode {
  defaultTheme('default', 'Cirrus Signature', 'Navy 30% • Off-white 60% • Teal 10%'),
  white('white', 'Pure White', 'Minimalist slate & crisp white'),
  black('black', 'Obsidian Black', 'Deep OLED dark & neon teal');

  const AppThemeMode(this.key, this.title, this.description);
  final String key;
  final String title;
  final String description;

  static AppThemeMode fromKey(String? key) {
    switch (key) {
      case 'white':
        return AppThemeMode.white;
      case 'black':
        return AppThemeMode.black;
      case 'default':
      default:
        return AppThemeMode.defaultTheme;
    }
  }
}

/// Curated visual styles for the Pay Wallet Card in Earnings & Leave.
enum PayCardStyle {
  cirrusNavy(
    key: 'cirrus_navy',
    nameEn: 'Cirrus Navy',
    nameTh: 'กรมท่าซีรัส',
    gradientStart: Color(0xFF102D40),
    gradientMid: Color(0xFF0E3D4F),
    gradientEnd: Color(0xFF165666),
    accentColor: Color(0xFF32D5C0),
    swatchColor: Color(0xFF124658),
  ),
  obsidianGold(
    key: 'obsidian_gold',
    nameEn: 'Obsidian Gold',
    nameTh: 'ดำออบซิเดียน-ทอง',
    gradientStart: Color(0xFF13151A),
    gradientMid: Color(0xFF1F222A),
    gradientEnd: Color(0xFF2E271D),
    accentColor: Color(0xFFE8C16F),
    swatchColor: Color(0xFF22252C),
  ),
  emeraldSlate(
    key: 'emerald_slate',
    nameEn: 'Emerald Slate',
    nameTh: 'เขียวมรกต',
    gradientStart: Color(0xFF0B2822),
    gradientMid: Color(0xFF114238),
    gradientEnd: Color(0xFF1A5E4F),
    accentColor: Color(0xFF5EEAD4),
    swatchColor: Color(0xFF145245),
  ),
  midnightIndigo(
    key: 'midnight_indigo',
    nameEn: 'Midnight Indigo',
    nameTh: 'น้ำเงินมิดไนท์',
    gradientStart: Color(0xFF171936),
    gradientMid: Color(0xFF25285A),
    gradientEnd: Color(0xFF3A3270),
    accentColor: Color(0xFF93C5FD),
    swatchColor: Color(0xFF2B2E66),
  ),
  royalBurgundy(
    key: 'royal_burgundy',
    nameEn: 'Royal Burgundy',
    nameTh: 'แดงเบอร์กันดี',
    gradientStart: Color(0xFF33111C),
    gradientMid: Color(0xFF4E1A2A),
    gradientEnd: Color(0xFF6B2437),
    accentColor: Color(0xFFF4A7B9),
    swatchColor: Color(0xFF581D2F),
  );

  const PayCardStyle({
    required this.key,
    required this.nameEn,
    required this.nameTh,
    required this.gradientStart,
    required this.gradientMid,
    required this.gradientEnd,
    required this.accentColor,
    required this.swatchColor,
  });

  final String key;
  final String nameEn;
  final String nameTh;
  final Color gradientStart;
  final Color gradientMid;
  final Color gradientEnd;
  final Color accentColor;
  final Color swatchColor;

  List<Color> get gradientColors => [gradientStart, gradientMid, gradientEnd];

  static PayCardStyle fromKey(String? key) {
    for (final style in PayCardStyle.values) {
      if (style.key == key) return style;
    }
    return PayCardStyle.cirrusNavy;
  }
}

/// User-selectable app text scale options.
enum AppTextScale {
  small('small', 'Small', 'เล็ก', 'Kecil', 0.92),
  normal('normal', 'Normal', 'ปกติ', 'Normal', 1.0),
  large('large', 'Large', 'ใหญ่', 'Besar', 1.12),
  extraLarge('xlarge', 'XL', 'ใหญ่มาก', 'Sangat Besar', 1.24);

  const AppTextScale(
    this.key,
    this.labelEn,
    this.labelTh,
    this.labelMs,
    this.factor,
  );

  final String key;
  final String labelEn;
  final String labelTh;
  final String labelMs;
  final double factor;

  static AppTextScale fromKey(String? key) {
    for (final s in AppTextScale.values) {
      if (s.key == key) return s;
    }
    return AppTextScale.normal;
  }
}

/// Service managing the application's active theme, pay card style, text scale,
/// haptics, and persistence.
class ThemeService {
  ThemeService._();

  static const String _prefKey = 'ems.themeMode';
  static const String _payCardStylePrefKey = 'ems.payCardStyle';
  static const String _textScalePrefKey = 'ems.textScale';
  static const String _hapticsPrefKey = 'ems.hapticsEnabled';

  /// ValueNotifier holding the current theme mode.
  static final ValueNotifier<AppThemeMode> themeModeNotifier =
      ValueNotifier<AppThemeMode>(AppThemeMode.defaultTheme);

  /// ValueNotifier holding the active PayWalletCard color style.
  static final ValueNotifier<PayCardStyle> payCardStyleNotifier =
      ValueNotifier<PayCardStyle>(PayCardStyle.cirrusNavy);

  /// ValueNotifier holding the active text scale preference.
  static final ValueNotifier<AppTextScale> textScaleNotifier =
      ValueNotifier<AppTextScale>(AppTextScale.normal);

  /// ValueNotifier holding whether haptic feedback is enabled.
  static final ValueNotifier<bool> hapticsEnabledNotifier = ValueNotifier<bool>(
    true,
  );

  /// Current active theme mode.
  static AppThemeMode get currentMode => themeModeNotifier.value;

  /// Current active pay card style.
  static PayCardStyle get currentPayCardStyle => payCardStyleNotifier.value;

  /// Current active text scale.
  static AppTextScale get currentTextScale => textScaleNotifier.value;

  /// Whether haptic feedback is currently enabled.
  static bool get hapticsEnabled => hapticsEnabledNotifier.value;

  /// Loads saved appearance preferences from [SharedPreferences].
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      themeModeNotifier.value = AppThemeMode.fromKey(prefs.getString(_prefKey));
      payCardStyleNotifier.value = PayCardStyle.fromKey(
        prefs.getString(_payCardStylePrefKey),
      );
      textScaleNotifier.value = AppTextScale.fromKey(
        prefs.getString(_textScalePrefKey),
      );
      hapticsEnabledNotifier.value = prefs.getBool(_hapticsPrefKey) ?? true;
    } catch (_) {
      themeModeNotifier.value = AppThemeMode.defaultTheme;
      payCardStyleNotifier.value = PayCardStyle.cirrusNavy;
      textScaleNotifier.value = AppTextScale.normal;
      hapticsEnabledNotifier.value = true;
    }
  }

  /// Updates and persists the theme mode.
  static Future<void> setThemeMode(AppThemeMode mode) async {
    themeModeNotifier.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode.key);
    } catch (_) {}
  }

  /// Updates and persists the PayWalletCard color style.
  static Future<void> setPayCardStyle(PayCardStyle style) async {
    payCardStyleNotifier.value = style;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_payCardStylePrefKey, style.key);
    } catch (_) {}
  }

  /// Updates and persists the text scale preference.
  static Future<void> setTextScale(AppTextScale scale) async {
    textScaleNotifier.value = scale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_textScalePrefKey, scale.key);
    } catch (_) {}
  }

  /// Updates and persists the haptic feedback preference.
  static Future<void> setHapticsEnabled(bool enabled) async {
    hapticsEnabledNotifier.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hapticsPrefKey, enabled);
    } catch (_) {}
  }

  /// Resets appearance preferences to defaults (useful for unit tests).
  @visibleForTesting
  static void debugReset() {
    themeModeNotifier.value = AppThemeMode.defaultTheme;
    payCardStyleNotifier.value = PayCardStyle.cirrusNavy;
    textScaleNotifier.value = AppTextScale.normal;
    hapticsEnabledNotifier.value = true;
  }
}
