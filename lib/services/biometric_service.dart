import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists biometric lock preference and provides safe device authentication
/// for sensitive views (e.g. Pay Estimate / E-Payslip).
class BiometricService {
  static const String _lockKey = 'ems.pref.biometricLockEnabled';
  static final LocalAuthentication _auth = LocalAuthentication();

  static final ValueNotifier<bool> biometricLockEnabledNotifier =
      ValueNotifier<bool>(false);

  static bool get biometricLockEnabled => biometricLockEnabledNotifier.value;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    biometricLockEnabledNotifier.value = prefs.getBool(_lockKey) ?? false;
  }

  static Future<void> setBiometricLockEnabled(bool enabled) async {
    if (biometricLockEnabledNotifier.value == enabled) return;
    biometricLockEnabledNotifier.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockKey, enabled);
  }

  static Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported || canCheck;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
      );
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  static void debugReset() {
    biometricLockEnabledNotifier.value = false;
  }
}
