import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client_factory.dart';
import 'technician_service.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Classified HTTP outcome for session-restoration requests.
enum _HttpOutcomeKind {
  success,
  unauthorized,
  forbidden,
  serverError,
  timeout,
  networkFailure,
  otherError,
}

class _TypedHttpResult {
  final _HttpOutcomeKind kind;
  final int? statusCode;
  final Map<String, dynamic>? body;

  const _TypedHttpResult(this.kind, {this.statusCode, this.body});
}

/// Outcome of [AuthService.checkSession] for the Splash Screen.
enum SessionRestorationStatus {
  authenticated,
  unauthenticated,
  connectionUnavailable,
}

class SessionRestorationResult {
  final SessionRestorationStatus status;
  final Map<String, dynamic>? session;
  final String? message;

  const SessionRestorationResult._(this.status, {this.session, this.message});

  factory SessionRestorationResult.authenticated(
    Map<String, dynamic> session,
  ) => SessionRestorationResult._(
    SessionRestorationStatus.authenticated,
    session: session,
  );

  factory SessionRestorationResult.unauthenticated() =>
      const SessionRestorationResult._(
        SessionRestorationStatus.unauthenticated,
      );

  factory SessionRestorationResult.connectionUnavailable(String message) =>
      SessionRestorationResult._(
        SessionRestorationStatus.connectionUnavailable,
        message: message,
      );
}

/// Lightweight metadata for previously signed-in accounts on this device
/// (used by Switch Account). Supports instant switching within
/// [AuthService.switchSessionMaxAge] (5 days); after 5 days of inactivity
/// (or explicit logout) password re-entry is required. Never stores passwords.
class RecentAccount {
  const RecentAccount({
    required this.username,
    required this.name,
    required this.lastUsedAt,
    this.employeeCode,
    this.email,
    this.savedToken,
    this.savedUser,
    this.savedRoles = const [],
    this.savedPermissions = const [],
  });

  final String username;
  final String name;
  final DateTime lastUsedAt;
  final String? employeeCode;
  final String? email;
  final String? savedToken;
  final Map<String, dynamic>? savedUser;
  final List<String> savedRoles;
  final List<String> savedPermissions;

  bool get canInstantSwitch {
    if (savedToken == null || savedToken!.isEmpty) return false;
    return DateTime.now().difference(lastUsedAt) <=
        AuthService.switchSessionMaxAge;
  }

  RecentAccount copyWith({
    DateTime? lastUsedAt,
    String? savedToken,
    bool clearToken = false,
  }) => RecentAccount(
    username: username,
    name: name,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    employeeCode: employeeCode,
    email: email,
    savedToken: clearToken ? null : (savedToken ?? this.savedToken),
    savedUser: savedUser,
    savedRoles: savedRoles,
    savedPermissions: savedPermissions,
  );

  Map<String, dynamic> toJson() => {
    'username': username,
    'name': name,
    'lastUsedAt': lastUsedAt.toIso8601String(),
    'employeeCode': employeeCode,
    'email': email,
    'savedToken': savedToken,
    'savedUser': savedUser,
    'savedRoles': savedRoles,
    'savedPermissions': savedPermissions,
  };

