import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'api_client_factory.dart';
import 'attendance_service.dart';
import 'auth_service.dart';

class TechnicianApiException implements Exception {
  final int statusCode;
  final String message;

  const TechnicianApiException({
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() => message;
}

class TechnicianJob {
  const TechnicianJob({
    required this.id,
    required this.jobCode,
    required this.title,
    this.description = '',
    this.status = 'open',
    this.priority = 'medium',
    this.jobSource = 'work_order',
    this.projectId,
    this.projectName,
    this.vesselName,
    this.location,
    this.isMine = true,
    this.assignedToName,
    this.scheduleStart,
    this.scheduleEnd,
    this.reportSubmitted = false,
    this.lastCheckoutStatus,
    this.vesselType,
    this.vesselRegistration,
    this.vesselModel,
    this.assetName,
    this.assetModel,
    this.assetSerial,
    this.assetCategory,
  });

  final String id;
  final String jobCode;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String jobSource;
  final String? projectId;
  final String? projectName;
  final String? vesselName;
  final String? location;
  final bool isMine;
  final String? assignedToName;
  final String? scheduleStart;
  final String? scheduleEnd;
  final bool reportSubmitted;
  final String? lastCheckoutStatus;
  final String? vesselType;
  final String? vesselRegistration;
  final String? vesselModel;
  final String? assetName;
  final String? assetModel;
  final String? assetSerial;
  final String? assetCategory;

  bool get hasVesselOrEquipmentDetails =>
      (vesselType != null && vesselType!.isNotEmpty) ||
      (vesselRegistration != null && vesselRegistration!.isNotEmpty) ||
      (vesselModel != null && vesselModel!.isNotEmpty) ||
      (assetName != null && assetName!.isNotEmpty) ||
      (assetModel != null && assetModel!.isNotEmpty) ||
      (assetSerial != null && assetSerial!.isNotEmpty) ||
      (assetCategory != null && assetCategory!.isNotEmpty);

  bool get isClosedOnBackend => const {
    'completed',
    'closed',
    'cancelled',
    'canceled',
  }.contains(status.toLowerCase());

  bool get isSubmittedAwaitingClose =>
      isMine && reportSubmitted && lastCheckoutStatus != 'in_progress';

  bool get isSelectableForCheckIn =>
      isMine && !isClosedOnBackend && !isSubmittedAwaitingClose;

  TechnicianJob copyWith({
    String? status,
    bool? reportSubmitted,
    String? lastCheckoutStatus,
  }) => TechnicianJob(
    id: id,
    jobCode: jobCode,
    title: title,
    description: description,
    status: status ?? this.status,
    priority: priority,
    jobSource: jobSource,
    projectId: projectId,
    projectName: projectName,
    vesselName: vesselName,
    location: location,
    isMine: isMine,
    assignedToName: assignedToName,
    scheduleStart: scheduleStart,
    scheduleEnd: scheduleEnd,
    reportSubmitted: reportSubmitted ?? this.reportSubmitted,
    lastCheckoutStatus: lastCheckoutStatus ?? this.lastCheckoutStatus,
    vesselType: vesselType,
    vesselRegistration: vesselRegistration,
    vesselModel: vesselModel,
    assetName: assetName,
    assetModel: assetModel,
    assetSerial: assetSerial,
    assetCategory: assetCategory,
  );

  factory TechnicianJob.fromJson(Map<String, dynamic> json) => TechnicianJob(
    id: (json['id'] ?? '').toString(),
    jobCode: (json['jobCode'] ?? 'JOB').toString(),
    title: (json['title'] ?? '').toString(),
    description: (json['description'] ?? '').toString(),
    status: (json['status'] ?? 'open').toString(),
    priority: (json['priority'] ?? 'medium').toString(),
    jobSource: (json['jobSource'] ?? 'work_order').toString(),
    projectId: json['projectId']?.toString(),
    projectName: json['projectName']?.toString(),
    vesselName: json['vesselName']?.toString(),
    location: json['location']?.toString(),
    isMine: json['isMine'] == null ? true : json['isMine'] == true,
    assignedToName: json['assignedToName']?.toString(),
    scheduleStart: json['scheduleStart']?.toString(),
    scheduleEnd: json['scheduleEnd']?.toString(),
    reportSubmitted: json['reportSubmitted'] == true,
    lastCheckoutStatus: json['lastCheckoutStatus']?.toString(),
    vesselType: json['vesselType']?.toString(),
    vesselRegistration: json['vesselRegistration']?.toString(),
    vesselModel: json['vesselModel']?.toString(),
    assetName: json['assetName']?.toString(),
    assetModel: json['assetModel']?.toString(),
    assetSerial: json['assetSerial']?.toString(),
    assetCategory: json['assetCategory']?.toString(),
  );
}

class TechnicianWorkSession {
  const TechnicianWorkSession({
    required this.id,
    required this.jobId,
    required this.jobCode,
    required this.jobTitle,
    required this.status,
    required this.checkInAt,
    this.vesselName,
    this.jobSource = 'work_order',
    this.checkOutAt,
    this.durationMinutes,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.jobStatusAtCheckout,
    this.notes,
    this.reportSubmitted = false,
  });

  final String id;
  final String jobId;
  final String jobSource;
  final String jobCode;
  final String jobTitle;
  final String? vesselName;
  final String status;
  final String checkInAt;
  final String? checkOutAt;
  final double? durationMinutes;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final String? jobStatusAtCheckout;
  final String? notes;
  final bool reportSubmitted;

  bool get isActive => status == 'active' && (checkOutAt == null || checkOutAt!.isEmpty);

  /// Work report deadline: 07:00 AM local time on the day after the work session.
  DateTime? get reportDeadlineLocal {
    final raw = (checkOutAt != null && checkOutAt!.isNotEmpty)
        ? checkOutAt!
        : checkInAt;
    final ref = DateTime.tryParse(raw)?.toLocal();
    if (ref == null) return null;
    return DateTime(ref.year, ref.month, ref.day + 1, 7, 0);
  }

  /// Overdue minutes past the 07:00 AM next-day deadline (0 if still on time).
  int reportLateMinutes([DateTime? now]) {
    final deadline = reportDeadlineLocal;
    if (deadline == null) return 0;
    final current = (now ?? DateTime.now()).toLocal();
    if (!current.isAfter(deadline)) return 0;
    final mins = current.difference(deadline).inMinutes;
    return mins < 1 ? 1 : mins;
  }

  /// Remaining duration until 07:00 AM next-day deadline, or null if overdue.
  Duration? reportRemainingTime([DateTime? now]) {
    final deadline = reportDeadlineLocal;
    if (deadline == null) return null;
    final current = (now ?? DateTime.now()).toLocal();
    if (current.isAfter(deadline)) return null;
    return deadline.difference(current);
  }

  factory TechnicianWorkSession.fromJson(Map<String, dynamic> json) =>
      TechnicianWorkSession(
        id: (json['id'] ?? '').toString(),
        jobId: (json['jobId'] ?? '').toString(),
        jobSource: (json['jobSource'] ?? 'work_order').toString(),
        jobCode: (json['jobCode'] ?? 'JOB').toString(),
        jobTitle: (json['jobTitle'] ?? '').toString(),
        vesselName: json['vesselName']?.toString(),
        status: (json['status'] ?? 'active').toString(),
        checkInAt: (json['checkInAt'] ?? '').toString(),
        checkOutAt: json['checkOutAt']?.toString(),
        durationMinutes: json['durationMinutes'] is num
            ? (json['durationMinutes'] as num).toDouble()
            : double.tryParse(json['durationMinutes']?.toString() ?? ''),
        checkInLatitude: json['checkInLatitude'] is num
            ? (json['checkInLatitude'] as num).toDouble()
            : null,
        checkInLongitude: json['checkInLongitude'] is num
            ? (json['checkInLongitude'] as num).toDouble()
            : null,
        checkOutLatitude: json['checkOutLatitude'] is num
            ? (json['checkOutLatitude'] as num).toDouble()
            : null,
        checkOutLongitude: json['checkOutLongitude'] is num
            ? (json['checkOutLongitude'] as num).toDouble()
            : null,
        jobStatusAtCheckout: json['jobStatusAtCheckout']?.toString(),
        notes: json['notes']?.toString(),
        reportSubmitted: json['reportSubmitted'] == true,
      );
}

class TechnicianDashboardData {
  const TechnicianDashboardData({
    required this.workDate,
    required this.jobs,
    required this.todaySessions,
    required this.completedWindows,
    this.activeSession,
    this.breakSession,
    this.pendingReportSession,
    this.nextWindowCode,
  });

  final String workDate;
  final List<TechnicianJob> jobs;
  final TechnicianWorkSession? activeSession;
  final TechnicianWorkSession? breakSession;
  final TechnicianWorkSession? pendingReportSession;
  final List<TechnicianWorkSession> todaySessions;
  final Set<String> completedWindows;
  final String? nextWindowCode;

  bool get hasPendingReport => pendingReportSession != null;
  bool get isOnBreak => breakSession != null && activeSession == null;

  factory TechnicianDashboardData.fromJson(Map<String, dynamic> json) {
    final rawJobs = json['jobs'];
    final jobs = rawJobs is List
        ? rawJobs
            .whereType<Map>()
            .map((m) => TechnicianJob.fromJson(Map<String, dynamic>.from(m)))
            .toList(growable: false)
        : const <TechnicianJob>[];

    final rawSessions = json['todaySessions'];
    final sessions = rawSessions is List
        ? rawSessions
            .whereType<Map>()
            .map(
              (m) => TechnicianWorkSession.fromJson(
                Map<String, dynamic>.from(m),
              ),
            )
            .toList(growable: false)
        : const <TechnicianWorkSession>[];

    final rawActive = json['activeSession'];
    final active = rawActive is Map
        ? TechnicianWorkSession.fromJson(Map<String, dynamic>.from(rawActive))
        : null;

    final rawBreak = json['breakSession'];
    final breakSess = rawBreak is Map
        ? TechnicianWorkSession.fromJson(Map<String, dynamic>.from(rawBreak))
        : null;

    final rawPendingRep = json['pendingReportSession'];
    final pendingRep = rawPendingRep is Map
        ? TechnicianWorkSession.fromJson(
            Map<String, dynamic>.from(rawPendingRep),
          )
        : null;

    final rawCompleted = json['completedWindows'];
    final completed = rawCompleted is List
        ? rawCompleted.map((e) => e.toString()).toSet()
        : <String>{};

    return TechnicianDashboardData(
      workDate: (json['workDate'] ?? '').toString(),
      jobs: jobs,
      activeSession: active,
      breakSession: breakSess,
      pendingReportSession: pendingRep,
      todaySessions: sessions,
      completedWindows: completed,
      nextWindowCode: json['nextWindowCode']?.toString(),
    );
  }
}

class TechnicianHistoryItem {
  const TechnicianHistoryItem({
    required this.sessionId,
    required this.technicianName,
    required this.isMine,
    required this.jobCode,
    required this.jobTitle,
    required this.sessionStatus,
    required this.checkInAt,
    this.checkOutAt,
    this.durationMinutes,
    this.jobStatusAtCheckout,
    this.hasGps = false,
    this.reportId,
    this.reportNumber,
    this.workType,
    this.workDescription,
    this.findings,
    this.recommendations,
    this.photoCount = 0,
    this.reportStatus,
    this.hoursWorked,
  });

  final String sessionId;
  final String technicianName;
  final bool isMine;
  final String jobCode;
  final String jobTitle;
  final String sessionStatus;
  final String checkInAt;
  final String? checkOutAt;
  final double? durationMinutes;
  final String? jobStatusAtCheckout;
  final bool hasGps;
  final String? reportId;
  final String? reportNumber;
  final String? workType;
  final String? workDescription;
  final String? findings;
  final String? recommendations;
  final int photoCount;
  final String? reportStatus;
  final double? hoursWorked;

  bool get hasReport => reportId != null && reportId!.isNotEmpty;

  factory TechnicianHistoryItem.fromJson(Map<String, dynamic> json) =>
      TechnicianHistoryItem(
        sessionId: (json['sessionId'] ?? '').toString(),
        technicianName: (json['technicianName'] ?? 'Technician').toString(),
        isMine: json['isMine'] == true,
        jobCode: (json['jobCode'] ?? 'JOB').toString(),
        jobTitle: (json['jobTitle'] ?? '').toString(),
        sessionStatus: (json['sessionStatus'] ?? 'completed').toString(),
        checkInAt: (json['checkInAt'] ?? '').toString(),
        checkOutAt: json['checkOutAt']?.toString(),
        durationMinutes: json['durationMinutes'] is num
            ? (json['durationMinutes'] as num).toDouble()
            : double.tryParse(json['durationMinutes']?.toString() ?? ''),
        jobStatusAtCheckout: json['jobStatusAtCheckout']?.toString(),
        hasGps: json['hasGps'] == true,
        reportId: json['reportId']?.toString(),
        reportNumber: json['reportNumber']?.toString(),
        workType: json['workType']?.toString(),
        workDescription: json['workDescription']?.toString(),
        findings: json['findings']?.toString(),
        recommendations: json['recommendations']?.toString(),
        photoCount: json['photoCount'] is num
            ? (json['photoCount'] as num).toInt()
            : 0,
        reportStatus: json['reportStatus']?.toString(),
        hoursWorked: json['hoursWorked'] is num
            ? (json['hoursWorked'] as num).toDouble()
            : double.tryParse(json['hoursWorked']?.toString() ?? ''),
      );
}

class TechnicianHistoryResponse {
  const TechnicianHistoryResponse({
    required this.isAdmin,
    required this.items,
  });

  final bool isAdmin;
  final List<TechnicianHistoryItem> items;
}

/// REST client for Technician field-job attendance (`GET /technician/my-jobs`,
/// `POST /technician/check-in`, `POST /technician/check-out`).
/// Strictly restricted to accounts carrying the `Technician` role.
class TechnicianService {
  @visibleForTesting
  static Future<TechnicianDashboardData> Function()? getMyJobsOverride;

  /// True when a test override is active (used to disable live background polling in tests).
  static bool get isUsingMockOverride => getMyJobsOverride != null;

  static String? _cachedTeamMemberUserId;
  static String? _cachedTeamMemberId;
  static TechnicianDashboardData? lastDashboardData;

  static void clearCachedDashboard() => lastDashboardData = null;

  /// Matches the signed-in user against `GET /team-members` so we know their
  /// `hr.team_members.id` even when it differs from `core.users.id`.
  static String? _resolveTeamMemberFromList(
    List<Map<String, dynamic>> rawTeamMembers,
    Set<String> userIds,
    Set<String> nameTokens,
  ) {
    for (final m in rawTeamMembers) {
      final memberId = _pickStr(m, const [
        'id',
        'teamMemberId',
        'team_member_id',
      ]);
      final nestedUser = m['user'] ?? m['employee'];
      final linkedUserId =
          _pickStr(m, const [
            'userId',
            'user_id',
            'employeeId',
            'employee_id',
          ]) ??
          (nestedUser is Map ? nestedUser['id']?.toString().trim() : null);

      final candidateNames = <String>{};
      for (final k in const [
        'name',
        'fullName',
        'full_name',
        'displayName',
        'username',
        'userName',
        'nickname',
        'email',
      ]) {
        final v = m[k]?.toString().trim().toLowerCase();
        if (v != null && v.isNotEmpty) candidateNames.add(v);
      }
      if (nestedUser is Map) {
        for (final k in const [
          'name',
          'fullName',
          'full_name',
          'displayName',
          'username',
          'userName',
          'nickname',
          'email',
        ]) {
          final v = nestedUser[k]?.toString().trim().toLowerCase();
          if (v != null && v.isNotEmpty) candidateNames.add(v);
        }
      }

      final matches =
          (memberId != null && userIds.contains(memberId)) ||
          (linkedUserId != null && userIds.contains(linkedUserId)) ||
          candidateNames.any(nameTokens.contains);
      if (matches) {
        if (memberId != null && memberId.isNotEmpty) userIds.add(memberId);
        if (linkedUserId != null && linkedUserId.isNotEmpty) {
          userIds.add(linkedUserId);
        }
        nameTokens.addAll(candidateNames);
        return memberId;
      }
    }
    return null;
  }

  @visibleForTesting
  static Future<Map<String, dynamic>> Function({
    required String jobId,
    required String jobSource,
    required String windowCode,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? photoStorageKey,
    String? notes,
  })? checkInOverride;

  @visibleForTesting
  static Future<Map<String, dynamic>> Function({
    required String sessionId,
    required String windowCode,
    required String jobStatus,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? photoStorageKey,
    String? notes,
  })? checkOutOverride;

  @visibleForTesting
  static Future<Map<String, dynamic>> Function({
    required String sessionId,
    required String workDescription,
    required String workType,
    String? findings,
    String? recommendations,
    List<String> photos,
  })? submitReportOverride;

  @visibleForTesting
  static Future<TechnicianHistoryResponse> Function()? getHistoryOverride;

  @visibleForTesting
  static Future<Map<String, dynamic>> Function({
    required String sessionId,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? photoStorageKey,
  })? startBreakOverride;

  @visibleForTesting
  static Future<Map<String, dynamic>> Function({
    required String sessionId,
    required String jobStatus,
  })? endFromBreakOverride;

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _decodeJson(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _extractList(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList(growable: false);
      }
      if (decoded is Map) {
        for (final key in const [
          'data',
          'items',
          'workOrders',
          'work_orders',
          'workAssignments',
          'work_assignments',
          'workSessions',
          'work_sessions',
          'sessions',
          'reports',
          'technicianReports',
          'rows',
          'results',
        ]) {
          final v = decoded[key];
          if (v is List) {
            return v
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList(growable: false);
          }
          if (v is Map) {
            for (final nested in const ['items', 'data', 'rows']) {
              if (v[nested] is List) {
                return (v[nested] as List)
                    .whereType<Map>()
                    .map((m) => Map<String, dynamic>.from(m))
                    .toList(growable: false);
              }
            }
          }
        }
      }
    } catch (_) {}
    return const <Map<String, dynamic>>[];
  }

  static String? _pickStr(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return null;
  }

  static double? _pickDouble(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v is num) return v.toDouble();
      if (v != null) {
        final parsed = double.tryParse(v.toString());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static Future<Set<String>> _currentUserIds() async {
    final user = await AuthService.getSavedUser();
    if (user == null) return const {};
    final ids = <String>{};
    for (final k in const [
      'id',
      'userId',
      'user_id',
      'employeeId',
      'employee_id',
      'employeeCode',
      'employee_code',
    ]) {
      final v = user[k]?.toString().trim();
      if (v != null && v.isNotEmpty) ids.add(v);
    }
    final emp = user['employee'];
    if (emp is Map) {
      final empId = emp['id']?.toString().trim();
      if (empId != null && empId.isNotEmpty) ids.add(empId);
    }
    return ids;
  }

  /// Lower-cased username / display name / email of the signed-in user, used
  /// as a fallback to match technicians by name (e.g. `Bom V.2`).
  static Future<Set<String>> _currentUserNameTokens() async {
    final user = await AuthService.getSavedUser();
    if (user == null) return const {};
    final tokens = <String>{};
    for (final k in const [
      'username',
      'userName',
      'user_name',
      'name',
      'displayName',
      'nickname',
      'email',
    ]) {
      final v = user[k]?.toString().trim().toLowerCase();
      if (v != null && v.isNotEmpty) tokens.add(v);
    }
    return tokens;
  }

  /// Parses the `technicians: [{id, name}]` array that the EMS API embeds in
  /// each work order. Returns all technician names and whether the signed-in
  /// user is one of them (matched by user id, or by username/name).
  static ({List<String> names, bool isMine}) _parseTechnicians(
    Map<String, dynamic> raw,
    Set<String> userIds,
    Set<String> nameTokens,
  ) {
    final names = <String>[];
    var mine = false;
    for (final key in const [
      'technicians',
      'assignedTechnicians',
      'assigned_technicians',
      'assignees',
    ]) {
      final list = raw[key];
      if (list is! List) continue;
      for (final item in list) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final nested = m['user'] ?? m['employee'];
          final id =
              _pickStr(m, const ['userId', 'user_id', 'id']) ??
              (nested is Map ? nested['id']?.toString() : null);
          final name =
              _pickStr(m, const [
                'name',
                'fullName',
                'full_name',
                'displayName',
                'username',
              ]) ??
              (nested is Map
                  ? _pickStr(Map<String, dynamic>.from(nested), const [
                      'name',
                      'username',
                    ])
                  : null);
          final username = _pickStr(m, const ['username', 'userName']);
          if (name != null && !names.contains(name)) names.add(name);
          if ((id != null && userIds.contains(id)) ||
              (name != null && nameTokens.contains(name.toLowerCase())) ||
              (username != null &&
                  nameTokens.contains(username.toLowerCase()))) {
            mine = true;
          }
        } else if (item != null) {
          final s = item.toString().trim();
          if (s.isEmpty) continue;
          if (userIds.contains(s) || nameTokens.contains(s.toLowerCase())) {
            mine = true;
          }
        }
      }
    }
    return (names: names, isMine: mine);
  }

