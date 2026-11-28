import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/payroll_calculator.dart';

/// Builds a Cirrus Marine digital E-Payslip PDF document for the selected
/// payroll cycle using bundled Sarabun fonts (full Thai & English support).
class PayslipPdfBuilder {
  static Future<Uint8List> build({
    required String employeeName,
    String? employeeCode,
    String? department,
    required PayrollCycle cycle,
    required PayEstimate estimate,
    required PaySettings settings,
    required List<PayrollAdjustmentItem> adjustments,
  }) async {
    final regularFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Sarabun-Regular.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Sarabun-Bold.ttf'),
    );

    final theme = pw.ThemeData.withFont(base: regularFont, bold: boldFont);
    final doc = pw.Document(theme: theme);

    final navy = PdfColor.fromHex('102D40');
    final teal = PdfColor.fromHex('32D5C0');
    final muted = PdfColor.fromHex('536575');
    final border = PdfColor.fromHex('DFE8EC');
    final softBg = PdfColor.fromHex('F3F6F7');

    final grossSatang = estimate.totalSatang;
    final grossBaht = grossSatang / 100.0;
    final hourlyRateBaht = settings.hourlySatang / 100.0;

    int allowancesSatang = 0;
    int deductionsSatang = 0;
    for (final item in adjustments) {
      if (!item.isActive) continue;
      final satang = item.computeSatang(grossSatang);
      if (!item.isDeduction) {
        allowancesSatang += satang;
      } else {
        deductionsSatang += satang;
      }
    }
    final netPay = ((grossSatang + allowancesSatang - deductionsSatang) / 100.0)
        .clamp(0.0, double.infinity);

    String fmtBaht(double v) => 'THB ${v.toStringAsFixed(2)}';
    String fmtDate(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  color: navy,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'CIRRUS MARINE E-PAYSLIP',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'สลิปเงินเดือนอิเล็กทรอนิกส์ (ประมาณการรอบบัญชี)',
                          style: pw.TextStyle(
                            color: teal,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'PAY PERIOD',
                          style: pw.TextStyle(color: teal, fontSize: 9),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          '${fmtDate(cycle.start)} - ${fmtDate(cycle.end)}',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              // Employee info card
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: softBg,
                  border: pw.Border.all(color: border),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'พนักงาน / Employee',
                          style: pw.TextStyle(color: muted, fontSize: 9),
                        ),
                        pw.Text(
                          employeeName.isEmpty ? 'Employee' : employeeName,
                          style: pw.TextStyle(
                            color: navy,
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'รหัส / Code',
                          style: pw.TextStyle(color: muted, fontSize: 9),
                        ),
                        pw.Text(
                          employeeCode?.isNotEmpty == true ? employeeCode! : '-',
                          style: pw.TextStyle(
                            color: navy,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'แผนก / Department',
                          style: pw.TextStyle(color: muted, fontSize: 9),
                        ),
                        pw.Text(
                          department?.isNotEmpty == true ? department! : '-',
                          style: pw.TextStyle(
                            color: navy,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              // Earnings table
              _sectionTitle('สรุปรายได้ตามเวลาทำงาน / Earnings', navy),
              pw.SizedBox(height: 6),
              _kvTable(
                border: border,
                navy: navy,
                muted: muted,
                rows: [
                  [
                    'ชั่วโมงทำงานปกติ (ก่อน 17:00)',
                    '${(estimate.regularMinutes / 60).toStringAsFixed(2)} hrs',
                    fmtBaht(grossBaht),
                  ],
                  [
                    'อัตราค่าแรงต่อชั่วโมง',
                    '${hourlyRateBaht.toStringAsFixed(2)} THB/hr',
                    '-',
                  ],
                  [
                    'เวลาล่วงเวลาหลัง 17:00 (บันทึกแยก)',
                    '${(estimate.otMinutes / 60).toStringAsFixed(2)} hrs',
                    'Bonus Time',
                  ],
                ],
              ),
              if (adjustments.any((a) => a.isActive)) ...[
                pw.SizedBox(height: 16),
                _sectionTitle('รายการเพิ่ม-หัก / Allowances & Deductions', navy),
                pw.SizedBox(height: 6),
                _kvTable(
                  border: border,
                  navy: navy,
                  muted: muted,
                  rows: adjustments.where((a) => a.isActive).map((item) {
                    final prefix = !item.isDeduction ? '+' : '-';
                    final baht = item.computeSatang(grossSatang) / 100.0;
                    return [
                      item.name,
                      !item.isDeduction ? 'Allowance' : 'Deduction',
                      '$prefix ${fmtBaht(baht)}',
                    ];
                  }).toList(),
                ),
              ],
              pw.SizedBox(height: 18),
              // Net pay highlight
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: navy,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'ยอดรับสุทธิโดยประมาณ / Estimated Net Pay',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      fmtBaht(netPay),
                      style: pw.TextStyle(
                        color: teal,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Divider(color: border),
              pw.Text(
                'เอกสารนี้สร้างจากระบบ Cirrus EMS สำหรับตรวจสอบยอดประมาณการเท่านั้น',
                style: pw.TextStyle(color: muted, fontSize: 9),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _sectionTitle(String text, PdfColor color) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  static pw.Widget _kvTable({
    required PdfColor border,
    required PdfColor navy,
    required PdfColor muted,
    required List<List<String>> rows,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: border),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(1.5),
      },
      children: rows.map((r) {
        return pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(r[0], style: pw.TextStyle(color: navy, fontSize: 10)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(r[1], style: pw.TextStyle(color: muted, fontSize: 10)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                r[2],
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  color: navy,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
