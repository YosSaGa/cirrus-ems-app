import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:uuid/validation.dart';

import '../models/captured_photo.dart';
import 'api_client_factory.dart';
import 'auth_service.dart';
import 'local_photo_store.dart';

// claude_prompt.txt (v161 -- Complete Attendance Photo Upload & Camera
// Switching Integration §4): thrown for transport-level upload failures
// (network failure, timeout, or a malformed/empty response) -- distinct
// from AttendanceApiException, which already covers HTTP-level error
// responses from the Backend via `_decodeResponse` and is reused as-is
// for those.
class AttendancePhotoUploadException implements Exception {
  final String message;

  const AttendancePhotoUploadException(this.message);

  @override
  String toString() => message;
}

class AttendanceApiException implements Exception {
  final int statusCode;
  final String? errorCode;
  final String message;

  AttendanceApiException({
    required this.statusCode,
    required this.message,
    this.errorCode,
  });

  @override
  String toString() => message;
}

enum PendingAttendanceRequestState { absent, valid, malformed }

class PendingAttendanceRequestLookup {
  final PendingAttendanceRequestState state;
  final Map<String, dynamic>? record;
  final Map<String, dynamic>? conflictingLegacyRecord;

  const PendingAttendanceRequestLookup._(
    this.state,
    this.record,
    this.conflictingLegacyRecord,
  );

  factory PendingAttendanceRequestLookup.absent() =>
      const PendingAttendanceRequestLookup._(
        PendingAttendanceRequestState.absent,
        null,
        null,
      );

  factory PendingAttendanceRequestLookup.valid(
    Map<String, dynamic> record, {
    Map<String, dynamic>? conflictingLegacyRecord,
  }) => PendingAttendanceRequestLookup._(
    PendingAttendanceRequestState.valid,
    record,
    conflictingLegacyRecord,
  );

  factory PendingAttendanceRequestLookup.malformed() =>
      const PendingAttendanceRequestLookup._(
        PendingAttendanceRequestState.malformed,
        null,
        null,
      );
}

class MalformedPendingRequestException implements Exception {
  final String message;

  const MalformedPendingRequestException([
    this.message = 'A stored Attendance request could not be read and requires manual recovery before it can be retried.',
  ]);

  @override
  String toString() => message;
}

enum AttendanceSubmissionOutcome {
  created,
  replay,
  pendingRequestExists,
  malformedPendingRequestDetected,
  busy,
}

class AttendanceSubmissionResult {
  final AttendanceSubmissionOutcome outcome;
  final Map<String, dynamic>? event;
  final Map<String, dynamic>? pendingRequest;

  const AttendanceSubmissionResult._(
    this.outcome,
    this.event,
    this.pendingRequest,
  );

  factory AttendanceSubmissionResult.created(Map<String, dynamic> event) =>
      AttendanceSubmissionResult._(
        AttendanceSubmissionOutcome.created,
        event,
        null,
      );

  factory AttendanceSubmissionResult.replay(Map<String, dynamic> event) =>
      AttendanceSubmissionResult._(
        AttendanceSubmissionOutcome.replay,
        event,
        null,
      );

  factory AttendanceSubmissionResult.pendingRequestExists(
    Map<String, dynamic> pendingRequest,
  ) => AttendanceSubmissionResult._(
    AttendanceSubmissionOutcome.pendingRequestExists,
    null,
    pendingRequest,
  );

  factory AttendanceSubmissionResult.malformedPendingRequestDetected() =>
      const AttendanceSubmissionResult._(
        AttendanceSubmissionOutcome.malformedPendingRequestDetected,
        null,
        null,
      );

  factory AttendanceSubmissionResult.busy() =>
      const AttendanceSubmissionResult._(
        AttendanceSubmissionOutcome.busy,
        null,
        null,
      );
}

enum DiscardPendingRequestOutcome {
  discarded,
  nothingToDiscard,
  validPendingRequestExists,
  busy,
}

// claude_prompt.txt (v117 -- Fix Pending Checkout Cleanup Race Conditions
// §3): `alreadyResolved` is new -- the exact
// APP_ATTENDANCE_PENDING_CHECKOUT_ALREADY_RESOLVED response is now handled
// entirely inside resolvePendingCheckout() (where the originally-captured
// userId is still in scope), represented as its own outcome rather than
// left to propagate as a thrown AttendanceApiException for the caller to
// catch and clean up after. Every other outcome/shape is unchanged.
enum ResolvePendingCheckoutOutcome { resolved, replay, alreadyResolved, busy }

