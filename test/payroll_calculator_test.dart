import 'package:flutter_test/flutter_test.dart';
import 'package:cirrus_app/models/payroll_calculator.dart';

Map<String, dynamic> scan(
  String code,
  String at, {
  String date = '2026-11-02',
}) => {'windowCode': code, 'scannedAt': at, 'workDate': date};

void main() {
  test(
    'paired scans split regular and bonus time and flag incomplete dates',
    () {
      final scans = [
        scan('morning_in', '2026-11-02T08:00:00+07:00'),
        scan('lunch_out', '2026-11-02T12:00:00+07:00'),
        scan('afternoon_in', '2026-11-02T13:00:00+07:00'),
        scan('leave', '2026-11-02T18:00:00+07:00'),
        scan('morning_in', '2026-11-03T08:00:00+07:00', date: '2026-11-03'),
      ];
      final result = calculateScanPay(
        scans,
        DateTime(2026, 11),
        PaySettings.fromDailyWage(300),
      );
      expect(result.workDays, 1);
      expect(result.regularMinutes, 480);
      expect(result.regularSatang, 30000);
      expect(result.otMinutes, 60);
      expect(result.issueDates, contains('2026-11-03'));
    },
  );
  test('daily wage options convert using eight hours and fixed 1.5 OT', () {
    for (final wage in [300, 400, 500]) {
      final settings = PaySettings.fromDailyWage(wage);
      expect(settings.hourlySatang, wage * 100 ~/ 8);
      expect(settings.otMultiplier, 1.5);
      final day = PayEstimate(
        regularMinutes: 480,
        otMinutes: 120,
        settings: settings,
      );
      expect(day.regularSatang, wage * 100);
      expect(day.totalSatang, (wage * 100 * 11 / 8).round());
    }
    expect(() => PaySettings.fromDailyWage(350), throwsArgumentError);
  });
  final settings = PaySettings(hourlySatang: 10000, otMultiplier: 1.5);
  test('exclude conflicting overnight work dates instead of paying twice', () {
    final result = calculateScanPay(
      [
        scan('afternoon_in', '2026-11-02T22:00:00+07:00'),
        scan('leave', '2026-11-03T02:00:00+07:00'),
        scan('morning_in', '2026-11-03T01:00:00+07:00', date: '2026-11-03'),
        scan('lunch_out', '2026-11-03T03:00:00+07:00', date: '2026-11-03'),
      ],
      DateTime(2026, 11),
      settings,
    );
    expect(result.totalSatang, 0);
    expect(result.issueDates, ['2026-11-02', '2026-11-03']);
  });
  test('reject overflowing clock fields rather than normalizing them', () {
    for (final clock in ['08:60:00', '08:70:00', '24:00:00', '08:30:60']) {
      final result = calculateScanPay(
        [
          scan('morning_in', '2026-11-02T$clock+07:00'),
          scan('lunch_out', '2026-11-02T12:00:00+07:00'),
        ],
        DateTime(2026, 11),
        settings,
      );
      expect(result.totalSatang, 0);
      expect(result.issueDates, ['2026-11-02']);
    }
  });
  test('minute and second 59 are valid clock boundaries', () {
    final result = calculateScanPay(
      [
        scan('morning_in', '2026-11-02T08:59:59+07:00'),
        scan('lunch_out', '2026-11-02T12:00:59+07:00'),
      ],
      DateTime(2026, 11),
      settings,
    );
    expect(result.regularMinutes, 181);
    expect(result.issueDates, isEmpty);
  });
  test('split paid work at Bangkok 17:00, exclude lunch', () {
    final result = calculateScanPay(
      [
        scan('morning_in', '2026-11-02T01:00:00Z'),
        scan('lunch_out', '2026-11-02T05:00:00Z'),
        scan('afternoon_in', '2026-11-02T06:00:00Z'),
        scan('leave', '2026-11-02T12:00:00Z'),
      ],
      DateTime(2026, 11),
      settings,
    );
    expect(result.regularMinutes, 480);
    expect(result.otMinutes, 120);
    expect(result.totalSatang, 110000);
    expect(result.issueDates, isEmpty);
  });
  test('merge overlap and duplicates without paying twice', () {
    final result = calculateScanPay(
      [
        scan('morning_in', '2026-11-02T08:00:00+07:00'),
        scan('morning_in', '2026-11-02T09:00:00+07:00'),
        scan('lunch_out', '2026-11-02T14:00:00+07:00'),
        scan('afternoon_in', '2026-11-02T13:00:00+07:00'),
        scan('leave', '2026-11-02T18:00:00+07:00'),
      ],
      DateTime(2026, 11),
      settings,
    );
    expect(result.regularMinutes, 540);
    expect(result.otMinutes, 60);
  });
  test('do not invent missing scans or count uncounted/invalid rows', () {
    final result = calculateScanPay(
      [
        scan('morning_in', '2026-11-02T08:00:00+07:00'),
        {...scan('lunch_out', '2026-11-02T12:00:00+07:00'), 'counted': false},
        scan('afternoon_in', 'not a date'),
        scan('leave', '2026-11-02T18:00:00+07:00'),
      ],
      DateTime(2026, 11),
      settings,
    );
    expect(result.totalSatang, 0);
    expect(result.issueDates, ['2026-11-02']);
  });
  test('overnight is attributed to workDate and cutoff can change', () {
    final result = calculateScanPay(
      [
        scan('afternoon_in', '2026-11-30T22:00:00+07:00', date: '2026-11-30'),
        scan('leave', '2026-12-01T02:00:00+07:00', date: '2026-11-30'),
        scan('morning_in', '2026-12-02T08:00:00+07:00', date: '2026-12-02'),
      ],
      DateTime(2026, 11),
      settings,
    );
    expect(result.otMinutes, 240);
    expect(result.regularMinutes, 0);
    final early = calculateScanPay(
      [
        scan('afternoon_in', '2026-11-02T15:00:00+07:00'),
        scan('leave', '2026-11-02T18:00:00+07:00'),
      ],
      DateTime(2026, 11),
      PaySettings(hourlySatang: 10000, otStartMinute: 16 * 60),
    );
    expect(early.regularMinutes, 60);
    expect(early.otMinutes, 120);
  });
  test('reject ambiguous timestamps and reversed intervals', () {
    for (final rows in [
      [
        scan('morning_in', '2026-11-02T08:00:00'),
        scan('lunch_out', '2026-11-02T12:00:00'),
      ],
      [
        scan('morning_in', '2026-11-02T12:00:00Z'),
        scan('lunch_out', '2026-11-02T08:00:00Z'),
      ],
    ]) {
      final result = calculateScanPay(rows, DateTime(2026, 11), settings);
      expect(result.totalSatang, 0);
      expect(result.issueDates, isNotEmpty);
    }
  });
  test('round monthly components to satang and reject bad numeric input', () {
    final result = PayEstimate(
      regularMinutes: 1,
      otMinutes: 1,
      settings: settings,
    );
    expect(result.regularSatang, 167);
    expect(result.otSatang, 250);
    expect(result.totalSatang, 417);
    expect(() => PaySettings(hourlySatang: -1), throwsArgumentError);
    expect(
      () => PaySettings(hourlySatang: 100, otMultiplier: double.nan),
      throwsArgumentError,
    );
    expect(
      () => PayEstimate(regularMinutes: -1, otMinutes: 0, settings: settings),
      throwsArgumentError,
    );
  });

  test('PayrollCycle resolves cutoff 25th (26 prev -> 25 curr) and payday 5th', () {
    final onCutoff = PayrollCycle.forDate(DateTime(2026, 11, 25));
    expect(onCutoff.year, 2026);
    expect(onCutoff.month, 11);
    expect(onCutoff.start, DateTime(2026, 10, 26));
    expect(onCutoff.end, DateTime(2026, 11, 25));
    expect(onCutoff.payday, DateTime(2026, 12, 5));
    expect(onCutoff.hasEnded(DateTime(2026, 11, 25)), isFalse);
    expect(onCutoff.hasEnded(DateTime(2026, 11, 26)), isTrue);

    final afterCutoff = PayrollCycle.forDate(DateTime(2026, 11, 26));
    expect(afterCutoff.year, 2026);
    expect(afterCutoff.month, 12);
    expect(afterCutoff.start, DateTime(2026, 11, 26));
    expect(afterCutoff.end, DateTime(2026, 12, 25));
    expect(afterCutoff.payday, DateTime(2027, 1, 5));

    final yearRollover = PayrollCycle.forDate(DateTime(2026, 12, 26));
    expect(yearRollover.year, 2027);
    expect(yearRollover.month, 1);
    expect(yearRollover.start, DateTime(2026, 12, 26));
    expect(yearRollover.end, DateTime(2027, 1, 25));
    expect(yearRollover.payday, DateTime(2027, 2, 5));
  });

  test('calculateScanPay with periodStart/periodEnd spans 26th to 25th inclusively', () {
    final cycle = PayrollCycle.fromYearMonth(2026, 11);
    final scans = [
      // Excluded: Oct 25 (previous cycle)
      scan('morning_in', '2026-10-25T08:00:00+07:00', date: '2026-10-25'),
      scan('leave', '2026-10-25T17:00:00+07:00', date: '2026-10-25'),
      // Included: Oct 26 (start of Nov cycle) -> 4h
      scan('morning_in', '2026-10-26T08:00:00+07:00', date: '2026-10-26'),
      scan('lunch_out', '2026-10-26T12:00:00+07:00', date: '2026-10-26'),
      // Included: Nov 25 (end of Nov cycle) -> 4h
      scan('morning_in', '2026-11-25T08:00:00+07:00', date: '2026-11-25'),
      scan('lunch_out', '2026-11-25T12:00:00+07:00', date: '2026-11-25'),
      // Excluded: Nov 26 (next cycle)
      scan('morning_in', '2026-11-26T08:00:00+07:00', date: '2026-11-26'),
      scan('leave', '2026-11-26T17:00:00+07:00', date: '2026-11-26'),
    ];
    final result = calculateScanPay(
      scans,
      DateTime(cycle.year, cycle.month),
      settings,
      periodStart: cycle.start,
      periodEnd: cycle.end,
    );
    expect(result.regularMinutes, 480);
    expect(result.workDays, 2);
  });
}
