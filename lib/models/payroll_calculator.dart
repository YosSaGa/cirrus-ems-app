import 'dart:math' as math;

class PaySettings {
  static const dailyWages = [300, 400, 500];
  static const baseDayOptions = [30, 26, 22];
  static const defaultBaseDays = 30;
  static const hoursPerDay = 8;
  static const fixedOtMultiplier = 1.5;
  static const trialDailyWageBaht = 300;
  static final trial = PaySettings.fromDailyWage(trialDailyWageBaht);

  factory PaySettings.fromDailyWage(int dailyBaht, {int otStartMinute = 1020}) {
    if (!dailyWages.contains(dailyBaht)) {
      throw ArgumentError('Choose a daily wage of THB 300, 400 or 500');
    }
    return PaySettings(
      hourlySatang: dailyBaht * 100 ~/ hoursPerDay,
      otMultiplier: fixedOtMultiplier,
      otStartMinute: otStartMinute,
    );
  }

  /// Derives hourly pay from monthly base salary:
  /// `hourly = monthlySalary ÷ baseDays ÷ dailyHours`.
  factory PaySettings.fromMonthlySalary(
    double monthlySalaryBaht, {
    int baseDays = defaultBaseDays,
    int dailyHours = hoursPerDay,
    int otStartMinute = 1020,
  }) {
    if (!monthlySalaryBaht.isFinite ||
        monthlySalaryBaht <= 0 ||
        baseDays <= 0 ||
        dailyHours <= 0) {
      throw ArgumentError('Invalid monthly salary, base days, or daily hours');
    }
    final hourlySatang = (monthlySalaryBaht * 100 / baseDays / dailyHours)
        .round();
    return PaySettings(
      hourlySatang: hourlySatang,
      otMultiplier: fixedOtMultiplier,
      otStartMinute: otStartMinute,
      monthlySalaryBaht: monthlySalaryBaht,
      baseDays: baseDays,
      dailyHours: dailyHours,
    );
  }

  /// Direct hourly rate (e.g. THB 75.00/hr configured by HR/Admin/Accountant).
  factory PaySettings.fromHourlyRate(
    double hourlyBaht, {
    int dailyHours = hoursPerDay,
    int otStartMinute = 1020,
    double? monthlySalaryBaht,
  }) {
    if (!hourlyBaht.isFinite || hourlyBaht <= 0 || dailyHours <= 0) {
      throw ArgumentError('Invalid hourly rate or daily hours');
    }
    return PaySettings(
      hourlySatang: (hourlyBaht * 100).round(),
      otMultiplier: fixedOtMultiplier,
      otStartMinute: otStartMinute,
      monthlySalaryBaht: monthlySalaryBaht,
      dailyHours: dailyHours,
      isDirectHourly: true,
    );
  }

  /// Uses direct [hourlyRateBaht] when configured (> 0), otherwise derives from
  /// [monthlySalaryBaht] (`salary ÷ baseDays ÷ dailyHours`), or falls back
  /// to the fixed trial rate (THB 300 / 8h).
  factory PaySettings.forEmployeeSalary(
    double? monthlySalaryBaht, {
    double? hourlyRateBaht,
    int baseDays = defaultBaseDays,
    int dailyHours = hoursPerDay,
  }) {
    if (hourlyRateBaht != null &&
        hourlyRateBaht.isFinite &&
        hourlyRateBaht > 0) {
      return PaySettings.fromHourlyRate(
        hourlyRateBaht,
        dailyHours: dailyHours,
        monthlySalaryBaht: monthlySalaryBaht,
      );
    }
    if (monthlySalaryBaht != null &&
        monthlySalaryBaht.isFinite &&
        monthlySalaryBaht > 0) {
      return PaySettings.fromMonthlySalary(
        monthlySalaryBaht,
        baseDays: baseDays,
        dailyHours: dailyHours,
      );
    }
    return trial;
  }