  factory RecentAccount.fromJson(Map<String, dynamic> json) {
    final parsedDate = DateTime.tryParse(json['lastUsedAt']?.toString() ?? '');
    final rawUser = json['savedUser'];
    final rawRoles = json['savedRoles'];
    final rawPerms = json['savedPermissions'];
    return RecentAccount(
      username: (json['username'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      lastUsedAt: parsedDate ?? DateTime.fromMillisecondsSinceEpoch(0),
      employeeCode: json['employeeCode']?.toString(),
      email: json['email']?.toString(),
      savedToken: json['savedToken']?.toString(),
      savedUser: rawUser is Map ? Map<String, dynamic>.from(rawUser) : null,
      savedRoles: rawRoles is List
          ? rawRoles.map((e) => e.toString()).toList(growable: false)
          : const [],
      savedPermissions: rawPerms is List
          ? rawPerms.map((e) => e.toString()).toList(growable: false)
          : const [],
    );
  }
}

class AuthService {
  AuthService._();

  static http.Client _client = createApiClient();

  /// Test-only seam to substitute a fake [http.Client].
  @visibleForTesting
  static void debugOverrideClient(http.Client client) {
    _client = client;
  }

  @visibleForTesting
  static void debugResetClient() {
    _client = createApiClient();
  }

  /// Test-only override for [kIsWeb].
  @visibleForTesting
  static bool? debugIsWebOverride;

  static bool get _isWeb => debugIsWebOverride ?? kIsWeb;

  static const String _androidUrlOverride = String.fromEnvironment(
    'API_BASE_URL_ANDROID',
    defaultValue: '',
  );
  static const String _webUrlOverride = String.fromEnvironment(
    'API_BASE_URL_WEB',
    defaultValue: '',
  );
  static const String _iosUrlOverride = String.fromEnvironment(
    'API_BASE_URL_IOS',
    defaultValue: '',
  );

  /// Priority: compile-time override → non-empty .env → platform default.
  @visibleForTesting
  static String resolveBaseUrl({
    required String compileTimeOverride,
    required String? envValue,
    required String platformDefault,
  }) {
    if (compileTimeOverride.isNotEmpty) return compileTimeOverride;
    if (envValue != null && envValue.isNotEmpty) return envValue;
    return platformDefault;
  }

  static String get baseUrl {
    if (_isWeb) {
      return resolveBaseUrl(
        compileTimeOverride: _webUrlOverride,
        envValue: dotenv.env['API_BASE_URL_WEB'],
        platformDefault: 'http://localhost:3000/api/v1/ems',
      );
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return resolveBaseUrl(
        compileTimeOverride: _androidUrlOverride,
        envValue: dotenv.env['API_BASE_URL_ANDROID'],
        platformDefault: 'http://10.0.2.2:3000/api/v1/ems',
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return resolveBaseUrl(
        compileTimeOverride: _iosUrlOverride,
        envValue: dotenv.env['API_BASE_URL_IOS'],
        platformDefault: 'http://localhost:3000/api/v1/ems',
      );
    }

    return 'http://localhost:3000/api/v1/ems';
  }

  static const String _tokenKey = 'ems.authToken';
  static const String _userKey = 'ems.user';
  static const String _rolesKey = 'ems.roles';
  static const String _permissionsKey = 'ems.permissions';

  static Uri _uri(String path) => Uri.parse('$baseUrl$path');

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (authenticated && token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final uri = _uri(path);

    late http.Response response;

    switch (method) {
      case 'GET':
        response = await _client
            .get(uri, headers: headers)
            .timeout(authRequestTimeout);
        break;
      case 'POST':
        response = await _client
            .post(
              uri,
              headers: headers,
              body: jsonEncode(body ?? <String, dynamic>{}),
            )
            .timeout(authRequestTimeout);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    dynamic decoded;

    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};

      final message = data['message'];
      final errorMessage = message is List
          ? message.join(', ')
          : message?.toString();

      throw Exception(
        errorMessage ??
            data['error']?.toString() ??
            'Request failed (${response.statusCode})',
      );
    }

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return <String, dynamic>{};
  }

  /// Timeout applied only to session-restoration requests.
  @visibleForTesting
  static Duration authRequestTimeout = const Duration(seconds: 10);

  /// Classified request path used by [checkSession]. Does not throw.
  static Future<_TypedHttpResult> _typedRequest(
    String path, {
    bool authenticated = false,
    String? tokenOverride,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (authenticated) {
      final token = tokenOverride ?? await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    http.Response response;
    try {
      response = await _client
          .get(_uri(path), headers: headers)
          .timeout(authRequestTimeout);
    } on TimeoutException {
      return const _TypedHttpResult(_HttpOutcomeKind.timeout);
    } catch (_) {
      // Covers SocketException / ClientException on all platforms.
      return const _TypedHttpResult(_HttpOutcomeKind.networkFailure);
    }

    Map<String, dynamic>? data;
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        data = null;
      }
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _TypedHttpResult(
        _HttpOutcomeKind.success,
        statusCode: response.statusCode,
        body: data ?? <String, dynamic>{},
      );
    }
    if (response.statusCode == 401) {
      return _TypedHttpResult(
        _HttpOutcomeKind.unauthorized,
        statusCode: 401,
        body: data,
      );
    }
    // 403 is deliberately separate from 401 — never clears the JWT.
    if (response.statusCode == 403) {
      return _TypedHttpResult(
        _HttpOutcomeKind.forbidden,
        statusCode: 403,
        body: data,
      );
    }
    if (response.statusCode >= 500) {
      return _TypedHttpResult(
        _HttpOutcomeKind.serverError,
        statusCode: response.statusCode,
        body: data,
      );
    }
    return _TypedHttpResult(
      _HttpOutcomeKind.otherError,
      statusCode: response.statusCode,
      body: data,
    );
  }

  static Future<void> _saveSession(Map<String, dynamic> result) async {
    final prefs = await SharedPreferences.getInstance();

    final token = result['accessToken'];
    if (token is! String || token.isEmpty) {
      throw Exception('Backend did not return an access token.');
    }

    await prefs.setString(_tokenKey, token);

    if (result['user'] != null) {
      await prefs.setString(_userKey, jsonEncode(result['user']));
    }

    await prefs.setString(_rolesKey, jsonEncode(result['roles'] ?? <String>[]));

    await prefs.setString(
      _permissionsKey,
      jsonEncode(result['permissions'] ?? <String>[]),
    );

    if (result['user'] is Map) {
      await _recordRecentAccount(
        prefs,
        Map<String, dynamic>.from(result['user'] as Map),
        token: prefs.getString(_tokenKey),
        roles: (result['roles'] is List)
            ? (result['roles'] as List).map((e) => e.toString()).toList()
            : const [],
        permissions: (result['permissions'] is List)
            ? (result['permissions'] as List).map((e) => e.toString()).toList()
            : const [],
      );
    }
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final result = await _request(
      'POST',
      '/auth/login',
      body: {'username': username, 'password': password},
    );

    await _saveSession(result);
    return result;
  }

  static Future<void> _persistMeFields(Map<String, dynamic> result) async {
    final prefs = await SharedPreferences.getInstance();

    if (result['user'] != null) {
      await prefs.setString(_userKey, jsonEncode(result['user']));
    }

    await prefs.setString(_rolesKey, jsonEncode(result['roles'] ?? <String>[]));

    await prefs.setString(
      _permissionsKey,
      jsonEncode(result['permissions'] ?? <String>[]),
    );

    if (result['user'] is Map) {
      await _recordRecentAccount(
        prefs,
        Map<String, dynamic>.from(result['user'] as Map),
        token: prefs.getString(_tokenKey),
        roles: (result['roles'] is List)
            ? (result['roles'] as List).map((e) => e.toString()).toList()
            : const [],
        permissions: (result['permissions'] is List)
            ? (result['permissions'] as List).map((e) => e.toString()).toList()
            : const [],
      );
    }
  }

  static Future<Map<String, dynamic>> fetchMe() async {
    final result = await _request('GET', '/auth/me', authenticated: true);
    await _persistMeFields(result);
    return result;
  }

  static Future<Map<String, dynamic>> ssoHydrate() async {
    final result = await _request('GET', '/auth/sso');
    await _saveSession(result);
    return result;
  }

  static Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);

    try {
      if (token != null && token.isNotEmpty) {
        await fetchMe();
      } else {
        await ssoHydrate();
      }

      return true;
    } catch (_) {
      await _clearLocalSession();
      return false;
    }
  }

