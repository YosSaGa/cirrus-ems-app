import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/payroll_calculator.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_panel.dart';
import '../widgets/empty_note.dart';
import '../widgets/fade_slide_entry.dart';
import '../widgets/shimmer_box.dart';
import '../widgets/status_banner.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/status_chip.dart';
import 'login_screen.dart';

// claude_prompt.txt (v141 -- Monthly Attendance Summary + Scan History;
// v144 -- Flutter History UI: Attendance Summary + Scan History Table;
// v145 -- Daily Scan History: Compact Rows & Expandable Daily Details;
// v146 -- Daily Working Minutes Calculation & Manual Recalculation):
// one History screen, one shared month selector, two independently
// loaded/erroring sections:
//   A. Monthly Attendance Summary -- GET /attendance (hr.attendance_records),
//      via the existing AttendanceService.getAttendanceHistory(). The
//      Present, Leave, Absent, and Overtime metrics come from these records.
//   B. Monthly Scan History -- GET /app-attendance/my-scans
//      (hr.device_scans, counted=true only), via AttendanceService.getMyScans()
//      (unchanged). v145's compact Date/Check In/Check Out row list gains
//      a fourth value, Working Hours (v146 §4 B), and the detail view
//      gains a "Daily Working Hours" section (v146 §4 C). A new
//      `Recalculate` button (v146 §5) re-fetches scan data via the same
//      existing `getMyScans()` call `_loadScans()` already makes -- the
//      working-minutes calculation is a pure function of already-fetched
//      scan data, so refreshing scans also refreshes the monthly total.
// Each section has its own loading/error/empty state and its own retry;
// a failure in one never hides the other's already-loaded data. A
// monotonic per-section "generation" counter discards a response that
// arrives after the user has already navigated to a different month
// (see `_loadSummary`/`_loadScans`), and each section's own loading flag
// blocks a second concurrent request for that section while one is
// already in flight -- unchanged since v141/v143, preserved exactly, per
// v146 §7.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

String _formatCalendarDate(String? raw) {
  if (raw == null) return '-';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return AppStrings.formatShortDate(parsed);
}

// claude_prompt.txt (v144 §5 "Display scan times in local device time"):
// replaces v141's own fixed +07:00 Bangkok-offset formatting for the Scan
// History table specifically -- `DateTime.toLocal()` reads the device's
// actual configured timezone rather than assuming Bangkok, which is the
// behavior this round's task explicitly calls for. (Section A's own
// summary never displayed a time-of-day at all, so it is unaffected.)
// Kept exclusively for DISPLAY -- v146's new business-boundary math
// below deliberately uses a different, Bangkok-fixed convention; see
// `_bangkokMinutesOfDay()`'s own doc comment for why.
String _formatDeviceLocalTime(String? raw) {
  if (raw == null) return '-';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return '-';
  final bangkok = parsed.toUtc().add(const Duration(hours: 7));
  final hour = bangkok.hour.toString().padLeft(2, '0');
  final minute = bangkok.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

// claude_prompt.txt (v141 §2 "Event Label Mapping"; v144 §4; v145 §1 §2):
// the four known `window_code` values (the HR seed in
// `1788513000000-DeviceScansFingerprintModule.ts`, also already displayed
// under these exact labels by AttendanceScreen's own private
// `_windowDisplayInfo` map). Duplicated here (not imported -- that map is
// private to a different screen file) rather than reused. Never guessed
// for an unrecognized or null code -- falls back to the same neutral
// label v141 already established, "Scan Event" (v145 §2 C "preserve the
// existing fallback event label for unknown scan types").
const Map<String, String> _windowCodeLabels = {
  'morning_in': 'Morning In',
  'lunch_out': 'Lunch Out',
  'afternoon_in': 'Afternoon In',
  'leave': 'Leave',
};

String _windowCodeLabel(String? code) {
  if (code == null) return AppStrings.t('Scan Event', 'รายการสแกน');
  final raw = _windowCodeLabels[code];
  if (raw == null) return AppStrings.t('Scan Event', 'รายการสแกน');
  return AppStrings.scanWindowLabel(raw);
}

// claude_prompt.txt (v141 §2): "only when non-null and meaningful" -- a
// value of exactly 0 is not meaningfully late/early/overtime, so only a
// strictly positive number is shown. Mirrors AttendanceScreen's own
// private `_positiveMinutes` exactly (duplicated for the same reason as
// the mapping above). Reused this round for `overTime` too (v144 §3 --
// `overTime` is an integer-minutes column with the same "NULL/non-
// positive means nothing to show" semantics as `lateMinutes`/
// `earlyLeaveMinutes`).
int? _positiveMinutes(dynamic value) {
  if (value is num && value > 0) return value.round();
  return null;
}

// claude_prompt.txt (v146 §3): promoted from v145's own
// `_ScanHistorySection._groupByWorkDateDesc` so both the Monthly
// Attendance Summary's new Working Hours calculation and the Monthly
// Scan History list group the exact same `_scans` list the exact same
// way -- one grouping rule, not two independently-maintained copies.
// Grouping/date-descending ordering themselves are UNCHANGED from
// v144/v145 (v146 §7 "do not change grouping by workDate / date
// ordering").
List<MapEntry<String, List<Map<String, dynamic>>>> _groupScansByWorkDateDesc(
  List<Map<String, dynamic>> scans,
) {
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final scan in scans) {
    final key = scan['workDate']?.toString() ?? '-';
    groups.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(scan);
  }
  final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final key in keys) MapEntry(key, groups[key]!)];
}

// claude_prompt.txt (v145 §3): promoted from v144's own private
// `_ScanHistoryTable._chronological` method to a top-level function --
// both the compact row (to pick the earliest Morning In / latest Leave)
// and the detail view (to list every scan oldest-to-newest) need the same
// ascending-by-`scannedAt` ordering now, not just one table's rows.
// UNCHANGED this round (v146 §7 "do not change... scan ordering in the
// detail view"); also now the basis for every scan-selection rule in the
// new Daily Working Minutes calculation below.
List<Map<String, dynamic>> _chronologicalScans(
  List<Map<String, dynamic>> rows,
) {
  final sorted = [...rows];
  sorted.sort((a, b) {
    final ta = DateTime.tryParse(a['scannedAt']?.toString() ?? '');
    final tb = DateTime.tryParse(b['scannedAt']?.toString() ?? '');
    if (ta == null && tb == null) return 0;
    if (ta == null) return 1;
    if (tb == null) return -1;
    return ta.compareTo(tb);
  });
  return sorted;
}

