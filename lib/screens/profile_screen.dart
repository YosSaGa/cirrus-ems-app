import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../services/technician_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_panel.dart';
import '../widgets/session_transition.dart';
import '../widgets/fade_slide_entry.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/shimmer_box.dart';
import '../widgets/status_banner.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'saved_accounts_screen.dart';
import 'settings_screen.dart';

// claude_prompt.txt (v98 Phase 2 -- Full UX/UI Redesign Implementation,
// Stage 5): the approved identity-header + borderless detail-list
// composition. `_loadUser()`'s call to `AuthService.fetchMe()` and its
// try/catch/setState structure are completely unchanged from v95/v97.
//
// claude_prompt.txt (v123 -- Implement Bottom Navigation Shell §3C): this
// screen is now also reached as the Profile tab inside `MainShell` (an
// `IndexedStack` entry, never popped), in addition to its original
// `Navigator.push` entry point from AttendanceScreen's own AppBar icon --
// both create their own independent `ProfileScreen` instance/state, which
// is an accepted, explicitly-flagged redundancy (see this round's
// PROGRESS_LOG.md report), not something this round resolved. Added: a
// SETTINGS section (a stub entry only -- task §3C "do not implement new
// settings functionality in this version") and a Log Out action
// integrating the exact same `AuthService.logout()` call and
// `pushAndRemoveUntil`-to-`LoginScreen` pattern AttendanceScreen's own
// `_logout()` already uses, so behavior is identical regardless of which
// screen the user signs out from.
//
// claude_prompt.txt (v127 -- Add Canonical Employee Code to Profile and
// Remove Stale Can Login Field): the "Can Login" DetailRow (and the
// Divider that existed solely to separate it from "Active") removed --
// per the v126 investigation, it read a `canLogin` JSON key the backend
// has never returned since the `core.users.can_login` column itself was
// permanently dropped by a schema migration; it always rendered "Not
// provided." The "Employee Code" DetailRow immediately above it is
// unchanged -- it already read the correct `employeeCode` key, which
// `AuthService.fetchMe()`'s backing endpoint now actually populates (from
// `core.employees.employee_code`, see ems-backend's own `auth.service.ts`
// for that half of this round's change).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  List<String> _roles = [];
  bool _loading = true;
  String? _errorMessage;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final result = await AuthService.fetchMe();

      if (!mounted) return;

      final user = result['user'];
      final roles = result['roles'];

      setState(() {
        _user = user is Map<String, dynamic> ? user : null;
        _roles = roles is List
            ? roles.map((role) => role.toString()).toList()
            : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.neutral,
        letterSpacing: 0.2,
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
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );

  Widget _profileField({
    required IconData icon,
    required String label,
    String? value,
    bool secondary = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: AppColors.neutral),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
                SelectableText(
                  value == null || value.isEmpty
                      ? AppStrings.t('Not provided', 'ไม่ระบุ')
                      : value,
                  style: TextStyle(
                    fontSize: secondary ? 13 : 16,
                    fontWeight: secondary ? FontWeight.w500 : FontWeight.w700,
                    color: secondary
                        ? AppColors.textSecondary
                        : AppColors.neutral,
                    letterSpacing: secondary ? 0.2 : 0.3,
                  ),
                ),
              ],
            ),
          ),
          if (value != null && value.isNotEmpty)
            IconButton(
              tooltip: AppStrings.t('Copy', 'คัดลอก', 'Salin'),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: Icon(
                Icons.copy_rounded,
                size: 19,
                color: AppColors.textSecondary,
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                HapticFeedback.selectionClick();
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        AppStrings.t(
                          'Copied $label',
                          'คัดลอก$labelแล้ว',
                          '$label disalin',
                        ),
                      ),
                    ),
                  );
              },
            ),
        ],
      ),
    );

  // claude_prompt.txt (v123 §3C): no settings functionality exists yet to
  // open -- this is the stub entry the task explicitly calls for ("Include
  // a Settings entry or section" while "Do not implement new settings
  // functionality in this version").
  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  // claude_prompt.txt (v123 §3C): identical sequence to AttendanceScreen's
  // own `_logout()` -- `AuthService.logout()` then
  // `pushAndRemoveUntil(..., (route) => false)` to `LoginScreen`, clearing
  // the entire navigation stack (including this screen, whichever of its
  // two entry points it was reached from).
  Future<void> _openSwitchAccountSheet() async {
    if (_loggingOut) return;
    HapticFeedback.selectionClick();

    var recent = await AuthService.getRecentAccounts();
    if (!mounted) return;
    final currentUsername =
        (_user?['username'] ?? _user?['email'] ?? _user?['employeeCode'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    final selected = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.hero),
        ),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.t(
                    'Switch Account',
                    'สลับบัญชีผู้ใช้',
                    'Tukar Akaun',
                  ),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.neutral,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.t(
                    'Switch instantly within 5 days; inactive accounts require password re-entry.',
                    'สลับบัญชีได้ทันทีภายใน 5 วัน หากไม่ได้ใช้งานเกิน 5 วันต้องใส่รหัสผ่านใหม่',
                    'Tukar serta-merta dalam 5 hari; akaun tidak aktif perlu kata laluan.',
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                for (final account
                    in recent.take(AuthService.quickSwitchMaxAccounts)) ...[
                  Builder(
                    builder: (_) {
                      final isCurrent =
                          account.username.toLowerCase() == currentUsername;
                      final instant = account.canInstantSwitch;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          border: Border.all(
                            color: isCurrent
                                ? AppColors.secondary
                                : AppColors.cardBorder,
                            width: isCurrent ? 1.5 : 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.input,
                              ),
                            ),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.neutral,
                            child: Text(
                              account.name.isNotEmpty
                                  ? account.name.characters.first.toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          title: Text(
                            account.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.neutral,
                            ),
                          ),
                          subtitle: Text(
                            account.employeeCode != null &&
                                    account.employeeCode!.isNotEmpty
                                ? '${account.username} · #${account.employeeCode}'
                                : account.username,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: isCurrent
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withValues(
                                      alpha: 0.16,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.pill,
                                    ),
                                  ),
                                  child: Text(
                                    AppStrings.t('ACTIVE', 'กำลังใช้งาน'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      instant
                                          ? Icons.bolt_rounded
                                          : Icons.lock_outline_rounded,
                                      size: 16,
                                      color: instant
                                          ? AppColors.secondary
                                          : AppColors.textSecondary,
                                    ),
                                    IconButton(
                                      tooltip: AppStrings.t('Remove', 'ลบออก'),
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: AppColors.textSecondary,
                                      ),
                                      onPressed: () async {
                                        await AuthService.removeRecentAccount(
                                          account.username,
                                        );
                                        final next =
                                            await AuthService.getRecentAccounts();
                                        setSheetState(() => recent = next);
                                      },
                                    ),
                                  ],
                                ),
                          onTap: isCurrent
                              ? () => Navigator.of(sheetCtx).pop()
                              : () => Navigator.of(sheetCtx).pop(account),
                          ),
                        ),
                      );
                    },
                  ),
                ],
                if (recent.length > AuthService.quickSwitchMaxAccounts) ...[
                  const SizedBox(height: 2),
                  OutlinedButton.icon(
                    key: const Key('view-all-switched-accounts-button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.neutral,
                      side: BorderSide(color: AppColors.cardBorder),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    icon: const Icon(Icons.people_outline_rounded, size: 18),
                    label: Text(
                      AppStrings.t(
                        'View all accounts (${recent.length})',
                        'ดูบัญชีที่เคยสลับทั้งหมด (${recent.length})',
                        'Lihat semua akaun (${recent.length})',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => Navigator.of(sheetCtx).pop('VIEW_ALL'),
                  ),
                  const SizedBox(height: 8),
                ] else
                  const SizedBox(height: 6),
                FilledButton.icon(
                  key: const Key('switch-another-account-button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.neutral,
                    foregroundColor: AppColors.onNeutral,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: Text(
                    AppStrings.t(
                      'Use another account',
                      'เข้าสู่ระบบด้วยบัญชีอื่น',
                      'Guna akaun lain',
                    ),
                  ),
                  onPressed: () => Navigator.of(sheetCtx).pop('NEW_ACCOUNT'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;
    if (selected == 'VIEW_ALL') {
      final chosen = await Navigator.of(context).push<Object?>(
        MaterialPageRoute<Object?>(
          builder: (_) => SavedAccountsScreen(currentUsername: currentUsername),
        ),
      );
      if (!mounted) return;
      await _handleSwitchSelection(chosen);
      return;
    }
    await _handleSwitchSelection(selected);
  }

  String? _technicianExitWarning() {
    if (!AuthService.hasTechnicianRole(_roles)) return null;
    final dash = TechnicianService.lastDashboardData;
    if (dash?.activeSession != null) {
      final jobCode = dash!.activeSession!.jobCode;
      return AppStrings.t(
        'You are currently ON SITE ($jobCode). Please Check Out before leaving, or continue anyway?',
        'คุณกำลังทำงานค้างอยู่ ($jobCode) แนะนำให้เช็คเอาท์ก่อน ต้องการดำเนินการต่อหรือไม่?',
        'Anda sedang bertugas ($jobCode). Sila daftar keluar dahulu, atau teruskan?',
      );
    }
    if (dash?.pendingReportSession != null) {
      final jobCode = dash!.pendingReportSession!.jobCode;
      return AppStrings.t(
        'You have a pending work report ($jobCode). Leaving now will keep it unsubmitted. Continue?',
        'คุณมีรายงานการทำงานค้างส่ง ($jobCode) ต้องการดำเนินการต่อหรือไม่?',
        'Anda mempunyai laporan kerja tertunda ($jobCode). Teruskan?',
      );
    }
    return null;
  }

  Future<void> _handleSwitchSelection(Object? selected) async {
    if (selected == null || !mounted) return;
    final techWarning = _technicianExitWarning();
    if (techWarning != null) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('switch-account-warning-dialog'),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.surface),
          ),
          title: Text(
            AppStrings.t(
              'Active Work Warning',
              'แจ้งเตือนงานค้างอยู่',
              'Amaran Kerja Aktif',
            ),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.neutral,
            ),
          ),
          content: Text(
            techWarning,
            style: TextStyle(color: AppColors.error),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(AppStrings.t('Cancel', 'ยกเลิก', 'Batal')),
            ),
            FilledButton(
              key: const Key('confirm-switch-account-warning-button'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(AppStrings.t('Continue', 'ดำเนินการต่อ', 'Teruskan')),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    if (selected == 'NEW_ACCOUNT') {
      await _performSignOut(revokeInstantSwitch: false);
      return;
    }
    if (selected is RecentAccount) {
      setState(() => _loggingOut = true);
      final switched = await AuthService.switchToAccount(selected);
      if (!mounted) return;
      if (switched) {
        Navigator.of(context).pushAndRemoveUntil(
          sessionTransition(context, const MainShell()),
          (route) => false,
        );
      } else {
        setState(() => _loggingOut = false);
        await _performSignOut(
          lockedAccount: selected,
          revokeInstantSwitch: false,
        );
      }
    }
  }

  Future<void> _performSignOut({
    RecentAccount? lockedAccount,
    bool revokeInstantSwitch = true,
  }) async {
    if (_loggingOut) return;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final stopwatch = Stopwatch()..start();

    setState(() => _loggingOut = true);

    TechnicianService.clearCachedDashboard();
    await AuthService.logout(revokeInstantSwitch: revokeInstantSwitch);

    if (!reducedMotion) {
      const minHoldMs = 700;
      final remaining = minHoldMs - stopwatch.elapsedMilliseconds;
      if (remaining > 0) {
        await Future<void>.delayed(Duration(milliseconds: remaining));
      }
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      sessionTransition(
        context,
        LoginScreen(lockedAccount: lockedAccount),
      ),
      (route) => false,
    );
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    HapticFeedback.lightImpact();

    bool hasPending = false;
    try {
      final pending = await AttendanceService.getPendingRequestForCurrentUser();
      hasPending = pending.state == PendingAttendanceRequestState.valid;
    } catch (_) {}
    if (!mounted) return;

    final techWarning = _technicianExitWarning();
    final hasWarning = hasPending || techWarning != null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: techWarning != null ? const Key('logout-warning-dialog') : null,
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.surface),
        ),
        title: Text(
          AppStrings.t('Log out?', 'ออกจากระบบหรือไม่?', 'Log keluar?'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.neutral,
          ),
        ),
        content: Text(
          techWarning ??
              (hasPending
                  ? AppStrings.t(
                      'You have a pending check-in waiting to be sent. Logging out will discard it. Continue?',
                      'คุณมีรายการลงเวลาที่รอส่งอยู่ หากออกจากระบบรายการค้างนี้จะถูกลบ ต้องการออกจากระบบใช่หรือไม่?',
                      'Anda mempunyai daftar masuk tertunda. Log keluar akan membuangnya. Teruskan?',
                    )
                  : AppStrings.t(
                      'Are you sure you want to sign out of your account?',
                      'คุณต้องการออกจากระบบบัญชีนี้ใช่หรือไม่?',
                      'Adakah anda pasti mahu log keluar daripada akaun anda?',
                    )),
          style: TextStyle(
            color: hasWarning ? AppColors.error : AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppStrings.t('Cancel', 'ยกเลิก', 'Batal')),
          ),
          FilledButton(
            key: const Key('confirm-logout-button'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppStrings.t('Log Out', 'ออกจากระบบ', 'Log Keluar')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _performSignOut();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeService.themeModeNotifier,
        LanguageService.languageNotifier,
      ]),
      builder: (context, _) {
        final textTheme = Theme.of(context).textTheme;
        final name =
            _user?['name']?.toString() ?? AppStrings.t('User', 'ผู้ใช้งาน');
        final email = _user?['email']?.toString() ?? '';

        return Scaffold(
          backgroundColor: AppColors.primary,
          appBar: AppBar(
            title: Text(AppStrings.t('Profile', 'โปรไฟล์')),
            actions: [
              IconButton(
                tooltip: AppStrings.t('Refresh profile', 'รีเฟรชโปรไฟล์'),
                onPressed: _loading
                    ? null
                    : () {
                        setState(() => _loading = true);
                        _loadUser();
                      },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: SafeArea(
        child: Center(
          child: RefreshIndicator(
            color: AppColors.secondary,
            onRefresh: _loadUser,
            child: SingleChildScrollView(
              primary: true,
              physics: const AlwaysScrollableScrollPhysics(),
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
                child: _loading
                    ? const Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ShimmerCardSkeleton(height: 170),
                          SizedBox(height: AppSpacing.lg),
                          ShimmerCardSkeleton(height: 160),
                          SizedBox(height: AppSpacing.lg),
                          ShimmerCardSkeleton(height: 76),
                        ],
                      )
                  : _errorMessage != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StatusBanner(
                          variant: StatusVariant.error,
                          title: AppStrings.t(
                            'Unable to load user information',
                            'ไม่สามารถโหลดข้อมูลผู้ใช้ได้',
                          ),
                          message: _errorMessage!,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        PrimaryActionButton(
                          label: AppStrings.t('Try again', 'ลองใหม่อีกครั้ง'),
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _errorMessage = null;
                            });
                            _loadUser();
                          },
                        ),
                      ],
                    )
                  : _user == null
                  ? Text(
                      AppStrings.t(
                        'No user information available.',
                        'ไม่พบข้อมูลผู้ใช้งาน',
                      ),
                      style: textTheme.bodyMedium,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FadeSlideEntry(
                          yOffset: 12,
                          child: AmbientPanel(
                            centered: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: 18,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: Column(
                              children: [
                                FadeSlideEntry(
                                  scaleBegin: 0.85,
                                  yOffset: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.secondary,
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.secondary.withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 30,
                                      backgroundColor:
                                          AppColors.avatarBackground,
                                      child: Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : 'U',
                                        style: TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.avatarForeground,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: LanguageService.isThai ? 24 : 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing:
                                        LanguageService.isThai ? 0.1 : 0.6,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                SelectableText(
                                  email,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.white70,
                                  ),
                                ),
                                if (_roles.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  Wrap(
                                    spacing: AppSpacing.sm,
                                    runSpacing: AppSpacing.sm,
                                    alignment: WrapAlignment.center,
                                    children: _roles
                                        .map(
                                          (role) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: AppColors.roleBadgeIcon.withValues(alpha: 0.45)),
                                              color:
                                                  AppColors.roleBadgeBackground,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadius.pill,
                                                  ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.verified_user_rounded,
                                                  size: 14,
                                                  color:
                                                      AppColors.roleBadgeIcon,
                                                ),
                                                const SizedBox(width: 5),
                                                Flexible(child: Text(
                                                  role,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors
                                                        .roleBadgeForeground,
                                                  ),
                                                )),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        FadeSlideEntry(
                          yOffset: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _sectionLabel(
                                AppStrings.t(
                                  'Account & Employment',
                                  'ข้อมูลบัญชีและการทำงาน',
                                ),
                              ),
                              _groupCard([
                                _profileField(
                                  icon: Icons.tag,
                                  label: AppStrings.t('Employee Code', 'รหัสพนักงาน'),
                                  value: _user!['employeeCode']?.toString(),
                                ),
                                const Divider(height: 1),
                                _profileField(
                                  icon: Icons.phone_outlined,
                                  label: AppStrings.t('Phone', 'เบอร์โทรศัพท์'),
                                  value: _user!['phone']?.toString(),
                                ),
                                const Divider(height: 1),
                                _profileField(
                                  icon: Icons.badge_outlined,
                                  label: AppStrings.t('User ID', 'รหัสผู้ใช้'),
                                  value: _user!['id']?.toString(),
                                  secondary: true,
                                ),
                              ]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        FadeSlideEntry(
                          yOffset: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _sectionLabel(
                                AppStrings.t('General', 'ทั่วไป'),
                              ),
                              _groupCard([
                                Material(
                                  type: MaterialType.transparency,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xs,
                                    ),
                                    leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.settings_outlined,
                                        size: 20,
                                        color: AppColors.neutral,
                                      ),
                                    ),
                                    title: Text(
                                      AppStrings.t('Settings', 'ตั้งค่า'),
                                    ),
                                    subtitle: Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          AppStrings.themeTitle(
                                            ThemeService.currentMode,
                                          ),
                                        ),
                                        Text(
                                          ' · ${LanguageService.currentLanguage.nativeName}',
                                        ),
                                      ],
                                    ),
                                    trailing: Icon(
                                      Icons.chevron_right,
                                      color: AppColors.textSecondary,
                                    ),
                                    onTap: _openSettings,
                                  ),
                                ),
                              ]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        FadeSlideEntry(
                          yOffset: 8,
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              key: const Key('switch-account-button'),
                              onPressed: _loggingOut
                                  ? null
                                  : _openSwitchAccountSheet,
                              icon: Icon(
                                Icons.switch_account_outlined,
                                color: AppColors.neutral,
                              ),
                              label: Text(
                                AppStrings.t(
                                  'Switch Account',
                                  'สลับบัญชีผู้ใช้',
                                  'Tukar Akaun',
                                ),
                                style: TextStyle(
                                  color: AppColors.neutral,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: AppColors.surface,
                                side: BorderSide(color: AppColors.cardBorder),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FadeSlideEntry(
                          yOffset: 8,
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _loggingOut ? null : _logout,
                              icon: _loggingOut
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      Icons.logout_rounded,
                                      color: AppColors.error,
                                    ),
                              label: Text(
                                _loggingOut
                                    ? AppStrings.t(
                                        'Signing out…',
                                        'กำลังออกจากระบบ…',
                                      )
                                    : AppStrings.t('Log Out', 'ออกจากระบบ'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.error,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppColors.error.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                backgroundColor: AppColors.surface,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
