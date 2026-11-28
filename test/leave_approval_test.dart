import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cirrus_app/screens/leave_approval_screen.dart';
import 'package:cirrus_app/services/auth_service.dart';
import 'package:cirrus_app/services/language_service.dart';
import 'package:cirrus_app/services/leave_service.dart';
import 'package:cirrus_app/services/work_trial_store.dart';

void main() {
  setUp(() async {
    await LanguageService.setLanguage(AppLanguage.en);
  });

  tearDown(() {
    LeaveService.getLeavesOverride = null;
    LeaveService.approveLeaveOverride = null;
    LeaveService.rejectLeaveOverride = null;
  });

  test('hasLeaveApproveAccess allows HR/Admin/Manager/Owner and blocks Staff', () {
    expect(AuthService.hasLeaveApproveAccess(['HR Officer'], []), isTrue);
    expect(AuthService.hasLeaveApproveAccess(['Admin'], []), isTrue);
    expect(AuthService.hasLeaveApproveAccess(['Manager'], []), isTrue);
    expect(AuthService.hasLeaveApproveAccess(['Owner'], []), isTrue);
    expect(AuthService.hasLeaveApproveAccess(['Staff'], ['leave.approve']), isTrue);
    expect(AuthService.hasLeaveApproveAccess(['Staff'], []), isFalse);
    expect(AuthService.hasLeaveApproveAccess(['Technician'], []), isFalse);
  });

  testWidgets('LeaveApprovalScreen blocks Staff role', (tester) async {
    SharedPreferences.setMockInitialValues({
      'ems.roles': jsonEncode(['Staff']),
      'ems.permissions': jsonEncode(<String>[]),
    });

    await tester.pumpWidget(const MaterialApp(home: LeaveApprovalScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('leave-approval-denied')), findsOneWidget);
  });

  testWidgets('LeaveApprovalScreen lists pending leaves for HR and approves/rejects', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'ems.roles': jsonEncode(['HR Officer']),
      'ems.permissions': jsonEncode(<String>[]),
    });

    var status = 'pending';
    String? approvedId;
    String? rejectedId;
    String? rejectedReason;

    LeaveService.getLeavesOverride = ({bool onlyMine = false}) async => [
      LeaveRequestRecord(
        id: 'lv-1',
        employeeId: 'emp-1',
        employeeName: 'Anuwat',
        employeeCode: '26061601',
        leaveType: LeaveType.sick,
        startDate: DateTime(2026, 11, 29),
        endDate: DateTime(2026, 11, 29),
        reason: 'Fever',
        status: status,
        createdAt: DateTime(2026, 11, 28),
      ),
    ];
    LeaveService.approveLeaveOverride = (id, {String? note}) async {
      approvedId = id;
      status = 'approved';
    };
    LeaveService.rejectLeaveOverride = (id, {String? reason}) async {
      rejectedId = id;
      rejectedReason = reason;
      status = 'rejected';
    };

    await tester.pumpWidget(const MaterialApp(home: LeaveApprovalScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('leave-approval-card-lv-1')), findsOneWidget);
    expect(find.text('Anuwat'), findsOneWidget);

    await tester.tap(find.byKey(const Key('approve-leave-lv-1')));
    await tester.pumpAndSettle();
    expect(approvedId, 'lv-1');

    // Reset to pending to test reject dialog
    status = 'pending';
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reject-leave-lv-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Busy shift');
    await tester.tap(find.byKey(const Key('confirm-reject-leave-lv-1')));
    await tester.pumpAndSettle();

    expect(rejectedId, 'lv-1');
    expect(rejectedReason, 'Busy shift');
  });
}