  PaySettings({
    required this.hourlySatang,
    this.otMultiplier = 1.5,
    this.otStartMinute = 1020,
    this.monthlySalaryBaht,
    this.baseDays = defaultBaseDays,
    this.dailyHours = hoursPerDay,
    this.isDirectHourly = false,
  }) {
    if (hourlySatang < 0 ||
        hourlySatang > 10000000 ||
        !otMultiplier.isFinite ||
        otMultiplier <= 0 ||
        otMultiplier > 10 ||
        otStartMinute < 0 ||
        otStartMinute >= 1440) {
      throw ArgumentError(
        'Invalid hourly rate, OT multiplier or OT start time',
      );
    }
  }
  final int hourlySatang;
  final double otMultiplier;
  final int otStartMinute;
  final double? monthlySalaryBaht;
  final int baseDays;
  final int dailyHours;
  final bool isDirectHourly;

  bool get isSalaryBased =>
      !isDirectHourly &&
      monthlySalaryBaht != null &&
      monthlySalaryBaht! > 0;
  int get dailySatang => hourlySatang * dailyHours;
}

/// A recurring payroll deduction or earning item attached to an employee
/// (e.g. Accommodation / ค่าที่พัก, Social Security / ค่าประกันสังคม,
/// Work Insurance / ค่าประกันงาน, or custom HR/Accountant items).
class PayrollAdjustmentItem {
  const PayrollAdjustmentItem({
    required this.id,
    required this.employeeId,
    this.componentId,
    required this.code,
    required this.name,
    required this.componentType,
    required this.calcMode,
    required this.amount,
    this.maxCap,
    this.isActive = true,
    this.notes = '',
  });

  final String id;
  final String employeeId;
  final String? componentId;
  final String code;
  final String name;

  /// `'deduction'` or `'earning'`.
  final String componentType;

  /// `'fixed'` (THB) or `'percent'` (% of gross pay, optionally capped at [maxCap]).
  final String calcMode;

  /// THB amount when [calcMode] == `'fixed'`, or percentage (0–100) when `'percent'`.
  final double amount;

  /// Optional maximum cap in THB when [calcMode] == `'percent'` (e.g. 750 for SSO).
  final double? maxCap;
  final bool isActive;
  final String notes;

  bool get isDeduction => componentType != 'earning';
  bool get isPercent => calcMode == 'percent';

  /// Computes the satang impact of this item given [grossSatang].
  int computeSatang(int grossSatang) {
    if (!isActive || amount <= 0) return 0;
    if (isPercent) {
      if (grossSatang <= 0) return 0;
      var computed = (grossSatang * amount / 100).round();
      if (maxCap != null && maxCap! > 0) {
        final capSatang = (maxCap! * 100).round();
        if (computed > capSatang) computed = capSatang;
      }
      return computed;
    }
    return (amount * 100).round();
  }

  factory PayrollAdjustmentItem.fromJson(Map<String, dynamic> json) {
    return PayrollAdjustmentItem(
      id: (json['id'] ?? '').toString(),
      employeeId: (json['employeeId'] ?? '').toString(),
      componentId: json['componentId']?.toString(),
      code: (json['code'] ?? 'CUSTOM').toString(),
      name: (json['name'] ?? '').toString(),
      componentType: (json['componentType'] ?? 'deduction').toString(),
      calcMode: (json['calcMode'] ?? 'fixed').toString(),
      amount: json['amount'] is num
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      maxCap: json['maxCap'] is num
          ? (json['maxCap'] as num).toDouble()
          : double.tryParse(json['maxCap']?.toString() ?? ''),
      isActive: json['isActive'] != false,
      notes: (json['notes'] ?? '').toString(),
    );
  }
}

class PayrollLineComputed {
  const PayrollLineComputed({required this.item, required this.satang});
  final PayrollAdjustmentItem item;
  final int satang;
}

