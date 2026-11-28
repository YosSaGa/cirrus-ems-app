import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/payroll_calculator.dart';
import 'api_client_factory.dart';
import 'auth_service.dart';
import 'work_trial_store.dart';

/// Represents a live leave request record returned by `GET /leave` / `POST /leave`.
class LeaveRequestRecord {
  const LeaveRequestRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    this.employeeCode,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.reviewNote,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String? employeeCode;
  final LeaveType leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status; // pending | approved | rejected | cancelled
  final DateTime createdAt;
  final String? reviewNote;

  int get calendarDays =>
      DateTime.utc(
        endDate.year,
        endDate.month,
        endDate.day,
      ).difference(
        DateTime.utc(startDate.year, startDate.month, startDate.day),
      ).inDays +
      1;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';

  /// Converts this live DB record into a [LeaveDraft] for TH/EN PDF export.
  LeaveDraft toLeaveDraft() => LeaveDraft(
    id: id,
    type: leaveType,
    start: startDate,
    end: endDate,
    reason: reason,
    createdAt: createdAt,
    cancelled: isCancelled || isRejected,
  );

  static String? _str(dynamic raw) {
    final s = raw?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static LeaveType _parseLeaveType(String? raw) {
    final lower = (raw ?? '').toLowerCase().trim();
    if (lower.contains('sick')) return LeaveType.sick;
    if (lower.contains('annual') || lower.contains('vacation')) {
      return LeaveType.annual;
    }
    if (lower.contains('unpaid')) return LeaveType.unpaid;
    return LeaveType.personal;
  }

  static DateTime _parseDate(dynamic raw, DateTime fallback) {
    final s = _str(raw);
    if (s == null) return fallback;
    final cal = parseCalendarDate(s.length >= 10 ? s.substring(0, 10) : s);
    if (cal != null) return cal;
    return DateTime.tryParse(s)?.toLocal() ?? fallback;
  }

  factory LeaveRequestRecord.fromJson(Map<String, dynamic> json) {
    final empObj = json['employee'] ?? json['user'] ?? json['teamMember'];
    final empMap = empObj is Map ? Map<String, dynamic>.from(empObj) : null;
    final now = DateTime.now();
    final start = _parseDate(
      json['startDate'] ?? json['start_date'] ?? json['fromDate'] ?? json['from'],
      DateTime(now.year, now.month, now.day),
    );
    final end = _parseDate(
      json['endDate'] ?? json['end_date'] ?? json['toDate'] ?? json['to'],
      start,
    );
    final rawStatus = (_str(json['status']) ?? 'pending').toLowerCase();
    return LeaveRequestRecord(
      id: _str(json['id']) ?? '',
      employeeId:
          _str(json['employeeId'] ?? json['employee_id'] ?? json['userId'] ?? json['user_id']) ??
          (empMap != null ? _str(empMap['id']) : null) ??
          '',
      employeeName:
          _str(json['employeeName'] ?? json['employee_name'] ?? json['userName']) ??
          (empMap != null
              ? _str(empMap['name'] ?? empMap['fullName'] ?? empMap['username'])
              : null) ??
          'Employee',
      employeeCode:
          _str(json['employeeCode'] ?? json['employee_code']) ??
          (empMap != null ? _str(empMap['employeeCode'] ?? empMap['employee_code']) : null),
      leaveType: _parseLeaveType(
        _str(json['leaveType'] ?? json['leave_type'] ?? json['type']),
      ),
      startDate: start,
      endDate: end.isBefore(start) ? start : end,
      reason: _str(json['reason'] ?? json['notes'] ?? json['description']) ?? '-',
      status: rawStatus,
      createdAt:
          DateTime.tryParse(_str(json['createdAt'] ?? json['created_at']) ?? '')
              ?.toLocal() ??
          now,
      reviewNote: _str(
        json['reviewNote'] ??
            json['review_note'] ??
            json['rejectionReason'] ??
            json['rejection_reason'] ??
            json['approverNote'],
      ),
    );
  }
}

/// REST client for live Leave Requests (`GET /leave`, `POST /leave`,
/// `POST /leave/:id/approve`, `POST /leave/:id/reject`).
class LeaveService {
  LeaveService._();

  static http.Client _client = createApiClient();
  static const Duration _timeout = Duration(seconds: 15);

  @visibleForTesting
  static void debugOverrideClient(http.Client client) {
    _client = client;
  }

  @visibleForTesting
  static void debugResetClient() {
    _client = createApiClient();
  }

  @visibleForTesting
  static Future<List<LeaveRequestRecord>> Function({bool onlyMine})?
  getLeavesOverride;

  @visibleForTesting
  static Future<LeaveRequestRecord> Function({
    required LeaveType type,
    required DateTime start,
    required DateTime end,
    required String reason,
  })?
  createLeaveOverride;

  @visibleForTesting
  static Future<void> Function(String id, {String? note})? approveLeaveOverride;