// --- Daily Working Minutes calculation (v146) -------------------------

// claude_prompt.txt (v146 §2 "Use scannedAt with the existing device-
// local/Bangkok time convention"): this codebase actually has TWO
// existing conventions for a scan's time-of-day, used for two different
// purposes -- `_formatDeviceLocalTime()` above (device-local,
// `DateTime.toLocal()`, used for every time this screen DISPLAYS) and the
// backend's own fixed +07:00 Bangkok-offset arithmetic
// (`device-scan-rules.ts`'s `bangkokMinutesOfDay()`, used for every
// BUSINESS-HOUR BOUNDARY check -- late/early-leave/overtime, and the
// 08:00/12:00/13:00/17:00 boundaries this task's own formulas reference).
// A device's own local clock/timezone setting has no bearing on what
// "08:00" means as a Bangkok business-hour boundary, so this calculation
// -- a boundary calculation, not a display -- deliberately uses the
// SECOND convention, replicated here exactly as the backend implements
// it, not the first.
int _bangkokMinutesOfDay(DateTime instant) {
  final shifted = instant.toUtc().add(const Duration(hours: 7));
  return shifted.hour * 60 + shifted.minute;
}

// claude_prompt.txt (v146 §2 "Use the actual reference times from the
// existing attendance-window configuration... do not silently hardcode
// if a reliable existing source is available"): investigated and
// verified this round, read-only, directly against the live `cirrus_db`
// (`SELECT code, reference_time FROM hr.attendance_windows`) --
// `morning_in.reference_time = 08:00`, `afternoon_in.reference_time =
// 13:00`, `leave.reference_time = 17:00` (all three match this task's
// own rules exactly). `lunch_out.reference_time` is actually **NULL**
// live, not `12:00` as this task's own Rule B states. No endpoint
// reachable by this Flutter app can read any of these values anyway --
// `GET /attendance-windows` requires the elevated `device_scans.read`
// permission (re-confirmed this round), never held by an ordinary
// employee -- so there is no "reliable existing source" this app could
// read from even if it wanted to. These three constants are therefore
// used exactly as this task's own Rules A-C directly specify (the task
// itself is the only available source), NOT silently reconciled with the
// live NULL value for `lunch_out` -- see this round's PROGRESS_LOG.md
// entry for the full discrepancy writeup.
const int _kMorningMinimumStartMinutes = 8 * 60; // 08:00
const int _kLunchOutFallbackMinutes = 12 * 60; // 12:00
const int _kAfternoonInFallbackMinutes = 13 * 60; // 13:00

class _DailyWorkingMinutes {
  const _DailyWorkingMinutes({this.morningMinutes, this.afternoonMinutes});

  final int? morningMinutes;
  final int? afternoonMinutes;

  int get total => (morningMinutes ?? 0) + (afternoonMinutes ?? 0);
}

/// Precomputed per-day scan summary built once in [_HistoryScreenState._loadScans]
/// so scrolling and expanding "View all" perform zero sorting or date parsing in build().
class _DailyScanSummary {
  const _DailyScanSummary({
    required this.workDate,
    required this.chronologicalScans,
    required this.checkIn,
    required this.checkOut,
    required this.workingMinutes,
    required this.scanCount,
  });

  final String workDate;
  final List<Map<String, dynamic>> chronologicalScans;
  final String checkIn;
  final String checkOut;
  final int workingMinutes;
  final int scanCount;

  factory _DailyScanSummary.fromGroup(
    String workDate,
    List<Map<String, dynamic>> scans,
  ) {
    final chronological = _chronologicalScans(scans);
    final morningIn = chronological.where(
      (s) => s['windowCode']?.toString() == 'morning_in',
    );
    final leave = chronological.where(
      (s) => s['windowCode']?.toString() == 'leave',
    );
    final checkIn = morningIn.isEmpty
        ? '-'
        : _formatDeviceLocalTime(morningIn.first['scannedAt']?.toString());
    final checkOut = leave.isEmpty
        ? '-'
        : _formatDeviceLocalTime(leave.last['scannedAt']?.toString());
    final workingMinutes = _calculateDailyWorkingMinutes(chronological).total;
    return _DailyScanSummary(
      workDate: workDate,
      chronologicalScans: chronological,
      checkIn: checkIn,
      checkOut: checkOut,
      workingMinutes: workingMinutes,
      scanCount: chronological.length,
    );
  }
}

int? _scanMinutesOfDay(Map<String, dynamic> scan) {
  final instant = DateTime.tryParse(scan['scannedAt']?.toString() ?? '');
  return instant == null ? null : _bangkokMinutesOfDay(instant);
}

