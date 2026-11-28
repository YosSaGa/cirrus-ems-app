import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import 'technician_service.dart';

/// Displays an ongoing Android status-bar / notification-shade chronometer
/// while a Technician has an active ON SITE work session.
class WorkTimerNotificationService {
  WorkTimerNotificationService._();

  static const MethodChannel _channel = MethodChannel(
    'com.cirrusgroup.ems/work_timer',
  );

  static String? _lastKey;

  static bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Shows or updates the live counting notification when [session] is active,
  /// or clears it when [session] is null.
  static Future<void> syncForActiveSession(
    TechnicianWorkSession? session,
  ) async {
    if (!_isSupported) return;
    if (session == null) {
      await cancel();
      return;
    }

    final title = AppStrings.t(
      'ON SITE · ${session.jobCode}',
      'กำลังทำงาน · ${session.jobCode}',
      'DI TAPAK · ${session.jobCode}',
    );
    final details = <String>[
      if (session.jobTitle.trim().isNotEmpty) session.jobTitle.trim(),
      if (session.vesselName != null && session.vesselName!.trim().isNotEmpty)
        session.vesselName!.trim(),
    ];
    final body = details.isNotEmpty
        ? details.join(' · ')
        : AppStrings.t(
            'Job timer is running',
            'กำลังจับเวลาการทำงาน',
            'Pemasa kerja sedang berjalan',
          );

    final startMillis =
        DateTime.tryParse(session.checkInAt)?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;

    final key = '${session.id}|$startMillis|$title|$body';
    if (_lastKey == key) return;

    try {
      final shown = await _channel.invokeMethod<bool>(
        'showWorkTimer',
        <String, dynamic>{
          'title': title,
          'body': body,
          'startEpochMillis': startMillis,
        },
      );
      if (shown == true) {
        _lastKey = key;
      }
    } on MissingPluginException {
      // Ignored in widget tests or platforms without the native channel.
    } on PlatformException {
      // Non-fatal: notification permission denied or OS restriction.
    }
  }

  /// Shows a high-priority heads-up notification with vibration when a new
  /// Job Code arrives (visible even when the app is backgrounded or locked).
  static Future<void> showNewJobAlert({
    required String title,
    required String body,
    bool vibrate = true,
  }) async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod<bool>('showNewJobAlert', <String, dynamic>{
        'title': title,
        'body': body,
        'vibrate': vibrate,
      });
    } on MissingPluginException {
      // Ignored in widget tests or unsupported platforms.
    } on PlatformException {
      // Non-fatal.
    }
  }

  /// Clears any ongoing work-timer notification.
  static Future<void> cancel() async {
    if (!_isSupported) return;
    if (_lastKey == null) {
      // Still invoke cancel once if needed? No-op if already cancelled,
      // unless called explicitly on sign-out/checkout where we always clear.
    }
    _lastKey = null;
    try {
      await _channel.invokeMethod<bool>('cancelWorkTimer');
    } on MissingPluginException {
      // Ignored in widget tests or platforms without the native channel.
    } on PlatformException {
      // Non-fatal.
    }
  }
}
