import 'dart:convert';

import 'package:cirrus_app/models/payroll_calculator.dart';
import 'package:cirrus_app/screens/pay_calculator_screen.dart';
import 'package:cirrus_app/screens/work_trial_screen.dart';
import 'package:cirrus_app/services/attendance_service.dart';
import 'package:cirrus_app/services/auth_service.dart';
import 'package:cirrus_app/services/language_service.dart';
import 'package:cirrus_app/services/theme_service.dart';
import 'package:cirrus_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(envString: '', isOptional: true);
    ThemeService.debugReset();
    LanguageService.debugReset();
  });

  tearDown(() {
    AuthService.debugResetClient();
    AttendanceService.debugResetClient();
    ThemeService.debugReset();
    LanguageService.debugReset();
  });

  test('PaySettings.fromMonthlySalary computes salary ÷ baseDays ÷ dailyHours', () {
    final s30 = PaySettings.fromMonthlySalary(16000);
    expect(s30.isSalaryBased, isTrue);
    expect(s30.baseDays, 30);
    expect(s30.dailyHours, 8);
    expect(s30.hourlySatang, 6667); // THB 66.67/hr

    final s22 = PaySettings.fromMonthlySalary(16000, baseDays: 22);
    expect(s22.hourlySatang, 9091); // THB 90.91/hr

    final fallback = PaySettings.forEmployeeSalary(null);
    expect(fallback.isSalaryBased, isFalse);
    expect(fallback.hourlySatang, 3750); // THB 37.50/hr
  });

  testWidgets(
    'EarningsTrialTab uses employee base salary formula and opens PayCalculatorScreen',
    (tester) async {
      final now = bangkokNow();
      final date = calendarDate(DateTime(now.year, now.month, 2));
      SharedPreferences.setMockInitialValues({
        'ems.user': jsonEncode({
          'id': 'salary-user',
          'name': 'Jirawat',
          'salary': 16000,
        }),
        'ems.authToken': 'test-token',
      });
      AuthService.debugOverrideClient(
        MockClient((_) async => http.Response('{}', 200)),
      );
      AttendanceService.debugOverrideClient(
        MockClient((_) async {
          return http.Response(
            jsonEncode([
              {
                'windowCode': 'morning_in',
                'workDate': date,
                'scannedAt': '${date}T08:00:00+07:00',
              },
              {
                'windowCode': 'lunch_out',
                'workDate': date,
                'scannedAt': '${date}T12:00:00+07:00',
              },
              {
                'windowCode': 'afternoon_in',
                'workDate': date,
                'scannedAt': '${date}T13:00:00+07:00',
              },
              {
                'windowCode': 'leave',
                'workDate': date,
                'scannedAt': '${date}T17:00:00+07:00',
              },
            ]),
            200,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const WorkTrialScreen()),
      );
      await tester.pumpAndSettle();

      // 8h × THB 66.67/hr = THB 533.36
      expect(find.text('THB 533.36'), findsOneWidget);
      expect(find.text('THB 66.67 / hr'), findsOneWidget);

      // Open custom Pay Simulator
      final simBtn = find.byKey(const Key('open-pay-calculator'));
      await tester.ensureVisible(simBtn);
      await tester.pumpAndSettle();
      await tester.tap(simBtn);
      await tester.pumpAndSettle();

      expect(find.byType(PayCalculatorScreen), findsOneWidget);
      expect(find.text('Pay Simulator'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('sim-result-amount'))).data,
        'THB 533.33',
      );

      // Change hours to 10h and base days to 22 -> 16000 / 22 / 8 * 10 = 909.09
      await tester.tap(find.text('22 days'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('sim-hours-input')), '10');
      await tester.pumpAndSettle();
      expect(find.text('THB 909.09'), findsOneWidget);

      // Tapping Full month (176h for 22 days) equals exact monthly salary
      final fullMonthChip = find.text('Full month (176h)');
      await tester.ensureVisible(fullMonthChip);
      await tester.pumpAndSettle();
      await tester.tap(fullMonthChip);
      await tester.pumpAndSettle();
      expect(find.text('THB 16,000.00'), findsOneWidget);

      // Change salary to 24000 with 30 days and 10h -> 24000 / 30 / 8 * 10 = 1,000.00
      final days30 = find.text('30 days');
      await tester.ensureVisible(days30);
      await tester.pumpAndSettle();
      await tester.tap(days30);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('sim-salary-input')), '24000');
      await tester.enterText(find.byKey(const Key('sim-hours-input')), '10');
      await tester.pumpAndSettle();
      expect(find.text('THB 1,000.00'), findsOneWidget);
    },
  );
}
