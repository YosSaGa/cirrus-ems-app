import 'dart:convert';

import 'package:cirrus_app/models/payroll_calculator.dart';
import 'package:cirrus_app/screens/payroll_management_screen.dart';
import 'package:cirrus_app/services/auth_service.dart';
import 'package:cirrus_app/services/payroll_service.dart';
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
  });

  tearDown(() {
    PayrollService.debugReset();
  });

  test('RBAC allows HR Officer, Admin, Accountant, Owner and blocks Staff', () {
    expect(AuthService.hasPayrollManageAccess(['Admin'], []), isTrue);
    expect(AuthService.hasPayrollManageAccess(['HR Officer'], []), isTrue);
    expect(AuthService.hasPayrollManageAccess(['Accountant'], []), isTrue);
    expect(AuthService.hasPayrollManageAccess(['Owner'], []), isTrue);
    expect(
      AuthService.hasPayrollManageAccess(['Staff'], ['payroll.update']),
      isTrue,
    );
    expect(
      AuthService.hasPayrollManageAccess(['Staff', 'Technician'], ['payroll.read']),
      isFalse,
    );
  });

  test('PayrollNetSummary computes hourly gross minus accommodation, SSO cap, and work insurance', () {
    // 160h * 100 THB/hr = 16,000 THB gross
    final settings = PaySettings.fromHourlyRate(100);
    final estimate = PayEstimate(
      regularMinutes: 160 * 60,
      otMinutes: 0,
      settings: settings,
    );
    expect(estimate.regularSatang, 1600000);

    final items = [
      const PayrollAdjustmentItem(
        id: '1',
        employeeId: 'e1',
        code: 'ACCOMMODATION',
        name: 'ค่าที่พัก',
        componentType: 'deduction',
        calcMode: 'fixed',
        amount: 1500,
      ),
      const PayrollAdjustmentItem(
        id: '2',
        employeeId: 'e1',
        code: 'SOCIAL_SECURITY',
        name: 'ค่าประกันสังคม',
        componentType: 'deduction',
        calcMode: 'percent',
        amount: 5,
        maxCap: 750,
      ),
      const PayrollAdjustmentItem(
        id: '3',
        employeeId: 'e1',
        code: 'WORK_INSURANCE',
        name: 'ค่าประกันงาน',
        componentType: 'deduction',
        calcMode: 'fixed',
        amount: 500,
      ),
    ];

    final summary = PayrollNetSummary.calculate(
      grossSatang: estimate.regularSatang,
      items: items,
    );
    // 5% of 16,000 = 800 -> capped at 750
    // Total deductions = 1500 + 750 + 500 = 2,750
    // Net = 16,000 - 2,750 = 13,250
    expect(summary.totalDeductionsSatang, 275000);
    expect(summary.netSatang, 1325000);
  });

  testWidgets('PayrollManagementScreen blocks Staff role', (tester) async {
    SharedPreferences.setMockInitialValues({
      'ems.roles': '["Staff","Technician"]',
      'ems.permissions': '[]',
    });

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const PayrollManagementScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Permission required'), findsOneWidget);
  });

  testWidgets('PayrollManagementScreen lists employees for Accountant role', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'ems.roles': '["Accountant"]',
      'ems.permissions': '["payroll.update"]',
    });
    PayrollService.debugEmployeesLoader = () async => const [
      EmployeePayrollProfile(
        employeeId: 'emp-1',
        employeeCode: '260831',
        name: 'Owen',
        salary: 16000,
        hourlyRate: 80,
        items: [
          PayrollAdjustmentItem(
            id: 'i1',
            employeeId: 'emp-1',
            code: 'ACCOMMODATION',
            name: 'Accommodation',
            componentType: 'deduction',
            calcMode: 'fixed',
            amount: 1500,
          ),
        ],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const PayrollManagementScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Owen'), findsOneWidget);
    expect(find.text('1 deductions'), findsOneWidget);
  });

  test(
    'PayrollService.getMyPayrollConfig skips /payroll/my-config on live API and reads GET /compensation',
    () async {
      dotenv.loadFromString(
        envString: 'API_BASE_URL_ANDROID=https://api.cirrusmarine.site/api/v1/ems',
        isOptional: true,
      );
      SharedPreferences.setMockInitialValues({
        'ems.user': jsonEncode({
          'id': 'u-100',
          'name': 'Jirawat Janjobtam',
          'employeeCode': '260831',
        }),
        'ems.authToken': 'tok',
      });

      var hitMyConfig = false;
      PayrollService.debugOverrideClient(
        MockClient((req) async {
          if (req.url.path.endsWith('/payroll/my-config')) {
            hitMyConfig = true;
            return http.Response('{"message":"Not found"}', 400);
          }
          if (req.url.path.endsWith('/compensation')) {
            return http.Response(
              jsonEncode([
                {
                  'id': 'comp-other',
                  'employeeId': 'emp-other',
                  'compensationType': 'salary',
                  'baseSalary': 99000,
                  'effectiveDate': '2026-01-01',
                  'employee': {'id': 'emp-other', 'employeeCode': '999999'},
                },
                {
                  'id': 'comp-mine',
                  'employeeId': 'emp-100',
                  'compensationType': 'salary',
                  'baseSalary': 18000,
                  'effectiveDate': '2026-11-01',
                  'employee': {
                    'id': 'emp-100',
                    'userId': 'u-100',
                    'employeeCode': '260831',
                    'department': 'Marine Engineering',
                  },
                },
              ]),
              200,
            );
          }
          return http.Response('[]', 404);
        }),
      );

      final cfg = await PayrollService.getMyPayrollConfig();
      expect(hitMyConfig, isFalse);
      expect(cfg.salary, 18000.0);
      expect(cfg.department, 'Marine Engineering');
      expect(cfg.employeeId, 'emp-100');
    },
  );
}
