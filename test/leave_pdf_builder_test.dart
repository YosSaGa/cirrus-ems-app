import 'dart:convert';
import 'dart:io';

import 'package:cirrus_app/services/leave_pdf_builder.dart';
import 'package:cirrus_app/services/work_trial_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'PDF supports Thai, long reasons, one-day leave and cancelled drafts',
    () async {
      final draft = LeaveDraft(
        id: 'example',
        type: LeaveType.sick,
        start: DateTime(2026, 11, 21),
        end: DateTime(2026, 11, 21),
        reason: List.filled(30, 'พบแพทย์และพักรักษาตัว').join(' '),
        createdAt: DateTime.utc(2026, 11, 20, 20),
        cancelled: true,
      );
      final bytes = await buildLeavePdf(
        draft: draft,
        user: {
          'name': 'สมชาย Example',
          'phone': '0123456789',
          'email': 'example@test.invalid',
        },
        roles: ['Employee'],
      );
      expect(ascii.decode(bytes.take(4).toList()), '%PDF');
      expect(bytes.length, greaterThan(1000));
      expect(draft.calendarDays, 1);
      if (Platform.environment['LEAVE_PDF_CAPTURE'] == '1') {
        await File('build/leave-pdf-preview.pdf').writeAsBytes(bytes);
      }
    },
  );

  test('PDF works with an old draft and missing profile fields', () async {
    final draft = LeaveDraft.fromJson({
      'id': 'old',
      'type': 'personal',
      'start': '2026-11-21',
      'end': '2026-11-22',
      'halfDay': false,
      'reason': 'Family',
      'createdAt': '2026-11-20T12:00:00Z',
      'cancelled': false,
    });
    expect(draft.calendarDays, 2);
    final bytes = await buildLeavePdf(draft: draft, user: {}, roles: []);
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });

  test('PDF handles a 1000-character unbroken reason', () async {
    final draft = LeaveDraft(
      id: 'long',
      type: LeaveType.personal,
      start: DateTime(2026, 11, 21),
      end: DateTime(2026, 11, 21),
      reason: List.filled(1000, 'ก').join(),
      createdAt: DateTime.utc(2026, 11, 20),
    );
    final bytes = await buildLeavePdf(draft: draft, user: {}, roles: []);
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    if (Platform.environment['LEAVE_PDF_CAPTURE'] == '1') {
      await File('build/leave-pdf-long.pdf').writeAsBytes(bytes);
    }
  });

  test('Thai formal leave PDF builds with all fields and long reason', () async {
    final draft = LeaveDraft(
      id: 'thai-form-1',
      type: LeaveType.personal,
      start: DateTime(2026, 11, 25),
      end: DateTime(2026, 11, 26),
      reason: 'ติดธุระส่วนตัวที่ต่างจังหวัด',
      createdAt: DateTime.utc(2026, 11, 25, 2),
      cancelled: false,
    );
    final bytes = await buildLeavePdf(
      draft: draft,
      user: {
        'name': 'จิรวัฒน์ จันทร์จ๊อบทำ',
        'employeeCode': '260831',
        'department': 'Operations',
      },
      roles: ['Admin'],
      language: LeavePdfLanguage.th,
    );
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });

  test('Thai formal leave PDF handles missing profile fields and 1000-char reason', () async {
    final draft = LeaveDraft(
      id: 'thai-long',
      type: LeaveType.sick,
      start: DateTime(2026, 11, 25),
      end: DateTime(2026, 11, 25),
      reason: List.filled(1000, 'ข').join(),
      createdAt: DateTime.utc(2026, 11, 25),
      cancelled: true,
    );
    final bytes = await buildLeavePdf(
      draft: draft,
      user: {},
      roles: [],
      language: LeavePdfLanguage.th,
    );
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });
}
