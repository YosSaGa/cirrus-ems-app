// claude_prompt.txt (v171 -- Flutter Attendance Photo Persistence & Retry
// Implementation §7 "Focused Tests"): the full Camera -> Upload -> Event
// flow orchestrated by `AttendanceScreen._checkIn()` -- no test exercised
// this screen-level flow at all before this round (confirmed absent as
// far back as v163's own audit, PROGRESS_LOG.md). Combines three
// already-established test seams from this codebase: `AttendanceService.
// debugOverrideClient` (MockClient, v160/v161's pattern), `CameraPlatform.
// instance` (`FakeCameraPlatform`, v161's own fake, reused unchanged from
// test/support/), and `LocalPhotoStore.debugDirectoryOverride` (this
// round's new seam, same shape as the other two).
import 'dart:convert';
import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cirrus_app/screens/attendance_screen.dart';
import 'package:cirrus_app/services/attendance_service.dart';
import 'package:cirrus_app/services/local_photo_store.dart';
import 'package:cirrus_app/widgets/time_action_button.dart';

import 'support/fake_camera_platform.dart';

const _tokenKey = 'ems.authToken';
const _userKey = 'ems.user';
const _userId = '11111111-1111-1111-1111-111111111111';
const _token = 'test-jwt-token';

const _front = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 0,
);

// A minimal valid 1x1 PNG -- AttendanceCameraScreen's preview phase decodes
// the captured bytes via Image.memory, which needs genuinely valid image
// data (confirmed in v161's own camera-switching tests).
const _validPngBytes = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

Directory? _scratchDir;

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

final _statusJson = {
  'currentWorkDate': '2026-11-06',
  'currentWindowCode': 'morning_in',
};

FakeCameraPlatform _installCamera() {
  final fake = FakeCameraPlatform(cameras: [_front]);
  fake.nextCaptureBytes = _validPngBytes;
  CameraPlatform.instance = fake;
  return fake;
}