  /// Full platform-aware session restoration for the Splash Screen.
  static Future<SessionRestorationResult> checkSession() async {
    final token = await getToken();
    final hasToken = token != null && token.isNotEmpty;

    if (hasToken) {
      final result = await _typedRequest('/auth/me', authenticated: true);

      if (result.kind == _HttpOutcomeKind.success) {
        final body = result.body ?? <String, dynamic>{};
        await _persistMeFields(body);
        return SessionRestorationResult.authenticated(body);
      }

      if (result.kind == _HttpOutcomeKind.unauthorized) {
        await _clearLocalSession();
        if (_isWeb) return _attemptSsoRestore();
        return SessionRestorationResult.unauthenticated();
      }

      // 403 / 5xx / timeout / network — JWT is left untouched.
      return SessionRestorationResult.connectionUnavailable(
        _connectionErrorMessage,
      );
    }

    if (!_isWeb) {
      // Android: no local JWT → LoginScreen, never call /auth/sso.
      return SessionRestorationResult.unauthenticated();
    }

    return _attemptSsoRestore();
  }

  static Future<SessionRestorationResult> _attemptSsoRestore() async {
    final result = await _typedRequest('/auth/sso', authenticated: false);

    if (result.kind == _HttpOutcomeKind.success) {
      final body = result.body ?? <String, dynamic>{};
      await _saveSession(body);
      return SessionRestorationResult.authenticated(body);
    }

    if (result.kind == _HttpOutcomeKind.unauthorized) {
      return SessionRestorationResult.unauthenticated();
    }

    return SessionRestorationResult.connectionUnavailable(
      _connectionErrorMessage,
    );
  }

  static const String _connectionErrorMessage =
      'The server cannot currently be reached. Please check your '
      'connection and try again.';