/// Net pay breakdown after applying active deductions and extra earnings to
/// [grossSatang].
class PayrollNetSummary {
  const PayrollNetSummary({
    required this.grossSatang,
    required this.totalEarningsSatang,
    required this.totalDeductionsSatang,
    required this.netSatang,
    required this.lines,
  });

  final int grossSatang;
  final int totalEarningsSatang;
  final int totalDeductionsSatang;
  final int netSatang;
  final List<PayrollLineComputed> lines;

  bool get hasAdjustments => lines.isNotEmpty;

  factory PayrollNetSummary.calculate({
    required int grossSatang,
    required List<PayrollAdjustmentItem> items,
  }) {
    var earnings = 0;
    var deductions = 0;
    final lines = <PayrollLineComputed>[];
    for (final item in items) {
      if (!item.isActive) continue;
      final satang = item.computeSatang(grossSatang);
      lines.add(PayrollLineComputed(item: item, satang: satang));
      if (item.isDeduction) {
        deductions += satang;
      } else {
        earnings += satang;
      }
    }
    final net = math.max(0, grossSatang + earnings - deductions);
    return PayrollNetSummary(
      grossSatang: grossSatang,
      totalEarningsSatang: earnings,
      totalDeductionsSatang: deductions,
      netSatang: net,
      lines: lines,
    );
  }
}

class PayEstimate {
  PayEstimate({
    required this.regularMinutes,
    required this.otMinutes,
    required this.settings,
    this.issueDates = const [],
    this.workDays = 0,
  }) {
    if (regularMinutes < 0 || otMinutes < 0) {
      throw ArgumentError('Hours cannot be negative');
    }
  }
  final int regularMinutes;
  final int otMinutes;
  final PaySettings settings;
  final List<String> issueDates;
  final int workDays;
  int get regularSatang =>
      (regularMinutes * settings.hourlySatang / 60).round();
  int get otSatang =>
      (otMinutes * settings.hourlySatang * settings.otMultiplier / 60).round();
  int get totalSatang => regularSatang + otSatang;
}

String calendarDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime? parseCalendarDate(String value) {
  final date = DateTime.tryParse(value);
  return date != null && calendarDate(date) == value ? date : null;
}

DateTime bangkokNow() => DateTime.now().toUtc().add(const Duration(hours: 7));
String formatWorkMinutes(int minutes) => '${minutes ~/ 60}h ${minutes % 60}m';
String formatBaht(int satang) {
  final whole = (satang ~/ 100).abs().toString();
  final cents = (satang % 100).abs().toString().padLeft(2, '0');
  final grouped = whole.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (match) => '${match[1]},',
  );
  final sign = satang < 0 ? '-' : '';
  return 'THB $sign$grouped.$cents';
}

DateTime? _parseScanInstant(String raw) {
  final match = RegExp(
    r'^(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(Z|[+-](\d{2}):(\d{2}))$',
  ).firstMatch(raw);
  if (match == null ||
      parseCalendarDate(match[1]!) == null ||
      int.parse(match[2]!) > 23 ||
      int.parse(match[3]!) > 59 ||
      int.parse(match[4]!) > 59 ||
      (match[6] != null &&
          (int.parse(match[6]!) > 23 || int.parse(match[7]!) > 59))) {
    return null;
  }
  return DateTime.tryParse(raw)?.toUtc();
}

