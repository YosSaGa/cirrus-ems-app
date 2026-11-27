import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cirrus_app/screens/attendance_screen.dart';
import 'package:cirrus_app/screens/history_screen.dart';
import 'package:cirrus_app/screens/login_screen.dart';
import 'package:cirrus_app/screens/main_shell.dart';
import 'package:cirrus_app/screens/profile_screen.dart';
import 'package:cirrus_app/screens/work_trial_screen.dart';
import 'package:cirrus_app/services/attendance_service.dart';
import 'package:cirrus_app/services/auth_service.dart';
import 'package:cirrus_app/theme/app_theme.dart';
import 'package:cirrus_app/widgets/app_bottom_nav.dart';
import 'package:cirrus_app/widgets/status_banner.dart';
import 'package:cirrus_app/widgets/time_action_button.dart';

import 'support/preview_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadPreviewFonts);
  testWidgets('History shows scan hours even without attendance records', (
    tester,
  ) async {
    dotenv.loadFromString(envString: '', isOptional: true);
    SharedPreferences.setMockInitialValues({
      'ems.user': jsonEncode({'id': 'history-user'}),
      'ems.authToken': 'test-token',
    });
    final now = DateTime.now();
    AttendanceService.debugOverrideClient(
      MockClient((request) async {
        if (!request.url.path.endsWith('/my-scans')) {
          return http.Response('[]', 200);
        }
        final date = request.url.queryParameters['from']!;
        final isCurrent = DateTime.parse(date).month == now.month;
        final hours = isCurrent ? 4 : 2;
        return http.Response(
          jsonEncode([
            {
              'workDate': date,
              'windowCode': 'morning_in',
              'counted': true,
              'scannedAt': '${date}T08:00:00+07:00',
            },
            if (!isCurrent)
              {
                'workDate': date,
                'windowCode': 'lunch_out',
                'counted': true,
                'scannedAt': '${date}T${hours + 8}:00:00+07:00',
              },
          ]),
          200,
        );
      }),
    );
    addTearDown(AttendanceService.debugResetClient);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const HistoryScreen()),
    );
    await tester.pumpAndSettle();

    void expectCard(String label, String value) {
      final card = find.ancestor(
        of: find.text(label),
        matching: find.byType(Card),
      );
      expect(card, findsOneWidget);
      final labelY = tester.getTopLeft(find.text(label)).dy;
      final values = find.descendant(of: card, matching: find.text(value));
      expect(values.evaluate(), isNotEmpty);
      expect(
        values.evaluate().any((e) {
          final box = e.renderObject! as RenderBox;
          return box.localToGlobal(Offset.zero).dy > labelY;
        }),
        isTrue,
      );
    }

    expect(find.textContaining('No attendance records for'), findsOneWidget);
    expectCard('Total Working Hours This Month', '4h 0m');
    expectCard('Hours Used for Pay', '0h 0m');
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expectCard('Total Working Hours', '2h 0m');
    final card = find.ancestor(
      of: find.text('Hours Used for Pay'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: card, matching: find.text('2h 0m')),
      findsNWidgets(2),
    );

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const WorkTrialScreen()),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('verified-hours-tile')),
        matching: find.text('0h 0m'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('verified-hours-tile')),
        matching: find.text('2h 0m'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('History shows four recent days and expands all for each month', (
    tester,
  ) async {
    dotenv.loadFromString(envString: '', isOptional: true);
    SharedPreferences.setMockInitialValues({
      'ems.user': jsonEncode({'id': 'history-user'}),
      'ems.authToken': 'test-token',
    });
    AttendanceService.debugOverrideClient(
      MockClient((request) async {
        if (!request.url.path.endsWith('/my-scans'))
          return http.Response('[]', 200);
        final first = DateTime.parse(request.url.queryParameters['from']!);
        final scans = [
          for (var day = 1; day <= 6; day++)
            {
              'workDate':
                  '${first.year}-${first.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
              'windowCode': 'morning_in',
              'counted': true,
              'scannedAt':
                  '${first.year}-${first.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}T08:00:00+07:00',
            },
        ];
        return http.Response(jsonEncode(scans), 200);
      }),
    );
    addTearDown(AttendanceService.debugResetClient);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const HistoryScreen()),
    );
    await tester.pumpAndSettle();
    final scrollable = find.byType(Scrollable).first;
    final viewAll = find.text('View all (6)');
    await tester.scrollUntilVisible(viewAll, 300, scrollable: scrollable);
    await tester.pumpAndSettle();
    expect(find.text('Show less'), findsNothing);
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final oldest = '${months[now.month - 1]} 1, ${now.year}';
    expect(find.text(oldest), findsNothing);
    await tester.tap(viewAll);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Show less'),
      300,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    expect(find.text('Show less'), findsOneWidget);
    expect(find.text(oldest), findsOneWidget);
    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    expect(find.text('View all (6)'), findsOneWidget);
    await tester.dragUntilVisible(
      find.byTooltip('Previous month'),
      find.byType(CustomScrollView).first,
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('View all (6)'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('Show less'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching tabs returns History to the top', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    dotenv.loadFromString(envString: '', isOptional: true);
    SharedPreferences.setMockInitialValues({
      'ems.user': jsonEncode({'id': 'history-user'}),
      'ems.authToken': 'test-token',
    });
    AttendanceService.debugOverrideClient(
      MockClient((_) async => http.Response('[]', 200)),
    );
    addTearDown(AttendanceService.debugResetClient);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const MainShell()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();
    final list = find
        .descendant(
          of: find.byType(HistoryScreen),
          matching: find.byType(CustomScrollView),
        )
        .first;
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: list, matching: find.byType(Scrollable)).first,
        )
        .position;
    await tester.drag(list, const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    await tester.tap(find.text('Attendance').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();
    expect(position.pixels, 0);
    await tester.tap(find.byKey(const ValueKey('nav-item-2')));
    await tester.pumpAndSettle();
    expect(find.byType(WorkTrialScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-item-3')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login form scrolls with a keyboard and enlarged text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(667, 375);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2), disableAnimations: true),
          child: child!,
        ),
        home: const LoginScreen(),
      ),
    );
    final password = find.byType(TextFormField).last;
    await tester.ensureVisible(password);
    await tester.tap(password);
    tester.view.viewInsets = const FakeViewPadding(bottom: 160);
    await tester.pumpAndSettle();

    final toggle = find.byTooltip('Show password');
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hide password'), findsOneWidget);

    final submit = find.widgetWithText(FilledButton, 'Sign In');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    expect(submit.hitTestable(), findsOneWidget);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Please enter your username.'), findsOneWidget);
    expect(find.text('Please enter your password.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final reducedMotion in [false, true]) {
    testWidgets('sign-in and sign-out replace the session screen '
        '(reduced motion: $reducedMotion)', (tester) async {
      dotenv.loadFromString(envString: '', isOptional: true);
      SharedPreferences.setMockInitialValues({});
      final requests = <String>[];
      final client = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'POST') requests.add(path.split('/').last);
        final Object response;
        if (path.endsWith('/auth/login') || path.endsWith('/auth/me')) {
          response = {
            'accessToken': 'test-token',
            'user': {'id': 'test-user', 'name': 'Alex'},
          };
        } else if (path.endsWith('/status')) {
          response = {'currentWorkDate': '2026-11-20'};
        } else if (path.endsWith('/auth/logout')) {
          response = <String, Object>{};
        } else {
          response = <Object>[];
        }
        return http.Response(jsonEncode(response), 200);
      });
      AuthService.debugOverrideClient(client);
      AttendanceService.debugOverrideClient(client);
      addTearDown(AuthService.debugResetClient);
      addTearDown(AttendanceService.debugResetClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reducedMotion),
            child: child!,
          ),
          home: const LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'alex');
      await tester.enterText(find.byType(TextFormField).last, 'password');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();

      final shell = tester.element(find.byType(MainShell));
      final signInRoute = ModalRoute.of(shell)!;
      expect(signInRoute.transitionDuration == Duration.zero, reducedMotion);
      expect(Navigator.of(shell).canPop(), isFalse);

      if (reducedMotion) {
        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        final logout = find.widgetWithText(OutlinedButton, 'Log Out');
        await tester.ensureVisible(logout);
        await tester.tap(logout);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirm-logout-button')));
      } else {
        await tester.tap(find.byTooltip('Account'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirm-logout-button')));
      }
      await tester.pumpAndSettle();
      final login = tester.element(find.byType(LoginScreen));
      final signOutRoute = ModalRoute.of(login)!;
      expect(signOutRoute.transitionDuration == Duration.zero, reducedMotion);
      expect(Navigator.of(login).canPop(), isFalse);
      expect(requests, ['login', 'logout']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'completed check-in remains visible with a reason and cannot submit again',
    (tester) async {
      dotenv.loadFromString(envString: '', isOptional: true);
      SharedPreferences.setMockInitialValues({
        'ems.user': jsonEncode({'id': 'ui-user', 'name': 'Alex'}),
        'ems.authToken': 'test-token',
      });
      final methods = <String>[];
      AttendanceService.debugOverrideClient(
        MockClient((request) async {
          methods.add(request.method);
          return http.Response(
            jsonEncode(
              request.url.path.endsWith('/status')
                  ? {
                      'currentWorkDate': '2026-11-20',
                      'currentWindowCode': 'morning_in',
                      'latestCountedEvent': {
                        'workDate': '2026-11-20',
                        'windowCode': 'morning_in',
                      },
                    }
                  : [],
            ),
            200,
          );
        }),
      );
      addTearDown(AttendanceService.debugResetClient);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const AttendanceScreen()),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      final button = find.byType(TimeActionButton);
      expect(find.widgetWithText(TimeActionButton, 'CHECK IN'), findsOneWidget);
      expect(find.text('Morning In • Already recorded'), findsOneWidget);
      expect(
        find.text('Next: Lunch Out · Opening time unavailable'),
        findsOneWidget,
      );
      expect(find.text('Recorded'), findsOneWidget);
      expect(tester.widget<TimeActionButton>(button).enabled, isFalse);
      await tester.tap(button);
      await tester.pump();
      expect(methods, everyElement('GET'));
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('text and status foregrounds retain readable contrast', () {
    for (final pair in [
      (AppColors.neutral, AppColors.secondary),
      (AppColors.textSecondary, AppColors.surface),
      (AppColors.onNeutralMuted, AppColors.neutral),
      (AppColors.onSuccessContainer, AppColors.successContainer),
      (AppColors.onWarningContainer, AppColors.warningContainer),
      (AppColors.onErrorContainer, AppColors.errorContainer),
    ]) {
      final a = pair.$1.computeLuminance();
      final b = pair.$2.computeLuminance();
      final ratio = a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
      expect(ratio, greaterThanOrEqualTo(4.5));
    }
  });
  testWidgets('attendance action works by keyboard and disabled stays inert', (
    tester,
  ) async {
    var calls = 0;
    Future<void> show(bool enabled) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TimeActionButton(
                label: 'Check In',
                icon: Icons.login,
                enabled: enabled,
                onPressed: () => calls++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await show(true);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 1);
    await show(false);
    await tester.tap(find.byType(TimeActionButton));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(calls, 1);
  });
  testWidgets(
    'mobile activity stays visible and reading never submits attendance',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      dotenv.loadFromString(envString: '', isOptional: true);
      SharedPreferences.setMockInitialValues({
        'ems.user': jsonEncode({'id': 'ui-user', 'name': 'Alex Morgan'}),
        'ems.authToken': 'test-token',
      });
      final methods = <String>[];
      AttendanceService.debugOverrideClient(
        MockClient((request) async {
          methods.add(request.method);
          return http.Response(
            jsonEncode(
              request.url.path.endsWith('/status')
                  ? {'currentWorkDate': '2026-11-20', 'currentWindowCode': null}
                  : [],
            ),
            200,
          );
        }),
      );
      addTearDown(AttendanceService.debugResetClient);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: const AttendanceScreen(),
            bottomNavigationBar: AppBottomNav(currentIndex: 0, onTap: (_) {}),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(
        tester.getBottomLeft(find.text("TODAY'S ACTIVITY")).dy,
        lessThan(640),
      );
      expect(methods, everyElement('GET'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('long error messages are not clipped', (tester) async {
    const message =
        'The attendance service could not complete this request. Please check your connection, keep your saved photo, and retry the same request when the service is available.';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: const StatusBanner(
              message: message,
              variant: StatusVariant.error,
            ),
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(find.text(message));
    expect(text.maxLines, isNull);
    expect(tester.takeException(), isNull);
  });
}
