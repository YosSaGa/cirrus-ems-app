import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cirrus_app/services/work_trial_store.dart';
import 'package:cirrus_app/models/payroll_calculator.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('settings and drafts persist per user and never leak', () async {
    final store = WorkTrialStore('alice');
    await store.saveSettings(PaySettings(hourlySatang: 8500));
    await store.addLeave(
      type: LeaveType.sick,
      start: DateTime(2026, 11, 3),
      end: DateTime(2026, 11, 3),
      reason: 'พบแพทย์',
    );
    expect((await WorkTrialStore('alice').loadSettings())!.hourlySatang, 8500);
    expect((await WorkTrialStore('alice').loadLeaves()).single.calendarDays, 1);
    expect(await WorkTrialStore('bob').loadSettings(), isNull);
    expect(await WorkTrialStore('bob').loadLeaves(), isEmpty);
    expect(() => WorkTrialStore(''), throwsArgumentError);
  });
  test('reject reversed dates, blank reasons and overlapping drafts', () async {
    final store = WorkTrialStore('alice');
    Future<void> add(
      DateTime start,
      DateTime end, {
      String reason = 'พักผ่อน',
    }) => store.addLeave(
      type: LeaveType.annual,
      start: start,
      end: end,
      reason: reason,
    );
    await expectLater(
      add(DateTime(2026, 11, 5), DateTime(2026, 11, 4)),
      throwsArgumentError,
    );
    await expectLater(
      add(DateTime(2026, 11, 4), DateTime(2026, 11, 4), reason: ' '),
      throwsArgumentError,
    );
    await add(DateTime(2026, 11, 4), DateTime(2026, 11, 5));
    await expectLater(
      add(DateTime(2026, 11, 5), DateTime(2026, 11, 6)),
      throwsStateError,
    );
    final draft = (await store.loadLeaves()).single;
    await store.cancelLeave(draft.id);
    expect((await store.loadLeaves()).single.cancelled, true);
    await add(DateTime(2026, 11, 5), DateTime(2026, 11, 6));
    expect((await store.loadLeaves()).length, 2);
  });
  test('legacy half-day drafts are treated as one full calendar day', () async {
    final draft = LeaveDraft.fromJson({
      'id': 'legacy-half-day',
      'type': 'annual',
      'start': '2026-11-04',
      'end': '2026-11-04',
      'halfDay': true,
      'reason': 'Personal errand',
      'createdAt': '2026-11-03T12:00:00Z',
      'cancelled': false,
    });
    expect(draft.calendarDays, 1);
    expect(draft.toJson(), isNot(contains('halfDay')));
  });
  test('preserve corrupt storage rather than silently replacing it', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'ems.workTrial.leaves.alice',
      jsonEncode({'bad': true}),
    );
    await expectLater(
      WorkTrialStore('alice').loadLeaves(),
      throwsFormatException,
    );
    expect(
      prefs.getString('ems.workTrial.leaves.alice'),
      jsonEncode({'bad': true}),
    );
  });
}