class ResolvePendingCheckoutResult {
  final ResolvePendingCheckoutOutcome outcome;
  final Map<String, dynamic>? event;
  final bool cleanupFailed;

  const ResolvePendingCheckoutResult._(
    this.outcome,
    this.event,
    this.cleanupFailed,
  );

  factory ResolvePendingCheckoutResult.resolved(
    Map<String, dynamic> event, {
    bool cleanupFailed = false,
  }) => ResolvePendingCheckoutResult._(
    ResolvePendingCheckoutOutcome.resolved,
    event,
    cleanupFailed,
  );

  factory ResolvePendingCheckoutResult.replay(
    Map<String, dynamic> event, {
    bool cleanupFailed = false,
  }) => ResolvePendingCheckoutResult._(
    ResolvePendingCheckoutOutcome.replay,
    event,
    cleanupFailed,
  );

  // claude_prompt.txt (v117 §3): no event body is available for this
  // outcome -- the Backend's 409 response carries only an error code/
  // message, never the resolved DeviceScan row -- so `event` is `null`,
  // the same as `busy`. `cleanupFailed` still applies: this outcome's own
  // local cleanup (clearing the stored request id, since the Backend has
  // confirmed the target work date is already closed) can itself fail
  // independently of the Backend's own, already-confirmed response.
  factory ResolvePendingCheckoutResult.alreadyResolved({
    bool cleanupFailed = false,
  }) => ResolvePendingCheckoutResult._(
    ResolvePendingCheckoutOutcome.alreadyResolved,
    null,
    cleanupFailed,
  );

  factory ResolvePendingCheckoutResult.busy() =>
      const ResolvePendingCheckoutResult._(
        ResolvePendingCheckoutOutcome.busy,
        null,
        false,
      );
}

class MalformedPendingCheckoutRequestIdException implements Exception {
  final String message;

  const MalformedPendingCheckoutRequestIdException([
    this.message =
        'A stored Pending Checkout request id could not be validated and '
        'requires manual recovery before it can be used.',
  ]);

  @override
  String toString() => message;
}

class _RawPendingRecordRead {
  final PendingAttendanceRequestState state;
  final Map<String, dynamic>? record;

  const _RawPendingRecordRead(this.state, this.record);
}

class AttendanceService {
  /// Incremented whenever a check-in / check-out event is accepted by the
  /// backend so [HistoryScreen] and [EarningsTrialTab] auto-refresh without
  /// requiring a manual pull-to-refresh.
  static final ValueNotifier<int> attendanceUpdatedNotifier = ValueNotifier<int>(
    0,
  );

  // claude_prompt.txt (Fix Flutter API Base URL for Android Emulator and
  // Flutter Web): derives from `AuthService.baseUrl` instead of reading
  // `.env` independently, so this service always resolves the exact same
  // platform-specific URL as `AuthService` rather than its own,
  // potentially-diverging copy of the same selection logic.
  static String get _baseUrl => '${AuthService.baseUrl}/app-attendance';

  static const String _pendingRequestKeyPrefix = 'ems.pendingAttendanceRequest';

  static String _pendingRequestKeyFor(String userId) =>
      '$_pendingRequestKeyPrefix.$userId';

  static const String _pendingCheckoutRequestKeyPrefix =
      'ems.pendingCheckoutRequest';

  static String _pendingCheckoutRequestKeyFor(String userId, String workDate) =>
      '$_pendingCheckoutRequestKeyPrefix.$userId.$workDate';

  static final Set<String> _usersWithSubmissionInFlight = <String>{};

  // claude_prompt.txt (v161 §9 "Upload"/"Attendance Integration"): every
  // existing HTTP call site in this file built its own throwaway
  // `createApiClient()` locally, which worked for production but left no
  // seam for tests to substitute a deterministic fake and exercise HTTP
  // errors, network failures, or timeouts -- this file had no unit tests
  // at all before this round. Mirrors `AuthService.debugOverrideClient`
  // (v160) exactly, the same already-established pattern in this
  // codebase, rather than inventing a second one. Production behavior is
  // unchanged: the default is still a fresh `createApiClient()`.
  static http.Client _client = createApiClient();

  @visibleForTesting
  static void debugOverrideClient(http.Client client) {
    _client = client;
  }

  @visibleForTesting
  static void debugResetClient() {
    _client = createApiClient();
  }

  // claude_prompt.txt (v161 §11): mutable so tests can shorten it --
  // mirrors `AuthService.authRequestTimeout`'s existing pattern (v160).
  // Longer than a plain JSON request's timeout since this one carries an
  // image payload.
  @visibleForTesting
  static Duration uploadTimeout = const Duration(seconds: 30);