/// Only explicit pairs are payable. Unlike History's display calculation,
/// estimates must not create hours from missing lunch/afternoon scans.
PayEstimate calculateScanPay(
  List<Map<String, dynamic>> scans,
  DateTime month,
  PaySettings settings,
) {
  final groups = <String, List<Map<String, dynamic>>>{};
  final issues = <String>{};
  for (final scan in scans) {
    if (scan['counted'] == false) continue;
    final key = scan['workDate']?.toString() ?? '';
    final date = parseCalendarDate(key);
    if (date == null) {
      issues.add('Invalid date');
      continue;
    }
    if (date.year != month.year || date.month != month.month) continue;
    groups.putIfAbsent(key, () => []).add(scan);
  }
  var regular = 0;
  var overtime = 0;
  var workDays = 0;
  final dailyIntervals = <String, List<(DateTime, DateTime)>>{};
  for (final entry in groups.entries) {
    final day = parseCalendarDate(entry.key)!;
    final midnight = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).subtract(const Duration(hours: 7));
    final times = <String, List<DateTime>>{};
    for (final scan in entry.value) {
      final code = scan['windowCode']?.toString() ?? '';
      final raw = scan['scannedAt']?.toString() ?? '';
      final parsed = _parseScanInstant(raw);
      if (![
            'morning_in',
            'lunch_out',
            'afternoon_in',
            'leave',
          ].contains(code) ||
          parsed == null) {
        issues.add(entry.key);
        continue;
      }
      times.putIfAbsent(code, () => []).add(parsed.toUtc());
    }
    for (final list in times.values) {
      list.sort();
    }
    final intervals = <(DateTime, DateTime)>[];
    for (final pair in [
      ('morning_in', 'lunch_out'),
      ('afternoon_in', 'leave'),
    ]) {
      final ins = times[pair.$1];
      final outs = times[pair.$2];
      if (ins == null && outs == null) continue;
      if (ins == null || outs == null) {
        issues.add(entry.key);
        continue;
      }
      final start = ins.first;
      final end = outs.last;
      if (start.isBefore(midnight) ||
          !start.isBefore(midnight.add(const Duration(days: 1))) ||
          !end.isAfter(start) ||
          end.difference(start) > const Duration(days: 1)) {
        issues.add(entry.key);
        continue;
      }
      intervals.add((start, end));
    }
    intervals.sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(DateTime, DateTime)>[];
    for (final interval in intervals) {
      if (merged.isNotEmpty && !interval.$1.isAfter(merged.last.$2)) {
        final last = merged.removeLast();
        merged.add((
          last.$1,
          interval.$2.isAfter(last.$2) ? interval.$2 : last.$2,
        ));
      } else {
        merged.add(interval);
      }
    }
    dailyIntervals[entry.key] = merged;
  }
  // Conflicting work dates cannot safely choose which day's pay rules apply.
  // Exclude both dates for review instead of paying physical hours twice.
  final datedIntervals = [
    for (final entry in dailyIntervals.entries)
      for (final interval in entry.value) (entry.key, interval.$1, interval.$2),
  ];
  final conflictingDates = <String>{};
  for (var i = 0; i < datedIntervals.length; i++) {
    for (var j = i + 1; j < datedIntervals.length; j++) {
      final a = datedIntervals[i];
      final b = datedIntervals[j];
      if (a.$1 != b.$1 && a.$2.isBefore(b.$3) && b.$2.isBefore(a.$3)) {
        conflictingDates.addAll([a.$1, b.$1]);
      }
    }
  }
  issues.addAll(conflictingDates);
  for (final entry in dailyIntervals.entries) {
    if (conflictingDates.contains(entry.key)) continue;
    if (entry.value.isNotEmpty) workDays++;
    final day = parseCalendarDate(entry.key)!;
    final cutoff = DateTime.utc(day.year, day.month, day.day)
        .subtract(const Duration(hours: 7))
        .add(Duration(minutes: settings.otStartMinute));
    for (final interval in entry.value) {
      final total = interval.$2.difference(interval.$1).inMinutes;
      final before = math.max(
        0,
        math.min(total, cutoff.difference(interval.$1).inMinutes),
      );
      regular += before;
      overtime += total - before;
    }
  }
  return PayEstimate(
    regularMinutes: regular,
    otMinutes: overtime,
    settings: settings,
    issueDates: issues.toList()..sort(),
    workDays: workDays,
  );
}
