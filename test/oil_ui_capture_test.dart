import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cirrus_app/screens/attendance_screen.dart';
import 'package:cirrus_app/screens/earnings_trial_tab.dart';
import 'package:cirrus_app/screens/history_screen.dart';
import 'package:cirrus_app/screens/leave_trial_tab.dart';
import 'package:cirrus_app/screens/login_screen.dart';
import 'package:cirrus_app/screens/profile_screen.dart';
import 'package:cirrus_app/services/attendance_service.dart';
import 'package:cirrus_app/services/auth_service.dart';
import 'package:cirrus_app/services/work_trial_store.dart';
import 'package:cirrus_app/theme/app_theme.dart';
import 'package:cirrus_app/widgets/app_bottom_nav.dart';
import 'package:cirrus_app/widgets/app_side_nav.dart';

import 'support/preview_fonts.dart';

// Opt-in real Flutter render captures for visual review; no real API requests.
void main() {
  final stage = Platform.environment['OIL_UI_CAPTURE'];
  testWidgets('capture oil-ui representative screens', (tester) async {
    await tester.runAsync(loadPreviewFonts);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    dotenv.loadFromString(envString: '', isOptional: true);
    SharedPreferences.setMockInitialValues({
      'ems.user': jsonEncode({'id': 'preview', 'name': 'Alex Morgan'}),
      'ems.authToken': 'preview-token',
    });
    String? windowCode;
    http.Response respond(http.Request request) {
      if (request.method != 'GET') {
        throw StateError('Visual capture must not write to an API');
      }
      final body = request.url.path.endsWith('/auth/me')
          ? {
              'user': {
                'id': 'preview',
                'name': 'Alex Morgan',
                'email': 'alex@example.test',
                'employeeCode': 'EMP-204',
                'active': true,
              },
              'roles': ['Employee'],
            }
          : request.url.path.endsWith('/status')
          ? {
              'currentWorkDate': '2026-11-20',
              'currentWindowCode': windowCode,
              if (windowCode == 'afternoon_in')
                'latestEvent': {
                  'workDate': '2026-11-20',
                  'scannedAt': '2026-11-20T03:12:28Z',
                  'counted': false,
                  'notCountedReason': 'duplicate_in_window',
                },
            }
          : request.url.path.endsWith('/my-scans') &&
                windowCode == 'afternoon_in'
          ? [
              {
                'workDate': '2026-11-20',
                'windowCode': 'morning_in',
                'counted': true,
              },
            ]
          : [];
      return http.Response(jsonEncode(body), 200);
    }

    AttendanceService.debugOverrideClient(MockClient((r) async => respond(r)));
    AuthService.debugOverrideClient(MockClient((r) async => respond(r)));
    addTearDown(AttendanceService.debugResetClient);
    addTearDown(AuthService.debugResetClient);
    final store = WorkTrialStore('preview');
    final cases = <(String, Size, Widget, int?, String?)>[
      (
        'attendance-mobile',
        const Size(390, 844),
        const AttendanceScreen(),
        0,
        null,
      ),
      (
        'attendance-enabled-mobile',
        const Size(390, 844),
        const AttendanceScreen(),
        0,
        'morning_in',
      ),
      (
        'attendance-activity-mobile',
        const Size(390, 844),
        const AttendanceScreen(),
        0,
        'afternoon_in',
      ),
      (
        'attendance-desktop',
        const Size(1440, 900),
        const AttendanceScreen(),
        0,
        'morning_in',
      ),
      ('history-mobile', const Size(390, 844), const HistoryScreen(), 1, null),
      (
        'pay-mobile',
        const Size(390, 844),
        Scaffold(
          appBar: AppBar(title: const Text('Earnings & Leave')),
          body: EarningsTrialTab(store: store),
        ),
        3,
        null,
      ),
      (
        'leave-mobile',
        const Size(390, 844),
        Scaffold(
          appBar: AppBar(title: const Text('Earnings & Leave')),
          body: LeaveTrialTab(store: store),
        ),
        3,
        null,
      ),
      ('profile-mobile', const Size(390, 844), const ProfileScreen(), 3, null),
      ('login-mobile', const Size(390, 844), const LoginScreen(), null, null),
      ('login-desktop', const Size(1280, 720), const LoginScreen(), null, null),
    ];
    for (final entry in cases) {
      windowCode = entry.$5;
      tester.view.physicalSize = entry.$2;
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: Scaffold(
              body: entry.$4 == null || entry.$2.width < 900
                  ? entry.$3
                  : Row(
                      children: [
                        AppSideNav(currentIndex: entry.$4!, onTap: (_) {}),
                        Expanded(child: entry.$3),
                      ],
                    ),
              bottomNavigationBar: entry.$4 == null || entry.$2.width >= 900
                  ? null
                  : AppBottomNav(currentIndex: entry.$4!, onTap: (_) {}),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File('.oil-ui/screenshots/$stage-${entry.$1}.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    }
  }, skip: stage == null);
}
