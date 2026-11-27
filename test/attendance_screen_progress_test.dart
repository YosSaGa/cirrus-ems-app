// claude_prompt.txt (v172 -- Attendance Progress Status-Based Segment
// Colors): focused tests for the Attendance Progress bar's new per-window
// completion coloring (`_completedWindowCodes`, attendance_screen.dart).
// `currentWindowCode: null` is used in every static test below so the
// primary action area renders the generic disabled "Check In" / schedule
// icon (attendance_screen.dart's `_buildCheckInAction`) instead of
// duplicating one of the four window segments' own label/icon -- avoiding
// any `find.text`/`find.byIcon` ambiguity between the stepper and the
// action button.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cirrus_app/screens/attendance_screen.dart';
import 'package:cirrus_app/services/attendance_service.dart';
import 'package:cirrus_app/theme/app_theme.dart';

const _tokenKey = 'ems.authToken';
const _userKey = 'ems.user';
const _userId = '11111111-1111-1111-1111-111111111111';
const _token = 'test-jwt-token';
const _workDate = '2026-11-06';

Future<void> _seedPrefs({Map<String, String>? extra}) async {
  SharedPreferences.setMockInitialValues({
    _tokenKey: _token,
    _userKey: jsonEncode({'id': _userId, 'name': 'Test User'}),
    ...?extra,
  });
}

void _mockHttp(Future<http.Response> Function(http.Request) handler) {
  AttendanceService.debugOverrideClient(MockClient(handler));
}

http.Response _json(Map<String, dynamic> body, int status) =>
    http.Response(jsonEncode(body), status);

http.Response _jsonArray(List<Map<String, dynamic>> body, int status) =>
    http.Response(jsonEncode(body), status);

Map<String, dynamic> _scan(String windowCode) => {
  'id': 'scan-$windowCode',
  'windowCode': windowCode,
  'workDate': _workDate,
  'counted': true,
  'scannedAt':
      '$_workDate'
      'T08:00:00.000Z',
};

/// Mocks `/status` (fixed) and `/my-scans` (returns [scans] every call,
/// unless [scansSequence] is given -- then each call in order returns the
/// next entry, holding the last one once exhausted; lets a test simulate
/// the My Scans result changing between the initial load and a later
/// status-refresh).
void _mockStatusAndScans({
  String? currentWindowCode,
  List<Map<String, dynamic>>? scans,
  List<List<Map<String, dynamic>>>? scansSequence,
}) {
  var myScansCallCount = 0;
  _mockHttp((req) async {
    if (req.url.path.endsWith('/status')) {
      return _json({
        'currentWorkDate': _workDate,
        'currentWindowCode': currentWindowCode,
      }, 200);
    }
    if (req.url.path.contains('my-scans')) {
      if (scansSequence != null) {
        final index = myScansCallCount < scansSequence.length
            ? myScansCallCount
            : scansSequence.length - 1;
        myScansCallCount++;
        return _jsonArray(scansSequence[index], 200);
      }
      return _jsonArray(scans ?? const [], 200);
    }
    return _json({}, 404);
  });
}

Color? _segmentLabelColor(WidgetTester tester, String label) {
  final widget = tester.widget<Text>(find.text(label));
  return widget.style?.color;
}

