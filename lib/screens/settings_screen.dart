import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/app_preferences_service.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/language_service.dart';
import '../services/shift_reminder_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_slide_entry.dart';
import 'appearance_settings_screen.dart';
import 'device_check_screen.dart';
import 'help_faq_screen.dart';
import 'language_settings_screen.dart';
import 'leave_approval_screen.dart';
import 'payroll_management_screen.dart';
import 'storage_cache_screen.dart';
import 'technician_history_screen.dart';

export 'appearance_settings_screen.dart';
export 'device_check_screen.dart';
export 'language_settings_screen.dart';
export 'payroll_management_screen.dart';
export 'storage_cache_screen.dart';
export 'technician_history_screen.dart';
export 'theme_settings_screen.dart';

/// Main settings menu screen.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _canManagePayroll = false;
  bool _canApproveLeave = false;
  bool _isTechnician = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final results = await Future.wait([
      AuthService.canManagePayroll(),
      AuthService.canApproveLeave(),
      AuthService.isTechnician(),
    ]);
    final allowedPayroll = results[0];
    final allowedLeave = results[1];
    final isTech = results[2];
    if (mounted &&
        (allowedPayroll != _canManagePayroll ||
            allowedLeave != _canApproveLeave ||
            isTech != _isTechnician)) {
      setState(() {
        _canManagePayroll = allowedPayroll;
        _canApproveLeave = allowedLeave;
        _isTechnician = isTech;
      });
    }
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.textSecondary,
      ),
    ),
  );

  Widget _groupCard(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.surface),
      border: Border.all(color: AppColors.cardBorder),
      boxShadow: [
        BoxShadow(
          color: AppColors.neutral.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );

  Widget _settingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: AppColors.secondary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutral,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeService.themeModeNotifier,
        ThemeService.payCardStyleNotifier,
        LanguageService.languageNotifier,
        AppPreferencesService.hapticsEnabledNotifier,
        AppPreferencesService.jobAlertsEnabledNotifier,
        AppPreferencesService.soundEffectsEnabledNotifier,
        BiometricService.biometricLockEnabledNotifier,
        ShiftReminderService.shiftRemindersEnabledNotifier,
      ]),
      builder: (context, _) {
        final activeMode = ThemeService.currentMode;
        final activeCard = ThemeService.currentPayCardStyle;
        final activeLanguage = LanguageService.currentLanguage;
        final cardName = AppStrings.isThai
            ? activeCard.nameTh
            : activeCard.nameEn;
        return Scaffold(
          backgroundColor: AppColors.primary,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.neutral,
            iconTheme: IconThemeData(color: AppColors.neutral),
            title: Text(AppStrings.t('Settings', 'ตั้งค่า')),
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  appTabBottomPadding(context),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: appContentMaxWidth(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // PREFERENCES
                      FadeSlideEntry(
                        yOffset: 8,
                        child: _sectionLabel(
                          AppStrings.t('PREFERENCES', 'การปรับแต่ง'),
                        ),
                      ),
                      FadeSlideEntry(
                        yOffset: 10,
                        child: _groupCard([
                          _settingsItem(
                            icon: Icons.palette_outlined,
                            title: AppStrings.t('Appearance', 'รูปลักษณ์'),
                            subtitle:
                                '${AppStrings.themeTitle(activeMode)} · $cardName',
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textSecondary,
                              size: 22,
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const AppearanceSettingsScreen(),
                                ),
                              );
                            },
                          ),
                        ]),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // SYSTEM
                      FadeSlideEntry(
                        yOffset: 12,
                        child: _sectionLabel(
                          AppStrings.t('SYSTEM', 'ระบบ'),
                        ),
                      ),
                      FadeSlideEntry(
                        yOffset: 14,
                        child: _groupCard([
                          _settingsItem(
                            icon: Icons.language_rounded,
                            title: AppStrings.t('Language', 'ภาษา'),
                            subtitle: activeLanguage.displayName,
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textSecondary,
                              size: 22,
                            ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const LanguageSettingsScreen(),
                                  ),
                                );
                              },
                            ),
                            Divider(height: 1, color: AppColors.cardBorder),
                            _settingsItem(
                              icon: Icons.health_and_safety_outlined,
                              title: AppStrings.t(
                                'Device & Connection Check',
                                'ตรวจกล้อง GPS และเซิร์ฟเวอร์',
                                'Semak Peranti & Sambungan',
                              ),
                              subtitle: AppStrings.t(
                                'Test server health, GPS permission & camera',
                                'เช็กสถานะเซิร์ฟเวอร์ สิทธิ์ GPS และกล้อง',
                                'Uji pelayan, kebenaran GPS & kamera',
                              ),
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textSecondary,
                                size: 22,
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const DeviceCheckScreen(),
                                  ),
                                );
                              },
                            ),
                            Divider(height: 1, color: AppColors.cardBorder),
                            _settingsItem(
                              icon: Icons.vibration_rounded,
                              title: AppStrings.t(
                                'Haptic Feedback',
                                'การสั่นตอบสนอง',
                                'Maklum Balas Haptik',
                              ),
                              subtitle: AppStrings.t(
                                'Vibrate on check-in, taps & alerts',
                                'สั่นเบาๆ เมื่อกดปุ่มลงเวลาหรือแจ้งเตือน',
                                'Getar semasa daftar masuk & amaran',
                              ),
                              trailing: Switch.adaptive(
                                key: const Key('settings-haptics-switch'),
                                value: AppPreferencesService.hapticsEnabled,
                                activeThumbColor: AppColors.secondary,
                                onChanged:
                                    AppPreferencesService.setHapticsEnabled,
                              ),
                            ),
                            Divider(height: 1, color: AppColors.cardBorder),
                            _settingsItem(
                              icon: Icons.volume_up_outlined,
                              title: AppStrings.t(
                                'Sound & Celebration Effects',
                                'เสียงและเอฟเฟกต์แจ้งเตือนสำเร็จ',
                                'Kesan Bunyi & Animasi',
                              ),
                              subtitle: AppStrings.t(
                                'Play chime and confirmation overlay',
                                'แสดงเอฟเฟกต์และเสียงเบาๆ เมื่อทำรายการสำเร็จ',
                                'Mainkan bunyi & paparan pengesahan',
                              ),
                              trailing: Switch.adaptive(
                                key: const Key('settings-sound-effects-switch'),
                                value:
                                    AppPreferencesService.soundEffectsEnabled,
                                activeThumbColor: AppColors.secondary,
                                onChanged: AppPreferencesService
                                    .setSoundEffectsEnabled,
                              ),
                            ),
                            Divider(height: 1, color: AppColors.cardBorder),
                            _settingsItem(
                              icon: Icons.fingerprint_rounded,
                              title: AppStrings.t(
                                'Biometric Pay Lock',
                                'ล็อกหน้าค่าแรงด้วยสแกนนิ้ว / Face ID',
                                'Kunci Biometrik Gaji',
                              ),
                              subtitle: AppStrings.t(
                                'Require biometric unlock for Pay & E-Payslip',
                                'ต้องยืนยันตัวตนก่อนดูค่าแรงและสลิปเงินเดือน',
                                'Perlukan biometrik untuk buka Gaji & E-Slip',
                              ),
                              trailing: Switch.adaptive(
                                key: const Key('settings-biometric-switch'),
                                value: BiometricService.biometricLockEnabled,
                                activeThumbColor: AppColors.secondary,
                                onChanged:
                                    BiometricService.setBiometricLockEnabled,
                              ),
                            ),
                            Divider(height: 1, color: AppColors.cardBorder),
                            _settingsItem(
                              icon: Icons.alarm_on_rounded,
                              title: AppStrings.t(
                                'Shift Scan Reminders',
                                'แจ้งเตือนเวลาสแกน 4 ช่วง',
                                'Peringatan Imbas Syif',
                              ),
                              subtitle: AppStrings.t(
                                'Daily alerts at 07:55, 12:00, 13:00, 17:00',
                                'เตือนอัตโนมัติเวลา 07:55, 12:00, 13:00 และ 17:00',
                                'Peringatan harian 07:55, 12:00, 13:00, 17:00',
                              ),
                              trailing: Switch.adaptive(
                                key: const Key('settings-shift-reminders-switch'),
                                value: ShiftReminderService.enabled,
                                activeThumbColor: AppColors.secondary,
                                onChanged: ShiftReminderService.setEnabled,
                              ),
                            ),
                            if (_isTechnician) ...[
                              Divider(height: 1, color: AppColors.cardBorder),
                              _settingsItem(
                                icon: Icons.notifications_active_outlined,
                                title: AppStrings.t(
                                  'New Job Alerts',
                                  'แจ้งเตือน Job Code ใหม่',
                                  'Makluman Kerja Baharu',
                                ),
                                subtitle: AppStrings.t(
                                  'Show banner when a new job arrives',
                                  'เด้งแถบแจ้งเตือนเมื่อมีใบงานใหม่เข้า',
                                  'Papar sepanduk apabila kerja baharu tiba',
                                ),
                                trailing: Switch.adaptive(
                                  key: const Key('settings-job-alerts-switch'),
                                  value: AppPreferencesService.jobAlertsEnabled,
                                  activeThumbColor: AppColors.secondary,
                                  onChanged:
                                      AppPreferencesService.setJobAlertsEnabled,
                                ),
                              ),
                            ],
                            Divider(height: 1, color: AppColors.cardBorder),
                            _settingsItem(
                              icon: Icons.donut_large_rounded,
                              title: AppStrings.t(
                                'Storage & Cache',
                                'พื้นที่จัดเก็บและแคช',
                                'Storan & Cache',
                              ),
                              subtitle: AppStrings.t(
                                'View cache breakdown & free up space',
                                'ดูรายละเอียดแคชแต่ละส่วนและล้างแคช',
                                'Lihat pecahan cache & kosongkan ruang',
                              ),
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textSecondary,
                                size: 22,
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const StorageCacheScreen(),
                                  ),
                                );
                              },
                            ),
                          ]),
                        ),
                      const SizedBox(height: AppSpacing.lg),

                      if (_isTechnician) ...[
                        // TECHNICIAN & ADMIN — Job & Report History
                        FadeSlideEntry(
                          yOffset: 15,
                          child: _sectionLabel(
                            AppStrings.t('TECHNICIAN', 'งานช่าง', 'JURUTEKNIK'),
                          ),
                        ),
                        FadeSlideEntry(
                          yOffset: 16,
                          child: _groupCard([
                            _settingsItem(
                              icon: Icons.assignment_turned_in_outlined,
                              title: AppStrings.t(
                                'Job & Report History',
                                'ประวัติงานและรายงานช่าง',
                                'Sejarah Kerja & Laporan',
                              ),
                              subtitle: AppStrings.t(
                                'Completed jobs, sessions & submitted work reports',
                                'ดูย้อนหลังงานที่ทำและรายงานที่ส่งแล้ว',
                                'Kerja selesai, sesi & laporan kerja dihantar',
                              ),
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textSecondary,
                                size: 22,
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const TechnicianHistoryScreen(),
                                  ),
                                );
                              },
                            ),
                          ]),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      if (_canManagePayroll || _canApproveLeave) ...[
                        // MANAGEMENT (HR / Admin / Accountant / Manager / Owner)
                        FadeSlideEntry(
                          yOffset: 15,
                          child: _sectionLabel(
                            AppStrings.t('MANAGEMENT', 'การจัดการ'),
                          ),
                        ),
                        FadeSlideEntry(
                          yOffset: 16,
                          child: _groupCard([
                            if (_canApproveLeave) ...[
                              KeyedSubtree(
                                key: const Key('settings-leave-approval-tile'),
                                child: _settingsItem(
                                  icon: Icons.fact_check_outlined,
                                  title: AppStrings.t(
                                    'Leave Approvals',
                                    'อนุมัติใบลาพนักงาน',
                                    'Kelulusan Cuti',
                                  ),
                                  subtitle: AppStrings.t(
                                    'Review, approve or reject employee leave requests',
                                    'ตรวจสอบ อนุมัติ หรือปฏิเสธคำขอลาของพนักงาน',
                                    'Semak, lulus atau tolak permohonan cuti pekerja',
                                  ),
                                  trailing: Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.textSecondary,
                                    size: 22,
                                  ),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const LeaveApprovalScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (_canManagePayroll)
                                Divider(height: 1, color: AppColors.cardBorder),
                            ],
                            if (_canManagePayroll)
                              _settingsItem(
                                icon: Icons.account_balance_wallet_outlined,
                                title: AppStrings.t(
                                  'Payroll & Deductions',
                                  'จัดการค่าแรงและรายการหัก',
                                ),
                                subtitle: AppStrings.t(
                                  'Hourly rate, Accommodation, Social Security, Work Insurance',
                                  'เรทต่อชั่วโมง · ค่าที่พัก · ประกันสังคม · ค่าประกันงาน',
                                ),
                                trailing: Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textSecondary,
                                  size: 22,
                                ),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const PayrollManagementScreen(),
                                    ),
                                  );
                                },
                              ),
                          ]),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      // ABOUT
                      FadeSlideEntry(
                        yOffset: 16,
                        child: _sectionLabel(
                          AppStrings.t('ABOUT', 'เกี่ยวกับแอป'),
                        ),
                      ),
                      FadeSlideEntry(
                        yOffset: 18,
                        child: _groupCard([
                          KeyedSubtree(
                            key: const Key('settings-help-faq-tile'),
                            child: _settingsItem(
                              icon: Icons.help_outline_rounded,
                              title: AppStrings.t(
                                'Help & FAQ',
                                'คู่มือ & คำถามที่พบบ่อย',
                                'Bantuan & Soalan Lazim',
                              ),
                              subtitle: AppStrings.t(
                                'Quick guide & common questions',
                                'วิธีใช้งานแอปและคำถามที่พบบ่อย',
                                'Panduan ringkas & soalan lazim',
                              ),
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textSecondary,
                                size: 22,
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const HelpFaqScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          Divider(height: 1, color: AppColors.cardBorder),
                          _settingsItem(
                            icon: Icons.info_outline_rounded,
                            title: 'Cirrus EMS',
                            subtitle: AppStrings.t(
                              'Version 1.0.0-beta (Build 2026.11)',
                              'เวอร์ชัน 1.0.0-beta (Build 2026.11)',
                              'Versi 1.0.0-beta (Build 2026.11)',
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
