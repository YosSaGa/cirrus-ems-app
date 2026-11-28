import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists client-side app preferences (haptic feedback and new job alerts)
/// in `SharedPreferences` with live `ValueNotifier` updates.
class AppPreferencesService {
  static const String _hapticsKey = 'ems.pref.hapticsEnabled';
  static const String _jobAlertsKey = 'ems.pref.jobAlertsEnabled';
  static const String _soundEffectsKey = 'ems.pref.soundEffectsEnabled';

  static final ValueNotifier<bool> hapticsEnabledNotifier = ValueNotifier<bool>(
    true,
  );
  static final ValueNotifier<bool> jobAlertsEnabledNotifier =
      ValueNotifier<bool>(true);
  static final ValueNotifier<bool> soundEffectsEnabledNotifier =
      ValueNotifier<bool>(true);

  static bool get hapticsEnabled => hapticsEnabledNotifier.value;
  static bool get jobAlertsEnabled => jobAlertsEnabledNotifier.value;
  static bool get soundEffectsEnabled => soundEffectsEnabledNotifier.value;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    hapticsEnabledNotifier.value = prefs.getBool(_hapticsKey) ?? true;
    jobAlertsEnabledNotifier.value = prefs.getBool(_jobAlertsKey) ?? true;
    soundEffectsEnabledNotifier.value = prefs.getBool(_soundEffectsKey) ?? true;
  }

  static Future<void> setHapticsEnabled(bool enabled) async {
    if (hapticsEnabledNotifier.value == enabled) return;
    hapticsEnabledNotifier.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticsKey, enabled);
  }

  static Future<void> setJobAlertsEnabled(bool enabled) async {
    if (jobAlertsEnabledNotifier.value == enabled) return;
    jobAlertsEnabledNotifier.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_jobAlertsKey, enabled);
  }

  static Future<void> setSoundEffectsEnabled(bool enabled) async {
    if (soundEffectsEnabledNotifier.value == enabled) return;
    soundEffectsEnabledNotifier.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEffectsKey, enabled);
  }

  @visibleForTesting
  static void debugReset() {
    hapticsEnabledNotifier.value = true;
    jobAlertsEnabledNotifier.value = true;
    soundEffectsEnabledNotifier.value = true;
  }
}
