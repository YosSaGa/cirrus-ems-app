import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/payroll_calculator.dart';

enum LeaveType {
  sick('Sick leave'),
  personal('Personal leave'),
  annual('Annual leave'),
  unpaid('Unpaid leave');

  const LeaveType(this.label);
  final String label;
}

class LeaveDraft {
  const LeaveDraft({
    required this.id,
    required this.type,
    required this.start,
    required this.end,
    required this.reason,
    required this.createdAt,
    this.cancelled = false,
  });
  final String id;
  final LeaveType type;
  final DateTime start;
  final DateTime end;
  final String reason;
  final DateTime createdAt;
  final bool cancelled;
  int get calendarDays =>
      DateTime.utc(
        end.year,
        end.month,
        end.day,
      ).difference(DateTime.utc(start.year, start.month, start.day)).inDays +
      1;
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'start': calendarDate(start),
    'end': calendarDate(end),
    'reason': reason,
    'createdAt': createdAt.toIso8601String(),
    'cancelled': cancelled,
  };
  factory LeaveDraft.fromJson(Map<String, dynamic> data) {
    final start = parseCalendarDate(data['start'] as String);
    final end = parseCalendarDate(data['end'] as String);
    if (start == null ||
        end == null ||
        end.isBefore(start) ||
        (data['reason'] as String).trim().isEmpty ||
        (data['id'] as String).isEmpty) {
      throw const FormatException('Invalid leave draft');
    }
    return LeaveDraft(
      id: data['id'] as String,
      type: LeaveType.values.byName(data['type'] as String),
      start: start,
      end: end,
      reason: data['reason'] as String,
      createdAt: DateTime.parse(data['createdAt'] as String),
      cancelled: data['cancelled'] as bool,
    );
  }
}

/// Local trial records, never submitted to an HR endpoint.
class WorkTrialStore {
  WorkTrialStore(this.userId) {
    if (userId.trim().isEmpty) throw ArgumentError('Please sign in first');
  }
  final String userId;
  static final _writes = <String, Future<void>>{};
  String get _settingsKey => 'ems.workTrial.settings.$userId';
  String get _leavesKey => 'ems.workTrial.leaves.$userId';

  Future<PaySettings?> loadSettings() async {
    final raw = (await SharedPreferences.getInstance()).getString(_settingsKey);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return PaySettings(
        hourlySatang: data['hourlySatang'] as int,
        otMultiplier: (data['otMultiplier'] as num).toDouble(),
        otStartMinute: data['otStartMinute'] as int,
      );
    } catch (_) {
      throw const FormatException(
        'Cannot read pay settings. Your existing data has been preserved.',
      );
    }
  }

  Future<void> saveSettings(PaySettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      _settingsKey,
      jsonEncode({
        'hourlySatang': settings.hourlySatang,
        'otMultiplier': settings.otMultiplier,
        'otStartMinute': settings.otStartMinute,
      }),
    )) {
      throw StateError('Could not save pay settings');
    }
  }

  Future<List<LeaveDraft>> loadLeaves() async {
    final raw = (await SharedPreferences.getInstance()).getString(_leavesKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => LeaveDraft.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw const FormatException(
        'Cannot read local leave drafts. Your existing data has been preserved.',
      );
    }
  }

  Future<void> _updateLeaves(void Function(List<LeaveDraft>) update) {
    final operation = (_writes[userId] ?? Future<void>.value()).then((_) async {
      final drafts = await loadLeaves();
      update(drafts);
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(
        _leavesKey,
        jsonEncode(drafts.map((e) => e.toJson()).toList()),
      )) {
        throw StateError('Could not save the leave draft');
      }
    });
    _writes[userId] = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<LeaveDraft> addLeave({
    required LeaveType type,
    required DateTime start,
    required DateTime end,
    required String reason,
  }) async {
    final from = DateTime(start.year, start.month, start.day);
    final to = DateTime(end.year, end.month, end.day);
    if (to.isBefore(from) ||
        reason.trim().isEmpty ||
        reason.trim().length > 1000) {
      throw ArgumentError('Check the date range and reason.');
    }
    late final LeaveDraft created;
    await _updateLeaves((drafts) {
      if (drafts.any(
        (e) => !e.cancelled && !to.isBefore(e.start) && !from.isAfter(e.end),
      )) {
        throw StateError('An active leave draft already overlaps these dates');
      }
      created = LeaveDraft(
        id: const Uuid().v4(),
        type: type,
        start: from,
        end: to,
        reason: reason.trim(),
        createdAt: DateTime.now().toUtc(),
      );
      drafts.insert(0, created);
    });
    return created;
  }

  Future<void> cancelLeave(String id) => _updateLeaves((drafts) {
    final index = drafts.indexWhere((e) => e.id == id);
    if (index < 0) throw StateError('Leave draft not found');
    final json = drafts[index].toJson()..['cancelled'] = true;
    drafts[index] = LeaveDraft.fromJson(json);
  });
}
