import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../screens/help_faq_screen.dart';
import '../screens/leave_approval_screen.dart';
import '../screens/pay_calculator_screen.dart';
import '../screens/payroll_management_screen.dart';
import '../screens/technician_history_screen.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import 'ambient_panel.dart';
import 'bouncy_tap.dart';
import 'fade_slide_entry.dart';

/// Role-aware navigation drawer providing quick access to secondary features
/// outside the 4-tab bottom navigation bar.
class AppQuickDrawer extends StatefulWidget {
  const AppQuickDrawer({super.key});

  @override
  State<AppQuickDrawer> createState() => _AppQuickDrawerState();
}

class _AppQuickDrawerState extends State<AppQuickDrawer> {
  static final Listenable _uiListenable = Listenable.merge([
    ThemeService.themeModeNotifier,
    LanguageService.languageNotifier,
  ]);

  String _displayName = '';
  List<String> _roles = const [];
  bool _canApproveLeave = false;
  bool _canManagePayroll = false;
  bool _isTechnician = false;

  @override
  void initState() {
    super.initState();
    _loadIdentity();
  }

  Future<void> _loadIdentity() async {
    final results = await Future.wait<dynamic>([
      AuthService.getSavedUser(),
      AuthService.getSavedRoles(),
      AuthService.canApproveLeave(),
      AuthService.canManagePayroll(),
      AuthService.isTechnician(),
    ]);
    if (!mounted) return;
    final user = results[0] as Map<String, dynamic>?;
    final roles = results[1] as List<String>;
    final rawName =
        (user?['name'] ?? user?['fullName'] ?? user?['username'] ?? '')
            .toString()
            .trim();
    setState(() {
      _displayName = rawName;
      _roles = roles;
      _canApproveLeave = results[2] as bool;
      _canManagePayroll = results[3] as bool;
      _isTechnician = results[4] as bool;
    });
  }

