import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Encrypted token storage backed by Android Keystore / iOS Keychain
/// (`flutter_secure_storage`), with automatic one-time migration from legacy
/// `SharedPreferences` keys and a clean fallback for unit/widget tests where
/// the native secure-storage channel is unavailable.
class SecureTokenStore {
  SecureTokenStore._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static bool _storageUnavailable = false;

  static bool get _bypassNativeStorage {
    if (_storageUnavailable) return true;
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return true;
    }
  }

  /// Returns the key used to store a switched account's instant-switch token.
  static String recentAccountTokenKey(String username) =>
      'ems.recentToken.${username.trim().toLowerCase()}';

  /// Reads a token from secure storage, migrating any legacy plaintext value
  /// from [SharedPreferences] on first access.
  static Future<String?> readToken(String key) async {
    if (_bypassNativeStorage) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
    try {
      final secure = await _storage.read(key: key);
      if (secure != null && secure.isNotEmpty) {
        return secure;
      }
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(key);
      if (legacy != null && legacy.isNotEmpty) {
        await _storage.write(key: key, value: legacy);
        await prefs.remove(key);
        return legacy;
      }
      return null;
    } catch (_) {
      _storageUnavailable = true;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
  }

  /// Writes [value] into secure storage and removes any legacy plaintext entry
  /// in [SharedPreferences]. Returns `true` when stored in secure storage, or
  /// `false` if it fell back to [SharedPreferences] (e.g. in unit/widget tests).
  static Future<bool> writeToken(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    if (_bypassNativeStorage) {
      await prefs.setString(key, value);
      return false;
    }
    try {
      await _storage.write(key: key, value: value);
      await prefs.remove(key);
      return true;
    } catch (_) {
      _storageUnavailable = true;
      await prefs.setString(key, value);
      return false;
    }
  }

  /// Deletes [key] from both secure storage and [SharedPreferences].
  static Future<void> deleteToken(String key) async {
    if (!_bypassNativeStorage) {
      try {
        await _storage.delete(key: key);
      } catch (_) {
        _storageUnavailable = true;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
