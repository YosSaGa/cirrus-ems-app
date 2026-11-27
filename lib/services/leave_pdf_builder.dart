import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'work_trial_store.dart';

/// Language template for generated leave PDF documents.
enum LeavePdfLanguage { th, en }

const _thaiMonths = <String>[
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];

String _formatThaiDate(DateTime date) {
  final beYear = date.year + 543;
  return '${date.day} ${_thaiMonths[date.month - 1]} $beYear';
}

String _thaiLeaveTypeLabel(LeaveType type) {
  switch (type) {
    case LeaveType.sick:
      return 'ลาป่วย';
    case LeaveType.personal:
      return 'ลากิจส่วนตัว';
    case LeaveType.annual:
      return 'ลาพักร้อน';
    case LeaveType.unpaid:
      return 'ลาไม่รับค่าจ้าง';
  }
}

/// Creates a draft leave PDF document from locally available profile and leave data.
///
/// Supports both:
/// - [LeavePdfLanguage.th]: Traditional Thai formal leave form ("แบบฟอร์มใบลา")
///   with auto-filled `เรียน หัวหน้า HR`.
/// - [LeavePdfLanguage.en]: Formal corporate English Leave Request Form
///   with auto-filled `To: HR Manager`.
Future<Uint8List> buildLeavePdf({
  required LeaveDraft draft,
  required Map<String, dynamic> user,
  required List<String> roles,
  LeavePdfLanguage language = LeavePdfLanguage.en,
}) async {
  final isThai = language == LeavePdfLanguage.th;
  final regular = pw.Font.ttf(
    await rootBundle.load(
      isThai
          ? 'assets/fonts/THSarabunPSK-Regular.ttf'
          : 'assets/fonts/Sarabun-Regular.ttf',
    ),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load(
      isThai
          ? 'assets/fonts/THSarabunPSK-Bold.ttf'
          : 'assets/fonts/Sarabun-Bold.ttf',
    ),
  );
  final logo = pw.MemoryImage(
    (await rootBundle.load('lib/assets/cirrus_group_logo.png')).buffer
        .asUint8List(),
  );
  final document = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );

  if (isThai) {
    _addThaiFormalPage(
      document: document,
      draft: draft,
      user: user,
      roles: roles,
      logo: logo,
    );
  } else {
    _addEnglishFormalPage(
      document: document,
      draft: draft,
      user: user,
      roles: roles,
      logo: logo,
    );
  }

  return document.save();
}