  static Future<T> _runExclusiveForUser<T>(
    String userId,
    Future<T> Function() action,
    T Function() onBusy,
  ) async {
    if (!_usersWithSubmissionInFlight.add(userId)) {
      return onBusy();
    }
    try {
      return await action();
    } finally {
      _usersWithSubmissionInFlight.remove(userId);
    }
  }

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Please sign in before recording attendance.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<String?> _currentUserId() async {
    final user = await AuthService.getSavedUser();
    final id = user?['id'];
    return id is String ? id : null;
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw AttendanceApiException(
        statusCode: response.statusCode,
        message: 'The server returned an invalid response.',
      );
    }

    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    final rawMessage = data['message'];
    final message = rawMessage is List
        ? rawMessage.join(', ')
        : rawMessage?.toString();

    final errorCode = data['errorCode']?.toString();

    throw AttendanceApiException(
      statusCode: response.statusCode,
      errorCode: errorCode,
      message: message ?? 'Request failed (${response.statusCode})',
    );
  }

  static bool _isValidPendingRecordShape(Map<String, dynamic> raw) {
    final userId = raw['userId'];
    final clientRequestId = raw['clientRequestId'];
    final payload = raw['payload'];
    final createdAt = raw['createdAt'];
    final status = raw['status'];

    return userId is String &&
        userId.isNotEmpty &&
        clientRequestId is String &&
        clientRequestId.isNotEmpty &&
        payload is Map &&
        createdAt is String &&
        createdAt.isNotEmpty &&
        status is String &&
        status.isNotEmpty;
  }

  static Future<_RawPendingRecordRead> _readPendingRecord(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) {
      return const _RawPendingRecordRead(
        PendingAttendanceRequestState.absent,
        null,
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const _RawPendingRecordRead(
        PendingAttendanceRequestState.malformed,
        null,
      );
    }

    if (decoded is! Map<String, dynamic> ||
        !_isValidPendingRecordShape(decoded)) {
      return const _RawPendingRecordRead(
        PendingAttendanceRequestState.malformed,
        null,
      );
    }

    return _RawPendingRecordRead(PendingAttendanceRequestState.valid, decoded);
  }

  static Future<void> _writePendingRequest(
    String userId,
    Map<String, dynamic> record,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingRequestKeyFor(userId), jsonEncode(record));
  }

  // claude_prompt.txt (v171 §5 "Clear local photo and pending metadata only
  // after confirmed Event success"): reads the record BEFORE removing it
  // so any associated local photo file (`photoFilePath`, v171 §3) can be
  // deleted too -- this is the ONE place the pending record is ever
  // cleared after a successful send (`_sendPendingRequest`, below), so it
  // is also the correct, single place to retire the photo file that
  // attempt was holding. Best-effort (`LocalPhotoStore.delete` never
  // throws) and web-safe (`photoFilePath` is simply never set on Web --
  // see `AttendanceScreen`'s own kIsWeb branch -- so this is a no-op
  // there, never an attempted platform-channel call).
  static Future<void> _clearPendingRequest(String userId) async {
    final existing = await _readPendingRecord(_pendingRequestKeyFor(userId));
    if (existing.state == PendingAttendanceRequestState.valid) {
      final photoFilePath = existing.record!['photoFilePath'];
      if (photoFilePath is String && photoFilePath.isNotEmpty) {
        await LocalPhotoStore.delete(photoFilePath);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingRequestKeyFor(userId));
  }

  static Future<Map<String, dynamic>?> _migrateLegacyPendingRequestIfApplicable(
    String userId,
  ) async {
    final legacy = await _readPendingRecord(_pendingRequestKeyPrefix);

    if (legacy.state != PendingAttendanceRequestState.valid) {
      return null;
    }

    final legacyRecord = legacy.record!;
    if (legacyRecord['userId'] != userId) {
      return null;
    }

    final existing = await _readPendingRecord(_pendingRequestKeyFor(userId));

    if (existing.state == PendingAttendanceRequestState.valid) {
      final existingRecord = existing.record!;
      if (legacyRecord['clientRequestId'] ==
          existingRecord['clientRequestId']) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_pendingRequestKeyPrefix);
        return null;
      }
      return legacyRecord;
    }

    if (existing.state == PendingAttendanceRequestState.malformed) {
      return legacyRecord;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingRequestKeyFor(userId),
      jsonEncode(legacyRecord),
    );

    final verification = await _readPendingRecord(
      _pendingRequestKeyFor(userId),
    );
    final verifiedOk =
        verification.state == PendingAttendanceRequestState.valid &&
        verification.record!['clientRequestId'] ==
            legacyRecord['clientRequestId'];

    if (!verifiedOk) {
      return null;
    }

    await prefs.remove(_pendingRequestKeyPrefix);
    return null;
  }

  static Future<PendingAttendanceRequestLookup>
  getPendingRequestForCurrentUser() async {
    final userId = await _currentUserId();
    if (userId == null) return PendingAttendanceRequestLookup.absent();

    final conflictingLegacy = await _migrateLegacyPendingRequestIfApplicable(
      userId,
    );

    final result = await _readPendingRecord(_pendingRequestKeyFor(userId));
    switch (result.state) {
      case PendingAttendanceRequestState.absent:
        return PendingAttendanceRequestLookup.absent();
      case PendingAttendanceRequestState.malformed:
        return PendingAttendanceRequestLookup.malformed();
      case PendingAttendanceRequestState.valid:
        return PendingAttendanceRequestLookup.valid(
          result.record!,
          conflictingLegacyRecord: conflictingLegacy,
        );
    }
  }

  // claude_prompt.txt (v171 §2 "Pending Request Recovery", §3 "Durable
  // Android Persistence"): the single entry point for starting a NEW
  // Check-In attempt or resuming an already-in-progress one. Generates
  // `clientRequestId`/`uploadRequestId` ONCE, at the very start of a
  // genuinely fresh attempt -- v169's own corrected ordering -- and
  // persists them immediately, before the camera even opens, so an app
  // restart at ANY later point has something durable to recover.
  // "Never create a new request identity while retrying an existing
  // pending request" is satisfied by construction: if a valid record
  // already exists, it is returned completely unchanged; a fresh record
  // (with fresh identities) is only ever created when none exists yet.
  static Future<Map<String, dynamic>> beginOrResumeAttendanceAttempt({
    String? windowCode,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw Exception('Please sign in before recording attendance.');
    }

    final existing = await _readPendingRecord(_pendingRequestKeyFor(userId));
    if (existing.state == PendingAttendanceRequestState.valid) {
      return existing.record!;
    }

    final record = <String, dynamic>{
      'userId': userId,
      'clientRequestId': const Uuid().v4(),
      'uploadRequestId': const Uuid().v4(),
      'windowCode': windowCode,
      'photoFilePath': null,
      'payload': <String, dynamic>{},
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'status': 'pending',
    };
    await _writePendingRequest(userId, record);
    return record;
  }

  // claude_prompt.txt (v171 §5 "Camera cancelled before capture: cancel
  // the provisional operation; no upload and no Attendance Event"): a
  // record created by `beginOrResumeAttendanceAttempt` but abandoned
  // before any durable progress was made (no photo file recorded, no
  // storageKey yet) is cleared entirely -- otherwise the NEXT, genuinely
  // new Check-In attempt would incorrectly be treated as "a check-in is
  // waiting to be sent" (PendingAttendanceRequestState.valid) even though
  // nothing was ever captured, uploaded, or submitted. A record that
  // already has a photo path or storageKey is never touched by this --
  // by construction, the camera is never reopened once either exists
  // (AttendanceScreen's own recovery check), so a "cancel before capture"
  // signal can only ever arrive for a record with neither.
  static Future<void> clearProvisionalAttemptIfNoProgress() async {
    final userId = await _currentUserId();
    if (userId == null) return;

    final existing = await _readPendingRecord(_pendingRequestKeyFor(userId));
    if (existing.state != PendingAttendanceRequestState.valid) return;

    final record = existing.record!;
    final hasPhoto =
        record['photoFilePath'] is String &&
        (record['photoFilePath'] as String).isNotEmpty;
    final payload = record['payload'] as Map?;
    final hasStorageKey =
        payload?['selfieStorageKey'] is String &&
        (payload!['selfieStorageKey'] as String).isNotEmpty;

    if (!hasPhoto && !hasStorageKey) {
      await _clearPendingRequest(userId);
    }
  }

  // claude_prompt.txt (v171 §3 "Captured photo file path"): persists the
  // local file path `LocalPhotoStore.save()` just returned into the
  // ALREADY-EXISTING pending record -- never generates a new
  // clientRequestId/uploadRequestId, only adds to the record
  // `beginOrResumeAttendanceAttempt` already created. Pass `null`
  // explicitly to clear a stale reference (e.g. the file was found
  // missing/corrupted on read-back) without touching anything else in
  // the record.
  static Future<void> recordCapturedPhotoPath(String? photoFilePath) async {
    final userId = await _currentUserId();
    if (userId == null) return;

    final existing = await _readPendingRecord(_pendingRequestKeyFor(userId));
    if (existing.state != PendingAttendanceRequestState.valid) return;

    final record = Map<String, dynamic>.from(existing.record!);
    record['photoFilePath'] = photoFilePath;
    await _writePendingRequest(userId, record);
  }

  // claude_prompt.txt (v171 §4 "After receiving storageKey, persist it
  // immediately before attempting Event submission"): merges the
  // returned key into the record's existing `payload` map -- preserves
  // every other already-set payload field (there should be none yet at
  // this point in the normal flow, but a retry recovering from an
  // earlier partial attempt must not lose anything).
  static Future<void> recordUploadedStorageKey(String storageKey) async {
    final userId = await _currentUserId();
    if (userId == null) return;

    final existing = await _readPendingRecord(_pendingRequestKeyFor(userId));
    if (existing.state != PendingAttendanceRequestState.valid) return;

    final record = Map<String, dynamic>.from(existing.record!);
    final payload = Map<String, dynamic>.from(
      record['payload'] as Map? ?? <String, dynamic>{},
    );
    payload['selfieStorageKey'] = storageKey;
    record['payload'] = payload;
    await _writePendingRequest(userId, record);
  }

  // claude_prompt.txt (v171 §1 step 6 "Submit ... with the existing event
  // data, clientRequestId, and selfieStorageKey"): merges freshly-captured
  // location/notes into the ALREADY-PERSISTED record's payload (never
  // touching clientRequestId or selfieStorageKey, both already set by the
  // time this is called) and re-persists it -- this is the ONE place
  // where "submit for the first time" and "retry an existing submission"
  // become the exact same operation: by the time this runs, the record
  // is already fully formed either way, so the actual send
  // (`retryPendingAttendanceEvent`, unchanged, reused as-is) behaves
  // identically regardless of which case led here.
  static Future<void> mergeFreshLocationIntoPendingRequest({
    double? latitude,
    double? longitude,
    double? accuracy,
    String? notes,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) return;

    final existing = await _readPendingRecord(_pendingRequestKeyFor(userId));
    if (existing.state != PendingAttendanceRequestState.valid) return;

    final record = Map<String, dynamic>.from(existing.record!);
    final payload = Map<String, dynamic>.from(
      record['payload'] as Map? ?? <String, dynamic>{},
    );
    if (latitude != null) payload['latitude'] = latitude;
    if (longitude != null) payload['longitude'] = longitude;
    if (accuracy != null) payload['accuracy'] = accuracy;
    if (notes != null) payload['notes'] = notes;
    record['payload'] = payload;
    await _writePendingRequest(userId, record);
  }

  static const Duration _requestTimeout = Duration(seconds: 20);

  static Future<AttendanceSubmissionResult> _sendPendingRequest(
    Map<String, dynamic> pending,
  ) async {
    final userId = pending['userId'] as String;
    final clientRequestId = pending['clientRequestId'] as String;
    final payload = Map<String, dynamic>.from(pending['payload'] as Map);

    final response = await _client
        .post(
          Uri.parse('$_baseUrl/events'),
          headers: await _headers(),
          body: jsonEncode({'clientRequestId': clientRequestId, ...payload}),
        )
        .timeout(_requestTimeout);

    final decoded = _decodeResponse(response);
    await _clearPendingRequest(userId);
    attendanceUpdatedNotifier.value++;

    return response.statusCode == 201
        ? AttendanceSubmissionResult.created(decoded)
        : AttendanceSubmissionResult.replay(decoded);
  }

  static Future<AttendanceSubmissionResult> submitAttendanceEvent({
    double? latitude,
    double? longitude,
    double? accuracy,
    String? selfieStorageKey,
    String? notes,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw Exception('Please sign in before recording attendance.');
    }

    return _runExclusiveForUser<AttendanceSubmissionResult>(userId, () async {
      final lookup = await getPendingRequestForCurrentUser();

      switch (lookup.state) {
        case PendingAttendanceRequestState.malformed:
          return AttendanceSubmissionResult.malformedPendingRequestDetected();
        case PendingAttendanceRequestState.valid:
          return AttendanceSubmissionResult.pendingRequestExists(
            lookup.record!,
          );
        case PendingAttendanceRequestState.absent:
          break;
      }

      final record = <String, dynamic>{
        'userId': userId,
        'clientRequestId': const Uuid().v4(),
        'payload': <String, dynamic>{
          'latitude': ?latitude,
          'longitude': ?longitude,
          'accuracy': ?accuracy,
          'selfieStorageKey': ?selfieStorageKey,
          'notes': ?notes,
        },
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'status': 'pending',
      };
      await _writePendingRequest(userId, record);

      return _sendPendingRequest(record);
    }, AttendanceSubmissionResult.busy);
  }

  static Future<AttendanceSubmissionResult>
  retryPendingAttendanceEvent() async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw Exception('Please sign in before recording attendance.');
    }

    return _runExclusiveForUser<AttendanceSubmissionResult>(userId, () async {
      final lookup = await getPendingRequestForCurrentUser();

      switch (lookup.state) {
        case PendingAttendanceRequestState.absent:
          throw StateError('No pending Attendance request exists to retry.');
        case PendingAttendanceRequestState.malformed:
          throw const MalformedPendingRequestException();
        case PendingAttendanceRequestState.valid:
          return _sendPendingRequest(lookup.record!);
      }
    }, AttendanceSubmissionResult.busy);
  }

  static Future<DiscardPendingRequestOutcome>
  discardMalformedPendingRequest() async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw Exception('Please sign in before recording attendance.');
    }

    return _runExclusiveForUser<DiscardPendingRequestOutcome>(userId, () async {
      final result = await _readPendingRecord(_pendingRequestKeyFor(userId));

      switch (result.state) {
        case PendingAttendanceRequestState.absent:
          return DiscardPendingRequestOutcome.nothingToDiscard;
        case PendingAttendanceRequestState.valid:
          return DiscardPendingRequestOutcome.validPendingRequestExists;
        case PendingAttendanceRequestState.malformed:
          await _clearPendingRequest(userId);

          final verification = await _readPendingRecord(
            _pendingRequestKeyFor(userId),
          );
          if (verification.state != PendingAttendanceRequestState.absent) {
            throw Exception(
              'Failed to discard the pending Attendance request.',
            );
          }
          return DiscardPendingRequestOutcome.discarded;
      }
    }, () => DiscardPendingRequestOutcome.busy);
  }

  static Future<Map<String, dynamic>> getAttendanceStatus() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/status'), headers: await _headers())
        .timeout(_requestTimeout);

    return _decodeResponse(response);
  }

  // claude_prompt.txt (v138 -- Flutter History API Integration): targets
  // GET /attendance directly -- the "Employee Attendance" API
  // (hr.attendance_records), NOT this file's own `_baseUrl`, which points
  // at the separate /app-attendance (device-scan) module. A dedicated
  // base URL, used only by this method.
  static String get _attendanceRecordsBaseUrl =>
      '${AuthService.baseUrl}/attendance';

  static String _formatQueryDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  // claude_prompt.txt (v138): `employeeId` is always the current user's own
  // `core.users.id` -- supplied unconditionally whenever it is available,
  // never omitted just because the account holds elevated permissions (an
  // elevated caller omitting it receives every employee's records; this
  // method never does that -- see GET /attendance's own
  // `canSeeAllAttendance` ownership gate, ems-backend attendance.controller.ts).
  // If no authenticated user id can be resolved, this throws instead of
  // silently requesting unscoped data.
  static Future<List<Map<String, dynamic>>> getAttendanceHistory({
    required DateTime from,
    required DateTime to,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw Exception('Please sign in to view attendance history.');
    }

    final uri = Uri.parse(_attendanceRecordsBaseUrl).replace(
      queryParameters: {
        'employeeId': userId,
        'from': _formatQueryDate(from),
        'to': _formatQueryDate(to),
      },
    );

    final response = await _client
        .get(uri, headers: await _headers())
        .timeout(_requestTimeout);
    return _decodeBareArrayResponse(response);
  }

  // claude_prompt.txt (v141 -- Monthly Attendance Summary + Scan History):
  // GET /app-attendance/my-scans (the v140 backend endpoint). Reuses this
  // file's own existing `_baseUrl` (already `.../app-attendance`) rather
  // than a new base-URL getter -- unlike `getAttendanceHistory` above,
  // this method sends NO identity query parameter at all: the v140
  // endpoint derives the authenticated user from the JWT itself, and the
  // task's own explicit instruction is "Never send userId or employeeId
  // to this endpoint." There is deliberately no `_currentUserId()` call
  // here -- there is nothing client-side for this method to resolve.
  static Future<List<Map<String, dynamic>>> getMyScans({
    required DateTime from,
    required DateTime to,
  }) async {
    final uri = Uri.parse('$_baseUrl/my-scans').replace(
      queryParameters: {
        'from': _formatQueryDate(from),
        'to': _formatQueryDate(to),
      },
    );

    final response = await _client
        .get(uri, headers: await _headers())
        .timeout(_requestTimeout);
    return _decodeBareArrayResponse(response);
  }

  // claude_prompt.txt (v138; renamed from _decodeAttendanceHistoryResponse
  // in v141 since it is now shared by two bare-array-returning endpoints,
  // GET /attendance and GET /app-attendance/my-scans): mirrors
  // `_decodeResponse`'s own error-message extraction exactly, but the
  // success shape differs -- both endpoints' documented contract is a bare
  // JSON array, not an envelope object, so the success branch cannot reuse
  // `_decodeResponse` as-is. Reusing one decoder for both, rather than a
  // second near-identical copy, is the "do not create duplicate API client
  // infrastructure" instruction applied directly.
  static List<Map<String, dynamic>> _decodeBareArrayResponse(
    http.Response response,
  ) {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
      throw AttendanceApiException(
        statusCode: response.statusCode,
        message: 'The server returned an invalid response.',
      );
    }

    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    final rawMessage = data['message'];
    final message = rawMessage is List
        ? rawMessage.join(', ')
        : rawMessage?.toString();

    final errorCode = data['errorCode']?.toString();

    throw AttendanceApiException(
      statusCode: response.statusCode,
      errorCode: errorCode,
      message: message ?? 'Request failed (${response.statusCode})',
    );
  }

  static Future<String> _obtainPendingCheckoutClientRequestId(
    String userId,
    String workDate,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _pendingCheckoutRequestKeyFor(userId, workDate);

    final existing = prefs.getString(key);
    if (existing != null && existing.isNotEmpty) {
      if (!UuidValidation.isValidUUID(fromString: existing)) {
        throw const MalformedPendingCheckoutRequestIdException();
      }
      return existing;
    }

    final newId = const Uuid().v4();
    await prefs.setString(key, newId);
    return newId;
  }

  // claude_prompt.txt (v117 -- Fix Pending Checkout Cleanup Race
  // Conditions §2): still re-reads the CURRENT authenticated user --
  // correct and unchanged for every OTHER caller of this public method
  // (none currently exist outside this file besides the removed internal
  // use below, but the public method itself is preserved per the task's
  // own "preserve the existing public cleanup method if other call sites
  // still require it" instruction). `resolvePendingCheckout` below no
  // longer calls this -- it uses `_clearPendingCheckoutRequestIdFor`
  // instead, which takes the already-captured userId explicitly rather
  // than re-reading it after the HTTP round trip.
  static Future<void> clearPendingCheckoutRequestId(String workDate) async {
    final userId = await _currentUserId();
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingCheckoutRequestKeyFor(userId, workDate));
  }

  // claude_prompt.txt (v117 §2 "Fix Cross-User Cleanup Race"): takes
  // `userId` explicitly -- never re-reads the currently authenticated
  // user. If the authenticated account changes while an HTTP request for
  // the ORIGINAL user is still in flight, this still removes only that
  // original user's own key, never whichever account happens to be
  // active by the time this runs.
  static Future<void> _clearPendingCheckoutRequestIdFor(
    String userId,
    String workDate,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingCheckoutRequestKeyFor(userId, workDate));
  }

  static Future<ResolvePendingCheckoutResult> resolvePendingCheckout({
    required String workDate,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw Exception('Please sign in before recording attendance.');
    }

    return _runExclusiveForUser<ResolvePendingCheckoutResult>(userId, () async {
      // `userId` above is captured once, before the HTTP round trip, and
      // reused for every cleanup call below -- never re-read via
      // `_currentUserId()` after the request is sent (v117 §2).
      final clientRequestId = await _obtainPendingCheckoutClientRequestId(
        userId,
        workDate,
      );

      final response = await _client
          .post(
            Uri.parse('$_baseUrl/pending-checkout/resolve'),
            headers: await _headers(),
            body: jsonEncode({
              'clientRequestId': clientRequestId,
              'workDate': workDate,
            }),
          )
          .timeout(_requestTimeout);

      // claude_prompt.txt (v117 §3 "Fix ALREADY_RESOLVED Cleanup
      // Handling"): the exact ALREADY_RESOLVED response is now caught
      // and handled HERE, where `userId` is still the originally
      // captured value -- not left to propagate out to the caller as a
      // thrown AttendanceApiException, which previously forced the
      // caller to perform its own cleanup outside this method (and,
      // per the v116 report, outside any catch block that could handle
      // a second exception from that cleanup itself). Only this one
      // exact error code is intercepted; every other AttendanceApiException
      // (including authentication failures and any other error code)
      // is rethrown completely unchanged, so the existing
      // `_redirectIfAuthFailure`/`_messageForApiException` handling in
      // the caller continues to see the exact same exception it always
      // did for every other case.
      try {
        final decoded = _decodeResponse(response);

        bool cleanupFailed = false;
        try {
          await _clearPendingCheckoutRequestIdFor(userId, workDate);
        } catch (_) {
          cleanupFailed = true;
        }

        return response.statusCode == 201
            ? ResolvePendingCheckoutResult.resolved(
                decoded,
                cleanupFailed: cleanupFailed,
              )
            : ResolvePendingCheckoutResult.replay(
                decoded,
                cleanupFailed: cleanupFailed,
              );
      } on AttendanceApiException catch (e) {
        if (e.errorCode != 'APP_ATTENDANCE_PENDING_CHECKOUT_ALREADY_RESOLVED') {
          rethrow;
        }

        bool cleanupFailed = false;
        try {
          await _clearPendingCheckoutRequestIdFor(userId, workDate);
        } catch (_) {
          cleanupFailed = true;
        }

        return ResolvePendingCheckoutResult.alreadyResolved(
          cleanupFailed: cleanupFailed,
        );
      }
    }, () => ResolvePendingCheckoutResult.busy());
  }

  // claude_prompt.txt (v161 §4 -- Attendance Photo Upload Integration,
  // v171 §4 -- Upload and Event Submission): POST /storage/uploads.
  // `employeeId` is deliberately the authenticated `core.users.id` from
  // `_currentUserId()` (the same saved-user field every other method in
  // this file already treats as the identity -- confirmed against
  // `AuthService.getSavedUser()`'s saved-user shape), never
  // `core.employees.id` or `employee_code`, per the task's own explicit
  // identity rule. Content-Type is deliberately never set on the
  // `MultipartRequest` -- `package:http` generates the multipart boundary
  // itself; setting it manually would silently break the boundary.
  //
  // `uploadRequestId` (v171, now required -- the Backend's v170
  // idempotency implementation only activates when this field is sent;
  // omitting it would silently fall back to the Backend's old,
  // non-idempotent upload path for every single call from this app) is
  // sent as a plain multipart text field, exactly like `category`/
  // `employeeId` -- the caller is responsible for generating it ONCE, at
  // the start of an attempt, and persisting it before this is ever
  // called (`AttendanceService.beginOrResumeAttendanceAttempt`), so the
  // SAME value is sent on every retry of the same logical attempt. A 409
  // response with `errorCode: 'ATTENDANCE_PHOTO_UPLOAD_LEASE_HELD'` (the
  // Backend's v170 "another worker currently owns this identity's lease"
  // signal) surfaces as an ordinary `AttendanceApiException` via the
  // existing `_decodeResponse` below -- no special-casing needed here;
  // the caller (`AttendanceScreen`) recognizes that specific errorCode.
  static Future<String> uploadAttendancePhoto(
    CapturedPhoto photo,
    String uploadRequestId,
  ) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw Exception('Please sign in before recording attendance.');
    }

    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Please sign in before recording attendance.');
    }

    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('${AuthService.baseUrl}/storage/uploads'),
          )
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['category'] = 'attendance'
          ..fields['employeeId'] = userId
          ..fields['uploadRequestId'] = uploadRequestId
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              photo.bytes,
              filename: photo.fileName,
              contentType: () {
                try {
                  return MediaType.parse(photo.mimeType);
                } catch (_) {
                  return MediaType('image', 'jpeg');
                }
              }(),
            ),
          );

    http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request).timeout(uploadTimeout);
    } on TimeoutException {
      throw const AttendancePhotoUploadException(
        'The photo upload timed out. Please check your connection and try again.',
      );
    } on AttendancePhotoUploadException {
      rethrow;
    } catch (_) {
      throw const AttendancePhotoUploadException(
        'The photo could not be uploaded. Please check your connection and try again.',
      );
    }

    // claude_prompt.txt (v161 §4 "Validate the response and reject empty
    // or malformed storage keys"): `_decodeResponse` already throws
    // `AttendanceApiException` for any non-2xx HTTP status, reusing the
    // same error-message extraction every other endpoint in this file
    // relies on, so only the success-shape check is new here.
    final response = await http.Response.fromStream(
      streamed,
    ).timeout(uploadTimeout);
    final decoded = _decodeResponse(response);

    final storageKey = decoded['storageKey'];
    if (storageKey is! String || storageKey.isEmpty) {
      throw const AttendancePhotoUploadException(
        'The server returned an invalid photo storage reference.',
      );
    }

    return storageKey;
  }
}
