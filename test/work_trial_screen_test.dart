import 'dart:convert';

import 'package:cirrus_app/models/payroll_calculator.dart';
import 'package:cirrus_app/screens/work_trial_screen.dart';
import 'package:cirrus_app/services/attendance_service.dart';
import 'package:cirrus_app/services/auth_service.dart';
import 'package:cirrus_app/services/file_download_service.dart';
import 'package:cirrus_app/services/work_trial_store.dart';
import 'package:cirrus_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(envString: '', isOptional: true);
    SharedPreferences.setMockInitialValues({
      'ems.user': jsonEncode({'id': 'trial-user'}),
      'ems.authToken': 'test-token',
    });
    AuthService.debugOverrideClient(
      MockClient((_) async => http.Response('{}', 200)),
    );
  });

  tearDown(() {
    AuthService.debugResetClient();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const WorkTrialScreen()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'fixed daily wage pays verified regular hours and keeps bonus time separate',
    (tester) async {
      final now = bangkokNow();
      final date = calendarDate(DateTime(now.year, now.month, 2));
      final incompleteDate = calendarDate(DateTime(now.year, now.month, 3));
      final scans = [
        {
          'windowCode': 'morning_in',
          'workDate': date,
          'scannedAt': '${date}T09:30:00+07:00',
        },
        {
          'windowCode': 'lunch_out',
          'workDate': date,
          'scannedAt': '${date}T12:00:00+07:00',
        },
        {
          'windowCode': 'afternoon_in',
          'workDate': date,
          'scannedAt': '${date}T13:00:00+07:00',
        },
        {
          'windowCode': 'leave',
          'workDate': date,
          'scannedAt': '${date}T18:00:00+07:00',
        },
        {
          'windowCode': 'morning_in',
          'workDate': incompleteDate,
          'scannedAt': '${incompleteDate}T08:00:00+07:00',
        },
      ];
      AttendanceService.debugOverrideClient(
        MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, contains('my-scans'));
          return http.Response(jsonEncode(scans), 200);
        }),
      );
      addTearDown(AttendanceService.debugResetClient);
      await open(tester);
      expect(find.text('THB 243.75'), findsOneWidget);
      final verifiedTile = find.byKey(const Key('verified-hours-tile'));
      expect(
        find.descendant(
          of: verifiedTile,
          matching: find.text('Verified hours counted'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: verifiedTile, matching: find.text('6h 30m')),
        findsOneWidget,
      );
      final bonusTile = find.byKey(const Key('bonus-time-tile'));
      expect(
        find.descendant(
          of: bonusTile,
          matching: find.text('Bonus time after 17:00'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bonusTile, matching: find.text('1h 0m')),
        findsOneWidget,
      );
      final breakdown = find.text('How this is calculated');
      expect(find.text(incompleteDate), findsNothing);
      await tester.ensureVisible(breakdown);
      await tester.tap(breakdown);
      await tester.pumpAndSettle();
      expect(find.text('= THB 243.75'), findsOneWidget);
      expect(find.text('THB 37.50/hr × 6h 30m'), findsOneWidget);
      final review = find.text('Scans need review (1)');
      expect(find.text(incompleteDate), findsNothing);
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(find.text(incompleteDate), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(await WorkTrialStore('trial-user').loadSettings(), isNull);
    },
  );

  testWidgets('local leave draft stays local', (tester) async {
    // Mock printing channel (used by PdfPreview widget internally)
    const printing = MethodChannel('net.nfet.printing');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(printing, (call) async {
          if (call.method == 'printingInfo') return <String, dynamic>{};
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(printing, null),
    );

    // Mock download service so tests don't touch the file system
    final downloadedFiles = <String>[];
    FileDownloadService.debugDownloadOverride = (bytes, filename) async {
      downloadedFiles.add(filename);
      return '/Download/$filename';
    };
    addTearDown(() => FileDownloadService.debugDownloadOverride = null);

    AttendanceService.debugOverrideClient(
      MockClient((_) async => http.Response('[]', 200)),
    );
    addTearDown(AttendanceService.debugResetClient);
    await open(tester);
    await tester.tap(find.text('Local leave'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('leave-reason')),
      'Medical visit',
    );
    await tester.ensureVisible(find.byKey(const Key('save-leave')));
    await tester.tap(find.byKey(const Key('save-leave')));
    await tester.pumpAndSettle();
    expect(
      (await WorkTrialStore('trial-user').loadLeaves()).single.reason,
      'Medical visit',
    );
    expect(find.text('View PDF'), findsNWidgets(2));
    await tester.tap(find.text('View PDF').last);
    await tester.pumpAndSettle();
    expect(find.text('Leave PDF'), findsOneWidget);
    expect(find.byTooltip('Download PDF'), findsOneWidget);
    expect(find.byTooltip('Share PDF'), findsOneWidget);
    await tester.tap(find.byTooltip('Download PDF'));
    await tester.pumpAndSettle();
    expect(downloadedFiles, hasLength(1));
    expect(downloadedFiles.single, endsWith('.pdf'));
  });

  testWidgets('scan failure is visible and does not show pay', (tester) async {
    AttendanceService.debugOverrideClient(
      MockClient((_) async => http.Response('{"message":"offline"}', 503)),
    );
    addTearDown(AttendanceService.debugResetClient);
    await open(tester);
    expect(find.textContaining('offline'), findsWidgets);
    expect(find.text('Estimated base pay'), findsNothing);
  });

  testWidgets('wallet card supports tap-to-flip 3D to back and back to front', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'ems.user': jsonEncode({
        'id': 'trial-user',
        'name': 'Jirawat Janjobtam',
        'employeeCode': '260831',
        'department': 'Administration',
        'employmentType': 'full_time',
        'employmentStatus': 'active',
        'startDate': '2026-10-06',
        'salary': 16000,
      }),
      'ems.authToken': 'test-token',
    });
    final now = bangkokNow();
    final date = calendarDate(DateTime(now.year, now.month, 2));
    final scans = [
      {
        'windowCode': 'morning_in',
        'workDate': date,
        'scannedAt': '${date}T09:30:00+07:00',
      },
      {
        'windowCode': 'lunch_out',
        'workDate': date,
        'scannedAt': '${date}T12:00:00+07:00',
      },
    ];
    AttendanceService.debugOverrideClient(
      MockClient((_) async => http.Response(jsonEncode(scans), 200)),
    );
    addTearDown(AttendanceService.debugResetClient);
    await open(tester);

    // 2h 30m × (16,000 ÷ 30 ÷ 8 = THB 66.67/hr) = THB 166.68
    expect(find.text('THB 166.68'), findsOneWidget);
    expect(find.text('Hide balance'), findsNothing);
    expect(find.text('Flip card'), findsNothing);

    await tester.tap(find.byKey(const Key('pay-wallet-card')));
    await tester.pumpAndSettle();
    expect(find.text('CIRRUS EMS · PAY CARD DETAILS'), findsOneWidget);
    expect(find.text('BASE SALARY'), findsOneWidget);
    expect(find.text('THB 16,000.00'), findsOneWidget);
    expect(find.text('DEPARTMENT'), findsOneWidget);
    expect(find.text('ADMINISTRATION'), findsOneWidget);
    expect(find.text('EMPLOYMENT'), findsOneWidget);
    expect(find.text('FULL-TIME · ACTIVE'), findsOneWidget);
    expect(find.text('START DATE'), findsOneWidget);
    expect(find.text('06 OCT 2026'), findsOneWidget);

    // Switching to Local leave and returning resets the card to its front face.
    await tester.tap(find.text('Local leave'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay estimate'));
    await tester.pumpAndSettle();
    expect(find.text('Estimated base pay'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pay-wallet-card')));
    await tester.pumpAndSettle();
    expect(find.text('CIRRUS EMS · PAY CARD DETAILS'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pay-wallet-card')));
    await tester.pumpAndSettle();
    expect(find.text('Estimated base pay'), findsOneWidget);
  });

  testWidgets('local leave shows 2 recent drafts and opens All Leave Drafts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'ems.user': jsonEncode({'id': 'trial-user'}),
      'ems.authToken': 'test-token',
      'ems.workTrial.leaves.trial-user': jsonEncode([
        {
          'id': 'draft-3',
          'type': 'annual',
          'start': '2026-11-10',
          'end': '2026-11-10',
          'reason': 'Third draft',
          'createdAt': '2026-11-10T08:00:00.000Z',
          'cancelled': false,
        },
        {
          'id': 'draft-2',
          'type': 'personal',
          'start': '2026-11-05',
          'end': '2026-11-05',
          'reason': 'Second draft',
          'createdAt': '2026-11-05T08:00:00.000Z',
          'cancelled': false,
        },
        {
          'id': 'draft-1',
          'type': 'sick',
          'start': '2026-11-01',
          'end': '2026-11-01',
          'reason': 'First draft',
          'createdAt': '2026-11-01T08:00:00.000Z',
          'cancelled': true,
        },
      ]),
    });

    AttendanceService.debugOverrideClient(
      MockClient((_) async => http.Response('[]', 200)),
    );
    addTearDown(AttendanceService.debugResetClient);
    await open(tester);
    await tester.tap(find.text('Local leave'));
    await tester.pumpAndSettle();

    expect(find.text('Third draft'), findsOneWidget);
    expect(find.text('Second draft'), findsOneWidget);
    expect(find.text('First draft'), findsNothing);

    final viewAll = find.byKey(const Key('view-all-leave-drafts'));
    await tester.ensureVisible(viewAll);
    await tester.tap(viewAll);
    await tester.pumpAndSettle();

    expect(find.text('All Leave Drafts'), findsOneWidget);
    expect(find.text('Third draft'), findsOneWidget);
    expect(find.text('Second draft'), findsOneWidget);
    expect(find.text('First draft'), findsOneWidget);

    await tester.tap(find.text('Cancelled (1)'));
    await tester.pumpAndSettle();
    expect(find.text('First draft'), findsOneWidget);
    expect(find.text('Third draft'), findsNothing);
  });
}
