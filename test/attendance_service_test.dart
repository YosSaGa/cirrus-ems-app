// claude_prompt.txt (v161 -- Complete Attendance Photo Upload & Camera
// Switching Integration, §9 "Upload" and "Attendance Integration"):
// `AttendanceService` had NO unit tests at all before this round (every
// HTTP call site built its own throwaway `createApiClient()`, with no
// seam for a test to substitute a fake). The shared, overridable
// `AttendanceService._client` seam added this round (mirroring
// `AuthService.debugOverrideClient` from v160 exactly) is what makes
// this file possible.
//
// `MockClient`'s regular (non-streaming) constructor finalizes whatever
// `BaseRequest` it is given -- including a `MultipartRequest` -- into
// plain bytes before handing a reconstructed `Request` to the handler,
// with the ORIGINAL request's headers preserved (confirmed by reading
// `package:http`'s own `mock_client.dart`). That is what lets the Upload
// scenarios below inspect the Authorization header and decode the
// multipart body to assert on field names/values and the
// `Content-Type: multipart/form-data; boundary=...` header, without a
// real HTTP stack.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cirrus_app/models/captured_photo.dart';
import 'package:cirrus_app/services/attendance_service.dart';

const _tokenKey = 'ems.authToken';
const _userKey = 'ems.user';
const _userId = '11111111-1111-1111-1111-111111111111';
const _token = 'test-jwt-token';

Future<void> _seedPrefs({Map<String, String>? extra}) async {
  SharedPreferences.setMockInitialValues({
    _tokenKey: _token,
    _userKey: jsonEncode({'id': _userId, 'name': 'Test User'}),
    ...?extra,
  });
}

void _mock(Future<http.Response> Function(http.Request) handler) {
  AttendanceService.debugOverrideClient(MockClient(handler));
}

http.Response _json(Map<String, dynamic> body, int status) =>
    http.Response(jsonEncode(body), status);

final _photo = CapturedPhoto(
  bytes: Uint8List.fromList([1, 2, 3, 4]),
  fileName: 'attendance_123.jpg',
  mimeType: 'image/jpeg',
);

// claude_prompt.txt (v171 -- Flutter Attendance Photo Persistence & Retry
// Implementation §4): `uploadAttendancePhoto` now requires an
// `uploadRequestId` argument (the Backend's v170 idempotency path only
// activates when this field is present) -- a single fixed value reused
// across every existing scenario below is sufficient; which exact value
// is sent is covered explicitly by scenario 11.
const _uploadRequestId = '22222222-2222-2222-2222-222222222222';

// Decodes a multipart/form-data body just enough to answer "does this
// part exist with this value" -- this is test-only scaffolding, not a
// general-purpose multipart parser.
String _multipartBodyAsText(http.Request request) =>
    latin1.decode(request.bodyBytes);

bool _hasField(String body, String name, String value) =>
    body.contains('name="$name"') && body.contains('\r\n\r\n$value\r\n');

bool _hasFilePart(String body, String fieldName, String filename) =>
    body.contains('name="$fieldName"; filename="$filename"');