void _addThaiFormalPage({
  required pw.Document document,
  required LeaveDraft draft,
  required Map<String, dynamic> user,
  required List<String> roles,
  required pw.MemoryImage logo,
}) {
  final created = draft.createdAt.toUtc().add(const Duration(hours: 7));
  final ink = PdfColor.fromHex('#111827');
  final navy = PdfColor.fromHex('#102D40');
  final lineCol = PdfColor.fromHex('#475569');
  final danger = PdfColor.fromHex('#D9383A');

  String cleanText(Object? value) => value?.toString().trim() ?? '';

  final empName = cleanText(user['name']);
  final empRole = roles.isEmpty ? '' : roles.join(', ');
  final empDepartment = cleanText(user['department']);
  final empCode = cleanText(user['employeeCode']);
  final reasonText = draft.reason.trim();

  // TH Sarabun PSK standard official sizing: 16pt body, 20pt heading
  const bodySize = 16.0;
  final bodyStyle = pw.TextStyle(fontSize: bodySize, color: ink);
  final boldStyle = pw.TextStyle(
    fontSize: bodySize,
    fontWeight: pw.FontWeight.bold,
    color: ink,
  );

  pw.Widget dottedField(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    double? width,
  }) => pw.Container(
    width: width,
    padding: const pw.EdgeInsets.only(left: 6, right: 6, bottom: 1),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(
          color: lineCol,
          width: 0.8,
          style: pw.BorderStyle.dotted,
        ),
      ),
    ),
    child: pw.Text(
      text.isEmpty ? ' ' : text,
      textAlign: align,
      style: bodyStyle,
    ),
  );

  pw.Widget checkbox(bool checked) => pw.Container(
    width: 12,
    height: 12,
    alignment: pw.Alignment.center,
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: ink, width: 0.9),
    ),
    child: checked
        ? pw.Text(
            'X',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: navy,
            ),
          )
        : null,
  );

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(56, 40, 56, 44),
      build: (_) => [
        // Top logo + centered title "แบบฟอร์มใบลา"
        pw.Stack(
          alignment: pw.Alignment.center,
          children: [
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Image(logo, width: 108, fit: pw.BoxFit.contain),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'แบบฟอร์มใบลา',
                  style: pw.TextStyle(
                    fontSize: 21,
                    fontWeight: pw.FontWeight.bold,
                    color: ink,
                  ),
                ),
                if (draft.cancelled)
                  pw.Text(
                    '(ยกเลิกแล้ว)',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: danger,
                    ),
                  ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 14),

        // Right-aligned: เขียนที่ / วันที่ (aligned labels)
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 230,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.SizedBox(
                      width: 44,
                      child: pw.Text('เขียนที่', style: bodyStyle),
                    ),
                    pw.Expanded(child: dottedField('Cirrus Marine Co.,Ltd')),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.SizedBox(
                      width: 44,
                      child: pw.Text('วันที่', style: bodyStyle),
                    ),
                    pw.Expanded(child: dottedField(_formatThaiDate(created))),
                  ],
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 12),

        // Left-aligned: เรื่อง / เรียน (auto-filled "หัวหน้า HR")
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: 36,
              child: pw.Text('เรื่อง', style: bodyStyle),
            ),
            pw.SizedBox(
              width: 240,
              child: dottedField('ขออนุญาตลาหยุดงาน'),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: 36,
              child: pw.Text('เรียน', style: bodyStyle),
            ),
            pw.SizedBox(
              width: 240,
              child: dottedField('หัวหน้าฝ่ายทรัพยากรบุคคล'),
            ),
          ],
        ),
        pw.SizedBox(height: 18),

        // Row 1: ข้าพเจ้า ... | ตำแหน่ง ...
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: 48,
              child: pw.Text('ข้าพเจ้า', style: bodyStyle),
            ),
            pw.Expanded(flex: 5, child: dottedField(empName)),
            pw.SizedBox(width: 14),
            pw.SizedBox(
              width: 74,
              child: pw.Text('ตำแหน่ง', style: bodyStyle),
            ),
            pw.Expanded(flex: 4, child: dottedField(empRole)),
          ],
        ),
        pw.SizedBox(height: 8),

        // Row 2: แผนก ... | รหัสพนักงาน ...
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: 48,
              child: pw.Text('แผนก', style: bodyStyle),
            ),
            pw.Expanded(flex: 5, child: dottedField(empDepartment)),
            pw.SizedBox(width: 14),
            pw.SizedBox(
              width: 74,
              child: pw.Text('รหัสพนักงาน', style: bodyStyle),
            ),
            pw.Expanded(flex: 4, child: dottedField(empCode)),
          ],
        ),
        pw.SizedBox(height: 16),

        // ขอลา (underlined heading)
        pw.Text(
          'ขอลา',
          style: pw.TextStyle(
            fontSize: bodySize,
            fontWeight: pw.FontWeight.bold,
            color: ink,
            decoration: pw.TextDecoration.underline,
          ),
        ),
        pw.SizedBox(height: 8),

        // Checkboxes for leave types
        for (final type in LeaveType.values)
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 14, bottom: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                checkbox(type == draft.type),
                pw.SizedBox(width: 10),
                pw.Text(
                  _thaiLeaveTypeLabel(type),
                  style: type == draft.type ? boldStyle : bodyStyle,
                ),
              ],
            ),
          ),
        pw.SizedBox(height: 6),

        // เนื่องจาก (inline label + full-width dotted paragraph)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.SizedBox(
                width: 56,
                child: pw.Text('เนื่องจาก', style: boldStyle),
              ),
            ),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.only(left: 6, right: 6, bottom: 2),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(
                      color: lineCol,
                      width: 0.8,
                      style: pw.BorderStyle.dotted,
                    ),
                  ),
                ),
                child: pw.Paragraph(
                  text: reasonText.isEmpty ? '-' : reasonText,
                  margin: pw.EdgeInsets.zero,
                  textAlign: pw.TextAlign.left,
                  style: pw.TextStyle(
                    fontSize: bodySize,
                    color: ink,
                    lineSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),

        // ตั้งแต่วันที่ ... ถึงวันที่ ... รวมเวลา ... วัน
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('ตั้งแต่วันที่', style: bodyStyle),
            pw.SizedBox(width: 4),
            pw.Expanded(
              flex: 4,
              child: dottedField(
                _formatThaiDate(draft.start),
                align: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text('ถึงวันที่', style: bodyStyle),
            pw.SizedBox(width: 4),
            pw.Expanded(
              flex: 4,
              child: dottedField(
                _formatThaiDate(draft.end),
                align: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text('รวมเวลา', style: bodyStyle),
            pw.SizedBox(width: 4),
            pw.SizedBox(
              width: 38,
              child: dottedField(
                '${draft.calendarDays}',
                align: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(width: 4),
            pw.Text('วัน', style: bodyStyle),
          ],
        ),
        pw.SizedBox(height: 26),

        // Centered closing: ขอแสดงความนับถือ / (ลงชื่อ) / (ชื่อเต็ม)
        pw.Center(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('ขอแสดงความนับถือ', style: bodyStyle),
              pw.SizedBox(height: 22),
              pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('(ลงชื่อ)', style: bodyStyle),
                  pw.SizedBox(width: 6),
                  dottedField('', width: 175),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 34),
                child: pw.Text(
                  empName.isEmpty
                      ? '(                                        )'
                      : '(  $empName  )',
                  style: bodyStyle,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 28),

        // ความคิดเห็นของฝ่ายทรัพยากรบุคคล (2 full-width dotted lines)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('ความคิดเห็นของฝ่ายทรัพยากรบุคคล', style: bodyStyle),
            pw.SizedBox(width: 8),
            pw.Expanded(child: dottedField('')),
          ],
        ),
        pw.SizedBox(height: 16),
        dottedField('', width: double.infinity),
        pw.SizedBox(height: 28),

        // Right-aligned approver signature
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 235,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.SizedBox(
                      width: 38,
                      child: pw.Text('ลงชื่อ', style: bodyStyle),
                    ),
                    pw.Expanded(child: dottedField('')),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.SizedBox(
                      width: 38,
                      child: pw.Text('วันที่', style: bodyStyle),
                    ),
                    pw.Expanded(
                      child: dottedField(
                        '       /            /              ',
                        align: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

const _englishMonths = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatEnglishDate(DateTime date) {
  return '${date.day} ${_englishMonths[date.month - 1]} ${date.year}';
}

void _addEnglishFormalPage({
  required pw.Document document,
  required LeaveDraft draft,
  required Map<String, dynamic> user,
  required List<String> roles,
  required pw.MemoryImage logo,
}) {
  final created = draft.createdAt.toUtc().add(const Duration(hours: 7));
  final ink = PdfColor.fromHex('#111827');
  final navy = PdfColor.fromHex('#102D40');
  final lineCol = PdfColor.fromHex('#475569');
  final danger = PdfColor.fromHex('#D9383A');

  String cleanText(Object? value) => value?.toString().trim() ?? '';

  final empName = cleanText(user['name']);
  final empRole = roles.isEmpty ? '' : roles.join(', ');
  final empDepartment = cleanText(user['department']);
  final empCode = cleanText(user['employeeCode']);
  final reasonText = draft.reason.trim();

  const bodySize = 11.5;
  final bodyStyle = pw.TextStyle(fontSize: bodySize, color: ink);
  final boldStyle = pw.TextStyle(
    fontSize: bodySize,
    fontWeight: pw.FontWeight.bold,
    color: ink,
  );

  pw.Widget dottedField(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    double? width,
  }) => pw.Container(
    width: width,
    padding: const pw.EdgeInsets.only(left: 6, right: 6, bottom: 2),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(
          color: lineCol,
          width: 0.8,
          style: pw.BorderStyle.dotted,
        ),
      ),
    ),
    child: pw.Text(
      text.isEmpty ? ' ' : text,
      textAlign: align,
      style: bodyStyle,
    ),
  );

  pw.Widget checkbox(bool checked) => pw.Container(
    width: 12,
    height: 12,
    alignment: pw.Alignment.center,
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: ink, width: 0.9),
    ),
    child: checked
        ? pw.Text(
            'X',
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: navy,
            ),
          )
        : null,
  );

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(56, 42, 56, 44),
      build: (_) => [
        // Top logo + centered title "LEAVE REQUEST FORM"
        pw.Stack(
          alignment: pw.Alignment.center,
          children: [
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Image(logo, width: 108, fit: pw.BoxFit.contain),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'LEAVE REQUEST FORM',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: ink,
                    letterSpacing: 0.4,
                  ),
                ),
                if (draft.cancelled)
                  pw.Text(
                    '(CANCELLED)',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: danger,
                    ),
                  ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 18),

        // Right-aligned: Location / Date
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 240,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.SizedBox(
                      width: 54,
                      child: pw.Text('Location', style: bodyStyle),
                    ),
                    pw.Expanded(child: dottedField('Cirrus Marine Co.,Ltd')),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.SizedBox(
                      width: 54,
                      child: pw.Text('Date', style: bodyStyle),
                    ),
                    pw.Expanded(
                      child: dottedField(_formatEnglishDate(created)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 14),

        // Left-aligned: Subject / To (auto-filled "HR Manager")
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: 48,
              child: pw.Text('Subject', style: bodyStyle),
            ),
            pw.SizedBox(
              width: 240,
              child: dottedField('Request for Leave of Absence'),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: 48,
              child: pw.Text('To', style: bodyStyle),
            ),
            pw.SizedBox(
              width: 240,
              child: dottedField('Human Resources Manager'),
            ),
          ],
        ),
        pw.SizedBox(height: 20),

        // Row 1: Name ... | Position ...
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: 68,
              child: pw.Text('Name', style: bodyStyle),
            ),
            pw.Expanded(flex: 5, child: dottedField(empName)),
            pw.SizedBox(width: 14),
            pw.SizedBox(
              width: 72,
              child: pw.Text('Position', style: bodyStyle),
            ),
            pw.Expanded(flex: 4, child: dottedField(empRole)),
          ],
        ),
        pw.SizedBox(height: 10),

        // Row 2: Department ... | Employee ID ...
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: 68,
              child: pw.Text('Department', style: bodyStyle),
            ),
            pw.Expanded(flex: 5, child: dottedField(empDepartment)),
            pw.SizedBox(width: 14),
            pw.SizedBox(
              width: 72,
              child: pw.Text('Employee ID', style: bodyStyle),
            ),
            pw.Expanded(flex: 4, child: dottedField(empCode)),
          ],
        ),
        pw.SizedBox(height: 18),

        // Leave Type (underlined heading)
        pw.Text(
          'Leave Type',
          style: pw.TextStyle(
            fontSize: bodySize,
            fontWeight: pw.FontWeight.bold,
            color: ink,
            decoration: pw.TextDecoration.underline,
          ),
        ),
        pw.SizedBox(height: 10),

        // Checkboxes for leave types
        for (final type in LeaveType.values)
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 14, bottom: 7),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                checkbox(type == draft.type),
                pw.SizedBox(width: 10),
                pw.Text(
                  type.label,
                  style: type == draft.type ? boldStyle : bodyStyle,
                ),
              ],
            ),
          ),
        pw.SizedBox(height: 8),

        // Reason (inline label + full-width dotted paragraph)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.SizedBox(
                width: 54,
                child: pw.Text('Reason', style: boldStyle),
              ),
            ),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.only(left: 6, right: 6, bottom: 2),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(
                      color: lineCol,
                      width: 0.8,
                      style: pw.BorderStyle.dotted,
                    ),
                  ),
                ),
                child: pw.Paragraph(
                  text: reasonText.isEmpty ? '-' : reasonText,
                  margin: pw.EdgeInsets.zero,
                  textAlign: pw.TextAlign.left,
                  style: pw.TextStyle(
                    fontSize: bodySize,
                    color: ink,
                    lineSpacing: 2.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),

        // From ... To ... Total ... day(s)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('From', style: bodyStyle),
            pw.SizedBox(width: 6),
            pw.Expanded(
              flex: 4,
              child: dottedField(
                _formatEnglishDate(draft.start),
                align: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Text('To', style: bodyStyle),
            pw.SizedBox(width: 6),
            pw.Expanded(
              flex: 4,
              child: dottedField(
                _formatEnglishDate(draft.end),
                align: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Text('Total', style: bodyStyle),
            pw.SizedBox(width: 6),
            pw.SizedBox(
              width: 36,
              child: dottedField(
                '${draft.calendarDays}',
                align: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(width: 4),
            pw.Text(
              draft.calendarDays == 1 ? 'day' : 'days',
              style: bodyStyle,
            ),
          ],
        ),
        pw.SizedBox(height: 30),

        // Centered closing: Sincerely yours / (Signature) / (Full Name)
        pw.Center(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('Sincerely yours,', style: bodyStyle),
              pw.SizedBox(height: 24),
              pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('(Signature)', style: bodyStyle),
                  pw.SizedBox(width: 6),
                  dottedField('', width: 170),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 52),
                child: pw.Text(
                  empName.isEmpty
                      ? '(                                        )'
                      : '(  $empName  )',
                  style: bodyStyle,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 32),

        // Human Resources Comments (2 full-width dotted lines)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Human Resources Comments', style: bodyStyle),
            pw.SizedBox(width: 8),
            pw.Expanded(child: dottedField('')),
          ],
        ),
        pw.SizedBox(height: 18),
        dottedField('', width: double.infinity),
        pw.SizedBox(height: 32),

        // Right-aligned approver signature
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 240,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.SizedBox(
                      width: 56,
                      child: pw.Text('Signature', style: bodyStyle),
                    ),
                    pw.Expanded(child: dottedField('')),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.SizedBox(
                      width: 56,
                      child: pw.Text('Date', style: bodyStyle),
                    ),
                    pw.Expanded(
                      child: dottedField(
                        '       /            /              ',
                        align: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
