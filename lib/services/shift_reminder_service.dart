import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and schedules daily local shift scan reminders
/// (07:55 Morning In, 12:00 Lunch Out, 13:00 Afternoon In, 17:00 Evening Out)
/// via Android `AlarmManager`.
class ShiftReminderService {
  static const String _prefKey = 'ems.pref.shiftRemindersEnabled';
  static const MethodChannel _channel = MethodChannel(
    'com.cirrusgroup.ems/work_timer',
  );

  static final ValueNotifier<bool> shiftRemindersEnabledNotifier =
      ValueNotifier<bool>(false);

  static bool get enabled => shiftRemindersEnabledNotifier.value;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    shiftRemindersEnabledNotifier.value = prefs.getBool(_prefKey) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    if (shiftRemindersEnabledNotifier.value == value) return;
    shiftRemindersEnabledNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    try {
      await _channel.invokeMethod<void>(
        value ? 'scheduleShiftReminders' : 'cancelShiftReminders',
      );
    } catch (_) {
      // Safe no-op in widget tests, Web, or desktop targets.
    }
  }

  @visibleForTesting
  static void debugReset() {
    shiftRemindersEnabledNotifier.value = false;
  }
}