void main() {
  // claude_prompt.txt (v161): `AuthService.baseUrl` (which
  // `AttendanceService` builds every URL from) reads `dotenv.env[...]`,
  // which is normally initialized once in `main()` via a real asset
  // read that never runs in a unit test -- same issue, same fix, as
  // `auth_service_test.dart` (v160).
  dotenv.loadFromString(envString: '', isOptional: true);

  setUp(() async {
    await _seedPrefs();
    AttendanceService.uploadTimeout = const Duration(milliseconds: 200);
  });

  tearDown(() {
    AttendanceService.debugResetClient();
    AttendanceService.uploadTimeout = const Duration(seconds: 30);
  });

  group('uploadAttendancePhoto (task §9 "Upload" scenarios 1-10)', () {
    test('1-2. Correct multipart field names and category', () async {
      http.Request? captured;
      _mock((req) async {
        captured = req;
        return _json({
          'storageKey': 'attendance/$_userId/2026-01-01/x.jpg',
        }, 201);
      });

      await AttendanceService.uploadAttendancePhoto(_photo, _uploadRequestId);

      final body = _multipartBodyAsText(captured!);
      expect(_hasFilePart(body, 'file', _photo.fileName), true);
      expect(_hasField(body, 'category', 'attendance'), true);
    });

    test('3. Correct authenticated user ID (core.users.id, not another identifier)', () async {
      http.Request? captured;
      _mock((req) async {
        captured = req;
        return _json({
          'storageKey': 'attendance/$_userId/2026-01-01/x.jpg',
        }, 201);
      });

      await AttendanceService.uploadAttendancePhoto(_photo, _uploadRequestId);

      final body = _multipartBodyAsText(captured!);
      expect(_hasField(body, 'employeeId', _userId), true);
    });

    test('4. Bearer token included', () async {
      http.Request? captured;
      _mock((req) async {
        captured = req;
        return _json({
          'storageKey': 'attendance/$_userId/2026-01-01/x.jpg',
        }, 201);
      });

      await AttendanceService.uploadAttendancePhoto(_photo, _uploadRequestId);

      expect(captured!.headers['authorization'], 'Bearer $_token');
    });

    test('5. Multipart boundary generated by the HTTP client itself, never overridden', () async {
      http.Request? captured;
      _mock((req) async {
        captured = req;
        return _json({
          'storageKey': 'attendance/$_userId/2026-01-01/x.jpg',
        }, 201);
      });

      await AttendanceService.uploadAttendancePhoto(_photo, _uploadRequestId);

      final contentType = captured!.headers['content-type'] ?? '';
      expect(contentType, startsWith('multipart/form-data; boundary='));
    });

    test('6. Successful response returns and validates storageKey', () async {
      const key = 'attendance/$_userId/2026-01-01/abc.jpg';
      _mock((req) async => _json({'storageKey': key}, 201));

      final result = await AttendanceService.uploadAttendancePhoto(
        _photo,
        _uploadRequestId,
      );

      expect(result, key);
    });

    test(
      '7. HTTP error responses are handled (AttendanceApiException)',
      () async {
        _mock(
          (req) async => _json({
            'message': 'File too large',
            'errorCode': 'STORAGE_FILE_TOO_LARGE',
          }, 413),
        );

        await expectLater(
          AttendanceService.uploadAttendancePhoto(_photo, _uploadRequestId),
          throwsA(isA<AttendanceApiException>()),
        );
      },
    );

    test(
      '8. Network failures are handled (AttendancePhotoUploadException)',
      () async {
        _mock((req) async => throw const SocketExceptionStub());

        await expectLater(
          AttendanceService.uploadAttendancePhoto(_photo, _uploadRequestId),
          throwsA(isA<AttendancePhotoUploadException>()),
        );
      },
    );

    test('9. Timeout is handled (AttendancePhotoUploadException)', () async {
      _mock((req) async {
        await Future<void>.delayed(const Duration(seconds: 5));
        return _json({'storageKey': 'x'}, 201);
      });

      await expectLater(
        AttendanceService.uploadAttendancePhoto(_photo, _uploadRequestId),
        throwsA(isA<AttendancePhotoUploadException>()),
      );
    });

    test(
      '10a. Empty storageKey in an otherwise-successful response is rejected',
      () async {
        _mock((req) async => _json({'storageKey': ''}, 201));

        await expectLater(
          AttendanceService.uploadAttendancePhoto(_photo, _uploadRequestId),
          throwsA(isA<AttendancePhotoUploadException>()),
        );
      },
    );

    test(
      '10b. Missing storageKey in an otherwise-successful response is rejected',
      () async {
        _mock((req) async => _json({}, 201));

        await expectLater(
          AttendanceService.uploadAttendancePhoto(_photo, _uploadRequestId),
          throwsA(isA<AttendancePhotoUploadException>()),
        );
      },
    );

    test('11. uploadRequestId is sent as its own multipart field', () async {
      http.Request? captured;
      _mock((req) async {
        captured = req;
        return _json({
          'storageKey': 'attendance/$_userId/2026-01-01/x.jpg',
        }, 201);
      });

      await AttendanceService.uploadAttendancePhoto(_photo, _uploadRequestId);

      final body = _multipartBodyAsText(captured!);
      expect(_hasField(body, 'uploadRequestId', _uploadRequestId), true);
    });

    test('12. HTTP 409 ATTENDANCE_PHOTO_UPLOAD_LEASE_HELD surfaces as an '
        'AttendanceApiException carrying that exact errorCode', () async {
      _mock(
        (req) async => _json({
          'message':
              'Another upload attempt for this photo is already in progress.',
          'errorCode': 'ATTENDANCE_PHOTO_UPLOAD_LEASE_HELD',
        }, 409),
      );

      await expectLater(
        AttendanceService.uploadAttendancePhoto(_photo, _uploadRequestId),
        throwsA(
          isA<AttendanceApiException>().having(
            (e) => e.errorCode,
            'errorCode',
            'ATTENDANCE_PHOTO_UPLOAD_LEASE_HELD',
          ),
        ),
      );
    });
  });

  group('submitAttendanceEvent / retryPendingAttendanceEvent idempotency '
      '(task §9 "Attendance Integration")', () {
    test(
      '1-2. A fresh event persists and submits the given selfieStorageKey',
      () async {
        http.Request? captured;
        _mock((req) async {
          captured = req;
          return _json({'id': 'evt-1', 'counted': true}, 201);
        });

        final result = await AttendanceService.submitAttendanceEvent(
          latitude: 13.7,
          longitude: 100.5,
          selfieStorageKey: 'attendance/$_userId/2026-01-01/a.jpg',
        );

        expect(result.outcome, AttendanceSubmissionOutcome.created);
        final sentBody = jsonDecode(captured!.body) as Map<String, dynamic>;
        expect(
          sentBody['selfieStorageKey'],
          'attendance/$_userId/2026-01-01/a.jpg',
        );
      },
    );

    test(
      '3-4. Success finalizes the pending request (cleared from storage)',
      () async {
        _mock((req) async => _json({'id': 'evt-1'}, 201));

        await AttendanceService.submitAttendanceEvent(
          selfieStorageKey: 'attendance/$_userId/2026-01-01/a.jpg',
        );

        final lookup =
            await AttendanceService.getPendingRequestForCurrentUser();
        expect(lookup.state, PendingAttendanceRequestState.absent);
      },
    );

    test('5. Event submission failure retains the pending request and its storageKey '
        '(upload is not re-attempted, since nothing here calls the upload endpoint)', () async {
      _mock((req) async {
        if (req.url.path.contains('storage')) {
          fail('submitAttendanceEvent must never call the upload endpoint');
        }
        return _json({'message': 'boom'}, 500);
      });

      await expectLater(
        AttendanceService.submitAttendanceEvent(
          selfieStorageKey: 'attendance/$_userId/2026-01-01/a.jpg',
        ),
        throwsA(isA<AttendanceApiException>()),
      );

      final lookup = await AttendanceService.getPendingRequestForCurrentUser();
      expect(lookup.state, PendingAttendanceRequestState.valid);
      expect(
        lookup.record!['payload']['selfieStorageKey'],
        'attendance/$_userId/2026-01-01/a.jpg',
      );
    });

    test(
      '6-7. Retry after a lost/failed response reuses the SAME clientRequestId '
      'and storageKey, and never calls the upload endpoint',
      () async {
        var eventPostCount = 0;
        String? firstClientRequestId;

        _mock((req) async {
          if (req.url.path.contains('storage')) {
            fail(
              'retryPendingAttendanceEvent must never call the upload endpoint',
            );
          }
          eventPostCount++;
          if (eventPostCount == 1) {
            return _json({'message': 'network blip'}, 500);
          }
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          firstClientRequestId = body['clientRequestId'] as String;
          return _json({'id': 'evt-1'}, 201);
        });

        await expectLater(
          AttendanceService.submitAttendanceEvent(
            selfieStorageKey: 'attendance/$_userId/2026-01-01/a.jpg',
          ),
          throwsA(isA<AttendanceApiException>()),
        );

        final pendingBefore =
            await AttendanceService.getPendingRequestForCurrentUser();
        final originalClientRequestId =
            pendingBefore.record!['clientRequestId'] as String;

        final retryResult =
            await AttendanceService.retryPendingAttendanceEvent();

        expect(retryResult.outcome, AttendanceSubmissionOutcome.created);
        expect(firstClientRequestId, originalClientRequestId);
        expect(eventPostCount, 2);
      },
    );

    test(
      '8. Duplicate (concurrent) submissions for the same user return "busy", '
      'never a second event',
      () async {
        final completer = Completer<http.Response>();
        var postCount = 0;
        _mock((req) async {
          postCount++;
          return completer.future;
        });

        final first = AttendanceService.submitAttendanceEvent(
          selfieStorageKey: 'attendance/$_userId/2026-01-01/a.jpg',
        );

        // claude_prompt.txt (v161): awaiting `second` directly here
        // (before `first` has reached the network call and parked on
        // the uncompleted `completer`) would race the two calls'
        // identical microtask-hop chains and could deadlock the test
        // itself if `second` ever reached the mock first -- the same
        // lesson the camera-switching tests already established. A
        // real, short timer lets every pending microtask (including
        // `first` registering itself in the exclusive-submission lock
        // AND reaching the mock, where it then genuinely blocks on a
        // real Completer) run to completion first, so `second` is
        // guaranteed to observe `first` as already in flight.
        await Future<void>.delayed(const Duration(milliseconds: 1));

        final secondResult = await AttendanceService.submitAttendanceEvent(
          selfieStorageKey: 'attendance/$_userId/2026-01-01/a.jpg',
        );
        expect(secondResult.outcome, AttendanceSubmissionOutcome.busy);
        expect(
          postCount,
          1,
          reason: 'the busy call must never reach the network',
        );

        completer.complete(_json({'id': 'evt-1'}, 201));
        final firstResult = await first;
        expect(firstResult.outcome, AttendanceSubmissionOutcome.created);
        expect(postCount, 1);
      },
    );

    test(
      '12. A legacy pending request with no selfieStorageKey is reported as '
      'pending (not silently replaced), and retrying it never fabricates a key',
      () async {
        await _seedPrefs(
          extra: {
            'ems.pendingAttendanceRequest.$_userId': jsonEncode({
              'userId': _userId,
              'clientRequestId': 'legacy-request-id',
              'payload': <String, dynamic>{'latitude': 13.7},
              'createdAt': DateTime.now().toUtc().toIso8601String(),
              'status': 'pending',
            }),
          },
        );

        final lookupBefore =
            await AttendanceService.getPendingRequestForCurrentUser();
        expect(lookupBefore.state, PendingAttendanceRequestState.valid);
        expect(lookupBefore.record!['payload']['selfieStorageKey'], isNull);

        final submitResult = await AttendanceService.submitAttendanceEvent(
          selfieStorageKey: 'attendance/$_userId/2026-01-01/new.jpg',
        );
        expect(
          submitResult.outcome,
          AttendanceSubmissionOutcome.pendingRequestExists,
          reason:
              'an existing pending request must block a NEW logical event, '
              'never be silently replaced by one carrying a freshly '
              'uploaded photo',
        );

        http.Request? captured;
        _mock((req) async {
          captured = req;
          return _json({'id': 'evt-1'}, 201);
        });

        await AttendanceService.retryPendingAttendanceEvent();

        final sentBody = jsonDecode(captured!.body) as Map<String, dynamic>;
        expect(
          sentBody.containsKey('selfieStorageKey'),
          false,
          reason: 'a legacy request with no photo must not have one fabricated',
        );
        expect(sentBody['clientRequestId'], 'legacy-request-id');
      },
    );
  });

  // claude_prompt.txt (v171 -- Flutter Attendance Photo Persistence &
  // Retry Implementation): the new pending-record lifecycle methods
  // AttendanceScreen's own `_checkIn()` is built on.
  group('beginOrResumeAttendanceAttempt / pending-record lifecycle (v171)', () {
    test('a fresh attempt generates and persists clientRequestId + uploadRequestId + windowCode', () async {
      final record = await AttendanceService.beginOrResumeAttendanceAttempt(
        windowCode: 'morning_in',
      );

      expect(record['clientRequestId'], isNotEmpty);
      expect(record['uploadRequestId'], isNotEmpty);
      expect(record['windowCode'], 'morning_in');
      expect(record['photoFilePath'], isNull);
      expect((record['payload'] as Map).containsKey('selfieStorageKey'), false);

      final lookup = await AttendanceService.getPendingRequestForCurrentUser();
      expect(lookup.state, PendingAttendanceRequestState.valid);
      expect(lookup.record!['clientRequestId'], record['clientRequestId']);
    });

    test('resuming an existing attempt returns the SAME record unchanged -- never a new identity', () async {
      final first = await AttendanceService.beginOrResumeAttendanceAttempt(
        windowCode: 'morning_in',
      );

      final second = await AttendanceService.beginOrResumeAttendanceAttempt(
        windowCode:
            'lunch_out', // a DIFFERENT window -- must be ignored when resuming
      );

      expect(second['clientRequestId'], first['clientRequestId']);
      expect(second['uploadRequestId'], first['uploadRequestId']);
      expect(
        second['windowCode'],
        'morning_in',
        reason: 'the resumed record keeps its ORIGINAL windowCode, never the new argument',
      );
    });

    test('recordCapturedPhotoPath persists the path without touching clientRequestId/uploadRequestId', () async {
      final original = await AttendanceService.beginOrResumeAttendanceAttempt(
        windowCode: 'morning_in',
      );

      await AttendanceService.recordCapturedPhotoPath('/tmp/fake/photo.jpg');

      final lookup = await AttendanceService.getPendingRequestForCurrentUser();
      expect(lookup.record!['photoFilePath'], '/tmp/fake/photo.jpg');
      expect(lookup.record!['clientRequestId'], original['clientRequestId']);
      expect(lookup.record!['uploadRequestId'], original['uploadRequestId']);
    });

    test('recordCapturedPhotoPath(null) clears a stale reference', () async {
      await AttendanceService.beginOrResumeAttendanceAttempt(
        windowCode: 'morning_in',
      );
      await AttendanceService.recordCapturedPhotoPath('/tmp/fake/photo.jpg');
      await AttendanceService.recordCapturedPhotoPath(null);

      final lookup = await AttendanceService.getPendingRequestForCurrentUser();
      expect(lookup.record!['photoFilePath'], isNull);
    });

    test('recordUploadedStorageKey merges the key into payload without disturbing other fields', () async {
      await AttendanceService.beginOrResumeAttendanceAttempt(
        windowCode: 'morning_in',
      );
      await AttendanceService.recordCapturedPhotoPath('/tmp/fake/photo.jpg');
      await AttendanceService.recordUploadedStorageKey(
        'attendance/$_userId/2026-01-01/x.jpg',
      );

      final lookup = await AttendanceService.getPendingRequestForCurrentUser();
      expect(
        lookup.record!['payload']['selfieStorageKey'],
        'attendance/$_userId/2026-01-01/x.jpg',
      );
      expect(lookup.record!['photoFilePath'], '/tmp/fake/photo.jpg');
    });

    test('mergeFreshLocationIntoPendingRequest merges location into payload, preserving an already-set selfieStorageKey', () async {
      await AttendanceService.beginOrResumeAttendanceAttempt(
        windowCode: 'morning_in',
      );
      await AttendanceService.recordUploadedStorageKey(
        'attendance/$_userId/2026-01-01/x.jpg',
      );

      await AttendanceService.mergeFreshLocationIntoPendingRequest(
        latitude: 13.7,
        longitude: 100.5,
        accuracy: 5.0,
      );

      final lookup = await AttendanceService.getPendingRequestForCurrentUser();
      final payload = lookup.record!['payload'] as Map;
      expect(payload['latitude'], 13.7);
      expect(payload['longitude'], 100.5);
      expect(
        payload['selfieStorageKey'],
        'attendance/$_userId/2026-01-01/x.jpg',
      );
    });

    test('clearProvisionalAttemptIfNoProgress clears a record with no photo and no storageKey', () async {
      await AttendanceService.beginOrResumeAttendanceAttempt(
        windowCode: 'morning_in',
      );
      await AttendanceService.clearProvisionalAttemptIfNoProgress();

      final lookup = await AttendanceService.getPendingRequestForCurrentUser();
      expect(lookup.state, PendingAttendanceRequestState.absent);
    });

    test('clearProvisionalAttemptIfNoProgress does NOT clear a record that already has a photo path', () async {
      await AttendanceService.beginOrResumeAttendanceAttempt(
        windowCode: 'morning_in',
      );
      await AttendanceService.recordCapturedPhotoPath('/tmp/fake/photo.jpg');
      await AttendanceService.clearProvisionalAttemptIfNoProgress();

      final lookup = await AttendanceService.getPendingRequestForCurrentUser();
      expect(lookup.state, PendingAttendanceRequestState.valid);
    });

    test('clearProvisionalAttemptIfNoProgress does NOT clear a record that already has a storageKey', () async {
      await AttendanceService.beginOrResumeAttendanceAttempt(
        windowCode: 'morning_in',
      );
      await AttendanceService.recordUploadedStorageKey(
        'attendance/$_userId/2026-01-01/x.jpg',
      );
      await AttendanceService.clearProvisionalAttemptIfNoProgress();

      final lookup = await AttendanceService.getPendingRequestForCurrentUser();
      expect(lookup.state, PendingAttendanceRequestState.valid);
    });

    test('a successful event submission clears the pending record (confirms existing _sendPendingRequest/_clearPendingRequest behavior is unchanged)', () async {
      await AttendanceService.beginOrResumeAttendanceAttempt(
        windowCode: 'morning_in',
      );
      await AttendanceService.recordUploadedStorageKey(
        'attendance/$_userId/2026-01-01/x.jpg',
      );
      await AttendanceService.mergeFreshLocationIntoPendingRequest(
        latitude: 13.7,
      );

      _mock((req) async => _json({'id': 'evt-1'}, 201));
      final result = await AttendanceService.retryPendingAttendanceEvent();

      expect(result.outcome, AttendanceSubmissionOutcome.created);
      final lookup = await AttendanceService.getPendingRequestForCurrentUser();
      expect(lookup.state, PendingAttendanceRequestState.absent);
    });
  });
}

// A minimal stand-in for a real network-layer exception (e.g.
// SocketException) -- only used to prove `uploadAttendancePhoto` wraps
// ANY thrown error from the client into `AttendancePhotoUploadException`,
// not to model a specific real exception type.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();

  @override
  String toString() => 'SocketExceptionStub';
}