// claude_prompt.txt (v146 §2 Rules A-E, §3 "Multiple Scan Handling"):
// implements the exact formulas given. Scan-selection rules, documented
// here per the task's own "document the selection rule" instruction:
//   - Start (Rule A): the earliest `morning_in` scan; if none exists, the
//     earliest scan of the day of ANY `windowCode` (still scoped to this
//     same `workDate` -- `scansForDate` is already grouped that way by
//     the caller, so a fallback scan can never belong to another date).
//   - `lunch_out` / `afternoon_in` (Rules B/C): the EARLIEST scan for
//     that window, if more than one exists for the date -- chosen for
//     consistency with `morning_in`'s own earliest-wins rule above, and
//     with the backend's own dedup semantics (`device-scan-rules.ts`'s
//     `recomputeGroupCounted`: "only the earliest scannedAt counts"
//     within one window/day group) -- which in practice already leaves
//     at most one COUNTED scan per window per day by the time this data
//     reaches Flutter (this endpoint only ever returns `counted = true`
//     rows), so this tie-break is a defensive choice, not expected to
//     change real output.
//   - Leave (Rule D): the LATEST counted `leave` scan, per the task's own
//     explicit instruction -- defends against the rare case of two
//     counted leave scans existing for one day (e.g. a real-time Leave
//     scan on a day a Forget-Leave record is also later attached to,
//     though the backend's own Forget-Leave precondition already
//     requires no counted Leave to exist first -- this is not relied
//     upon, Flutter re-applies "latest wins" defensively regardless).
// "If there are no scans at all, do not calculate a morning period" --
// and, with no scan to select a Leave record from either, no afternoon
// period is calculated in that case either.
_DailyWorkingMinutes _calculateDailyWorkingMinutes(
  List<Map<String, dynamic>> scansForDate,
) {
  if (scansForDate.isEmpty) {
    return const _DailyWorkingMinutes();
  }

  final chronological = _chronologicalScans(scansForDate);

  final morningInScans = chronological
      .where((s) => s['windowCode']?.toString() == 'morning_in')
      .toList();
  final startScan = morningInScans.isNotEmpty
      ? morningInScans.first
      : chronological.first;

  int? morningMinutes;
  final startMinutesOfDay = _scanMinutesOfDay(startScan);
  if (startMinutesOfDay != null) {
    // Formula: Effective Start = MAX(Selected Start Time, 08:00).
    final effectiveStart = startMinutesOfDay > _kMorningMinimumStartMinutes
        ? startMinutesOfDay
        : _kMorningMinimumStartMinutes;

    final lunchOutScans = chronological
        .where((s) => s['windowCode']?.toString() == 'lunch_out')
        .toList();
    final lunchOutMinutes = lunchOutScans.isNotEmpty
        ? _scanMinutesOfDay(lunchOutScans.first)
        : null;
    final effectiveLunchOut = lunchOutMinutes ?? _kLunchOutFallbackMinutes;

    // Formula: Morning Minutes = MAX(0, Effective Lunch Out - Effective Start).
    final diff = effectiveLunchOut - effectiveStart;
    morningMinutes = diff > 0 ? diff : 0;
  }

  final leaveScans = chronological
      .where((s) => s['windowCode']?.toString() == 'leave')
      .toList();

  int? afternoonMinutes;
  if (leaveScans.isNotEmpty) {
    final effectiveLeave = _scanMinutesOfDay(leaveScans.last);
    if (effectiveLeave != null) {
      final afternoonInScans = chronological
          .where((s) => s['windowCode']?.toString() == 'afternoon_in')
          .toList();
      final afternoonInMinutes = afternoonInScans.isNotEmpty
          ? _scanMinutesOfDay(afternoonInScans.first)
          : null;
      final effectiveAfternoonIn =
          afternoonInMinutes ?? _kAfternoonInFallbackMinutes;

      // Formula: Afternoon Minutes = MAX(0, Effective Leave - Effective Afternoon In).
      final diff = effectiveLeave - effectiveAfternoonIn;
      afternoonMinutes = diff > 0 ? diff : 0;
    }
  }
  // "If no Leave record exists, do not calculate the afternoon period" --
  // `afternoonMinutes` stays `null` (not `0`) in that case, distinguishing
  // "no Leave, unknown" from "Leave existed, afternoon happened to be 0
  // minutes" for the detail view's own optional breakdown display, while
  // `.total` below still treats a null component as contributing 0.

  return _DailyWorkingMinutes(
    morningMinutes: morningMinutes,
    afternoonMinutes: afternoonMinutes,
  );
}

// claude_prompt.txt (v146 §4): "Display the result in a readable format,
// such as `168h 45m`." Applied consistently to the monthly total, the
// compact daily row, and the detail view.
String _formatWorkingMinutes(int totalMinutes) =>
    AppStrings.formatHoursMinutes(totalMinutes);

// claude_prompt.txt (v146 §4 A "Sum daily working minutes" for the
// selected month): `null` only when the month has no scan data at all
// (mirrors the existing "N/A, not 0.00" convention `_buildMonthlySummary`
// already uses for `totalWorkingHours`/`totalOvertimeHours`) -- every
// day that DOES have scans always contributes a real, non-null `.total`
// (Rule A guarantees some start scan is selected whenever a day has any
// scan at all), so a 0 total is never confused with "no data."
int? _monthlyWorkingMinutesTotal(List<Map<String, dynamic>> scans) {
  if (scans.isEmpty) return null;
  var total = 0;
  for (final group in _groupScansByWorkDateDesc(scans)) {
    total += _calculateDailyWorkingMinutes(group.value).total;
  }
  return total;
}

// --- Section A: Monthly Attendance Summary -------------------------------
// claude_prompt.txt (v146 §4 A, §7): Present/Leave/Absent/Overtime and
// their underlying calculations are byte-for-byte unchanged from v141 --
// only the "Working hours" `_MetricCard`'s own VALUE (in
// `_SummarySectionState.build()` below) now reads from the new scan-based
// calculation instead of `summary.totalWorkingHours`. `_MonthlySummary`/
// `_buildMonthlySummary()` themselves are untouched, including the now-
// unused-for-display `totalWorkingHours` field -- left in place rather
// than removed, since deleting it would be exactly the kind of unrelated
// refactor this round's own task says to avoid.

// claude_prompt.txt (v141 §2 "Important data rules"): the authoritative
// `hr.attendance_status` Postgres enum, re-verified this round directly
// from `database/schema_dump_33.sql` (`CREATE TYPE hr.attendance_status
// AS ENUM ('present','absent','late','half_day','on_leave','holiday')`) --
// not assumed, not taken from any frontend type file. `present`/`late`/
// `half_day` all require a non-null check_in_at (the DB's own
// `chk_attendance_checkin_required_when_present` constraint) -- i.e. all
// three are "the employee was actually present" variants, differing only
// in lateness/partial-day nature, and are folded into one "Present days"
// count per the task's own fixed 5-metric list (it does not ask for a
// separate "late" metric). `holiday` is a non-working-day marker, not an
// attendance outcome -- it increments none of the three day-count
// buckets, so a holiday is never miscounted as absence.
class _MonthlySummary {
  final int presentDays;
  final int lateDaysWithinPresent;
  final int leaveDays;
  final int absentDays;
  final double? totalWorkingHours;
  final double? totalOvertimeHours;
  final List<Map<String, dynamic>> dailyBreakdown;

  const _MonthlySummary({
    required this.presentDays,
    required this.lateDaysWithinPresent,
    required this.leaveDays,
    required this.absentDays,
    required this.totalWorkingHours,
    required this.totalOvertimeHours,
    required this.dailyBreakdown,
  });
}

