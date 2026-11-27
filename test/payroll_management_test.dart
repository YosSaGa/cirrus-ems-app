import 'package:cirrus_app/models/payroll_calculator.dart';
import 'package:cirrus_app/screens/payroll_management_screen.dart';
import 'package:cirrus_app/services/auth_service.dart';
import 'package:cirrus_app/services/payroll_service.dart';
import 'package:cirrus_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
}
