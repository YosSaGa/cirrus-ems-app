// claude_prompt.txt (v160 -- Authentication Session Restoration & Platform
// API Configuration, §8): deterministic, mocked-HTTP coverage of
// `AuthService.checkSession()`'s full Android/Web decision table, using
// `package:http/testing.dart`'s `MockClient` (shipped with the `http`
// package this project already depends on -- no new dependency) injected
// via the new `AuthService.debugOverrideClient` test seam, and
// `AuthService.debugIsWebOverride` to exercise the Web branch from a plain
// VM `flutter test` run (where the real `kIsWeb` constant is always
// false). `AuthService.authRequestTimeout` is lowered for every test so
// the one timeout scenario resolves in milliseconds, not the real 10s
// default.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cirrus_app/services/auth_service.dart';

const _tokenKey = 'ems.authToken';

Future<void> _seedPrefs({String? token}) async {
  SharedPreferences.setMockInitialValues(
    token != null ? {_tokenKey: token} : <String, Object>{},
  );
}

void _mock(Future<http.Response> Function(http.Request) handler) {
  AuthService.debugOverrideClient(MockClient(handler));
}

http.Response _json(Map<String, dynamic> body, int status) =>
    http.Response(jsonEncode(body), status);

void main() {
  // claude_prompt.txt (v160): `AuthService.baseUrl` reads `dotenv.env[...]`
  // on the Android/Web branches it builds `_uri()` from -- `dotenv` is
  // normally initialized once in `main()` via `dotenv.load()` (a real
  // asset read), which never runs in a unit test. Found empirically this
  // round: without this, every `_typedRequest` call threw
  // `NotInitializedError`, and `_typedRequest`'s own deliberately-broad
  // catch (needed to classify a REAL network failure the same way on
  // Android and Web, see its own comment) silently misclassified that as
  // `networkFailure` -- every success-path test failed with
  // `connectionUnavailable` until this was diagnosed and fixed.
  // `loadFromString` (synchronous, no asset bundle needed) is
  // `flutter_dotenv`'s own test-friendly alternative to `load()`.
  dotenv.loadFromString(envString: '', isOptional: true);

  setUp(() {
    AuthService.authRequestTimeout = const Duration(milliseconds: 200);
  });

  tearDown(() {
    AuthService.debugResetClient();
    AuthService.debugIsWebOverride = null;
    AuthService.authRequestTimeout = const Duration(seconds: 10);
  });

  test('switch preserves the current session and saved token on server failure', () async {
    final account = RecentAccount(
      username: 'other',
      name: 'Other',
      lastUsedAt: DateTime.now(),
      savedToken: 'other-token',
    );
    SharedPreferences.setMockInitialValues({
      _tokenKey: 'current-token',
      'ems.recentAccounts': jsonEncode([account.toJson()]),
    });
    _mock((request) async {
      expect(request.headers['Authorization'], 'Bearer other-token');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_tokenKey), 'current-token');
      return _json({'message': 'unavailable'}, 503);
    });

    await expectLater(AuthService.switchToAccount(account), throwsException);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_tokenKey), 'current-token');
    expect((await AuthService.getRecentAccounts()).single.savedToken, 'other-token');
  });

  test('expired switch token is cleared only after an unauthorized response', () async {
    final account = RecentAccount(
      username: 'other',
      name: 'Other',
      lastUsedAt: DateTime.now(),
      savedToken: 'expired-token',
    );
    SharedPreferences.setMockInitialValues({
      _tokenKey: 'current-token',
      'ems.recentAccounts': jsonEncode([account.toJson()]),
    });
    _mock((_) async => _json({}, 401));

    expect(await AuthService.switchToAccount(account), isFalse);
    expect((await SharedPreferences.getInstance()).getString(_tokenKey), 'current-token');
    expect((await AuthService.getRecentAccounts()).single.savedToken, isNull);
  });

  test('unauthorized session restoration preserves pending attendance', () async {
    const pendingKey = 'ems.pendingAttendanceRequest.user-1';
    SharedPreferences.setMockInitialValues({
      _tokenKey: 'expired-token',
      'ems.user': jsonEncode({'id': 'user-1'}),
      pendingKey: 'pending-record',
    });
    AuthService.debugIsWebOverride = false;
    _mock((_) async => _json({}, 401));

    expect((await AuthService.checkSession()).status, SessionRestorationStatus.unauthenticated);
    expect((await SharedPreferences.getInstance()).getString(pendingKey), 'pending-record');
  });

  group('checkSession — Android (task §8 Android scenarios 1-6)', () {
    setUp(() => AuthService.debugIsWebOverride = false);

    test('1. No JWT -> unauthenticated; /auth/sso is never called', () async {
      await _seedPrefs();
      var ssoCalled = false;
      _mock((req) async {
        if (req.url.path.contains('/auth/sso')) ssoCalled = true;
        return _json({}, 404);
      });

      final result = await AuthService.checkSession();

      expect(result.status, SessionRestorationStatus.unauthenticated);
      expect(
        ssoCalled,
        false,
        reason: '/auth/sso must never be called on Android with no local JWT',
      );
    });

    test('2. Valid JWT, /auth/me 200 -> authenticated', () async {
      await _seedPrefs(token: 'valid-token');
      _mock(
        (req) async => _json({
          'user': {'id': 'u1'},
          'roles': <String>[],
          'permissions': <String>[],
        }, 200),
      );

      final result = await AuthService.checkSession();

      expect(result.status, SessionRestorationStatus.authenticated);
    });

    test(
      '3. Invalid JWT, /auth/me 401 -> JWT cleared; unauthenticated',
      () async {
        await _seedPrefs(token: 'stale-token');
        _mock(
          (req) async => _json({'message': 'Invalid or expired token'}, 401),
        );

        final result = await AuthService.checkSession();

        expect(result.status, SessionRestorationStatus.unauthenticated);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(_tokenKey),
          isNull,
          reason: 'a definitive 401 must clear the local JWT',
        );
      },
    );

    test('4. /auth/me 500 -> JWT preserved; connectionUnavailable', () async {
      await _seedPrefs(token: 'valid-token');
      _mock((req) async => _json({}, 500));

      final result = await AuthService.checkSession();

      expect(result.status, SessionRestorationStatus.connectionUnavailable);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(_tokenKey),
        'valid-token',
        reason: 'HTTP 500 must never clear a potentially valid JWT',
      );
    });

    test(
      '5. Network failure -> JWT preserved; connectionUnavailable',
      () async {
        await _seedPrefs(token: 'valid-token');
        _mock((req) async => throw Exception('socket closed'));

        final result = await AuthService.checkSession();

        expect(result.status, SessionRestorationStatus.connectionUnavailable);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(_tokenKey), 'valid-token');
      },
    );

    test('6. Timeout -> JWT preserved; connectionUnavailable', () async {
      await _seedPrefs(token: 'valid-token');
      // A Future that never completes -- no real Timer is scheduled by
      // this handler itself, so `.timeout()`'s own internal timer is the
      // only one in play, firing after authRequestTimeout (200ms here).
      _mock((req) => Completer<http.Response>().future);

      final result = await AuthService.checkSession();

      expect(result.status, SessionRestorationStatus.connectionUnavailable);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_tokenKey), 'valid-token');
    });

    test(
      '7. Retry after a connection failure succeeds -> authenticated',
      () async {
        await _seedPrefs(token: 'valid-token');
        _mock((req) async => _json({}, 500));
        final first = await AuthService.checkSession();
        expect(first.status, SessionRestorationStatus.connectionUnavailable);

        _mock(
          (req) async => _json({
            'user': {'id': 'u1'},
            'roles': [],
            'permissions': [],
          }, 200),
        );
        final retry = await AuthService.checkSession();

        expect(retry.status, SessionRestorationStatus.authenticated);
      },
    );
  });

  group('checkSession — Web (task §8 Web scenarios 1-6)', () {
    setUp(() => AuthService.debugIsWebOverride = true);

    test('1. No JWT, /auth/sso 200 -> authenticated', () async {
      await _seedPrefs();
      _mock(
        (req) async => _json({
          'accessToken': 'restored-token',
          'user': {'id': 'u1'},
          'roles': <String>[],
          'permissions': <String>[],
        }, 200),
      );

      final result = await AuthService.checkSession();

      expect(result.status, SessionRestorationStatus.authenticated);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_tokenKey), 'restored-token');
    });

    test('2. No JWT, /auth/sso 401 -> unauthenticated', () async {
      await _seedPrefs();
      _mock((req) async => _json({'message': 'No session'}, 401));

      final result = await AuthService.checkSession();

      expect(result.status, SessionRestorationStatus.unauthenticated);
    });

    test('3. No JWT, /auth/sso 500 -> connectionUnavailable', () async {
      await _seedPrefs();
      _mock((req) async => _json({}, 500));

      final result = await AuthService.checkSession();

      expect(result.status, SessionRestorationStatus.connectionUnavailable);
    });

    test(
      '4. Existing JWT, /auth/me 401 -> clear JWT, then attempt SSO',
      () async {
        await _seedPrefs(token: 'stale-token');
        var ssoCalled = false;
        _mock((req) async {
          if (req.url.path.contains('/auth/sso')) {
            ssoCalled = true;
            return _json({
              'accessToken': 'fresh-token',
              'user': {'id': 'u1'},
              'roles': [],
              'permissions': [],
            }, 200);
          }
          return _json({}, 401);
        });

        final result = await AuthService.checkSession();

        expect(
          ssoCalled,
          true,
          reason: 'Web must attempt /auth/sso after a 401 clears the JWT',
        );
        expect(result.status, SessionRestorationStatus.authenticated);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(_tokenKey), 'fresh-token');
      },
    );

    test('5. Existing JWT, /auth/me 500 -> JWT preserved; connectionUnavailable (no SSO attempt)', () async {
      await _seedPrefs(token: 'valid-token');
      var ssoCalled = false;
      _mock((req) async {
        if (req.url.path.contains('/auth/sso')) ssoCalled = true;
        return _json({}, 500);
      });

      final result = await AuthService.checkSession();

      expect(result.status, SessionRestorationStatus.connectionUnavailable);
      expect(
        ssoCalled,
        false,
        reason: 'a 500 on /auth/me is not a definitive rejection -- it must not fall through to SSO',
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_tokenKey), 'valid-token');
    });

    test('6. Network failure -> JWT preserved', () async {
      await _seedPrefs(token: 'valid-token');
      _mock((req) async => throw Exception('DNS failure'));

      final result = await AuthService.checkSession();

      expect(result.status, SessionRestorationStatus.connectionUnavailable);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_tokenKey), 'valid-token');
    });
  });

  group('resolveBaseUrl — compile-time override / .env / platform-default priority (task §8 "URL Configuration")', () {
    test('a non-empty compile-time override takes precedence over .env', () {
      expect(
        AuthService.resolveBaseUrl(
          compileTimeOverride: 'http://override:1',
          envValue: 'http://env:2',
          platformDefault: 'http://default:3',
        ),
        'http://override:1',
      );
    });

    test('.env is used when the override is empty', () {
      expect(
        AuthService.resolveBaseUrl(
          compileTimeOverride: '',
          envValue: 'http://env:2',
          platformDefault: 'http://default:3',
        ),
        'http://env:2',
      );
    });

    test('the platform default remains valid when both override and .env are absent', () {
      expect(
        AuthService.resolveBaseUrl(
          compileTimeOverride: '',
          envValue: null,
          platformDefault: 'http://default:3',
        ),
        'http://default:3',
      );
    });

    test('an empty (present but blank) .env value also falls through to the platform default', () {
      expect(
        AuthService.resolveBaseUrl(
          compileTimeOverride: '',
          envValue: '',
          platformDefault: 'http://default:3',
        ),
        'http://default:3',
      );
    });
  });
}