// claude_prompt.txt (v141 §2 "Important data rules"): "do not count
// duplicate records as multiple attendance days" -- de-duplicated by
// `date` defensively here (hr.attendance_records is already upserted by
// (employeeId, date) server-side, so a true duplicate should not occur,
// but this never trusts that as a client-side guarantee). "Do not infer
// absent days merely from dates without attendance records" -- every
// count below comes only from a row that actually exists; no date in the
// selected month that has NO row is ever counted toward any bucket, so
// weekends/holidays-with-no-row are never miscounted as absent. Working/
// overtime hours: summed only from records that actually parse to a
// number -- if not a single record in the month has a parseable value,
// the total is `null` ("not available"), never a misleading "0.00".
_MonthlySummary _buildMonthlySummary(List<Map<String, dynamic>> rawRecords) {
  final seenDates = <String>{};
  final deduped = <Map<String, dynamic>>[];
  for (final record in rawRecords) {
    final date = record['date']?.toString();
    if (date == null || date.isEmpty || !seenDates.add(date)) continue;
    deduped.add(record);
  }
  deduped.sort((a, b) {
    final dateA = a['date']?.toString() ?? '';
    final dateB = b['date']?.toString() ?? '';
    return dateB.compareTo(dateA);
  });

  var present = 0;
  var lateWithinPresent = 0;
  var leave = 0;
  var absent = 0;
  var workingSum = 0.0;
  var overtimeSum = 0.0;
  var anyWorkingHours = false;
  var anyOvertimeHours = false;

  for (final record in deduped) {
    switch (record['status']?.toString()) {
      case 'present':
        present++;
        break;
      case 'late':
        present++;
        lateWithinPresent++;
        break;
      case 'half_day':
        present++;
        break;
      case 'on_leave':
        leave++;
        break;
      case 'absent':
        absent++;
        break;
      case 'holiday':
      default:
        break;
    }

    final hoursWorked = double.tryParse(
      record['hoursWorked']?.toString() ?? '',
    );
    if (hoursWorked != null) {
      workingSum += hoursWorked;
      anyWorkingHours = true;
    }

    final overtimeHours = double.tryParse(
      record['overtimeHours']?.toString() ?? '',
    );
    if (overtimeHours != null) {
      overtimeSum += overtimeHours;
      anyOvertimeHours = true;
    }
  }

  return _MonthlySummary(
    presentDays: present,
    lateDaysWithinPresent: lateWithinPresent,
    leaveDays: leave,
    absentDays: absent,
    totalWorkingHours: anyWorkingHours ? workingSum : null,
    totalOvertimeHours: anyOvertimeHours ? overtimeSum : null,
    dailyBreakdown: deduped,
  );
}

ChipVariant _variantForStatus(String raw) {
  switch (raw) {
    case 'absent':
      return ChipVariant.error;
    case 'late':
    case 'half_day':
      return ChipVariant.warning;
    case 'on_leave':
    case 'holiday':
      return ChipVariant.info;
    case 'present':
    default:
      return ChipVariant.success;
  }
}