void main() {
  dotenv.loadFromString(envString: '', isOptional: true);

  setUp(() async {
    await _seedPrefs();
  });

  tearDown(() {
    AttendanceService.debugResetClient();
  });

  testWidgets('1. No completed events: all four segments grey', (tester) async {
    _mockStatusAndScans(scans: const []);

    await tester.pumpWidget(const MaterialApp(home: AttendanceScreen()));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    for (final label in ['Morning In', 'Lunch Out', 'Afternoon In', 'Leave']) {
      expect(
        _segmentLabelColor(tester, label),
        AppColors.textSecondary,
        reason: '$label must be grey when no event was recorded for it',
      );
    }
  });

  testWidgets('2. Morning In only: only Morning In is green', (tester) async {
    _mockStatusAndScans(scans: [_scan('morning_in')]);

    await tester.pumpWidget(const MaterialApp(home: AttendanceScreen()));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(_segmentLabelColor(tester, 'Morning In'), AppColors.success);
    expect(_segmentLabelColor(tester, 'Lunch Out'), AppColors.textSecondary);
    expect(_segmentLabelColor(tester, 'Afternoon In'), AppColors.textSecondary);
    expect(_segmentLabelColor(tester, 'Leave'), AppColors.textSecondary);
  });

  testWidgets(
    '3. Morning In and Afternoon In recorded: only those two are green, Lunch Out and Leave stay grey',
    (tester) async {
      _mockStatusAndScans(scans: [_scan('morning_in'), _scan('afternoon_in')]);

      await tester.pumpWidget(const MaterialApp(home: AttendanceScreen()));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(_segmentLabelColor(tester, 'Morning In'), AppColors.success);
      expect(_segmentLabelColor(tester, 'Afternoon In'), AppColors.success);
      expect(_segmentLabelColor(tester, 'Lunch Out'), AppColors.textSecondary);
      expect(_segmentLabelColor(tester, 'Leave'), AppColors.textSecondary);
    },
  );

  testWidgets('4. All four events completed: all four segments green', (
    tester,
  ) async {
    _mockStatusAndScans(
      scans: [
        _scan('morning_in'),
        _scan('lunch_out'),
        _scan('afternoon_in'),
        _scan('leave'),
      ],
    );

    await tester.pumpWidget(const MaterialApp(home: AttendanceScreen()));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    for (final label in ['Morning In', 'Lunch Out', 'Afternoon In', 'Leave']) {
      expect(
        _segmentLabelColor(tester, label),
        AppColors.success,
        reason: '$label must be green once every window has a recorded event',
      );
    }
  });

  testWidgets(
    '5. Status refresh after a successful submission updates the corresponding segment',
    (tester) async {
      // Simulates "upload already succeeded, Event not yet submitted" --
      // the same shape v171's own resume-after-restart test uses --
      // so tapping Retry goes straight to Event submission with no
      // camera/upload involved (out of scope for this round).
      await _seedPrefs(
        extra: {
          'ems.pendingAttendanceRequest.$_userId': jsonEncode({
            'userId': _userId,
            'clientRequestId': 'client-request-1',
            'uploadRequestId': 'upload-request-1',
            'windowCode': 'morning_in',
            'photoFilePath': null,
            'payload': {
              'selfieStorageKey': 'attendance/$_userId/$_workDate/x.jpg',
            },
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'status': 'pending',
          }),
        },
      );

      // First My Scans call (initial load) returns nothing recorded yet;
      // the second (triggered by `_refreshAfter` after the Event
      // succeeds) reflects the newly-recorded Morning In scan. One
      // combined handler answers /status, /my-scans (sequenced), and the
      // Event submission POST.
      var myScansCallCount = 0;
      final scansSequence = [
        const <Map<String, dynamic>>[],
        [_scan('morning_in')],
      ];
      _mockHttp((req) async {
        if (req.url.path.endsWith('/status')) {
          return _json({
            'currentWorkDate': _workDate,
            'currentWindowCode': null,
          }, 200);
        }
        if (req.url.path.contains('my-scans')) {
          final index = myScansCallCount < scansSequence.length
              ? myScansCallCount
              : scansSequence.length - 1;
          myScansCallCount++;
          return _jsonArray(scansSequence[index], 200);
        }
        if (req.url.path.endsWith('/events')) {
          return _json({
            'id': 'evt-1',
            'windowCode': 'morning_in',
            'workDate': _workDate,
            'counted': true,
            'scannedAt': '${_workDate}T12:00:00.000Z',
          }, 201);
        }
        return _json({}, 404);
      });

      await tester.pumpWidget(const MaterialApp(home: AttendanceScreen()));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(
        _segmentLabelColor(tester, 'Morning In'),
        AppColors.textSecondary,
        reason: 'not yet recorded before the retry succeeds',
      );

      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      // claude_prompt.txt (v171's own finding, reused here): any real,
      // non-Timer async work in this chain (e.g. LocationService's
      // platform-channel call) cannot progress on bare `pump()` alone --
      // `AutomatedTestWidgetsFlutterBinding`'s fake-time zone never lets
      // the real event loop spin to deliver it. Alternate short
      // `runAsync()` (let it land) with `pump()` (drain the
      // continuation) until the submission completes.
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump();
      tester.takeException();

      expect(
        _segmentLabelColor(tester, 'Morning In'),
        AppColors.success,
        reason:
            'the status-refresh mechanism after a successful submission '
            'must update Morning In to green',
      );
      expect(_segmentLabelColor(tester, 'Lunch Out'), AppColors.textSecondary);
      expect(
        _segmentLabelColor(tester, 'Afternoon In'),
        AppColors.textSecondary,
      );
      expect(_segmentLabelColor(tester, 'Leave'), AppColors.textSecondary);
    },
  );
}