  @visibleForTesting
  static Future<void> Function(String id, {String? reason})? rejectLeaveOverride;

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
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
        for (final key in const ['data', 'items', 'leaves', 'rows', 'results']) {
          final v = decoded[key];
          if (v is List) {
            return v
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList(growable: false);
          }
        }
      }
    } catch (_) {}
    return const <Map<String, dynamic>>[];
  }

  static String? _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final msg = decoded['message'];
        if (msg is List) return msg.join(', ');
        if (msg != null) return msg.toString();
      }
    } catch (_) {}
    return null;
  }

  static Future<List<LeaveRequestRecord>> getLeaveRequests({
    bool onlyMine = false,
  }) async {
    if (getLeavesOverride != null) {
      return getLeavesOverride!(onlyMine: onlyMine);
    }

    final headers = await _headers();
    final res = await _client
        .get(Uri.parse('${AuthService.baseUrl}/leave'), headers: headers)
        .timeout(_timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        _errorMessage(res.body) ??
            'Failed to load leave requests (${res.statusCode}).',
      );
    }
    var records = _extractList(res.body)
        .map(LeaveRequestRecord.fromJson)
        .where((r) => r.id.isNotEmpty)
        .toList();

    if (onlyMine) {
      final user = await AuthService.getSavedUser();
      final myId = user?['id']?.toString().trim();
      final myEmpId = user?['employeeId']?.toString().trim();
      final ids = <String>{
        if (myId != null && myId.isNotEmpty) myId,
        if (myEmpId != null && myEmpId.isNotEmpty) myEmpId,
      };
      if (ids.isNotEmpty) {
        final mine = records.where((r) => ids.contains(r.employeeId)).toList();
        if (mine.isNotEmpty || records.any((r) => r.employeeId.isNotEmpty)) {
          records = mine;
        }
      }
    }

    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  static String _toApiLeaveType(LeaveType type) {
    switch (type) {
      case LeaveType.sick:
        return 'sick';
      case LeaveType.annual:
        return 'annual';
      case LeaveType.unpaid:
        return 'unpaid';
      case LeaveType.personal:
        return 'other';
    }
  }

  static Future<LeaveRequestRecord> submitLeaveRequest({
    required LeaveType type,
    required DateTime start,
    required DateTime end,
    required String reason,
  }) async {
    if (createLeaveOverride != null) {
      return createLeaveOverride!(
        type: type,
        start: start,
        end: end,
        reason: reason,
      );
    }

    final headers = await _headers();
    final user = await AuthService.getSavedUser();
    final userId = user?['id']?.toString().trim();
    final empId = (user?['employeeId'] ?? userId)?.toString().trim();
    final rawDays =
        DateTime.utc(end.year, end.month, end.day)
            .difference(DateTime.utc(start.year, start.month, start.day))
            .inDays +
        1;
    final days = rawDays < 1 ? 1 : rawDays;
    final res = await _client
        .post(
          Uri.parse('${AuthService.baseUrl}/leave'),
          headers: headers,
          body: jsonEncode({
            if (empId != null && empId.isNotEmpty) 'employeeId': empId,
            if (userId != null && userId.isNotEmpty) 'createdBy': userId,
            'type': _toApiLeaveType(type),
            'startDate': calendarDate(start),
            'endDate': calendarDate(end),
            'days': days,
            'reason': reason.trim(),
          }),
        )
        .timeout(_timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        _errorMessage(res.body) ??
            'Failed to submit leave request (${res.statusCode}).',
      );
    }
    final decoded = jsonDecode(res.body);
    final map = decoded is Map && decoded['data'] is Map
        ? Map<String, dynamic>.from(decoded['data'] as Map)
        : (decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{});
    return LeaveRequestRecord.fromJson(map);
  }

  static Future<void> approveLeave(
    String id, {
    String payrollTreatment = 'paid',
    String? note,
  }) async {
    if (approveLeaveOverride != null) {
      return approveLeaveOverride!(id, note: note);
    }
    final headers = await _headers();
    final user = await AuthService.getSavedUser();
    final reviewerId = user?['id']?.toString().trim();
    final res = await _client
        .post(
          Uri.parse('${AuthService.baseUrl}/leave/$id/approve'),
          headers: headers,
          body: jsonEncode({
            'payrollTreatment': payrollTreatment,
            if (reviewerId != null && reviewerId.isNotEmpty)
              'reviewedBy': reviewerId,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          }),
        )
        .timeout(_timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        _errorMessage(res.body) ??
            'Failed to approve leave (${res.statusCode}).',
      );
    }
  }

  static Future<void> rejectLeave(String id, {String? reason}) async {
    if (rejectLeaveOverride != null) {
      return rejectLeaveOverride!(id, reason: reason);
    }
    final headers = await _headers();
    final user = await AuthService.getSavedUser();
    final reviewerId = user?['id']?.toString().trim();
    final res = await _client
        .post(
          Uri.parse('${AuthService.baseUrl}/leave/$id/reject'),
          headers: headers,
          body: jsonEncode({
            if (reviewerId != null && reviewerId.isNotEmpty)
              'reviewedBy': reviewerId,
            if (reason != null && reason.trim().isNotEmpty)
              'reason': reason.trim(),
          }),
        )
        .timeout(_timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        _errorMessage(res.body) ??
            'Failed to reject leave (${res.statusCode}).',
      );
    }
  }
}