String _humanizeStatus(String raw) {
  return raw
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

class _HistoryScreenState extends State<HistoryScreen> {
  late DateTime _month;

  bool _summaryLoading = true;
  String? _summaryError;
  _MonthlySummary? _summary;
  int _summaryGeneration = 0;

  bool _scansLoading = true;
  String? _scansError;
  List<Map<String, dynamic>> _scans = const [];
  List<_DailyScanSummary> _dailySummaries = const [];
  int? _monthlyWorkingMinutes;
  int _verifiedPayMinutes = 0;
  int _scansGeneration = 0;

  // claude_prompt.txt (v146 §5 "Prevent duplicate simultaneous
  // recalculation requests"): a dedicated flag, separate from
  // `_scansLoading` (which `_loadScans()` itself still owns) -- this one
  // specifically drives the Recalculate button's own disabled/spinner
  // state and gates re-entrancy, and is distinguishable from an ordinary
  // background scan refresh for the SnackBar feedback step below.
  bool _recalculating = false;
  bool _showAllScans = false;

  bool _navigatingToLogin = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    AttendanceService.attendanceUpdatedNotifier.addListener(
      _onAttendanceUpdated,
    );
    _loadSummary();
    _loadScans();
  }

  @override
  void dispose() {
    AttendanceService.attendanceUpdatedNotifier.removeListener(
      _onAttendanceUpdated,
    );
    super.dispose();
  }

  void _onAttendanceUpdated() {
    if (!mounted) return;
    _loadSummary();
    _loadScans();
  }

  DateTime get _monthEnd => DateTime(_month.year, _month.month + 1, 0);

  // claude_prompt.txt (v141 §3 "Interaction"): the current calendar month
  // is the latest one navigation may reach -- there is no existing
  // product requirement anywhere in this codebase for viewing a future
  // month's attendance/scan history, so forward navigation stops here
  // rather than inventing one.
  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  Future<void> _loadSummary() async {
    final generation = ++_summaryGeneration;
    setState(() {
      _summaryLoading = true;
      _summaryError = null;
    });

    try {
      final records = await AttendanceService.getAttendanceHistory(
        from: _month,
        to: _monthEnd,
      );
      if (!mounted || generation != _summaryGeneration) return;
      setState(() {
        _summary = _buildMonthlySummary(records);
        _summaryLoading = false;
      });
    } on AttendanceApiException catch (e) {
      if (_redirectIfAuthFailure(e)) return;
      if (!mounted || generation != _summaryGeneration) return;
      setState(() {
        _summaryError = _messageForApiException(e);
        _summaryLoading = false;
      });
    } catch (e) {
      if (!mounted || generation != _summaryGeneration) return;
      setState(() {
        _summaryError = e.toString().replaceFirst('Exception: ', '');
        _summaryLoading = false;
      });
    }
  }

  Future<void> _loadScans() async {
    final generation = ++_scansGeneration;
    final month = _month;
    setState(() {
      _scansLoading = true;
      _scansError = null;
    });

    try {
      final scans = await AttendanceService.getMyScans(
        from: month,
        to: _monthEnd,
      );
      if (!mounted || generation != _scansGeneration) return;
      final verifiedPayMinutes = calculateScanPay(
        scans,
        month,
        PaySettings.trial,
      ).regularMinutes;
      final groupedScans = _groupScansByWorkDateDesc(scans);
      final dailySummaries = [
        for (final entry in groupedScans)
          _DailyScanSummary.fromGroup(entry.key, entry.value),
      ];
      setState(() {
        _scans = scans;
        _dailySummaries = dailySummaries;
        _monthlyWorkingMinutes = _monthlyWorkingMinutesTotal(scans);
        _verifiedPayMinutes = verifiedPayMinutes;
        _scansLoading = false;
      });
    } on AttendanceApiException catch (e) {
      if (_redirectIfAuthFailure(e)) return;
      if (!mounted || generation != _scansGeneration) return;
      setState(() {
        _scansError = _messageForApiException(e);
        _scansLoading = false;
      });
    } catch (e) {
      if (!mounted || generation != _scansGeneration) return;
      setState(() {
        _scansError = e.toString().replaceFirst('Exception: ', '');
        _scansLoading = false;
      });
    }
  }

  // Reload the selected month so both daily rows and the monthly total refresh.
  Future<void> _recalculate() async {
    if (_recalculating || _scansLoading) return; // §5.5, re-entrancy guard
    setState(() => _recalculating = true);
    try {
      await _loadScans();
      if (!mounted) return;
      final monthLabel = _monthLabel();
      if (_scansError == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Working hours recalculated for $monthLabel.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recalculation failed: $_scansError')),
        );
      }
    } finally {
      if (mounted) setState(() => _recalculating = false);
    }
  }

  bool _redirectIfAuthFailure(AttendanceApiException error) {
    final isAuthFailure =
        error.errorCode == 'AUTHENTICATION_REQUIRED' ||
        (error.errorCode == null && error.statusCode == 401);
    if (!isAuthFailure) return false;

    if (!mounted || _navigatingToLogin) return true;
    _navigatingToLogin = true;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    return true;
  }

  String _messageForApiException(AttendanceApiException e) {
    if (e.errorCode == 'PERMISSION_DENIED') {
      return 'You do not have permission to view this data.';
    }
    return e.message.isNotEmpty
        ? e.message
        : 'Something went wrong (${e.statusCode}).';
  }

  // claude_prompt.txt (v141 §3 "Interaction"): "Previous/next month
  // controls update both sections together" -- both loads are kicked off
  // from the same handler, each tracked by its own generation counter so
  // a slow response for the OLD month can never clobber the newly
  // selected month's state once it (eventually) arrives.
  void _goToPreviousMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1, 1);
      _showAllScans = false;
    });
    _loadSummary();
    _loadScans();
  }

  void _goToNextMonth() {
    if (_isCurrentMonth) return;
    setState(() {
      _month = DateTime(_month.year, _month.month + 1, 1);
      _showAllScans = false;
    });
    _loadSummary();
    _loadScans();
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadSummary(), _loadScans()]);
  }

  String _monthLabel() => AppStrings.formatMonthYear(_month.year, _month.month);

  @override
  Widget build(BuildContext context) {
    final anyLoading = _summaryLoading || _scansLoading;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(AppStrings.t('Attendance History', 'ประวัติการลงเวลา')),
        actions: [
          IconButton(
            tooltip: AppStrings.t('Refresh', 'รีเฟรช'),
            onPressed: anyLoading ? null : _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: appContentMaxWidth(context)),
            child: RefreshIndicator(
              color: AppColors.secondary,
              onRefresh: _refreshAll,
              child: CustomScrollView(
                primary: true,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      0,
                    ),
                    sliver: SliverList.list(
                      children: [
                        _MonthSelector(
                          label: _monthLabel(),
                          onPrevious: anyLoading ? null : _goToPreviousMonth,
                          onNext: (anyLoading || _isCurrentMonth)
                              ? null
                              : _goToNextMonth,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _WorkingHoursCard(
                          isCurrentMonth: _isCurrentMonth,
                          loading: _scansLoading,
                          unavailable: _scansError != null,
                          minutes: _monthlyWorkingMinutes,
                          verifiedPayMinutes: _verifiedPayMinutes,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          AppStrings.t(
                            'Monthly Attendance Summary',
                            'สรุปการเข้างานรายเดือน',
                          ),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _SummarySection(
                          loading: _summaryLoading,
                          errorMessage: _summaryError,
                          summary: _summary,
                          monthLabel: _monthLabel(),
                          onRetry: _loadSummary,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                AppStrings.t(
                                  'Monthly Scan History',
                                  'ประวัติการสแกนรายเดือน',
                                ),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: (_recalculating || _scansLoading)
                                  ? null
                                  : _recalculate,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.neutral,
                                backgroundColor: AppColors.surface,
                                minimumSize: const Size(0, 36),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                side: BorderSide(color: AppColors.cardBorder),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                              ),
                              icon: _recalculating
                                  ? const SizedBox.square(
                                      dimension: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.refresh_rounded,
                                      size: 16,
                                    ),
                              label: Text(
                                AppStrings.t('Recalculate', 'คำนวณใหม่'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ),
                  ),
                  ..._buildScanHistorySlivers(context),
                  SliverToBoxAdapter(
                    child: SizedBox(height: appTabBottomPadding(context)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildScanHistorySlivers(BuildContext context) {
    if (_scansLoading) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverList.list(
            children: const [
              ShimmerCardSkeleton(height: 112),
              SizedBox(height: AppSpacing.sm),
              ShimmerCardSkeleton(height: 112),
            ],
          ),
        ),
      ];
    }

    if (_scansError != null) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StatusBanner(
                  variant: StatusVariant.error,
                  title: AppStrings.t(
                    'Unable to load scan history',
                    'ไม่สามารถโหลดประวัติการสแกนได้',
                  ),
                  message: _scansError!,
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryActionButton(
                  label: AppStrings.t('Try again', 'ลองใหม่อีกครั้ง'),
                  onPressed: _loadScans,
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (_scans.isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: EmptyNote(
              icon: Icons.history_toggle_off,
              message: AppStrings.isThai
                  ? 'ไม่มีรายการสแกนที่นับเวลาสำหรับ ${_monthLabel()}'
                  : 'No counted scan events for ${_monthLabel()}.',
            ),
          ),
        ),
      ];
    }

    final totalCount = _dailySummaries.length;
    final visibleCount = _showAllScans
        ? totalCount
        : (totalCount > 4 ? 4 : totalCount);

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        sliver: SliverList.builder(
          itemCount: visibleCount,
          itemBuilder: (context, index) {
            final summary = _dailySummaries[index];
            return Padding(
              padding: EdgeInsets.only(top: index > 0 ? AppSpacing.sm : 0),
              child: FadeSlideEntry(
                yOffset: 8,
                child: _DailyScanRow(summary: summary),
              ),
            );
          },
        ),
      ),
      if (totalCount > 4)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: FilledButton.tonalIcon(
              onPressed: () => setState(() => _showAllScans = !_showAllScans),
              icon: Icon(_showAllScans ? Icons.expand_less : Icons.expand_more),
              label: Text(
                _showAllScans
                    ? AppStrings.t('Show less', 'แสดงน้อยลง')
                    : (AppStrings.isThai
                          ? 'ดูทั้งหมด ($totalCount)'
                          : 'View all ($totalCount)'),
              ),
            ),
          ),
        ),
    ];
  }
}

