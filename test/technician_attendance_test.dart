import 'dart:convert';

import 'package:cirrus_app/screens/attendance_screen.dart';
import 'package:cirrus_app/screens/settings_screen.dart';
import 'package:cirrus_app/screens/technician_report_screen.dart';
import 'package:cirrus_app/services/attendance_service.dart';
import 'package:cirrus_app/services/auth_service.dart';
import 'package:cirrus_app/services/language_service.dart';
import 'package:cirrus_app/services/technician_service.dart';
import 'package:cirrus_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(envString: '', isOptional: true);
  });

  tearDown(() {
    AttendanceService.debugResetClient();
    TechnicianService.getMyJobsOverride = null;
    TechnicianService.checkInOverride = null;
    TechnicianService.checkOutOverride = null;
    TechnicianService.submitReportOverride = null;
    TechnicianService.getHistoryOverride = null;
    TechnicianService.startBreakOverride = null;
    TechnicianService.endFromBreakOverride = null;
  });

  Widget wrapScreen(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: child,
  );

  void stubBaseAttendance() {
    AttendanceService.debugOverrideClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/my-scans')) {
          return http.Response('[]', 200);
        }
        return http.Response(
          jsonEncode({
            'currentWorkDate': '2026-11-25',
            'currentWindowCode': null,
            'latestEvent': null,
            'latestCountedEvent': null,
          }),
          200,
        );
      }),
    );
  }

  test('AuthService.hasTechnicianRole allows Technician and Admin roles only', () {
    expect(AuthService.hasTechnicianRole(['Technician']), isTrue);
    expect(AuthService.hasTechnicianRole(['Staff', 'technician']), isTrue);
    expect(AuthService.hasTechnicianRole(['Admin']), isTrue);
    expect(AuthService.hasTechnicianRole(['Staff', 'HR Officer']), isFalse);
    expect(AuthService.hasTechnicianRole(const []), isFalse);
  });

  testWidgets('Non-technician account does NOT see Technician mode UI', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'ems.user': jsonEncode({'id': 'u1', 'name': 'Staff User'}),
      'ems.roles': jsonEncode(['Staff', 'HR Officer']),
    });
    await LanguageService.setLanguage(AppLanguage.en);
    stubBaseAttendance();

    await tester.pumpWidget(wrapScreen(const AttendanceScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('technician-role-badge')), findsNothing);
    expect(find.byKey(const Key('technician-job-picker')), findsNothing);
  });

  testWidgets(
    'Technician sees role badge, selects own Job Code, and unlocks Check In',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'ems.user': jsonEncode({'id': 't1', 'name': 'Touch'}),
        'ems.roles': jsonEncode(['Staff', 'Technician']),
      });
      await LanguageService.setLanguage(AppLanguage.en);
      stubBaseAttendance();

      TechnicianService.getMyJobsOverride = () async =>
          const TechnicianDashboardData(
            workDate: '2026-11-25',
            jobs: [
              TechnicianJob(
                id: 'wo-1',
                jobCode: 'JOB-2611-101',
                title: 'Marine Generator Maintenance',
                description: '500-hour generator inspection at Pier A',
                vesselName: 'M/Y Andaman Star',
                projectName: 'Annual Refit 2026',
                isMine: true,
                assignedToName: 'Touch',
              ),
              TechnicianJob(
                id: 'wo-2',
                jobCode: 'JOB-2611-202',
                title: 'Electrical Panel Diagnostics',
                description: 'Breaker inspection at Dock B',
                isMine: false,
                assignedToName: 'Owen',
              ),
            ],
            todaySessions: [],
            completedWindows: {},
            nextWindowCode: 'morning_in',
          );

      await tester.pumpWidget(wrapScreen(const AttendanceScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('technician-role-badge')), findsOneWidget);
      expect(find.byKey(const Key('technician-job-picker')), findsOneWidget);
      expect(find.byKey(const Key('technician-my-jobs-badge')), findsOneWidget);
      expect(find.textContaining('Select your Job Code above'), findsOneWidget);

      // Open All Job Codes page -> own job highlighted at top, other jobs below
      await tester.tap(find.byKey(const Key('technician-job-picker')));
      await tester.pumpAndSettle();

      expect(find.text('YOUR JOB'), findsOneWidget);
      expect(find.text('JOB-2611-101'), findsOneWidget);
      expect(find.text('M/Y Andaman Star'), findsOneWidget);
      expect(find.text('JOB-2611-202'), findsOneWidget);

      // Tap own job -> shows confirmation dialog to prevent human error -> confirm -> pops back to AttendanceScreen
      await tester.tap(find.byKey(const Key('job-item-JOB-2611-101')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('confirm-job-selection-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('confirm-select-job-button')));
      await tester.pumpAndSettle();

      expect(
        find.text('500-hour generator inspection at Pier A'),
        findsOneWidget,
      );
      expect(find.text('M/Y Andaman Star'), findsOneWidget);
      expect(find.textContaining('Morning In · JOB-2611-101'), findsOneWidget);

      // Unselect via quick clear button -> Check In disables again
      await tester.tap(find.byKey(const Key('technician-clear-job-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Select your Job Code above'), findsOneWidget);
    },
  );

  testWidgets(
    'Technician with active session sees GPS badge and Lunch/Leave Check Out options',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'ems.user': jsonEncode({'id': 't1', 'name': 'Touch'}),
        'ems.roles': jsonEncode(['Technician']),
      });
      await LanguageService.setLanguage(AppLanguage.en);
      stubBaseAttendance();

      TechnicianService.getMyJobsOverride = () async =>
          const TechnicianDashboardData(
            workDate: '2026-11-25',
            jobs: [
              TechnicianJob(
                id: 'wo-1',
                jobCode: 'JOB-2611-101',
                title: 'Marine Generator Maintenance',
              ),
            ],
            activeSession: TechnicianWorkSession(
              id: 'sess-1',
              jobId: 'wo-1',
              jobCode: 'JOB-2611-101',
              jobTitle: 'Marine Generator Maintenance',
              vesselName: 'M/Y Andaman Star',
              status: 'active',
              checkInAt: '2026-11-25T01:30:00.000Z',
              checkInLatitude: 7.8804,
              checkInLongitude: 98.3923,
            ),
            todaySessions: [
              TechnicianWorkSession(
                id: 'sess-1',
                jobId: 'wo-1',
                jobCode: 'JOB-2611-101',
                jobTitle: 'Marine Generator Maintenance',
                status: 'active',
                checkInAt: '2026-11-25T01:30:00.000Z',
                checkInLatitude: 7.8804,
                checkInLongitude: 98.3923,
              ),
            ],
            completedWindows: {'morning_in'},
            nextWindowCode: 'lunch_out',
          );

      await tester.pumpWidget(wrapScreen(const AttendanceScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('technician-active-job-card')), findsOneWidget);
      expect(find.text('M/Y Andaman Star'), findsWidgets);
      expect(find.byKey(const Key('technician-work-timer')), findsOneWidget);
      expect(find.textContaining('GPS 7.8804, 98.3923'), findsOneWidget);
      expect(find.byKey(const Key('technician-break-button')), findsOneWidget);

      // Tap Check Out -> opens auto-locked checkout sheet (no manual period toggle)
      await tester.tap(find.text('CHECK OUT'));
      await tester.pumpAndSettle();

      expect(find.text('Lunch Break Out'), findsOneWidget);
      expect(find.text('End of Day (Leave)'), findsNothing);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Take Photo & Check Out'), findsOneWidget);
    },
  );

  testWidgets(
    'Technician on break sees Resume Work button and End Shift Now prompt',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'ems.user': jsonEncode({'id': 't1', 'name': 'Touch'}),
        'ems.roles': jsonEncode(['Technician']),
      });
      await LanguageService.setLanguage(AppLanguage.en);
      stubBaseAttendance();

      TechnicianService.getMyJobsOverride = () async =>
          const TechnicianDashboardData(
            workDate: '2026-11-26',
            jobs: [
              TechnicianJob(
                id: 'wo-1',
                jobCode: 'JOB-2611-101',
                title: 'Marine Generator Maintenance',
              ),
            ],
            breakSession: TechnicianWorkSession(
              id: 'sess-brk',
              jobId: 'wo-1',
              jobCode: 'JOB-2611-101',
              jobTitle: 'Marine Generator Maintenance',
              status: 'completed',
              checkInAt: '2026-11-26T01:30:00.000Z',
              checkOutAt: '2026-11-26T05:00:00.000Z',
              jobStatusAtCheckout: 'on_break',
            ),
            todaySessions: [],
            completedWindows: {'morning_in', 'lunch_out'},
            nextWindowCode: 'afternoon_in',
          );

      await tester.pumpWidget(wrapScreen(const AttendanceScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('technician-on-break-card')), findsOneWidget);
      expect(find.text('RESUME WORK'), findsOneWidget);
      expect(
        find.byKey(const Key('technician-end-from-break-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('technician-end-from-break-button')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Pending work report locks next job until technician submits the report',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'ems.user': jsonEncode({'id': 't1', 'name': 'Touch'}),
        'ems.roles': jsonEncode(['Technician']),
      });
      await LanguageService.setLanguage(AppLanguage.en);
      stubBaseAttendance();

      var reportSubmitted = false;
      TechnicianService.getMyJobsOverride = () async => TechnicianDashboardData(
        workDate: '2026-11-25',
        jobs: const [
          TechnicianJob(
            id: 'wo-1',
            jobCode: 'JOB-2611-101',
            title: 'Marine Generator Maintenance',
          ),
        ],
        pendingReportSession: reportSubmitted
            ? null
            : const TechnicianWorkSession(
                id: 'sess-1',
                jobId: 'wo-1',
                jobCode: 'JOB-2611-101',
                jobTitle: 'Marine Generator Maintenance',
                status: 'completed',
                checkInAt: '2026-11-25T01:30:00.000Z',
                checkOutAt: '2026-11-25T05:00:00.000Z',
                durationMinutes: 210,
              ),
        todaySessions: const [],
        completedWindows: const {'morning_in', 'lunch_out'},
        nextWindowCode: 'afternoon_in',
      );

      String? submittedFindings;
      TechnicianService.submitReportOverride = ({
        required sessionId,
        required workDescription,
        required workType,
        findings,
        recommendations,
        photos = const [],
      }) async {
        reportSubmitted = true;
        submittedFindings = findings;
        return {'report': {'id': 'rep-1', 'status': 'submitted'}};
      };

      await tester.pumpWidget(wrapScreen(const AttendanceScreen()));
      await tester.pumpAndSettle();

      // Job picker is locked and pending report card is displayed
      expect(find.byKey(const Key('technician-pending-report-card')), findsOneWidget);
      expect(find.byKey(const Key('technician-job-picker')), findsNothing);

      // Open mandatory report screen, verify Work Photos & Problems fields, fill and submit
      await tester.tap(find.byKey(const Key('open-pending-report-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add-report-photo-button')), findsOneWidget);
      expect(find.byKey(const Key('report-findings-field')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('report-description-field')),
        'Replaced oil filter and verified voltage output.',
      );
      await tester.enterText(
        find.byKey(const Key('report-findings-field')),
        'Minor oil seepage around gasket.',
      );
      await tester.tap(find.byKey(const Key('submit-technician-report-button')));
      await tester.pumpAndSettle();

      expect(submittedFindings, 'Minor oil seepage around gasket.');
      // Report lock disappears and Job Picker unlocks for the next job
      expect(find.byKey(const Key('technician-pending-report-card')), findsNothing);
      expect(find.byKey(const Key('technician-job-picker')), findsOneWidget);
    },
  );

  testWidgets(
    'Settings shows Job & Report History for Technician/Admin and displays reports',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'ems.user': jsonEncode({'id': 't1', 'name': 'Touch'}),
        'ems.roles': jsonEncode(['Technician']),
      });
      await LanguageService.setLanguage(AppLanguage.en);

      TechnicianService.getHistoryOverride = () async =>
          const TechnicianHistoryResponse(
            isAdmin: false,
            items: [
              TechnicianHistoryItem(
                sessionId: 'sess-1',
                technicianName: 'Touch',
                isMine: true,
                jobCode: 'JOB-2611-101',
                jobTitle: 'Marine Generator Maintenance',
                sessionStatus: 'completed',
                checkInAt: '2026-11-25T01:30:00.000Z',
                checkOutAt: '2026-11-25T05:00:00.000Z',
                durationMinutes: 210,
                jobStatusAtCheckout: 'completed',
                hasGps: true,
                reportId: 'rep-1',
                reportNumber: 'TR-20261125-ABCD',
                workType: 'maintenance',
                workDescription: 'Changed oil filter and checked voltage.',
                findings: 'Minor oil leak on gasket',
                photoCount: 2,
                reportStatus: 'submitted',
              ),
            ],
          );

      await tester.pumpWidget(wrapScreen(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Job & Report History'), findsOneWidget);
      await tester.ensureVisible(find.text('Job & Report History'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Job & Report History'));
      await tester.pumpAndSettle();

      expect(find.text('JOB-2611-101'), findsOneWidget);
      expect(find.text('TR-20261125-ABCD'), findsOneWidget);
      expect(
        find.text('Changed oil filter and checked voltage.'),
        findsOneWidget,
      );
      expect(find.textContaining('Minor oil leak on gasket'), findsOneWidget);
      expect(find.text('2 photos'), findsOneWidget);
    },
  );

  testWidgets(
    'TechnicianReportScreen restores saved draft and deletes it on submit',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'ems.reportDraft.job-draft-1': jsonEncode({
          'workType': 'repair',
          'desc': 'Replaced coolant pump seal',
          'findings': 'Minor wear on impeller',
          'recommend': 'Recheck after sea trial',
        }),
      });
      TechnicianService.submitReportOverride = ({
        required String sessionId,
        required String workDescription,
        String workType = 'service',
        String? findings,
        String? recommendations,
        List<String> photos = const [],
      }) async => {'ok': true};

      await tester.pumpWidget(
        wrapScreen(
          const TechnicianReportScreen(
            job: TechnicianJob(
              id: 'job-draft-1',
              jobCode: 'WO-000099',
              title: 'Coolant Pump Repair',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('report-draft-restored-banner')),
        findsOneWidget,
      );
      expect(find.text('Replaced coolant pump seal'), findsOneWidget);

      final submitBtn = find.byKey(
        const Key('submit-technician-report-button'),
      );
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ems.reportDraft.job-draft-1'), isNull);
    },
  );
}
