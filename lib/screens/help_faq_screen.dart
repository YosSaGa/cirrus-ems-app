import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_panel.dart';

/// Quick guide and frequently asked questions screen accessible from Settings.
class HelpFaqScreen extends StatefulWidget {
  const HelpFaqScreen({super.key});

  @override
  State<HelpFaqScreen> createState() => _HelpFaqScreenState();
}

class _HelpFaqScreenState extends State<HelpFaqScreen> {
  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          AppStrings.t(
            'Help & Guide',
            'คู่มือ & คำถามที่พบบ่อย',
            'Bantuan & Panduan',
          ),
          style: TextStyle(
            color: AppColors.neutral,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
          children: [
            AmbientPanel(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: AppColors.secondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.t(
                            'Cirrus EMS Quick Guide',
                            'คู่มือใช้งาน Cirrus EMS',
                            'Panduan Ringkas Cirrus EMS',
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.t(
                            'Tap a question below to view the answer.',
                            'แตะหัวข้อด้านล่างเพื่อดูคำตอบแบบย่อ',
                            'Ketik soalan di bawah untuk lihat jawapan.',
                          ),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.onNeutralMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < items.length; i++)
              _faqCard(i, items[i].question, items[i].answer),
          ],
        ),
      ),
    );
  }

  Widget _faqCard(int index, String question, String answer) {
    final isOpen = _expanded.contains(index);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.surface),
        border: Border.all(
          color: isOpen
              ? AppColors.secondary.withValues(alpha: 0.55)
              : AppColors.cardBorder,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('help-faq-item-$index'),
          borderRadius: BorderRadius.circular(AppRadius.surface),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (isOpen) {
                _expanded.remove(index);
              } else {
                _expanded.add(index);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        question,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isOpen ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: isOpen
                      ? Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              answer,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_FaqItem> _buildItems() => [
    _FaqItem(
      question: AppStrings.t(
        'Do in-app scans sync with the fingerprint machine?',
        'สแกนในแอปกับเครื่องสแกนนิ้วเชื่อมกันไหม?',
        'Adakah imbasan aplikasi disegerakkan dengan mesin cap jari?',
      ),
      answer: AppStrings.t(
        'Yes. Both save to the same system and auto-sync every 15 seconds. Grey button means that window is already recorded or not open yet.',
        'เชื่อมข้อมูลเดียวกันและอัปเดตอัตโนมัติทุก 15 วินาทีครับ หากปุ่มเป็นสีเทาแปลว่าช่วงนั้นสแกนแล้วหรือยังไม่ถึงเวลาเปิดรับ',
        'Ya. Kedua-duanya disimpan dalam sistem yang sama dan dikemas kini setiap 15 saat.',
      ),
    ),
    _FaqItem(
      question: AppStrings.t(
        'How do Check In, Break, and Check Out work for technicians?',
        'ช่างเริ่มงาน พักเบรก และจบงานยังไง?',
        'Bagaimanakah Check In, Rehat, dan Check Out berfungsi?',
      ),
      answer: AppStrings.t(
        'Pick your Job Code and tap Check In (or Start Job). Tap Take a Break for lunch, Resume Work after, and Check Out when done.',
        'เลือก Job Code แล้วกด Check In (หรือ Start Job ถ้าสแกนเข้างานแล้ว) กด Take a Break ตอนพัก และกด Check Out เมื่อเลิกงานครับ',
        'Pilih Kod Kerja dan ketik Check In (atau Start Job), Take a Break untuk rehat, dan Check Out apabila selesai.',
      ),
    ),
    _FaqItem(
      question: AppStrings.t(
        'When is the work report due?',
        'ต้องส่งรายงานการทำงานภายในกี่โมง?',
        'Bilakah laporan kerja perlu dihantar?',
      ),
      answer: AppStrings.t(
        'Submit on the same day before 07:00 AM the next morning. If multiple technicians share a job, each person submits their own report.',
        'ส่งภายในวันนั้นและไม่เกิน 07:00 น. วันถัดไปครับ ถ้างานเดียวกันทำหลายคน ให้ส่งรายงานแยกเป็นรายคน',
        'Hantar sebelum jam 07:00 pagi keesokan harinya. Setiap juruteknik menghantar laporan masing-masing.',
      ),
    ),
    _FaqItem(
      question: AppStrings.t(
        'When is the payroll cutoff and payday?',
        'รอบตัดเงินเดือนและวันเงินออกคือวันไหน?',
        'Bilakah tarikh potong gaji dan hari gaji?',
      ),
      answer: AppStrings.t(
        'Pay Estimate counts from the 26th of the previous month to the 25th of the current month, with payday on the 5th. Local Leave exports a PDF for HR.',
        'ตัดรอบวันที่ 26 เดือนก่อน – 25 เดือนนี้ และเงินเข้าวันที่ 5 เดือนถัดไปครับ ส่วนใบลาสามารถกด View PDF เพื่อส่งให้ HR ได้เลย',
        'Kitaran gaji adalah dari 26hb hingga 25hb, dan hari gaji pada 5hb bulan berikutnya.',
      ),
    ),
    _FaqItem(
      question: AppStrings.t(
        'Camera or GPS not working?',
        'เปิดกล้องหรือจับพิกัด GPS ไม่ได้ทำยังไง?',
        'Kamera atau GPS tidak berfungsi?',
      ),
      answer: AppStrings.t(
        'Open Settings > Device & Connection Check to test permissions and server status, or pull down on the screen to refresh.',
        'เข้า Settings > Device & Connection Check เพื่อตรวจสิทธิ์กล้อง/GPS และสถานะเซิร์ฟเวอร์ หรือปัดหน้าจอลงเพื่อรีเฟรชครับ',
        'Buka Tetapan > Semakan Peranti & Sambungan untuk menyemak kebenaran kamera dan GPS.',
      ),
    ),
  ];
}

class _FaqItem {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}