// --- Shared month selector --------------------------------------------------

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return FadeSlideEntry(
      yOffset: -10,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.neutral.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
              color: onPrevious != null
                  ? AppColors.neutral
                  : AppColors.textSecondary.withValues(alpha: 0.35),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral,
                  ),
                ),
              ],
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
              color: onNext != null
                  ? AppColors.neutral
                  : AppColors.textSecondary.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkingHoursCard extends StatelessWidget {
  const _WorkingHoursCard({
    required this.isCurrentMonth,
    required this.loading,
    required this.unavailable,
    required this.minutes,
    required this.verifiedPayMinutes,
  });

  final bool isCurrentMonth;
  final bool loading;
  final bool unavailable;
  final int? minutes;
  final int verifiedPayMinutes;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = minutes;
    final hasTotal = !loading && !unavailable && total != null;
    final value = switch ((loading, unavailable, total)) {
      (true, _, _) => AppStrings.t(
        'Loading scan hours…',
        'กำลังโหลดชั่วโมงทำงาน…',
      ),
      (_, true, _) => AppStrings.t(
        'Scan hours unavailable',
        'ไม่สามารถโหลดชั่วโมงทำงานได้',
      ),
      (_, _, null) => AppStrings.t('No counted scans', 'ไม่มีรายการสแกนที่นับ'),
      (_, _, final int minutes) => _formatWorkingMinutes(minutes),
    };

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: AmbientPanel(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasTotal) ...[
              // Primary Hero: Hours Used for Pay
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.42),
                      ),
                    ),
                    child: Icon(
                      Icons.verified_outlined,
                      color: AppColors.secondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.t(
                            'Hours Used for Pay',
                            'ชั่วโมงที่ใช้คำนวณค่าแรง',
                          ),
                          style: text.titleSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontWeight: FontWeight.w700,
                            letterSpacing: AppStrings.isThai ? 0 : 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.formatHoursMinutes(verifiedPayMinutes),
                          style: text.displaySmall?.copyWith(
                            fontSize: 38,
                            height: 1.08,
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppStrings.t(
                            'From complete scan pairs before 17:00 (Bangkok time).',
                            'จากคู่สแกนที่ครบถ้วนก่อน 17:00 น. (เวลาประเทศไทย)',
                          ),
                          style: text.bodySmall?.copyWith(
                            color: AppColors.onNeutralMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              // Secondary Metric: Total Working Hours (smaller, compact)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 46,
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Icon(
                          Icons.schedule_rounded,
                          color: AppColors.onNeutralMuted,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCurrentMonth
                              ? AppStrings.t(
                                  'Total Working Hours This Month',
                                  'ชั่วโมงทำงานรวมเดือนนี้',
                                )
                              : AppStrings.t(
                                  'Total Working Hours',
                                  'ชั่วโมงทำงานรวม',
                                ),
                          style: text.labelSmall?.copyWith(
                            color: AppColors.onNeutralMuted,
                            fontWeight: FontWeight.w600,
                            letterSpacing: AppStrings.isThai ? 0 : 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: text.titleLarge?.copyWith(
                            fontSize: 20,
                            height: 1.15,
                            color: Colors.white.withValues(alpha: 0.90),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.t(
                            'May use reference times when scans are missing.',
                            'อาจใช้เวลาอ้างอิงเมื่อขาดการสแกนบางช่วง',
                          ),
                          style: text.bodySmall?.copyWith(
                            fontSize: 11.5,
                            color: AppColors.onNeutralMuted.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      Icons.schedule_rounded,
                      color: AppColors.secondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCurrentMonth
                              ? AppStrings.t(
                                  'Total Working Hours This Month',
                                  'ชั่วโมงทำงานรวมเดือนนี้',
                                )
                              : AppStrings.t(
                                  'Total Working Hours',
                                  'ชั่วโมงทำงานรวม',
                                ),
                          style: text.titleSmall?.copyWith(
                            color: AppColors.onNeutralMuted,
                            fontWeight: FontWeight.w700,
                            letterSpacing: AppStrings.isThai ? 0 : 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          style: text.bodyMedium?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// --- Section A widgets -------------------------------------------------------

class _SummarySection extends StatefulWidget {
  const _SummarySection({
    required this.loading,
    required this.errorMessage,
    required this.summary,
    required this.monthLabel,
    required this.onRetry,
  });

  final bool loading;
  final String? errorMessage;
  final _MonthlySummary? summary;
  final String monthLabel;
  final VoidCallback onRetry;

  @override
  State<_SummarySection> createState() => _SummarySectionState();
}

class _SummarySectionState extends State<_SummarySection> {
  bool _breakdownExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const ShimmerCardSkeleton(height: 64);
    }

    if (widget.errorMessage != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatusBanner(
            variant: StatusVariant.error,
            title: 'Unable to load the monthly summary',
            message: widget.errorMessage!,
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryActionButton(label: 'Try again', onPressed: widget.onRetry),
        ],
      );
    }

    final summary = widget.summary;
    if (summary == null ||
        (summary.presentDays == 0 &&
            summary.leaveDays == 0 &&
            summary.absentDays == 0)) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                AppStrings.isThai
                    ? 'ไม่มีบันทึกการเข้างานสำหรับ ${widget.monthLabel}'
                    : 'No attendance records for ${widget.monthLabel}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            FadeSlideEntry(
              child: _MetricCard(
                label: AppStrings.t('Present', 'มาทำงาน'),
                value: '${summary.presentDays}',
                caption: summary.lateDaysWithinPresent > 0
                    ? (AppStrings.isThai
                          ? 'สาย ${summary.lateDaysWithinPresent} วัน'
                          : '${summary.lateDaysWithinPresent} late')
                    : null,
                variant: ChipVariant.success,
              ),
            ),
            FadeSlideEntry(
              child: _MetricCard(
                label: AppStrings.t('Leave', 'ลา'),
                value: '${summary.leaveDays}',
                variant: ChipVariant.info,
              ),
            ),
            FadeSlideEntry(
              child: _MetricCard(
                label: AppStrings.t('Absent', 'ขาดงาน'),
                value: '${summary.absentDays}',
                variant: ChipVariant.error,
              ),
            ),
            FadeSlideEntry(
              child: _MetricCard(
                label: AppStrings.t('Overtime', 'ล่วงเวลา'),
                value: summary.totalOvertimeHours == null
                    ? 'N/A'
                    : summary.totalOvertimeHours!.toStringAsFixed(1),
                variant: ChipVariant.active,
              ),
            ),
          ],
        ),
        if (summary.dailyBreakdown.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: () =>
                setState(() => _breakdownExpanded = !_breakdownExpanded),
            borderRadius: BorderRadius.circular(AppRadius.input),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(
                    _breakdownExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _breakdownExpanded
                        ? 'Hide daily breakdown'
                        : 'Show daily breakdown',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          if (_breakdownExpanded)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.surface),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < summary.dailyBreakdown.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _DailyBreakdownRow(record: summary.dailyBreakdown[i]),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.variant,
    this.caption,
  });

  final String label;
  final String value;
  final String? caption;
  final ChipVariant variant;

  @override
  Widget build(BuildContext context) {
    final (
      Color background,
      Color foreground,
      IconData icon,
    ) = switch (variant) {
      ChipVariant.success => (
        AppColors.successContainer,
        AppColors.success,
        Icons.check_circle_outline_rounded,
      ),
      ChipVariant.warning => (
        AppColors.warningContainer,
        AppColors.warning,
        Icons.schedule_rounded,
      ),
      ChipVariant.error => (
        AppColors.errorContainer,
        AppColors.error,
        Icons.cancel_outlined,
      ),
      ChipVariant.info => (
        AppColors.infoContainer,
        AppColors.info,
        Icons.event_busy_outlined,
      ),
      ChipVariant.active => (
        AppColors.secondary.withValues(alpha: 0.16),
        AppColors.neutral,
        Icons.hourglass_bottom_rounded,
      ),
    };

    return Container(
      width: 156,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.surface),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: foreground),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.neutral,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                caption!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DailyBreakdownRow extends StatelessWidget {
  const _DailyBreakdownRow({required this.record});

  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final date = record['date']?.toString();
    final status = record['status']?.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _formatCalendarDate(date),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (status != null && status.isNotEmpty)
            StatusChip(
              label: _humanizeStatus(status),
              variant: _variantForStatus(status),
            ),
        ],
      ),
    );
  }
}

