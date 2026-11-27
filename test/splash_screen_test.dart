// claude_prompt.txt (v160 -- Authentication Session Restoration & Platform
// API Configuration, §8): widget-level coverage of SplashScreen's new
// explicit state machine -- navigation outcomes, the recoverable
// connection-error state (message + Retry), Retry actually repeating
// session restoration, and the "no duplicate simultaneous restoration
// requests" guard. Every HTTP call is mocked via
// `AuthService.debugOverrideClient` -- no real backend or network
// involved, per the task's own instruction.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cirrus_app/screens/login_screen.dart';
import 'package:cirrus_app/screens/main_shell.dart';
import 'package:cirrus_app/screens/splash_screen.dart';
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
  dotenv.loadFromString(envString: '', isOptional: true);

  setUp(() {
    AuthService.authRequestTimeout = const Duration(milliseconds: 200);
    AuthService.debugIsWebOverride = false; // Android by default in these tests
  });

  tearDown(() {
    AuthService.debugResetClient();
    AuthService.debugIsWebOverride = null;
    AuthService.authRequestTimeout = const Duration(seconds: 10);
  });

  testWidgets(
    'No local JWT -> navigates to LoginScreen; /auth/sso is never called (Android)',
    (tester) async {
      await _seedPrefs();
      var ssoCalled = false;
      _mock((req) async {
        if (req.url.path.contains('/auth/sso')) ssoCalled = true;
        return _json({}, 404);
      });

      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      // claude_prompt.txt (v158's own lesson, applied again here): fixed,
      // finite pumps -- never pumpAndSettle() -- since SplashScreen's own
      // "checking" phase renders an indeterminate CircularProgressIndicator
      // that would make it time out. A MockClient's handler resolves on a
      // plain microtask (no real platform channel involved, unlike the
      // `camera` plugin's own availableCameras() in the v158 case), so a
      // couple of `pump()` calls are enough here -- no `runAsync()` needed.
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(ssoCalled, false);
    },
  );

  testWidgets('Valid local JWT, /auth/me 200 -> navigates to MainShell', (
    tester,
  ) async {
    await _seedPrefs(token: 'valid-token');
    _mock(
      (req) async => _json({
        'user': {'id': 'u1'},
        'roles': <String>[],
        'permissions': <String>[],
      }, 200),
    );

    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(MainShell), findsOneWidget);
  });

  testWidgets(
    'Invalid local JWT, /auth/me 401 -> clears JWT and navigates to LoginScreen',
    (tester) async {
      await _seedPrefs(token: 'stale-token');
      _mock((req) async => _json({'message': 'Invalid or expired token'}, 401));

      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_tokenKey), isNull);
    },
  );

  testWidgets(
    'Connection failure shows the recoverable error state with a Retry action, and preserves the JWT',
    (tester) async {
      await _seedPrefs(token: 'valid-token');
      _mock((req) async => _json({}, 500));

      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('Connection Problem'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(MainShell), findsNothing);
      expect(find.byType(LoginScreen), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_tokenKey), 'valid-token');
    },
  );

  testWidgets(
    'Tapping Retry repeats session restoration and succeeds -> MainShell',
    (tester) async {
      await _seedPrefs(token: 'valid-token');
      _mock((req) async => _json({}, 500));

      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.text('Retry'), findsOneWidget);

      _mock(
        (req) async => _json({
          'user': {'id': 'u1'},
          'roles': <String>[],
          'permissions': <String>[],
        }, 200),
      );

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(MainShell), findsOneWidget);
    },
  );

  testWidgets(
    'Multiple rapid Retry taps do not trigger concurrent restoration requests',
    (tester) async {
      await _seedPrefs(token: 'valid-token');
      _mock((req) async => _json({}, 500));

      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.text('Retry'), findsOneWidget);

      var callCount = 0;
      final unblock = Completer<void>();
      _mock((req) async {
        callCount++;
        // Each call blocks until the test explicitly releases it, so any
        // second concurrent call occurring before the first resolves
        // would be unambiguously visible as callCount reaching 2 while
        // still mid-flight.
        await unblock.future;
        return _json({}, 500);
      });

      // claude_prompt.txt (v160): both taps dispatched against the SAME
      // still-rendered frame, with NO `pump()` between them -- the first
      // tap's own `setState` (which swaps the Retry button out for the
      // checking spinner) has not been rendered yet, so this genuinely
      // exercises the `_restoring` guard itself, not just "the button
      // happened to already be gone." A `pump()` between the two taps
      // would make the second one unable to find "Retry" at all (the
      // button is hidden once a restoration starts) -- a real UI
      // behavior, but not what this specific test is checking.
      await tester.tap(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(
        callCount,
        1,
        reason: 'a second tap while a restoration is already in flight must be a no-op',
      );

      unblock.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(
        callCount,
        1,
        reason: 'still exactly one request after the in-flight one resolves',
      );
    },
  );
}
