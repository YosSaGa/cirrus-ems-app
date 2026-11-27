import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists client-side app preferences (haptic feedback and new job alerts)
/// in `SharedPreferences` with live `ValueNotifier` updates.
class AppPreferencesService {
  static const String _hapticsKey = 'ems.pref.hapticsEnabled';
  static const String _jobAlertsKey = 'ems.pref.jobAlertsEnabled';

  static final ValueNotifier<bool> hapticsEnabledNotifier = ValueNotifier<bool>(
    true,
  );
  static final ValueNotifier<bool> jobAlertsEnabledNotifier =
      ValueNotifier<bool>(true);

  static bool get hapticsEnabled => hapticsEnabledNotifier.value;
  static bool get jobAlertsEnabled => jobAlertsEnabledNotifier.value;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    hapticsEnabledNotifier.value = prefs.getBool(_hapticsKey) ?? true;
    jobAlertsEnabledNotifier.value = prefs.getBool(_jobAlertsKey) ?? true;
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

  @visibleForTesting
  static void debugReset() {
    hapticsEnabledNotifier.value = true;
    jobAlertsEnabledNotifier.value = true;
  }
}