// --- Section B: Monthly Scan History ----------------------------------
// claude_prompt.txt (v145 -- Daily Scan History: Compact Rows &
// Expandable Daily Details; v146 -- Daily Working Minutes Calculation &
// Manual Recalculation): the compact 3-column (Date / Check In / Check
// Out) tappable row list gains a fourth value, Working Hours (v146 §4 B);
// the detail view gains a "Daily Working Hours" section (v146 §4 C).
// Grouping/ordering/Check-In-Check-Out selection are all unchanged.

class _DailyScanRow extends StatelessWidget {
  const _DailyScanRow({required this.summary});

  final _DailyScanSummary summary;

  @override
  Widget build(BuildContext context) {
    final workDate = summary.workDate;
    final chronological = summary.chronologicalScans;
    final checkIn = summary.checkIn;
    final checkOut = summary.checkOut;
    final workingMinutes = summary.workingMinutes;
    final workingHoursLabel = _formatWorkingMinutes(workingMinutes);

    final dateLabel = workDate == '-'
        ? AppStrings.t('Unknown date', 'ไม่ทราบวันที่')
        : _formatCalendarDate(workDate);

    final hasWorkingHours = workingMinutes > 0;
    final scanCountLabel = AppStrings.isThai
        ? '${summary.scanCount} ครั้ง'
        : (summary.scanCount == 1 ? '1 scan' : '${summary.scanCount} scans');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.surface),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.surface),
          onTap: () => _openDailyScanDetail(context, workDate, chronological),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          dateLabel,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.neutral,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.fingerprint_rounded,
                                size: 12,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                scanCountLabel,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MetricMini(
                          icon: Icons.login_rounded,
                          label: AppStrings.t('Check In', 'เข้างาน'),
                          value: checkIn,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: AppColors.cardBorder,
                      ),
                      Expanded(
                        child: _MetricMini(
                          icon: Icons.logout_rounded,
                          label: AppStrings.t('Check Out', 'ออกงาน'),
                          value: checkOut,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: AppColors.cardBorder,
                      ),
                      Expanded(
                        child: _MetricMini(
                          icon: Icons.schedule_rounded,
                          label: AppStrings.t('Working Hours', 'ชั่วโมงทำงาน'),
                          value: workingHoursLabel,
                          isHighlight: hasWorkingHours,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// claude_prompt.txt (v145 §2 "Preferred presentation: Mobile: Modal
// Bottom Sheet. Tablet/Desktop: Dialog or another responsive detail
// presentation consistent with the existing application."): reuses this
// same file's own existing `AppBreakpoints.isTablet()` threshold (already
// the single source of truth for "is this a small phone screen" elsewhere
// in this app, per app_theme.dart) -- not a new breakpoint invented for
// this one feature.
void _openDailyScanDetail(
  BuildContext context,
  String workDate,
  List<Map<String, dynamic>> chronologicalScans,
) {
  if (!AppBreakpoints.isTablet(context)) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.primary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.hero),
        ),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        expand: false,
        builder: (sheetContext2, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                _DailyScanDetailContent(
                  workDate: workDate,
                  scans: chronologicalScans,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return;
  }

  showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.surface),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: SingleChildScrollView(
          child: _DailyScanDetailContent(
            workDate: workDate,
            scans: chronologicalScans,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    ),
  );
}

// claude_prompt.txt (v145 §2 "A. Daily Scan Details" + "C. Other
// Scans"): a single chronological list containing EVERY scan for the
// date -- "every scan event for that date" (§2 A) is satisfied literally
// by including every record regardless of windowCode; a scan with a
// null/unrecognized code is never dropped, it is rendered with the same
// neutral "Scan Event" fallback label v141/v144 already established
// (§2 C's own "preserve the existing fallback event label"), inline in
// this same list rather than as a second, visually duplicate list -- a
// deliberate reading of §2's A/C split, stated here rather than silently
// assumed. "B. Daily Time Metrics" follows as its own section, minute
// values only, with no scan time shown beside them (§2 B). v146 adds a
// "Daily Working Hours" section between the two (§4 C), showing the
// total plus the optional Morning/Afternoon breakdown.
class _DailyScanDetailContent extends StatelessWidget {
  const _DailyScanDetailContent({
    required this.workDate,
    required this.scans,
    this.onClose,
  });

  final String workDate;
  final List<Map<String, dynamic>> scans; // already chronological
  final VoidCallback? onClose;

  // claude_prompt.txt (v145 §2 B "Display only the numeric minutes
  // followed by `min`... Null or zero values display `-`."): `-` only
  // when NOT A SINGLE scan this date has a positive value; otherwise
  // every positive value is listed (§3 "do not... sum, average... or
  // discard multiple scans" -- a hard constraint that applies here too,
  // so multiple values are joined, never reduced to one number).
  String _metricText(List<int> values) {
    if (values.isEmpty) return '-';
    return '${values.join(', ')} min';
  }

  @override
  Widget build(BuildContext context) {
    final lateValues = <int>[];
    final earlyLeaveValues = <int>[];
    final overtimeValues = <int>[];
    for (final scan in scans) {
      final late = _positiveMinutes(scan['lateMinutes']);
      if (late != null) lateValues.add(late);
      final earlyLeave = _positiveMinutes(scan['earlyLeaveMinutes']);
      if (earlyLeave != null) earlyLeaveValues.add(earlyLeave);
      // claude_prompt.txt (v145 §2 B "Use API values directly; do not
      // recalculate them."): `overTime` read straight from the backend
      // response field, same as every other field here.
      final overTime = _positiveMinutes(scan['overTime']);
      if (overTime != null) overtimeValues.add(overTime);
    }

    final dateLabel = workDate == '-'
        ? 'Unknown date'
        : _formatCalendarDate(workDate);

    // claude_prompt.txt (v146 §4 C "Add Daily Working Hours... Display
    // the total in hours and minutes, and optionally show the Morning
    // and Afternoon contributions separately."):
    final daily = _calculateDailyWorkingMinutes(scans);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (onClose != null)
                IconButton(
                  tooltip: 'Close',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            AppStrings.t('Daily Working Hours', 'ชั่วโมงทำงานรายวัน'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _MetricMini(
                  label: AppStrings.t('Total', 'รวม'),
                  value: _formatWorkingMinutes(daily.total),
                ),
              ),
              Expanded(
                child: _MetricMini(
                  label: AppStrings.t('Morning', 'ช่วงเช้า'),
                  value: daily.morningMinutes == null
                      ? '-'
                      : _formatWorkingMinutes(daily.morningMinutes!),
                ),
              ),
              Expanded(
                child: _MetricMini(
                  label: AppStrings.t('Afternoon', 'ช่วงบ่าย'),
                  value: daily.afternoonMinutes == null
                      ? '-'
                      : _formatWorkingMinutes(daily.afternoonMinutes!),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            AppStrings.t('Daily Scan Details', 'รายละเอียดการสแกน'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (scans.isEmpty)
            Text(
              AppStrings.t(
                'No scan events for this date.',
                'ไม่มีรายการสแกนในวันนี้',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.surface),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < scans.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _DailyScanEventTile(scan: scans[i]),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            AppStrings.t('Daily Time Metrics', 'ข้อมูลเวลารายวัน'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _MetricMini(
                  label: AppStrings.t('Late (min)', 'มาสาย (นาที)'),
                  value: _metricText(lateValues),
                ),
              ),
              Expanded(
                child: _MetricMini(
                  label: AppStrings.t('Early Leave (min)', 'ออกก่อน (นาที)'),
                  value: _metricText(earlyLeaveValues),
                ),
              ),
              Expanded(
                child: _MetricMini(
                  label: AppStrings.t('OT (min)', 'ล่วงเวลา (นาที)'),
                  value: _metricText(overtimeValues),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// claude_prompt.txt (v145 §2 A): one row per scan -- event label/window
// (with the existing unknown-code fallback), scan time (device-local,
// same `_formatDeviceLocalTime` v144 introduced), source, and late/early-
// leave/overtime ONLY when positive (unlike §2 B's metrics list, the
// scan time IS shown alongside these here, since this is the per-event
// detail list, not the no-time metrics summary). Unchanged this round
// (v146 §7 "keep all existing scan details, source labels, Late, Early
// Leave, and OT displays unchanged").
class _DailyScanEventTile extends StatelessWidget {
  const _DailyScanEventTile({required this.scan});

  final Map<String, dynamic> scan;

  @override
  Widget build(BuildContext context) {
    final windowCode = scan['windowCode']?.toString();
    final source = scan['source']?.toString();
    final time = _formatDeviceLocalTime(scan['scannedAt']?.toString());
    final late = _positiveMinutes(scan['lateMinutes']);
    final earlyLeave = _positiveMinutes(scan['earlyLeaveMinutes']);
    final overTime = _positiveMinutes(scan['overTime']);

    final sourceLabel = source == 'app'
        ? AppStrings.scanSourceLabel('APP')
        : (source == 'fingerprint'
              ? AppStrings.scanSourceLabel('Fingerprint')
              : null);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.fingerprint,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _windowCodeLabel(windowCode),
                        style: Theme.of(context).textTheme.bodyLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (sourceLabel != null)
                      StatusChip(label: sourceLabel, variant: ChipVariant.info),
                  ],
                ),
                if (late != null)
                  Text(
                    'Late: $late min',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 12.5,
                    ),
                  ),
                if (earlyLeave != null)
                  Text(
                    'Early leave: $earlyLeave min',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 12.5,
                    ),
                  ),
                if (overTime != null)
                  Text(
                    'Overtime: $overTime min',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 12.5,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(time, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MetricMini extends StatelessWidget {
  const _MetricMini({
    required this.label,
    required this.value,
    this.icon,
    this.isHighlight = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isHighlight
                ? AppColors.neutral
                : AppColors.neutral.withValues(alpha: 0.85),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