  static Future<void> logout({bool revokeInstantSwitch = true}) async {
    final savedUser = await getSavedUser();
    final uname =
        (savedUser?['username'] ??
                savedUser?['email'] ??
                savedUser?['employeeCode'] ??
                '')
            .toString()
            .trim();
    try {
      await _request('POST', '/auth/logout', authenticated: true);
    } catch (_) {
      // Clear local session even if the server is unavailable.
    } finally {
      if (revokeInstantSwitch && uname.isNotEmpty) {
        await clearRecentAccountToken(uname);
      }
      await _clearLocalSession();
    }
  }

  /// Clears JWT and cached user data.
  static Future<void> _clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_rolesKey);
    await prefs.remove(_permissionsKey);
    TechnicianService.clearCachedDashboard();

  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<Map<String, dynamic>?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);

    if (raw == null) return null;

    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<List<String>> getSavedRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_rolesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList(growable: false);
      }
    } catch (_) {}
    return const [];
  }

  static Future<List<String>> getSavedPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_permissionsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList(growable: false);
      }
    } catch (_) {}
    return const [];
  }

  static const Set<String> _payrollManagerRoles = {
    'admin',
    'hr officer',
    'hr',
    'accountant',
    'owner',
  };

  /// Synchronous RBAC check for payroll management (HR / Admin / Accountant / Owner).
  static bool hasPayrollManageAccess(
    List<String> roles,
    List<String> permissions,
  ) {
    for (final role in roles) {
      if (_payrollManagerRoles.contains(role.toLowerCase().trim())) {
        return true;
      }
    }
    for (final perm in permissions) {
      final p = perm.toLowerCase().trim();
      if (p == 'payroll.create' ||
          p == 'payroll.update' ||
          p == 'payroll.delete') {
        return true;
      }
    }
    return false;
  }

  /// Returns whether the currently cached session can manage employee payroll
  /// rates and deductions (HR Officer, Admin, Accountant, or Owner).
  static Future<bool> canManagePayroll() async {
    final roles = await getSavedRoles();
    final perms = await getSavedPermissions();
    return hasPayrollManageAccess(roles, perms);
  }

  /// Synchronous role check for Technician field-job attendance mode
  /// (`Technician` and `Admin`).
  static bool hasTechnicianRole(List<String> roles) {
    for (final role in roles) {
      final r = role.toLowerCase().trim();
      if (r == 'technician' || r == 'admin') {
        return true;
      }
    }
    return false;
  }

  /// Returns whether the currently cached session has the `Technician` role.
  static Future<bool> isTechnician() async {
    final roles = await getSavedRoles();
    return hasTechnicianRole(roles);
  }

  /// Maximum idle duration before Switch Account requires password re-entry.
  static const Duration switchSessionMaxAge = Duration(days: 5);

  /// Maximum number of most recently switched accounts shown in the quick sheet.
  static const int quickSwitchMaxAccounts = 3;

  static const String _recentAccountsKey = 'ems.recentAccounts';

  static Future<void> _recordRecentAccount(
    SharedPreferences prefs,
    Map<String, dynamic> user, {
    String? token,
    List<String> roles = const [],
    List<String> permissions = const [],
  }) async {
    final username =
        (user['username'] ?? user['email'] ?? user['employeeCode'] ?? '')
            .toString()
            .trim();
    if (username.isEmpty) return;
    final name = (user['name'] ?? username).toString().trim();
    final entry = RecentAccount(
      username: username,
      name: name.isEmpty ? username : name,
      lastUsedAt: DateTime.now(),
      employeeCode: user['employeeCode']?.toString(),
      email: user['email']?.toString(),
      savedToken: token,
      savedUser: user,
      savedRoles: roles,
      savedPermissions: permissions,
    );
    final existing = await getRecentAccounts();
    final updated = <RecentAccount>[
      entry,
      ...existing.where(
        (a) => a.username.toLowerCase() != username.toLowerCase(),
      ),
    ].take(30).toList(growable: false);
    await prefs.setString(
      _recentAccountsKey,
      jsonEncode(updated.map((a) => a.toJson()).toList()),
    );
  }

  /// Clears saved instant-switch token for [username] (e.g. on explicit logout
  /// or 5-day expiry) while keeping display metadata in the recent list.
  static Future<void> clearRecentAccountToken(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getRecentAccounts();
    final updated = existing
        .map(
          (a) => a.username.toLowerCase() == username.toLowerCase()
              ? a.copyWith(clearToken: true)
              : a,
        )
        .toList(growable: false);
    await prefs.setString(
      _recentAccountsKey,
      jsonEncode(updated.map((a) => a.toJson()).toList()),
    );
  }

  /// Attempts an instant switch to [account] when used within the last 5 days
  /// and its saved session token is still accepted by `/auth/me`.
  /// Returns `true` if switched immediately, or `false` if password re-entry
  /// is required.
  static Future<bool> switchToAccount(RecentAccount account) async {
    if (!account.canInstantSwitch) {
      await clearRecentAccountToken(account.username);
      return false;
    }
    final verification = await _typedRequest(
      '/auth/me',
      authenticated: true,
      tokenOverride: account.savedToken,
    );
    if (verification.kind == _HttpOutcomeKind.unauthorized) {
      await clearRecentAccountToken(account.username);
      return false;
    }
    if (verification.kind != _HttpOutcomeKind.success) {
      throw Exception(_connectionErrorMessage);
    }
    final verifiedUser = verification.body?['user'];
    if (verifiedUser is! Map || verifiedUser['id'] == null) {
      throw Exception(_connectionErrorMessage);
    }
    final prefs = await SharedPreferences.getInstance();
    final prevToken = prefs.getString(_tokenKey);
    final prevUser = prefs.getString(_userKey);
    final prevRoles = prefs.getString(_rolesKey);
    final prevPerms = prefs.getString(_permissionsKey);

    try {
      await prefs.setString(_tokenKey, account.savedToken!);
      if (account.savedUser != null) {
        await prefs.setString(_userKey, jsonEncode(account.savedUser));
      } else {
        await prefs.remove(_userKey);
      }
      await prefs.setString(_rolesKey, jsonEncode(account.savedRoles));
      await prefs.setString(_permissionsKey, jsonEncode(account.savedPermissions));
      await _persistMeFields(verification.body!);
      final existing = await getRecentAccounts();
      final promoted = account.copyWith(lastUsedAt: DateTime.now());
      final updated = <RecentAccount>[
        promoted,
        ...existing.where(
          (a) => a.username.toLowerCase() != account.username.toLowerCase(),
        ),
      ].take(30).toList(growable: false);
      await prefs.setString(
        _recentAccountsKey,
        jsonEncode(updated.map((a) => a.toJson()).toList()),
      );
      TechnicianService.clearCachedDashboard();
      return true;
    } catch (_) {
      if (prevToken != null) {
        await prefs.setString(_tokenKey, prevToken);
      } else {
        await prefs.remove(_tokenKey);
      }
      if (prevUser != null) {
        await prefs.setString(_userKey, prevUser);
      } else {
        await prefs.remove(_userKey);
      }
      if (prevRoles != null) {
        await prefs.setString(_rolesKey, prevRoles);
      } else {
        await prefs.remove(_rolesKey);
      }
      if (prevPerms != null) {
        await prefs.setString(_permissionsKey, prevPerms);
      } else {
        await prefs.remove(_permissionsKey);
      }
      TechnicianService.clearCachedDashboard();
      rethrow;
    }
  }

  /// Lists up to 6 accounts that have previously signed in on this device.
  static Future<List<RecentAccount>> getRecentAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentAccountsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((m) => RecentAccount.fromJson(Map<String, dynamic>.from(m)))
            .where((a) => a.username.isNotEmpty)
            .toList(growable: false);
      }
    } catch (_) {}
    return const [];
  }

  /// Removes a saved display entry from the Switch Account list.
  static Future<void> removeRecentAccount(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getRecentAccounts();
    final filtered = existing
        .where((a) => a.username.toLowerCase() != username.toLowerCase())
        .toList(growable: false);
    await prefs.setString(
      _recentAccountsKey,
      jsonEncode(filtered.map((a) => a.toJson()).toList()),
    );
  }

  static Future<bool> isLoggedIn() async {
    return await restoreSession();
  }

  static Future<void> logIn(String username, String password) async {
    await login(username, password);
  }

  static Future<void> logOut() async {
    await logout();
  }

  static Future<String> getCurrentUserId() async {
    final result = await fetchMe();
    final user = result['user'];

    if (user is Map && user['id'] is String) {
      return user['id'] as String;
    }

    throw Exception('Unable to retrieve current user ID.');
  }

  static Future<Map<String, dynamic>> getCurrentUser() async {
    final result = await fetchMe();
    final user = result['user'];

    if (user is Map<String, dynamic>) {
      return user;
    }

    throw Exception('Unable to retrieve current user.');
  }
}