Future<void> _captureAndConfirmPhoto(WidgetTester tester) async {
  // AttendanceCameraScreen opens (initializing -> ready).
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
  await tester.pump();

  await tester.tap(find.bySemanticsLabel('Capture photo'));
  await tester.pump();
  await tester.pump();

  await tester.tap(find.text('Use Photo'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
  await tester.pump();
}

// claude_prompt.txt (v171 §3): `LocalPhotoStore`'s real file I/O (even
// against the scratch temp directory these tests substitute) only ever
// advances one step per `pump()` -- `AutomatedTestWidgetsFlutterBinding`'s
// fake-time zone queues each I/O completion's continuation as a microtask
// that `pump()` must drain, but `pump()` alone never lets the real OS
// thread pool deliver that completion in the first place. `runAsync()` is
// the documented Flutter-test API for letting real I/O land; alternating
// a short `runAsync` with a `pump()`, once per step in the underlying
// chain (exists -> create -> writeAsBytes, then whatever mocked HTTP
// calls follow), lets the whole flow actually complete. `done()` reports
// when the chain has gone far enough that this test's own assertions no
// longer need any more waiting; also consumes any benign image-codec
// exception from the already-popped camera preview's in-flight decode
// finally landing once real time is given a chance to run (see v171's
// PROGRESS_LOG.md entry for the full diagnosis).
Future<void> _settleRealIo(
  WidgetTester tester, {
  required bool Function() done,
}) async {
  var settleRunsAfterDone = 0;
  for (var i = 0; i < 25 && settleRunsAfterDone < 3; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    if (done()) settleRunsAfterDone++;
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();
  await tester.pump();
  tester.takeException();
}

void main() {
  dotenv.loadFromString(envString: '', isOptional: true);

  setUp(() async {
    await _seedPrefs();
    AttendanceService.uploadTimeout = const Duration(seconds: 2);
    _scratchDir = Directory.systemTemp.createTempSync(
      'attendance_checkin_test_',
    );
    LocalPhotoStore.debugDirectoryOverride = () async => _scratchDir!;
  });

  tearDown(() {
    AttendanceService.debugResetClient();
    AttendanceService.uploadTimeout = const Duration(seconds: 30);
    LocalPhotoStore.debugDirectoryOverride = null;
    _scratchDir?.deleteSync(recursive: true);
  });

  testWidgets(
    '1. Normal flow: camera -> upload -> event submission -> success',
    (tester) async {
      _installCamera();
      final uploadRequests = <Map<String, String>>[];
      var eventPostCount = 0;

      _mockHttp((req) async {
        if (req.url.path.endsWith('/status')) {
          return _json(_statusJson, 200);
        }
        if (req.url.path.contains('storage/uploads')) {
          // A MockClient-reconstructed Request exposes the multipart body
          // as plain bytes -- decode just enough to confirm the fields.
          final body = latin1.decode(req.bodyBytes);
          uploadRequests.add({
            'hasCategory': body.contains('name="category"').toString(),
            'hasUploadRequestId': body
                .contains('name="uploadRequestId"')
                .toString(),
          });
          return _json({
            'storageKey': 'attendance/$_userId/2026-11-06/x.jpg',
          }, 201);
        }
        if (req.url.path.endsWith('/events')) {
          eventPostCount++;
          final sent = jsonDecode(req.body) as Map<String, dynamic>;
          expect(
            sent['selfieStorageKey'],
            'attendance/$_userId/2026-11-06/x.jpg',
          );
          return _json({'id': 'evt-1', 'counted': true}, 201);
        }
        return _json({}, 404);
      });

      await tester.pumpWidget(const MaterialApp(home: AttendanceScreen()));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(
        find.widgetWithText(TimeActionButton, 'Morning In'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TimeActionButton, 'Morning In'));
      await tester.pump();
      await tester.pump();

      await _captureAndConfirmPhoto(tester);
      await _settleRealIo(tester, done: () => eventPostCount > 0);

      expect(uploadRequests.length, 1, reason: 'exactly one photo upload');
      expect(uploadRequests.single['hasCategory'], 'true');
      expect(uploadRequests.single['hasUploadRequestId'], 'true');
      expect(eventPostCount, 1, reason: 'exactly one event submission');

      final lookup = await AttendanceService.getPendingRequestForCurrentUser();
      expect(
        lookup.state,
        PendingAttendanceRequestState.absent,
        reason: 'pending record must be cleared after confirmed success',
      );
    },
  );

  testWidgets(
    '2. Camera cancellation: no upload, no event, provisional record cleared',
    (tester) async {
      _installCamera();
      var uploadCalled = false;
      var eventCalled = false;

      _mockHttp((req) async {
        if (req.url.path.endsWith('/status')) return _json(_statusJson, 200);
        if (req.url.path.contains('storage/uploads')) {
          uploadCalled = true;
          return _json({'storageKey': 'x'}, 201);
        }
        if (req.url.path.endsWith('/events')) {
          eventCalled = true;
          return _json({'id': 'evt-1'}, 201);
        }
        return _json({}, 404);
      });

      await tester.pumpWidget(const MaterialApp(home: AttendanceScreen()));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      await tester.tap(find.widgetWithText(TimeActionButton, 'Morning In'));
      await tester.pump();
      await tester.pump();

      // AttendanceCameraScreen is open -- tap its close/cancel button.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump();

      expect(uploadCalled, false);
      expect(eventCalled, false);

      final lookup = await AttendanceService.getPendingRequestForCurrentUser();
      expect(
        lookup.state,
        PendingAttendanceRequestState.absent,
        reason:
            'a cancel-before-capture must leave no provisional record behind',
      );
    },
  );

  testWidgets(
    '3. Upload failure retains photo+identity; retry reuses the SAME uploadRequestId without reopening the camera',
    (tester) async {
      _installCamera();
      final uploadRequestIds = <String>[];
      var uploadAttempt = 0;
      var eventCount = 0;

      _mockHttp((req) async {
        if (req.url.path.endsWith('/status')) return _json(_statusJson, 200);
        if (req.url.path.contains('storage/uploads')) {
          uploadAttempt++;
          final body = latin1.decode(req.bodyBytes);
          final match = RegExp(r'name="uploadRequestId"\r\n\r\n([^\r\n]+)')
              .firstMatch(body);
          if (match != null) uploadRequestIds.add(match.group(1)!);
          if (uploadAttempt == 1) {
            return _json({'message': 'boom'}, 500);
          }
          return _json({
            'storageKey': 'attendance/$_userId/2026-11-06/x.jpg',
          }, 201);
        }
        if (req.url.path.endsWith('/events')) {
          eventCount++;
          return _json({'id': 'evt-1'}, 201);
        }
        return _json({}, 404);
      });

      await tester.pumpWidget(const MaterialApp(home: AttendanceScreen()));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      await tester.tap(find.widgetWithText(TimeActionButton, 'Morning In'));
      await tester.pump();
      await tester.pump();

      await _captureAndConfirmPhoto(tester);
      await _settleRealIo(tester, done: () => uploadAttempt > 0);

      expect(uploadAttempt, 1);
      expect(
        find.widgetWithText(TimeActionButton, 'Morning In'),
        findsOneWidget,
        reason: 'the Check-In button (now functioning as retry) must still be shown, not the Retry banner, since no event-level pending record exists yet',
      );

      // Retry -- must NOT reopen the camera (no FakeCameraPlatform
      // interaction needed/possible here; if the code tried to navigate to
      // AttendanceCameraScreen again, the capture-and-confirm sequence
      // below would simply find nothing to tap and the test would fail).
      await tester.tap(find.widgetWithText(TimeActionButton, 'Morning In'));
      await _settleRealIo(tester, done: () => eventCount > 0);

      expect(uploadAttempt, 2, reason: 'the retry must re-attempt the upload');
      expect(uploadRequestIds.length, 2);
      expect(
        uploadRequestIds[0],
        uploadRequestIds[1],
        reason: 'the SAME uploadRequestId must be reused, never regenerated',
      );

      final lookup = await AttendanceService.getPendingRequestForCurrentUser();
      expect(
        lookup.state,
        PendingAttendanceRequestState.absent,
        reason: 'the retry succeeded end-to-end',
      );
    },
  );

  testWidgets(
    '4. Event submission failure after a successful upload: retry submits the event WITHOUT uploading again',
    (tester) async {
      _installCamera();
      var uploadCount = 0;
      var eventCount = 0;
      String? firstClientRequestId;

      _mockHttp((req) async {
        if (req.url.path.endsWith('/status')) return _json(_statusJson, 200);
        if (req.url.path.contains('storage/uploads')) {
          uploadCount++;
          return _json({
            'storageKey': 'attendance/$_userId/2026-11-06/x.jpg',
          }, 201);
        }
        if (req.url.path.endsWith('/events')) {
          eventCount++;
          if (eventCount == 1) {
            return _json({'message': 'boom'}, 500);
          }
          final sent = jsonDecode(req.body) as Map<String, dynamic>;
          firstClientRequestId ??= sent['clientRequestId'] as String;
          expect(sent['clientRequestId'], firstClientRequestId);
          expect(
            sent['selfieStorageKey'],
            'attendance/$_userId/2026-11-06/x.jpg',
          );
          return _json({'id': 'evt-1'}, 201);
        }
        return _json({}, 404);
      });

      await tester.pumpWidget(const MaterialApp(home: AttendanceScreen()));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      await tester.tap(find.widgetWithText(TimeActionButton, 'Morning In'));
      await tester.pump();
      await tester.pump();

      await _captureAndConfirmPhoto(tester);
      await _settleRealIo(tester, done: () => eventCount > 0);

      expect(uploadCount, 1);
      expect(eventCount, 1);

      // Retry: the pending lookup is now PendingAttendanceRequestState.valid
      // (event failed, record retained with its storageKey) -- the UI
      // shows "Retry", not "Morning In". storageKey is already persisted,
      // so this retry skips LocalPhotoStore.save()/read() -- but on
      // success, `_clearPendingRequest` deletes the locally-saved photo
      // file (real I/O again), so this still needs the same settling.
      await tester.pump();
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await _settleRealIo(tester, done: () => eventCount > 1);

      expect(
        uploadCount,
        1,
        reason: 'the photo must never be uploaded a second time',
      );
      expect(eventCount, 2, reason: 'the event submission is retried');

      final lookup = await AttendanceService.getPendingRequestForCurrentUser();
      expect(lookup.state, PendingAttendanceRequestState.absent);
    },
  );

  testWidgets(
    '5. HTTP 409 ATTENDANCE_PHOTO_UPLOAD_LEASE_HELD during upload: pending state retained, clear retry message shown, no second upload identity',
    (tester) async {
      _installCamera();
      final uploadRequestIds = <String>[];

      _mockHttp((req) async {
        if (req.url.path.endsWith('/status')) return _json(_statusJson, 200);
        if (req.url.path.contains('storage/uploads')) {
          final body = latin1.decode(req.bodyBytes);
          final match = RegExp(r'name="uploadRequestId"\r\n\r\n([^\r\n]+)')
              .firstMatch(body);
          if (match != null) uploadRequestIds.add(match.group(1)!);
          return _json({
            'message':
                'Another upload attempt for this photo is already in progress.',
            'errorCode': 'ATTENDANCE_PHOTO_UPLOAD_LEASE_HELD',
          }, 409);
        }
        return _json({}, 404);
      });

      await tester.pumpWidget(const MaterialApp(home: AttendanceScreen()));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      await tester.tap(find.widgetWithText(TimeActionButton, 'Morning In'));
      await tester.pump();
      await tester.pump();

      await _captureAndConfirmPhoto(tester);
      await _settleRealIo(tester, done: () => uploadRequestIds.isNotEmpty);

      expect(
        find.textContaining('still being processed'),
        findsOneWidget,
        reason: 'a clear, specific retry message must be shown for the lease-held case',
      );
      expect(uploadRequestIds.length, 1);

      // A second tap must reuse the SAME uploadRequestId, not generate a new
      // one -- this retry re-reads the already-saved photo from disk via
      // LocalPhotoStore.read() (real I/O), so it needs the same settling.
      await tester.tap(find.widgetWithText(TimeActionButton, 'Morning In'));
      await _settleRealIo(tester, done: () => uploadRequestIds.length > 1);

      expect(uploadRequestIds.length, 2);
      expect(uploadRequestIds[0], uploadRequestIds[1]);
    },
  );

  testWidgets(
    '6. Resume after simulated app restart: a persisted storageKey skips camera AND upload, submits the event directly',
    (tester) async {
      // Simulates "app restarted after upload succeeded but before event
      // submission" by seeding the pending record directly into
      // SharedPreferences, exactly as it would exist on disk -- no camera
      // or upload interaction should occur at all.
      await _seedPrefs(
        extra: {
          'ems.pendingAttendanceRequest.$_userId': jsonEncode({
            'userId': _userId,
            'clientRequestId': 'resumed-client-request-id',
            'uploadRequestId': 'resumed-upload-request-id',
            'windowCode': 'morning_in',
            'photoFilePath': null,
            'payload': {
              'selfieStorageKey': 'attendance/$_userId/2026-11-06/resumed.jpg',
            },
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'status': 'pending',
          }),
        },
      );

      var uploadCalled = false;
      var eventCount = 0;

      _mockHttp((req) async {
        if (req.url.path.endsWith('/status')) return _json(_statusJson, 200);
        if (req.url.path.contains('storage/uploads')) {
          uploadCalled = true;
          return _json({'storageKey': 'x'}, 201);
        }
        if (req.url.path.endsWith('/events')) {
          eventCount++;
          final sent = jsonDecode(req.body) as Map<String, dynamic>;
          expect(sent['clientRequestId'], 'resumed-client-request-id');
          expect(
            sent['selfieStorageKey'],
            'attendance/$_userId/2026-11-06/resumed.jpg',
          );
          return _json({'id': 'evt-1'}, 201);
        }
        return _json({}, 404);
      });

      await tester.pumpWidget(const MaterialApp(home: AttendanceScreen()));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // The UI shows "Retry" (a valid pending record exists), not "Morning In".
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await _settleRealIo(tester, done: () => eventCount > 0);

      expect(
        uploadCalled,
        false,
        reason:
            'a persisted storageKey must skip the camera and upload entirely',
      );
      expect(eventCount, 1);

      final lookup = await AttendanceService.getPendingRequestForCurrentUser();
      expect(lookup.state, PendingAttendanceRequestState.absent);
    },
  );
}
