import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported UI display languages.
///
/// Switching language only affects presentation text and typography; backend
/// payloads, stored leave types, and payroll calculations remain unchanged.
enum AppLanguage {
  en('en', 'English', 'English (US)', 'Default interface language with Bebas Neue headings'),
  th('th', 'ภาษาไทย', 'ภาษาไทย (Thai)', 'อินเทอร์เฟซภาษาไทยพร้อมฟอนต์ IBM Plex Sans Thai'),
  ms('ms', 'Bahasa Melayu', 'Bahasa Melayu (Malay)', 'Antara muka Bahasa Melayu');

  const AppLanguage(this.code, this.nativeName, this.displayName, this.description);

  final String code;
  final String nativeName;
  final String displayName;
  final String description;

  static AppLanguage fromCode(String? code) {
    switch (code) {
      case 'th':
        return AppLanguage.th;
      case 'ms':
        return AppLanguage.ms;
      case 'en':
      default:
        return AppLanguage.en;
    }
  }
}

/// Service managing the application's active display language and persistence.
class LanguageService {
  LanguageService._();

  static const String _prefKey = 'ems.language';

  /// ValueNotifier holding the current display language.
  static final ValueNotifier<AppLanguage> languageNotifier =
      ValueNotifier<AppLanguage>(AppLanguage.en);

  /// Current active display language.
  static AppLanguage get currentLanguage => languageNotifier.value;

  /// Convenience check for Thai mode.
  static bool get isThai => languageNotifier.value == AppLanguage.th;

  /// Convenience check for Malay mode.
  static bool get isMalay => languageNotifier.value == AppLanguage.ms;

  /// Loads saved language preference from [SharedPreferences].
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefKey);
      languageNotifier.value = AppLanguage.fromCode(savedCode);
    } catch (_) {
      languageNotifier.value = AppLanguage.en;
    }
  }

  /// Updates and persists the display language.
  static Future<void> setLanguage(AppLanguage language) async {
    languageNotifier.value = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, language.code);
    } catch (_) {
      // Ignored in transient or test environments.
    }
  }

  /// Resets language to default English (useful for unit tests).
  @visibleForTesting
  static void debugReset() {
    languageNotifier.value = AppLanguage.en;
  }
}