  void _openScreen(BuildContext context, Widget screen) {
    HapticFeedback.selectionClick();
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  String _initialFor(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'E';
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _uiListenable,
      builder: (context, _) {
        final displayName = _displayName.isEmpty
            ? AppStrings.t('Employee', 'พนักงาน', 'Pekerja')
            : _displayName;
        final hasManagement = _canApproveLeave || _canManagePayroll;
        final drawerWidth =
            (MediaQuery.sizeOf(context).width * 0.84).clamp(304.0, 390.0);

        return Drawer(
          width: drawerWidth,
          backgroundColor: AppColors.primary,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(AppRadius.surface),
              bottomRight: Radius.circular(AppRadius.surface),
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              children: [
                FadeSlideEntry(
                  delay: Duration.zero,
                  yOffset: 10,
                  child: _DrawerHeader(
                    displayName: displayName,
                    initial: _initialFor(displayName),
                    roles: _roles,
                  ),
                ),
                const SizedBox(height: 16),
                if (hasManagement) ...[
                  FadeSlideEntry(
                    delay: const Duration(milliseconds: 45),
                    yOffset: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionLabel(
                          AppStrings.t('Management', 'การจัดการ', 'Pengurusan'),
                        ),
                        const SizedBox(height: 8),
                        _DrawerCard(
                          children: [
                            if (_canApproveLeave)
                              _DrawerItem(
                                key: const Key('drawer-leave-approvals'),
                                icon: Icons.fact_check_outlined,
                                title: AppStrings.t(
                                  'Leave Approvals',
                                  'อนุมัติใบลา',
                                  'Kelulusan Cuti',
                                ),
                                subtitle: AppStrings.t(
                                  'Review employee requests',
                                  'ตรวจสอบและอนุมัติคำขอลา',
                                  'Semak permohonan cuti',
                                ),
                                onTap: () => _openScreen(
                                  context,
                                  const LeaveApprovalScreen(),
                                ),
                              ),
                            if (_canApproveLeave && _canManagePayroll)
                              _itemDivider(),
                            if (_canManagePayroll)
                              _DrawerItem(
                                key: const Key('drawer-payroll-management'),
                                icon: Icons.account_balance_wallet_outlined,
                                title: AppStrings.t(
                                  'Payroll & Deductions',
                                  'จัดการเรทค่าแรงและรายการหัก',
                                  'Gaji & Potongan',
                                ),
                                subtitle: AppStrings.t(
                                  'Hourly rates & fixed deductions',
                                  'ตั้งค่าเรทต่อชม. และรายการหักประจำ',
                                  'Kadar sejam & potongan tetap',
                                ),
                                onTap: () => _openScreen(
                                  context,
                                  const PayrollManagementScreen(),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_isTechnician) ...[
                  FadeSlideEntry(
                    delay: const Duration(milliseconds: 90),
                    yOffset: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionLabel(
                          AppStrings.t('Technician', 'งานช่าง', 'Juruteknik'),
                        ),
                        const SizedBox(height: 8),
                        _DrawerCard(
                          children: [
                            _DrawerItem(
                              key: const Key('drawer-tech-history'),
                              icon: Icons.engineering_outlined,
                              title: AppStrings.t(
                                'Job & Report History',
                                'ประวัติงานและรายงานช่าง',
                                'Sejarah Kerja & Laporan',
                              ),
                              subtitle: AppStrings.t(
                                'Past work sessions & reports',
                                'ดูประวัติเช็กอินงานและรายงานย้อนหลัง',
                                'Sesi kerja & laporan terdahulu',
                              ),
                              onTap: () => _openScreen(
                                context,
                                const TechnicianHistoryScreen(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                FadeSlideEntry(
                  delay: const Duration(milliseconds: 135),
                  yOffset: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionLabel(
                        AppStrings.t('Tools', 'เครื่องมือ', 'Alat'),
                      ),
                      const SizedBox(height: 8),
                      _DrawerCard(
                        children: [
                          _DrawerItem(
                            key: const Key('drawer-pay-simulator'),
                            icon: Icons.calculate_outlined,
                            title: AppStrings.t(
                              'Pay Simulator',
                              'จำลองคำนวณค่าแรง',
                              'Simulator Gaji',
                            ),
                            subtitle: AppStrings.t(
                              'Estimate daily & hourly pay',
                              'ทดลองคำนวณรายได้บนเครื่อง',
                              'Anggar gaji harian & sejam',
                            ),
                            onTap: () => _openScreen(
                              context,
                              const PayCalculatorScreen(),
                            ),
                          ),
                          _itemDivider(),
                          _DrawerItem(
                            key: const Key('drawer-help-faq'),
                            icon: Icons.help_outline_rounded,
                            title: AppStrings.t(
                              'Help & FAQ',
                              'คู่มือและคำถามที่พบบ่อย',
                              'Bantuan & Soalan Lazim',
                            ),
                            subtitle: AppStrings.t(
                              'Guides & troubleshooting',
                              'วิธีใช้งานและแก้ปัญหาเบื้องต้น',
                              'Panduan & penyelesaian masalah',
                            ),
                            onTap: () =>
                                _openScreen(context, const HelpFaqScreen()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                  ],
                ),
              ),
            );
      },
    );
  }

  Widget _itemDivider() {
    return Divider(
      height: 1,
      indent: 58,
      endIndent: 14,
      color: AppColors.cardBorder,
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.displayName,
    required this.initial,
    required this.roles,
  });

  final String displayName;
  final String initial;
  final List<String> roles;

  @override
  Widget build(BuildContext context) {
    return AmbientPanel(
      centered: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.avatarBackground,
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: AppColors.avatarForeground,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppStrings.t(
                              'Quick Menu',
                              'เมนูลัด',
                              'Menu Pantas',
                            ),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (roles.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: roles.map((role) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: AppColors.secondary.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

class _DrawerCard extends StatelessWidget {
  const _DrawerCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: AppColors.neutral),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.neutral,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
      ),
    );
  }
}
