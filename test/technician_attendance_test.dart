import 'dart:convert';

import 'package:cirrus_app/l10n/app_strings.dart';
import 'package:cirrus_app/screens/attendance_screen.dart';
import 'package:cirrus_app/screens/profile_screen.dart';
import 'package:cirrus_app/screens/settings_screen.dart';
import 'package:cirrus_app/screens/technician_jobs_screen.dart';
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
    AuthService.debugResetClient();
    AttendanceService.debugResetClient();
    TechnicianService.getMyJobsOverride = null;
    TechnicianService.checkInOverride = null;
    TechnicianService.checkOutOverride = null;
    TechnicianService.submitReportOverride = null;
    TechnicianService.getHistoryOverride = null;
    TechnicianService.startBreakOverride = null;
    TechnicianService.endFromBreakOverride = null;
    TechnicianService.clearCachedDashboard();
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

      // Startup center alert appears automatically for the pending report
      expect(
        find.byKey(const Key('pending-report-startup-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('pending-report-startup-ok-button')));
      await tester.pumpAndSettle();

      // Navigates straight to the pending report screen
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

      expect(
        find.byKey(const Key('confirm-submit-report-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('confirm-submit-report-button')));
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
      expect(find.textContaining('TR-20261125-ABCD'), findsOneWidget);
      expect(find.text('2 photos'), findsOneWidget);
      expect(
        find.text('Changed oil filter and checked voltage.'),
        findsNothing,
      );
      expect(find.textContaining('Minor oil leak on gasket'), findsNothing);

      await tester.tap(find.byKey(const Key('history-card-sess-1')));
      await tester.pumpAndSettle();

      expect(
        find.text('Changed oil filter and checked voltage.'),
        findsOneWidget,
      );
      expect(find.textContaining('Minor oil leak on gasket'), findsOneWidget);
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

      expect(
        find.byKey(const Key('confirm-submit-report-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('confirm-submit-report-button')));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ems.reportDraft.job-draft-1'), isNull);
    },
  );

  testWidgets(
    'TechnicianReportScreen asks confirmation before clearing saved draft',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'ems.reportDraft.job-draft-2': jsonEncode({
          'workType': 'service',
          'desc': 'Checked generator belts',
          'findings': '',
          'recommend': '',
        }),
      });
      await LanguageService.setLanguage(AppLanguage.en);

      await tester.pumpWidget(
        wrapScreen(
          const TechnicianReportScreen(
            job: TechnicianJob(
              id: 'job-draft-2',
              jobCode: 'WO-000100',
              title: 'Belt Check',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Checked generator belts'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('confirm-clear-draft-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('confirm-clear-draft-button')));
      await tester.pumpAndSettle();

      expect(find.text('Checked generator belts'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ems.reportDraft.job-draft-2'), isNull);
    },
  );

  test('AppStrings.friendlyError translates network and server errors cleanly', () async {
    await LanguageService.setLanguage(AppLanguage.en);
    expect(
      AppStrings.friendlyError(Exception('TimeoutException after 0:00:15')),
      contains('Connection timed out'),
    );
    expect(
      AppStrings.friendlyError(Exception('SocketException: Failed host lookup')),
      contains('Unable to connect to the server'),
    );
    expect(
      AppStrings.friendlyError(Exception('502 Bad Gateway')),
      contains('temporarily unavailable'),
    );
    expect(
      AppStrings.friendlyError(Exception('Work order already closed')),
      'Work order already closed',
    );
  });

  testWidgets(
    'ProfileScreen warns Technician before Log Out when ON SITE session is active',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'ems.token': 'tok-1',
        'ems.user': jsonEncode({'id': 't1', 'name': 'Touch'}),
        'ems.roles': jsonEncode(['Technician']),
      });
      await LanguageService.setLanguage(AppLanguage.en);

      AuthService.debugOverrideClient(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'user': {'id': 't1', 'name': 'Touch'},
              'roles': ['Technician'],
            }),
            200,
          );
        }),
      );
      TechnicianService.lastDashboardData = const TechnicianDashboardData(
        workDate: '2026-11-27',
        jobs: [],
        activeSession: TechnicianWorkSession(
          id: 'sess-active-1',
          jobId: 'wo-17',
          jobCode: 'WO-000017',
          jobTitle: 'Engine Overhaul',
          status: 'active',
          checkInAt: '2026-11-27T01:30:00.000Z',
        ),
        todaySessions: [],
        completedWindows: {},
      );

      await tester.pumpWidget(wrapScreen(const ProfileScreen()));
      await tester.pumpAndSettle();

      final logoutBtn = find.text('Log Out');
      await tester.ensureVisible(logoutBtn);
      await tester.pumpAndSettle();
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('logout-warning-dialog')), findsOneWidget);
      expect(find.textContaining('WO-000017'), findsWidgets);
    },
  );

  testWidgets(
    'TechnicianJobsScreen separates submitted awaiting-close jobs and locks Check-In',
    (tester) async {
      await LanguageService.setLanguage(AppLanguage.en);

      await tester.pumpWidget(
        wrapScreen(
          const TechnicianJobsScreen(
            jobs: [
              TechnicianJob(
                id: 'wo-open',
                jobCode: 'WO-OPEN-1',
                title: 'Active Generator Job',
                isMine: true,
                status: 'open',
              ),
              TechnicianJob(
                id: 'wo-done',
                jobCode: 'WO-DONE-1',
                title: 'Submitted Engine Job',
                isMine: true,
                status: 'open',
                reportSubmitted: true,
                lastCheckoutStatus: 'completed',
              ),
              TechnicianJob(
                id: 'wo-closed',
                jobCode: 'WO-CLOSED-1',
                title: 'Closed Archive Job',
                isMine: true,
                status: 'closed',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ASSIGNED TO YOU (1)'), findsOneWidget);
      expect(find.text('SUBMITTED · AWAITING CLOSE (1)'), findsOneWidget);
      expect(find.text('WO-OPEN-1'), findsOneWidget);
      expect(find.byKey(const Key('submitted-job-item-WO-DONE-1')), findsOneWidget);
      expect(find.text('WO-CLOSED-1'), findsNothing);

      await tester.tap(find.byKey(const Key('submitted-job-item-WO-DONE-1')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('job-submitted-awaiting-close-banner')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('select-job-for-checkin-button')), findsNothing);
    },
  );

  testWidgets(
    'Technician who already scanned attendance sees Start Job instead of Check In',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'ems.user': jsonEncode({'id': 't1', 'name': 'Touch'}),
        'ems.roles': jsonEncode(['Technician']),
      });
      await LanguageService.setLanguage(AppLanguage.en);

      AttendanceService.debugOverrideClient(
        MockClient((request) async {
          if (request.url.path.endsWith('/my-scans')) {
            return http.Response('[]', 200);
          }
          return http.Response(
            jsonEncode({
              'currentWorkDate': '2026-11-27',
              'currentWindowCode': 'morning_in',
              'latestEvent': {
                'windowCode': 'morning_in',
                'scannedAt': '2026-11-27T01:00:00.000Z',
              },
              'latestCountedEvent': {
                'windowCode': 'morning_in',
                'scannedAt': '2026-11-27T01:00:00.000Z',
              },
            }),
            200,
          );
        }),
      );

      TechnicianService.getMyJobsOverride = () async => const TechnicianDashboardData(
        workDate: '2026-11-27',
        jobs: [
          TechnicianJob(
            id: 'wo-200',
            jobCode: 'WO-200',
            title: 'Hull Inspection',
            isMine: true,
          ),
        ],
        todaySessions: [],
        completedWindows: {'morning_in'},
        nextWindowCode: 'afternoon_in',
      );

      await tester.pumpWidget(wrapScreen(const AttendanceScreen()));
      await tester.pumpAndSettle();

      expect(find.text('START JOB'), findsOneWidget);
      expect(find.text('CHECK IN'), findsNothing);
      expect(
        find.byKey(const Key('technician-scan-reminder-banner')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Technician with job today and stale yesterday scan sees scan reminder and Check In',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'ems.user': jsonEncode({'id': 't1', 'name': 'Touch'}),
        'ems.roles': jsonEncode(['Technician']),
      });
      await LanguageService.setLanguage(AppLanguage.en);

      AttendanceService.debugOverrideClient(
        MockClient((request) async {
          if (request.url.path.endsWith('/my-scans')) {
            return http.Response('[]', 200);
          }
          return http.Response(
            jsonEncode({
              'currentWorkDate': '2026-11-27',
              'currentWindowCode': 'morning_in',
              'latestEvent': {
                'workDate': '2026-11-26',
                'windowCode': 'leave',
                'scannedAt': '2026-11-26T10:00:00.000Z',
              },
              'latestCountedEvent': {
                'workDate': '2026-11-26',
                'windowCode': 'leave',
                'scannedAt': '2026-11-26T10:00:00.000Z',
              },
            }),
            200,
          );
        }),
      );

      TechnicianService.getMyJobsOverride = () async => const TechnicianDashboardData(
        workDate: '2026-11-27',
        jobs: [
          TechnicianJob(
            id: 'wo-201',
            jobCode: 'WO-201',
            title: 'Engine Check',
            isMine: true,
          ),
        ],
        todaySessions: [],
        completedWindows: {},
        nextWindowCode: 'morning_in',
      );

      await tester.pumpWidget(wrapScreen(const AttendanceScreen()));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('technician-scan-reminder-banner')),
        findsOneWidget,
      );
      expect(find.text('CHECK IN'), findsOneWidget);
      expect(find.text('START JOB'), findsNothing);
    },
  );

  testWidgets(
    'Pending TechnicianReportScreen hides back button and blocks maybePop until submitted',
    (tester) async {
      await LanguageService.setLanguage(AppLanguage.en);
      await tester.pumpWidget(
        wrapScreen(
          Builder(
            builder: (btnCtx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open-locked-report-btn'),
                  onPressed: () {
                    Navigator.of(btnCtx).push(
                      MaterialPageRoute(
                        builder: (_) => const TechnicianReportScreen(
                          session: TechnicianWorkSession(
                            id: 'sess-lock-1',
                            jobId: 'wo-lock-1',
                            jobCode: 'WO-900',
                            jobTitle: 'Locked Report Job',
                            status: 'completed',
                            checkInAt: '2026-11-27T08:00:00Z',
                            reportSubmitted: false,
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-locked-report-btn')));
      await tester.pumpAndSettle();

      expect(find.byType(TechnicianReportScreen), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byTooltip('Back'), findsNothing);

      final ctx = tester.element(find.byType(TechnicianReportScreen));
      await Navigator.of(ctx).maybePop();
      await tester.pumpAndSettle();

      expect(find.byType(TechnicianReportScreen), findsOneWidget);
      expect(find.byKey(const Key('open-locked-report-btn')), findsNothing);
      expect(find.byKey(const Key('report-locked-snackbar')), findsOneWidget);
    },
  );

  testWidgets(
    'Technician with no jobs and no scan today still sees scan reminder banner',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'ems.user': jsonEncode({'id': 't1', 'name': 'Touch'}),
        'ems.roles': jsonEncode(['Technician']),
      });
      await LanguageService.setLanguage(AppLanguage.en);
      stubBaseAttendance();

      TechnicianService.getMyJobsOverride = () async =>
          const TechnicianDashboardData(
            workDate: '2026-11-27',
            jobs: [],
            todaySessions: [],
            completedWindows: {},
            nextWindowCode: 'morning_in',
          );

      await tester.pumpWidget(wrapScreen(const AttendanceScreen()));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('technician-scan-reminder-banner')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'TechnicianJobDetailScreen shows VESSEL & EQUIPMENT card when specs exist and hides when empty',
    (tester) async {
      await LanguageService.setLanguage(AppLanguage.en);

      await tester.pumpWidget(
        wrapScreen(
          const TechnicianJobDetailScreen(
            job: TechnicianJob(
              id: 'wo-spec-1',
              jobCode: 'WO-301',
              title: 'Main Engine Overhaul',
              vesselName: 'PUNN',
              vesselType: 'Tugboat',
              vesselRegistration: 'TH-9981',
              assetName: 'Caterpillar C32',
              assetModel: 'C32 ACERT',
              assetSerial: 'SN-44102',
            ),
            isSelected: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('job-vessel-equipment-card')),
        findsOneWidget,
      );
      expect(find.text('Tugboat'), findsOneWidget);
      expect(find.text('TH-9981'), findsOneWidget);
      expect(find.text('Caterpillar C32'), findsOneWidget);
      expect(find.text('C32 ACERT'), findsOneWidget);
      expect(find.text('SN-44102'), findsOneWidget);

      await tester.pumpWidget(
        wrapScreen(
          const TechnicianJobDetailScreen(
            key: ValueKey('detail-spec-2'),
            job: TechnicianJob(
              id: 'wo-spec-2',
              jobCode: 'WO-302',
              title: 'Deck Paint',
              vesselName: 'PUNN',
            ),
            isSelected: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('job-vessel-equipment-card')), findsNothing);
    },
  );

  test(
    'TechnicianWorkSession.reportLateMinutes counts minutes past 07:00 next day',
    () {
      final session = TechnicianWorkSession(
        id: 'sess-dl-1',
        jobId: 'wo-dl-1',
        jobCode: 'WO-401',
        jobTitle: 'Deadline Check',
        status: 'completed',
        checkInAt: DateTime(2026, 11, 26, 8, 0).toIso8601String(),
        checkOutAt: DateTime(2026, 11, 26, 17, 0).toIso8601String(),
        reportSubmitted: false,
      );

      final beforeDeadline = DateTime(2026, 11, 27, 6, 30);
      expect(session.reportLateMinutes(beforeDeadline), 0);
      expect(
        session.reportRemainingTime(beforeDeadline),
        const Duration(minutes: 30),
      );

      final afterDeadline = DateTime(2026, 11, 27, 7, 45);
      expect(session.reportLateMinutes(afterDeadline), 45);
      expect(session.reportRemainingTime(afterDeadline), isNull);
    },
  );

  testWidgets(
    'TechnicianReportScreen shows overdue late-minutes banner when past 07:00 next day',
    (tester) async {
      await LanguageService.setLanguage(AppLanguage.en);

      await tester.pumpWidget(
        wrapScreen(
          TechnicianReportScreen(
            session: TechnicianWorkSession(
              id: 'sess-overdue-1',
              jobId: 'wo-overdue-1',
              jobCode: 'WO-402',
              jobTitle: 'Overdue Report Test',
              status: 'completed',
              checkInAt: DateTime(2026, 11, 20, 8, 0).toIso8601String(),
              checkOutAt: DateTime(2026, 11, 20, 17, 0).toIso8601String(),
              reportSubmitted: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('report-late-banner')), findsOneWidget);
      expect(find.textContaining('Overdue by'), findsOneWidget);
    },
  );
}