  static String _todayDateStr() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static bool _isTodayIso(String? iso) {
    if (iso == null || iso.isEmpty) return false;
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return false;
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  static Future<List<Map<String, dynamic>>> _safeGetList(
    http.Client client,
    Map<String, String> headers,
    String path,
  ) async {
    try {
      final res = await client
          .get(Uri.parse('${AuthService.baseUrl}$path'), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _extractList(res.body);
      }
    } catch (_) {}
    return const <Map<String, dynamic>>[];
  }

  static Future<TechnicianDashboardData> _getMyJobsFromNestApi(
    http.Client client,
    Map<String, String> headers,
  ) async {
    final ordersRes = await client
        .get(Uri.parse('${AuthService.baseUrl}/work-orders'), headers: headers)
        .timeout(const Duration(seconds: 15));
    if (ordersRes.statusCode < 200 || ordersRes.statusCode >= 300) {
      final errBody = _decodeJson(ordersRes);
      throw TechnicianApiException(
        statusCode: ordersRes.statusCode,
        message:
            errBody['message']?.toString() ??
            'Failed to load work orders (${ordersRes.statusCode}).',
      );
    }
    final rawOrders = _extractList(ordersRes.body);

    final user = await AuthService.getSavedUser();
    final currentUserId = user?['id']?.toString().trim();
    final currentUserName = user?['name']?.toString().trim();
    final userIds = await _currentUserIds();
    final nameTokens = await _currentUserNameTokens();
    final results = await Future.wait<dynamic>([
      _safeGetList(client, headers, '/work-assignments'),
      _safeGetList(client, headers, '/work-sessions'),
      _safeGetList(client, headers, '/technician-reports'),
      AttendanceService.getAttendanceStatus().catchError(
        (_) => <String, dynamic>{},
      ),
      _safeGetList(client, headers, '/projects'),
      _safeGetList(client, headers, '/vessels'),
      _safeGetList(client, headers, '/assets'),
      _safeGetList(client, headers, '/team-members'),
    ]);

    final rawAssignments = results[0] as List<Map<String, dynamic>>;
    final rawSessions = results[1] as List<Map<String, dynamic>>;
    final rawReports = results[2] as List<Map<String, dynamic>>;
    final attStatus = results[3] as Map<String, dynamic>;
    final rawProjects = results[4] as List<Map<String, dynamic>>;
    final rawVessels = results[5] as List<Map<String, dynamic>>;
    final rawAssets = results[6] as List<Map<String, dynamic>>;
    final rawTeamMembers = results[7] as List<Map<String, dynamic>>;

    final resolvedTeamMemberId = _resolveTeamMemberFromList(
      rawTeamMembers,
      userIds,
      nameTokens,
    );
    if (resolvedTeamMemberId != null &&
        currentUserId != null &&
        currentUserId.isNotEmpty) {
      _cachedTeamMemberUserId = currentUserId;
      _cachedTeamMemberId = resolvedTeamMemberId;
    }

    final vesselNameById = <String, String>{};
    for (final v in rawVessels) {
      final id = _pickStr(v, const ['id']);
      final name = _pickStr(v, const ['name', 'vesselName', 'vessel_name', 'title']);
      if (id != null && name != null) vesselNameById[id] = name;
    }

    final assetById = <String, Map<String, dynamic>>{};
    for (final a in rawAssets) {
      final id = _pickStr(a, const ['id']);
      if (id != null) assetById[id] = a;
    }

    final projectById = <String, Map<String, dynamic>>{};
    for (final p in rawProjects) {
      final id = _pickStr(p, const ['id']);
      if (id != null) projectById[id] = p;
    }

    // Map assignments -> which workOrderIds belong to current user
    final myAssignedOrderIds = <String>{};
    final assignedNameByOrder = <String, String>{};
    void registerAssignment(Map<String, dynamic> a, {String? fallbackOrderId}) {
      final woId =
          _pickStr(a, const ['workOrderId', 'work_order_id', 'jobId']) ??
          fallbackOrderId;
      if (woId == null) return;
      final empObj = a['user'] ?? a['employee'] ?? a['technician'] ?? a['assignee'];
      final empId =
          _pickStr(a, const [
            'userId',
            'user_id',
            'employeeId',
            'employee_id',
            'technicianId',
            'technician_id',
          ]) ??
          (empObj is Map ? empObj['id']?.toString() : null);
      final empName =
          _pickStr(a, const [
            'userName',
            'user_name',
            'employeeName',
            'employee_name',
            'technicianName',
            'technician_name',
            'assigneeName',
            'assignedToName',
            'assigned_to_name',
          ]) ??
          (empObj is Map
              ? _pickStr(Map<String, dynamic>.from(empObj), const [
                  'name',
                  'fullName',
                  'full_name',
                  'displayName',
                  'username',
                ])
              : null);
      if (empName != null && !assignedNameByOrder.containsKey(woId)) {
        assignedNameByOrder[woId] = empName;
      }
      if (empId != null && userIds.contains(empId)) {
        myAssignedOrderIds.add(woId);
        if (currentUserName != null &&
            currentUserName.isNotEmpty &&
            !assignedNameByOrder.containsKey(woId)) {
          assignedNameByOrder[woId] = currentUserName;
        }
      }
    }

    for (final a in rawAssignments) {
      registerAssignment(a);
    }

    // Build jobs list from /work-orders
    final orderById = <String, TechnicianJob>{};
    final jobs = <TechnicianJob>[];
    for (final wo in rawOrders) {
      final id = _pickStr(wo, const ['id']);
      if (id == null) continue;

      // Also check embedded assignments inside the work order object
      for (final embedKey in const [
        'assignments',
        'workAssignments',
        'work_assignments',
      ]) {
        final embedded = wo[embedKey];
        if (embedded is List) {
          for (final item in embedded.whereType<Map>()) {
            registerAssignment(
              Map<String, dynamic>.from(item),
              fallbackOrderId: id,
            );
          }
        }
      }

      final code =
          _pickStr(wo, const [
            'number',
            'workOrderNumber',
            'work_order_number',
            'jobCode',
            'job_code',
            'woNumber',
            'wo_number',
            'code',
            'orderNumber',
            'order_number',
          ]) ??
          'WO-${id.length >= 6 ? id.substring(0, 6).toUpperCase() : id}';
      final title =
          _pickStr(wo, const [
            'title',
            'name',
            'subject',
            'workTitle',
            'work_title',
          ]) ??
          '';
      final desc =
          _pickStr(wo, const [
            'description',
            'notes',
            'details',
            'scope',
            'summary',
            'remarks',
          ]) ??
          '';
      final status = (_pickStr(wo, const ['status']) ?? 'open').toLowerCase();
      final priority =
          (_pickStr(wo, const [
                    'priority',
                    'priorityLevel',
                    'priority_level',
                    'urgency',
                  ]) ??
                  'medium')
              .toLowerCase();
      final projectId = _pickStr(wo, const ['projectId', 'project_id']);
      final assetId = _pickStr(wo, const ['assetId', 'asset_id']);
      final vesselId = _pickStr(wo, const ['vesselId', 'vessel_id']);
      final projMap = projectId != null ? projectById[projectId] : null;
      final assetMap = assetId != null ? assetById[assetId] : null;

      final projectObj = wo['project'];
      final projectName =
          _pickStr(wo, const ['projectName', 'project_name']) ??
          (projectObj is Map
              ? _pickStr(Map<String, dynamic>.from(projectObj), const [
                  'name',
                  'title',
                  'projectName',
                ])
              : null) ??
          (projMap != null
              ? _pickStr(projMap, const ['name', 'title', 'projectName'])
              : null);

      final directVesselObj = wo['vessel'];
      final projVesselObj = projMap?['vessel'];
      final projVesselId = projMap != null
          ? _pickStr(projMap, const ['vesselId', 'vessel_id'])
          : null;
      final assetVesselObj = assetMap?['vessel'];
      final assetVesselId = assetMap != null
          ? _pickStr(assetMap, const ['vesselId', 'vessel_id'])
          : null;

      final vesselName =
          _pickStr(wo, const ['vesselName', 'vessel_name', 'boatName', 'boat_name']) ??
          (directVesselObj is Map
              ? _pickStr(Map<String, dynamic>.from(directVesselObj), const [
                  'name',
                  'vesselName',
                  'title',
                ])
              : null) ??
          (vesselId != null ? vesselNameById[vesselId] : null) ??
          (projMap != null
              ? _pickStr(projMap, const ['vesselName', 'vessel_name'])
              : null) ??
          (projVesselObj is Map
              ? _pickStr(Map<String, dynamic>.from(projVesselObj), const [
                  'name',
                  'vesselName',
                ])
              : null) ??
          (projVesselId != null ? vesselNameById[projVesselId] : null) ??
          (assetVesselObj is Map
              ? _pickStr(Map<String, dynamic>.from(assetVesselObj), const [
                  'name',
                  'vesselName',
                ])
              : null) ??
          (assetVesselId != null ? vesselNameById[assetVesselId] : null) ??
          (assetMap != null
              ? _pickStr(assetMap, const ['name', 'assetName', 'title'])
              : null);

      final location = _pickStr(wo, const ['location', 'siteName', 'site_name']);

      final rawAssignedTo = wo['assignedTo'] ?? wo['assigned_to'];
      final techInfo = _parseTechnicians(wo, userIds, nameTokens);
      final assignedObj =
          (rawAssignedTo is Map ? rawAssignedTo : null) ??
          wo['assignedToUser'] ??
          wo['assigned_to_user'] ??
          wo['assignee'] ??
          wo['assignedUser'] ??
          wo['technician'] ??
          wo['user'];
      final directAssigneeId =
          (rawAssignedTo is String && rawAssignedTo.trim().isNotEmpty
              ? rawAssignedTo.trim()
              : null) ??
          _pickStr(wo, const [
            'assignedToId',
            'assigned_to_id',
            'assigneeId',
            'assignee_id',
            'technicianId',
            'technician_id',
          ]) ??
          (assignedObj is Map ? assignedObj['id']?.toString() : null);

      final isMine = myAssignedOrderIds.contains(id) ||
          techInfo.isMine ||
          (directAssigneeId != null && userIds.contains(directAssigneeId));

      final directAssigneeName =
          (techInfo.names.isNotEmpty ? techInfo.names.join(', ') : null) ??
          _pickStr(wo, const [
            'assignedToName',
            'assigned_to_name',
            'assigneeName',
            'assignee_name',
            'technicianName',
            'technician_name',
            'userName',
            'user_name',
          ]) ??
          (assignedObj is Map
              ? _pickStr(Map<String, dynamic>.from(assignedObj), const [
                  'name',
                  'fullName',
                  'full_name',
                  'displayName',
                  'username',
                ])
              : null) ??
          assignedNameByOrder[id] ??
          (isMine && currentUserName != null && currentUserName.isNotEmpty
              ? currentUserName
              : null);

      final job = TechnicianJob(
        id: id,
        jobCode: code,
        title: title,
        description: desc,
        status: status,
        priority: priority,
        jobSource: 'work_order',
        projectId: projectId,
        projectName: projectName,
        vesselName: vesselName,
        location: location,
        isMine: isMine,
        assignedToName: directAssigneeName,
        scheduleStart: _pickStr(wo, const [
          'scheduleStart',
          'schedule_start',
          'scheduledStart',
          'scheduled_start',
          'startDate',
          'start_date',
          'scheduledDate',
          'scheduled_date',
          'dueDate',
          'due_date',
        ]),
        scheduleEnd: _pickStr(wo, const [
          'scheduleEnd',
          'schedule_end',
          'scheduledEnd',
          'scheduled_end',
          'endDate',
          'end_date',
        ]),
      );
      orderById[id] = job;
      jobs.add(job);
    }

    // Sort: user's open jobs first, then user's completed, then other jobs
    jobs.sort((a, b) {
      if (a.isMine != b.isMine) return a.isMine ? -1 : 1;
      final aDone = a.status == 'completed' || a.status == 'closed';
      final bDone = b.status == 'completed' || b.status == 'closed';
      if (aDone != bDone) return aDone ? 1 : -1;
      return a.jobCode.compareTo(b.jobCode);
    });

    // Map submitted report session IDs and workOrderIds
    final reportedSessionIds = <String>{};
    final reportedWorkOrderIds = <String>{};
    for (final r in rawReports) {
      final sid = _pickStr(r, const ['workSessionId', 'work_session_id', 'sessionId']);
      if (sid != null) reportedSessionIds.add(sid);
      final woid = _pickStr(r, const ['workOrderId', 'work_order_id', 'jobId']);
      if (woid != null) reportedWorkOrderIds.add(woid);
    }

    // Parse sessions belonging to current user
    TechnicianWorkSession? activeSession;
    TechnicianWorkSession? breakSession;
    TechnicianWorkSession? pendingReportSession;
    final todaySessions = <TechnicianWorkSession>[];
    final latestReportedByOrder = <String, TechnicianWorkSession>{};

    for (final s in rawSessions) {
      final sid = _pickStr(s, const ['id']);
      if (sid == null) continue;
      final sEmpId = _pickStr(s, const [
        'teamMemberId',
        'team_member_id',
        'employeeId',
        'employee_id',
        'userId',
        'user_id',
        'technicianId',
        'technician_id',
      ]);
      if (sEmpId != null && userIds.isNotEmpty && !userIds.contains(sEmpId)) {
        continue;
      }
      final woId =
          _pickStr(s, const ['workOrderId', 'work_order_id', 'jobId']) ?? '';
      final woObj = s['workOrder'] ?? s['work_order'];
      final matchedJob = orderById[woId];
      final jobCode =
          matchedJob?.jobCode ??
          (woObj is Map
              ? _pickStr(Map<String, dynamic>.from(woObj), const [
                  'workOrderNumber',
                  'work_order_number',
                  'jobCode',
                  'code',
                ])
              : null) ??
          'JOB';
      final jobTitle =
          matchedJob?.title ??
          (woObj is Map
              ? _pickStr(Map<String, dynamic>.from(woObj), const ['title', 'name'])
              : null) ??
          '';
      final checkInAt =
          _pickStr(s, const ['checkInAt', 'check_in_at', 'startedAt', 'createdAt']) ??
          '';
      final checkOutAt =
          _pickStr(s, const ['checkOutAt', 'check_out_at', 'endedAt']);
      final status = (_pickStr(s, const ['status']) ??
              (checkOutAt == null ? 'active' : 'completed'))
          .toLowerCase();
      final jobStatusAtCheckout = _pickStr(s, const [
        'jobStatusAtCheckout',
        'job_status_at_checkout',
        'checkoutStatus',
      ]);
      final reportSubmitted = reportedSessionIds.contains(sid);

      final parsed = TechnicianWorkSession(
        id: sid,
        jobId: woId,
        jobCode: jobCode,
        jobTitle: jobTitle,
        vesselName: matchedJob?.vesselName,
        status: status,
        checkInAt: checkInAt,
        checkOutAt: checkOutAt,
        durationMinutes: _pickDouble(s, const [
          'durationMinutes',
          'duration_minutes',
        ]),
        checkInLatitude: _pickDouble(s, const [
          'checkInLatitude',
          'check_in_latitude',
          'latitude',
        ]),
        checkInLongitude: _pickDouble(s, const [
          'checkInLongitude',
          'check_in_longitude',
          'longitude',
        ]),
        checkOutLatitude: _pickDouble(s, const [
          'checkOutLatitude',
          'check_out_latitude',
        ]),
        checkOutLongitude: _pickDouble(s, const [
          'checkOutLongitude',
          'check_out_longitude',
        ]),
        jobStatusAtCheckout: jobStatusAtCheckout,
        notes: _pickStr(s, const ['notes']),
        reportSubmitted: reportSubmitted,
      );

      if (parsed.isActive) {
        activeSession ??= parsed;
      } else if (reportSubmitted && woId.isNotEmpty) {
        final existing = latestReportedByOrder[woId];
        final currentStamp = checkOutAt ?? checkInAt;
        final existingStamp = existing == null
            ? ''
            : (existing.checkOutAt ?? existing.checkInAt);
        if (existing == null || currentStamp.compareTo(existingStamp) >= 0) {
          latestReportedByOrder[woId] = parsed;
        }
      }
      if (_isTodayIso(checkInAt)) {
        todaySessions.add(parsed);
        if (!parsed.isActive && jobStatusAtCheckout == 'on_break') {
          breakSession ??= parsed;
        } else if (!parsed.isActive && !reportSubmitted) {
          pendingReportSession ??= parsed;
        }
      }
    }

    if (activeSession != null) {
      breakSession = null;
    }

    final visibleJobs = <TechnicianJob>[];
    for (final job in jobs) {
      if (job.isClosedOnBackend) continue;
      final latestReported = latestReportedByOrder[job.id];
      final hasReport =
          latestReported != null || reportedWorkOrderIds.contains(job.id);
      if (hasReport) {
        final checkoutStatus =
            latestReported?.jobStatusAtCheckout?.toLowerCase() ?? 'completed';
        final nextStatus =
            (checkoutStatus == 'in_progress' && job.status == 'open')
                ? 'in_progress'
                : job.status;
        visibleJobs.add(
          job.copyWith(
            status: nextStatus,
            reportSubmitted: true,
            lastCheckoutStatus: checkoutStatus,
          ),
        );
      } else {
        visibleJobs.add(job);
      }
    }

    visibleJobs.sort((a, b) {
      if (a.isSubmittedAwaitingClose != b.isSubmittedAwaitingClose) {
        return a.isSubmittedAwaitingClose ? 1 : -1;
      }
      if (a.isMine != b.isMine) return a.isMine ? -1 : 1;
      return a.jobCode.compareTo(b.jobCode);
    });

    final workDate =
        attStatus['currentWorkDate']?.toString() ?? _todayDateStr();
    final nextWindow = attStatus['currentWindowCode']?.toString() ??
        (todaySessions.isEmpty ? 'morning_in' : 'afternoon_in');

    return TechnicianDashboardData(
      workDate: workDate,
      jobs: visibleJobs,
      activeSession: activeSession,
      breakSession: breakSession,
      pendingReportSession: pendingReportSession,
      todaySessions: todaySessions,
      completedWindows: const <String>{},
      nextWindowCode: nextWindow,
    );
  }

  static Future<TechnicianJob?> getJobDetail(
    String jobId, {
    TechnicianJob? fallback,
  }) async {
    if (isUsingMockOverride || jobId.isEmpty) return fallback;
    final client = createApiClient();
    try {
      final headers = await _authHeaders();
      final res = await client
          .get(
            Uri.parse('${AuthService.baseUrl}/work-orders/$jobId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode < 200 || res.statusCode >= 300) return fallback;
      final decoded = _decodeJson(res);
      final raw = decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'] as Map)
          : decoded;
      if (raw.isEmpty) return fallback;

      final user = await AuthService.getSavedUser();
      final currentUserName = user?['name']?.toString().trim();
      final userIds = await _currentUserIds();
      final nameTokens = await _currentUserNameTokens();
      final techInfo = _parseTechnicians(raw, userIds, nameTokens);

      final rawAssignedTo = raw['assignedTo'] ?? raw['assigned_to'];
      final assignedObj =
          (rawAssignedTo is Map ? rawAssignedTo : null) ??
          raw['assignedToUser'] ??
          raw['assigned_to_user'] ??
          raw['assignee'] ??
          raw['assignedUser'] ??
          raw['technician'] ??
          raw['user'];

      String? embeddedAssigneeName;
      bool embeddedIsMine = false;
      for (final embedKey in const [
        'assignments',
        'workAssignments',
        'work_assignments',
      ]) {
        final list = raw[embedKey];
        if (list is List) {
          for (final item in list.whereType<Map>()) {
            final m = Map<String, dynamic>.from(item);
            final uObj = m['user'] ?? m['employee'] ?? m['technician'];
            final uid =
                _pickStr(m, const ['userId', 'user_id', 'employeeId', 'employee_id']) ??
                (uObj is Map ? uObj['id']?.toString() : null);
            if (uid != null && userIds.contains(uid)) {
              embeddedIsMine = true;
            }
            embeddedAssigneeName ??=
                _pickStr(m, const [
                  'userName',
                  'user_name',
                  'employeeName',
                  'employee_name',
                  'technicianName',
                ]) ??
                (uObj is Map
                    ? _pickStr(Map<String, dynamic>.from(uObj), const [
                        'name',
                        'fullName',
                        'full_name',
                        'displayName',
                        'username',
                      ])
                    : null);
          }
        }
      }

      final directAssigneeId =
          (rawAssignedTo is String && rawAssignedTo.trim().isNotEmpty
              ? rawAssignedTo.trim()
              : null) ??
          _pickStr(raw, const [
            'assignedToId',
            'assigned_to_id',
            'assigneeId',
            'assignee_id',
            'technicianId',
            'technician_id',
          ]) ??
          (assignedObj is Map ? assignedObj['id']?.toString() : null);

      final isMine =
          (fallback?.isMine ?? false) ||
          embeddedIsMine ||
          techInfo.isMine ||
          (directAssigneeId != null && userIds.contains(directAssigneeId));

      final assignedToName =
          (techInfo.names.isNotEmpty ? techInfo.names.join(', ') : null) ??
          _pickStr(raw, const [
            'assignedToName',
            'assigned_to_name',
            'assigneeName',
            'assignee_name',
            'technicianName',
            'technician_name',
            'userName',
            'user_name',
          ]) ??
          (assignedObj is Map
              ? _pickStr(Map<String, dynamic>.from(assignedObj), const [
                  'name',
                  'fullName',
                  'full_name',
                  'displayName',
                  'username',
                ])
              : null) ??
          embeddedAssigneeName ??
          fallback?.assignedToName ??
          (isMine && currentUserName != null && currentUserName.isNotEmpty
              ? currentUserName
              : null);

      final vesselObj = raw['vessel'] ?? raw['site'] ?? raw['project'];
      final location =
          _pickStr(raw, const [
            'location',
            'siteName',
            'site_name',
            'vesselName',
            'vessel_name',
          ]) ??
          (vesselObj is Map
              ? _pickStr(Map<String, dynamic>.from(vesselObj), const [
                  'name',
                  'title',
                  'location',
                ])
              : null) ??
          fallback?.location;

      final desc =
          _pickStr(raw, const [
            'description',
            'notes',
            'details',
            'scope',
            'summary',
            'remarks',
          ]) ??
          fallback?.description ??
          '';

      final resolvedVesselName =
          _pickStr(raw, const [
            'vesselName',
            'vessel_name',
            'boatName',
            'boat_name',
          ]) ??
          (raw['vessel'] is Map
              ? _pickStr(
                  Map<String, dynamic>.from(raw['vessel'] as Map),
                  const ['name', 'vesselName', 'title'],
                )
              : null) ??
          fallback?.vesselName;

      final rawVesselMap = raw['vessel'] is Map
          ? Map<String, dynamic>.from(raw['vessel'] as Map)
          : <String, dynamic>{};
      final rawAssetMap = raw['asset'] is Map
          ? Map<String, dynamic>.from(raw['asset'] as Map)
          : (raw['equipment'] is Map
                ? Map<String, dynamic>.from(raw['equipment'] as Map)
                : <String, dynamic>{});
      final vesselId =
          _pickStr(raw, const ['vesselId', 'vessel_id']) ??
          _pickStr(rawVesselMap, const ['id']);
      final assetId =
          _pickStr(raw, const [
            'assetId',
            'asset_id',
            'equipmentId',
            'equipment_id',
          ]) ??
          _pickStr(rawAssetMap, const ['id']);

      final vesselAndAsset = await Future.wait<List<Map<String, dynamic>>>([
        _safeGetList(client, headers, '/vessels'),
        _safeGetList(client, headers, '/assets'),
      ]);
      final vessels = vesselAndAsset[0];
      final assets = vesselAndAsset[1];

      Map<String, dynamic> matchedVessel = {...rawVesselMap};
      for (final v in vessels) {
        final vid = _pickStr(v, const ['id']);
        final vName = _pickStr(v, const ['name', 'vesselName', 'title']);
        final idMatch = vesselId != null && vid == vesselId;
        final nameMatch =
            resolvedVesselName != null &&
            vName != null &&
            vName.toLowerCase() == resolvedVesselName.toLowerCase();
        if (idMatch || nameMatch) {
          matchedVessel = {...v, ...matchedVessel};
          break;
        }
      }

      Map<String, dynamic> matchedAsset = {...rawAssetMap};
      for (final a in assets) {
        final aid = _pickStr(a, const ['id']);
        final aVesselId = _pickStr(a, const ['vesselId', 'vessel_id']);
        if (assetId != null && aid == assetId) {
          matchedAsset = {...a, ...matchedAsset};
          break;
        }
        if (assetId == null &&
            vesselId != null &&
            aVesselId == vesselId &&
            matchedAsset.isEmpty) {
          matchedAsset = {...a};
        }
      }

      return TechnicianJob(
        id: fallback?.id ?? jobId,
        jobCode:
            _pickStr(raw, const [
              'number',
              'workOrderNumber',
              'work_order_number',
              'jobCode',
              'job_code',
              'code',
            ]) ??
            fallback?.jobCode ??
            'JOB',
        title:
            _pickStr(raw, const ['title', 'name', 'subject']) ??
            fallback?.title ??
            '',
        description: desc,
        status:
            (_pickStr(raw, const ['status']) ?? fallback?.status ?? 'open')
                .toLowerCase(),
        priority:
            (_pickStr(raw, const [
                      'priority',
                      'priorityLevel',
                      'priority_level',
                      'urgency',
                    ]) ??
                    fallback?.priority ??
                    'medium')
                .toLowerCase(),
        jobSource: fallback?.jobSource ?? 'work_order',
        projectId:
            _pickStr(raw, const ['projectId', 'project_id']) ??
            fallback?.projectId,
        projectName:
            _pickStr(raw, const ['projectName', 'project_name']) ??
            (raw['project'] is Map
                ? _pickStr(
                    Map<String, dynamic>.from(raw['project'] as Map),
                    const ['name', 'title', 'projectName'],
                  )
                : null) ??
            fallback?.projectName,
        vesselName:
            resolvedVesselName ??
            _pickStr(matchedVessel, const ['name', 'vesselName', 'title']),
        location: location,
        isMine: isMine,
        assignedToName: assignedToName,
        scheduleStart:
            _pickStr(raw, const [
              'scheduleStart',
              'schedule_start',
              'scheduledStart',
              'scheduled_start',
              'startDate',
              'start_date',
              'scheduledDate',
              'scheduled_date',
              'dueDate',
              'due_date',
            ]) ??
            fallback?.scheduleStart,
        scheduleEnd:
            _pickStr(raw, const [
              'scheduleEnd',
              'schedule_end',
              'scheduledEnd',
              'scheduled_end',
              'endDate',
              'end_date',
            ]) ??
            fallback?.scheduleEnd,
        reportSubmitted: fallback?.reportSubmitted ?? false,
        lastCheckoutStatus: fallback?.lastCheckoutStatus,
        vesselType:
            _pickStr(matchedVessel, const [
              'vesselType',
              'vessel_type',
              'type',
              'category',
            ]) ??
            fallback?.vesselType,
        vesselRegistration:
            _pickStr(matchedVessel, const [
              'registrationNumber',
              'registration_number',
              'imoNumber',
              'imo_number',
              'hullNumber',
              'hull_number',
              'registration',
              'code',
            ]) ??
            fallback?.vesselRegistration,
        vesselModel:
            _pickStr(matchedVessel, const [
              'model',
              'make',
              'builder',
              'manufacturer',
            ]) ??
            fallback?.vesselModel,
        assetName:
            _pickStr(matchedAsset, const [
              'name',
              'title',
              'assetName',
              'asset_name',
            ]) ??
            fallback?.assetName,
        assetModel:
            _pickStr(matchedAsset, const [
              'model',
              'make',
              'manufacturer',
              'brand',
            ]) ??
            fallback?.assetModel,
        assetSerial:
            _pickStr(matchedAsset, const [
              'serialNumber',
              'serial_number',
              'assetCode',
              'asset_code',
              'code',
            ]) ??
            fallback?.assetSerial,
        assetCategory:
            _pickStr(matchedAsset, const [
              'category',
              'assetType',
              'asset_type',
              'type',
            ]) ??
            fallback?.assetCategory,
      );
    } catch (_) {
      return fallback;
    } finally {
      client.close();
    }
  }

  static Future<TechnicianDashboardData> getMyJobs() async {
    if (getMyJobsOverride != null) {
      final data = await getMyJobsOverride!();
      lastDashboardData = data;
      return data;
    }

    final client = createApiClient();
    try {
      final headers = await _authHeaders();
      final res = await client
          .get(
            Uri.parse('${AuthService.baseUrl}/technician/my-jobs'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 404) {
        final data = await _getMyJobsFromNestApi(client, headers);
        lastDashboardData = data;
        return data;
      }
      final body = _decodeJson(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = TechnicianDashboardData.fromJson(body);
        lastDashboardData = data;
        return data;
      }
      throw TechnicianApiException(
        statusCode: res.statusCode,
        message: body['message']?.toString() ?? 'Failed to load assigned jobs.',
      );
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> checkIn({
    required String jobId,
    required String jobSource,
    required String windowCode,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? photoStorageKey,
    String? notes,
  }) async {
    if (checkInOverride != null) {
      final res = await checkInOverride!(
        jobId: jobId,
        jobSource: jobSource,
        windowCode: windowCode,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        photoStorageKey: photoStorageKey,
        notes: notes,
      );
      AttendanceService.attendanceUpdatedNotifier.value++;
      return res;
    }

    final client = createApiClient();
    try {
      final headers = await _authHeaders();
      final res = await client
          .post(
            Uri.parse('${AuthService.baseUrl}/technician/check-in'),
            headers: headers,
            body: jsonEncode({
              'jobId': jobId,
              'jobSource': jobSource,
              'windowCode': windowCode,
              'latitude': latitude,
              'longitude': longitude,
              'accuracy': accuracy,
              'photoStorageKey': photoStorageKey,
              'notes': notes,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 404) {
        return await _checkInViaNestApi(
          client: client,
          headers: headers,
          jobId: jobId,
          latitude: latitude,
          longitude: longitude,
          accuracy: accuracy,
          photoStorageKey: photoStorageKey,
          notes: notes,
        );
      }
      final body = _decodeJson(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        AttendanceService.attendanceUpdatedNotifier.value++;
        return body;
      }
      throw TechnicianApiException(
        statusCode: res.statusCode,
        message: body['message']?.toString() ?? 'Failed to check in.',
      );
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> _checkInViaNestApi({
    required http.Client client,
    required Map<String, String> headers,
    required String jobId,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? photoStorageKey,
    String? notes,
  }) async {
    String? attendanceError;
    try {
      final attRes = await client
          .post(
            Uri.parse('${AuthService.baseUrl}/app-attendance/events'),
            headers: headers,
            body: jsonEncode({
              'clientRequestId': const Uuid().v4(),
              'latitude': ?latitude,
              'longitude': ?longitude,
              'accuracy': ?accuracy,
              if (photoStorageKey != null && photoStorageKey.isNotEmpty)
                'selfieStorageKey': photoStorageKey,
              if (notes != null && notes.isNotEmpty) 'notes': notes,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (attRes.statusCode < 200 || attRes.statusCode >= 300) {
        final attBody = _decodeJson(attRes);
        attendanceError =
            'Attendance (${attRes.statusCode}): ${attBody['message'] ?? attRes.body}';
      }
    } catch (e) {
      attendanceError = 'Attendance error: $e';
    }

    final user = await AuthService.getSavedUser();
    final userId = user?['id']?.toString().trim();
    final teamMemberId =
        (_cachedTeamMemberUserId != null &&
            _cachedTeamMemberUserId == userId &&
            _cachedTeamMemberId != null)
        ? _cachedTeamMemberId
        : userId;
    final gpsNote = (latitude != null && longitude != null)
        ? 'GPS: ${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}'
        : null;
    final combinedNotes = [
      if (notes != null && notes.trim().isNotEmpty) notes.trim(),
      ?gpsNote,
    ].join(' | ');

    final payload = <String, dynamic>{
      'workOrderId': jobId,
      if (teamMemberId != null && teamMemberId.isNotEmpty)
        'teamMemberId': teamMemberId,
      if (userId != null && userId.isNotEmpty) 'createdBy': userId,
      if (combinedNotes.isNotEmpty) 'notes': combinedNotes,
    };

    var res = await client
        .post(
          Uri.parse('${AuthService.baseUrl}/work-sessions'),
          headers: headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 404) {
      res = await client
          .post(
            Uri.parse('${AuthService.baseUrl}/work-sessions/check-in'),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));
    }
    final body = _decodeJson(res);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final sessionMsg =
          body['message']?.toString() ?? 'Failed to check in to work session.';
      throw TechnicianApiException(
        statusCode: res.statusCode,
        message: attendanceError != null
            ? '$attendanceError | $sessionMsg'
            : sessionMsg,
      );
    }

    AttendanceService.attendanceUpdatedNotifier.value++;
    return {'session': body['data'] ?? body};
  }

  static Future<Map<String, dynamic>> checkOut({
    required String sessionId,
    required String windowCode,
    String jobStatus = 'in_progress',
    double? latitude,
    double? longitude,
    double? accuracy,
    String? photoStorageKey,
    String? notes,
  }) async {
    if (checkOutOverride != null) {
      final res = await checkOutOverride!(
        sessionId: sessionId,
        windowCode: windowCode,
        jobStatus: jobStatus,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        photoStorageKey: photoStorageKey,
        notes: notes,
      );
      AttendanceService.attendanceUpdatedNotifier.value++;
      return res;
    }

    final client = createApiClient();
    try {
      final headers = await _authHeaders();
      final res = await client
          .post(
            Uri.parse('${AuthService.baseUrl}/technician/check-out'),
            headers: headers,
            body: jsonEncode({
              'sessionId': sessionId,
              'windowCode': windowCode,
              'jobStatus': jobStatus,
              'latitude': latitude,
              'longitude': longitude,
              'accuracy': accuracy,
              'photoStorageKey': photoStorageKey,
              'notes': notes,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 404) {
        return await _closeSessionViaNestApi(
          client: client,
          headers: headers,
          sessionId: sessionId,
          jobStatus: jobStatus,
          latitude: latitude,
          longitude: longitude,
          accuracy: accuracy,
          photoStorageKey: photoStorageKey,
          notes: notes,
          recordAttendance: true,
        );
      }
      final body = _decodeJson(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        AttendanceService.attendanceUpdatedNotifier.value++;
        return body;
      }
      throw TechnicianApiException(
        statusCode: res.statusCode,
        message: body['message']?.toString() ?? 'Failed to check out.',
      );
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> _closeSessionViaNestApi({
    required http.Client client,
    required Map<String, String> headers,
    required String sessionId,
    required String jobStatus,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? photoStorageKey,
    String? notes,
    required bool recordAttendance,
  }) async {
    final gpsNote = (latitude != null && longitude != null)
        ? 'GPS: ${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}'
        : null;
    final combinedNotes = [
      if (notes != null && notes.trim().isNotEmpty) notes.trim(),
      ?gpsNote,
    ].join(' | ');
    final actionPayload = <String, dynamic>{
      if (combinedNotes.isNotEmpty) 'notes': combinedNotes,
    };
    final actionPath = jobStatus == 'on_break'
        ? '/work-sessions/$sessionId/break'
        : '/work-sessions/$sessionId/check-out';

    var res = await client
        .post(
          Uri.parse('${AuthService.baseUrl}$actionPath'),
          headers: headers,
          body: jsonEncode(actionPayload),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 404 || res.statusCode == 405) {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final patchPayload = <String, dynamic>{
        'status': 'completed',
        'checkOutAt': nowIso,
        'jobStatusAtCheckout': jobStatus,
        'checkOutLatitude': ?latitude,
        'checkOutLongitude': ?longitude,
        if (combinedNotes.isNotEmpty) 'notes': combinedNotes,
      };
      res = await client
          .patch(
            Uri.parse('${AuthService.baseUrl}/work-sessions/$sessionId'),
            headers: headers,
            body: jsonEncode(patchPayload),
          )
          .timeout(const Duration(seconds: 20));
    }
    final body = _decodeJson(res);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw TechnicianApiException(
        statusCode: res.statusCode,
        message: body['message']?.toString() ?? 'Failed to update work session.',
      );
    }

    if (jobStatus != 'on_break') {
      try {
        await _confirmJobStatusViaNestApi(
          client: client,
          headers: headers,
          sessionId: sessionId,
          jobStatus: jobStatus,
        );
      } catch (_) {}
    }

    if (recordAttendance) {
      try {
        await client
            .post(
              Uri.parse('${AuthService.baseUrl}/app-attendance/events'),
              headers: headers,
              body: jsonEncode({
                'clientRequestId': const Uuid().v4(),
                'latitude': ?latitude,
                'longitude': ?longitude,
                'accuracy': ?accuracy,
                if (photoStorageKey != null && photoStorageKey.isNotEmpty)
                  'selfieStorageKey': photoStorageKey,
                if (notes != null && notes.isNotEmpty) 'notes': notes,
              }),
            )
            .timeout(const Duration(seconds: 15));
      } catch (_) {}
    }

    AttendanceService.attendanceUpdatedNotifier.value++;
    return {'session': body['data'] ?? body};
  }

  static Future<void> _confirmJobStatusViaNestApi({
    required http.Client client,
    required Map<String, String> headers,
    required String sessionId,
    required String jobStatus,
  }) async {
    final uri = Uri.parse(
      '${AuthService.baseUrl}/work-sessions/$sessionId/confirm-job-status',
    );
    final candidates = <Map<String, dynamic>>[
      {'jobStatus': jobStatus},
      {'status': jobStatus},
      {'jobStatusAtCheckout': jobStatus},
      {'isCompleted': jobStatus == 'completed'},
      {'completed': jobStatus == 'completed'},
      <String, dynamic>{},
    ];
    TechnicianApiException? lastError;
    for (final payload in candidates) {
      final res = await client
          .post(uri, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return;
      }
      final body = _decodeJson(res);
      lastError = TechnicianApiException(
        statusCode: res.statusCode,
        message:
            body['message']?.toString() ?? 'Failed to confirm job status.',
      );
    }
    if (lastError != null) {
      throw TechnicianApiException(
        statusCode: lastError.statusCode,
        message: 'confirm-job-status (${lastError.statusCode}): ${lastError.message}',
      );
    }
  }

  static Future<Map<String, dynamic>> submitReport({
    required String sessionId,
    required String workDescription,
    String workType = 'service',
    String? findings,
    String? recommendations,
    List<String> photos = const [],
    String? workOrderId,
    String? projectId,
  }) async {
    if (submitReportOverride != null) {
      return submitReportOverride!(
        sessionId: sessionId,
        workDescription: workDescription,
        workType: workType,
        findings: findings,
        recommendations: recommendations,
        photos: photos,
      );
    }

    final client = createApiClient();
    try {
      final headers = await _authHeaders();
      final res = await client
          .post(
            Uri.parse('${AuthService.baseUrl}/technician/reports'),
            headers: headers,
            body: jsonEncode({
              'sessionId': sessionId,
              'workDescription': workDescription,
              'workType': workType,
              'findings': findings,
              'recommendations': recommendations,
              'photos': photos,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 404) {
        final user = await AuthService.getSavedUser();
        final userId = user?['id']?.toString().trim();
        final formattedDesc = [
          workDescription.trim(),
          if (findings != null && findings.trim().isNotEmpty)
            '[ปัญหาที่พบ / Issues]\n${findings.trim()}',
          if (recommendations != null && recommendations.trim().isNotEmpty)
            '[งานค้างต่อ / Recommendations]\n${recommendations.trim()}',
        ].join('\n\n');

        final reportPayload = jsonEncode({
          if (sessionId.isNotEmpty) 'workSessionId': sessionId,
          if (workOrderId != null && workOrderId.isNotEmpty)
            'workOrderId': workOrderId,
          if (userId != null && userId.isNotEmpty) 'technicianId': userId,
          'workDescription': formattedDesc,
          'workType': workType,
          'photos': photos,
          'status': 'submitted',
        });

        var nestRes = await client
            .post(
              Uri.parse('${AuthService.baseUrl}/technician-reports'),
              headers: headers,
              body: reportPayload,
            )
            .timeout(const Duration(seconds: 20));
        var nestBody = _decodeJson(nestRes);
        final errText = (nestBody['message'] ?? '').toString().toLowerCase();
        if (nestRes.statusCode >= 400 &&
            nestRes.statusCode < 500 &&
            sessionId.isNotEmpty &&
            errText.contains('confirm the job status')) {
          await _confirmJobStatusViaNestApi(
            client: client,
            headers: headers,
            sessionId: sessionId,
            jobStatus: 'completed',
          );
          nestRes = await client
              .post(
                Uri.parse('${AuthService.baseUrl}/technician-reports'),
                headers: headers,
                body: reportPayload,
              )
              .timeout(const Duration(seconds: 20));
          nestBody = _decodeJson(nestRes);
        }
        if (nestRes.statusCode >= 200 && nestRes.statusCode < 300) {
          return {'report': nestBody['data'] ?? nestBody};
        }
        throw TechnicianApiException(
          statusCode: nestRes.statusCode,
          message:
              nestBody['message']?.toString() ?? 'Failed to submit work report.',
        );
      }
      final body = _decodeJson(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return body;
      }
      throw TechnicianApiException(
        statusCode: res.statusCode,
        message: body['message']?.toString() ?? 'Failed to submit work report.',
      );
    } finally {
      client.close();
    }
  }

  static Future<TechnicianHistoryResponse> getHistory() async {
    if (getHistoryOverride != null) return getHistoryOverride!();

    final client = createApiClient();
    try {
      final headers = await _authHeaders();
      final res = await client
          .get(
            Uri.parse('${AuthService.baseUrl}/technician/history'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 404) {
        return await _getHistoryFromNestApi(client, headers);
      }
      final body = _decodeJson(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final rawItems = body['items'];
        final items = rawItems is List
            ? rawItems
                .whereType<Map>()
                .map(
                  (m) => TechnicianHistoryItem.fromJson(
                    Map<String, dynamic>.from(m),
                  ),
                )
                .toList(growable: false)
            : const <TechnicianHistoryItem>[];
        return TechnicianHistoryResponse(
          isAdmin: body['isAdmin'] == true,
          items: items,
        );
      }
      throw TechnicianApiException(
        statusCode: res.statusCode,
        message: body['message']?.toString() ?? 'Failed to load job history.',
      );
    } finally {
      client.close();
    }
  }

  static Future<TechnicianHistoryResponse> _getHistoryFromNestApi(
    http.Client client,
    Map<String, String> headers,
  ) async {
    final userIds = await _currentUserIds();
    final roles = await AuthService.getSavedRoles();
    final isAdmin = roles.any((r) => r.trim().toLowerCase() == 'admin');

    final results = await Future.wait<List<Map<String, dynamic>>>([
      _safeGetList(client, headers, '/work-sessions'),
      _safeGetList(client, headers, '/technician-reports'),
      _safeGetList(client, headers, '/work-orders'),
    ]);
    final rawSessions = results[0];
    final rawReports = results[1];
    final rawOrders = results[2];

    final orderMap = <String, Map<String, dynamic>>{};
    for (final o in rawOrders) {
      final id = _pickStr(o, const ['id']);
      if (id != null) orderMap[id] = o;
    }

    final reportBySession = <String, Map<String, dynamic>>{};
    for (final r in rawReports) {
      final sid = _pickStr(r, const ['workSessionId', 'work_session_id', 'sessionId']);
      if (sid != null) reportBySession[sid] = r;
    }

    final items = <TechnicianHistoryItem>[];
    for (final s in rawSessions) {
      final sid = _pickStr(s, const ['id']);
      if (sid == null) continue;
      final sEmpId = _pickStr(s, const [
        'teamMemberId',
        'team_member_id',
        'employeeId',
        'employee_id',
        'userId',
        'user_id',
      ]);
      final isMine = sEmpId == null || userIds.contains(sEmpId);
      if (!isAdmin && !isMine) continue;

      final woId = _pickStr(s, const ['workOrderId', 'work_order_id', 'jobId']);
      final wo = woId != null ? orderMap[woId] : null;
      final rep = reportBySession[sid];
      final rawPhotos = rep?['photos'];
      final photoCount = rawPhotos is List ? rawPhotos.length : 0;

      items.add(
        TechnicianHistoryItem(
          sessionId: sid,
          technicianName:
              _pickStr(s, const ['employeeName', 'technicianName']) ??
              'Technician',
          isMine: isMine,
          jobCode:
              (wo != null
                  ? _pickStr(wo, const [
                      'number',
                      'workOrderNumber',
                      'work_order_number',
                      'jobCode',
                      'code',
                    ])
                  : null) ??
              'JOB',
          jobTitle:
              (wo != null ? _pickStr(wo, const ['title', 'name']) : null) ?? '',
          sessionStatus: _pickStr(s, const ['status']) ?? 'completed',
          checkInAt:
              _pickStr(s, const ['checkInAt', 'check_in_at', 'createdAt']) ?? '',
          checkOutAt: _pickStr(s, const ['checkOutAt', 'check_out_at']),
          durationMinutes: _pickDouble(s, const [
            'durationMinutes',
            'duration_minutes',
          ]),
          jobStatusAtCheckout: _pickStr(s, const [
            'jobStatusAtCheckout',
            'job_status_at_checkout',
          ]),
          hasGps: _pickDouble(s, const ['checkInLatitude', 'check_in_latitude']) !=
              null,
          reportId: rep != null ? _pickStr(rep, const ['id']) : null,
          reportNumber: rep != null
              ? _pickStr(rep, const ['reportNumber', 'report_number'])
              : null,
          workType:
              rep != null ? _pickStr(rep, const ['workType', 'work_type']) : null,
          workDescription: rep != null
              ? _pickStr(rep, const ['workDescription', 'work_description'])
              : null,
          findings: rep != null ? _pickStr(rep, const ['findings']) : null,
          recommendations:
              rep != null ? _pickStr(rep, const ['recommendations']) : null,
          photoCount: photoCount,
          reportStatus: rep != null ? _pickStr(rep, const ['status']) : null,
        ),
      );
    }

    items.sort((a, b) => b.checkInAt.compareTo(a.checkInAt));
    return TechnicianHistoryResponse(isAdmin: isAdmin, items: items);
  }

  static Future<Map<String, dynamic>> startBreak({
    required String sessionId,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? photoStorageKey,
  }) async {
    if (startBreakOverride != null) {
      final res = await startBreakOverride!(
        sessionId: sessionId,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        photoStorageKey: photoStorageKey,
      );
      AttendanceService.attendanceUpdatedNotifier.value++;
      return res;
    }

    final client = createApiClient();
    try {
      final headers = await _authHeaders();
      final res = await client
          .post(
            Uri.parse('${AuthService.baseUrl}/technician/break'),
            headers: headers,
            body: jsonEncode({
              'sessionId': sessionId,
              'latitude': latitude,
              'longitude': longitude,
              'accuracy': accuracy,
              'photoStorageKey': photoStorageKey,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 404) {
        return await _closeSessionViaNestApi(
          client: client,
          headers: headers,
          sessionId: sessionId,
          jobStatus: 'on_break',
          latitude: latitude,
          longitude: longitude,
          accuracy: accuracy,
          photoStorageKey: photoStorageKey,
          recordAttendance: true,
        );
      }
      final body = _decodeJson(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        AttendanceService.attendanceUpdatedNotifier.value++;
        return body;
      }
      throw TechnicianApiException(
        statusCode: res.statusCode,
        message: body['message']?.toString() ?? 'Failed to start break.',
      );
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> endFromBreak({
    required String sessionId,
    String jobStatus = 'in_progress',
  }) async {
    if (endFromBreakOverride != null) {
      return endFromBreakOverride!(
        sessionId: sessionId,
        jobStatus: jobStatus,
      );
    }

    final client = createApiClient();
    try {
      final headers = await _authHeaders();
      final res = await client
          .post(
            Uri.parse('${AuthService.baseUrl}/technician/end-from-break'),
            headers: headers,
            body: jsonEncode({
              'sessionId': sessionId,
              'jobStatus': jobStatus,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 404) {
        return await _closeSessionViaNestApi(
          client: client,
          headers: headers,
          sessionId: sessionId,
          jobStatus: jobStatus,
          recordAttendance: false,
        );
      }
      final body = _decodeJson(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return body;
      }
      throw TechnicianApiException(
        statusCode: res.statusCode,
        message: body['message']?.toString() ?? 'Failed to end shift.',
      );
    } finally {
      client.close();
    }
  }
}
