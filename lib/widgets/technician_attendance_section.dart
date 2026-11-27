import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../screens/technician_jobs_screen.dart';
import '../services/technician_service.dart';
import '../theme/app_theme.dart';
import 'status_banner.dart';
import 'status_chip.dart';
import 'time_action_button.dart';

/// Subtle Technician Role badge displayed inside the Attendance hero header
/// so technicians immediately know they are in Field Job Attendance mode.
class TechnicianRoleBadge extends StatelessWidget {
  const TechnicianRoleBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('technician-role-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.build_rounded,
            size: 12,
            color: AppColors.secondary,
          ),
          const SizedBox(width: 5),
          Text(
            AppStrings.t('TECHNICIAN', 'โหมดช่าง', 'JURUTEKNIK'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.secondary,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Job Code selector + Check-In / Check-Out action zone for accounts with the
/// `Technician` role. Strictly displays only jobs assigned to the current user.
class TechnicianJobActionZone extends StatelessWidget {
  const TechnicianJobActionZone({
    super.key,
    required this.data,
    required this.selectedJob,
    required this.actionInProgress,
    required this.stageLabel,
    required this.errorMessage,
    required this.onSelectJob,
    required this.onClearJob,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onBreak,
    required this.onResumeFromBreak,
    required this.onEndFromBreak,
    required this.onWriteReport,
    this.onRetry,
    this.alreadyClockedIn = false,
  });

  final TechnicianDashboardData? data;
  final TechnicianJob? selectedJob;
  final bool actionInProgress;
  final String? stageLabel;
  final String? errorMessage;
  final ValueChanged<TechnicianJob> onSelectJob;
  final VoidCallback onClearJob;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final VoidCallback onBreak;
  final ValueChanged<TechnicianWorkSession> onResumeFromBreak;
  final ValueChanged<TechnicianWorkSession> onEndFromBreak;
  final ValueChanged<TechnicianWorkSession> onWriteReport;
  final VoidCallback? onRetry;
  final bool alreadyClockedIn;

  @override
  Widget build(BuildContext context) {
    final active = data?.activeSession;
    final breakSession = data?.breakSession;
    final pendingReport = data?.pendingReportSession;
    final jobs = data?.jobs ?? const <TechnicianJob>[];
    final nextWindow = data?.nextWindowCode;
    final isAfternoon = nextWindow == 'afternoon_in';
    final alreadyTookBreak =
        data?.completedWindows.contains('lunch_out') ?? false;
    final isLoadError =
        data == null && errorMessage != null && errorMessage!.isNotEmpty;

    final String buttonLabel;
    final IconData buttonIcon;
    final String? windowLabel;
    final String? helperText;
    final bool canTap;
    final VoidCallback? onPressed;

    if (pendingReport != null && active == null) {
      buttonLabel = AppStrings.t('Check In', 'เช็คอิน', 'Daftar Masuk');
      buttonIcon = Icons.schedule_rounded;
      windowLabel = null;
      helperText = AppStrings.t(
        'Submit work report for ${pendingReport.jobCode} first',
        'กรุณาส่งรายงานงาน ${pendingReport.jobCode} ก่อนเริ่มงานอื่น',
        'Hantar laporan kerja ${pendingReport.jobCode} dahulu',
      );
      canTap = false;
      onPressed = null;
    } else if (breakSession != null && active == null) {
      buttonLabel = AppStrings.t('Resume Work', 'กลับเข้าทำงาน', 'Sambung Kerja');
      buttonIcon = Icons.play_arrow_rounded;
      windowLabel = AppStrings.t(
        'Resume · ${breakSession.jobCode}',
        'กลับเข้างาน · ${breakSession.jobCode}',
        'Sambung · ${breakSession.jobCode}',
      );
      helperText = AppStrings.t(
        'Tap to resume afternoon shift with photo & GPS',
        'แตะเพื่อกลับเข้าทำงานรอบบ่าย (ถ่ายรูป + GPS)',
        'Ketik untuk sambung kerja petang (foto & GPS)',
      );
      canTap = !actionInProgress;
      onPressed = canTap ? () => onResumeFromBreak(breakSession) : null;
    } else if (active != null) {
      buttonLabel = AppStrings.t('Check Out', 'เช็คเอาท์', 'Daftar Keluar');
      buttonIcon = Icons.logout_rounded;
      windowLabel = AppStrings.t(
        'End Shift · ${active.jobCode}',
        'เลิกงาน · ${active.jobCode}',
        'Tamat Kerja · ${active.jobCode}',
      );
      helperText = AppStrings.t(
        'Tap to check out & write your work report',
        'แตะเพื่อเลิกงานและเขียนรายงานการทำงาน',
        'Ketik untuk daftar keluar & tulis laporan',
      );
      canTap = !actionInProgress;
      onPressed = canTap ? onCheckOut : null;
    } else if (jobs.isEmpty) {
      buttonLabel = alreadyClockedIn
          ? AppStrings.t('Start Job', 'เริ่มงาน', 'Mula Kerja')
          : AppStrings.t('Check In', 'เช็คอิน', 'Daftar Masuk');
      buttonIcon = alreadyClockedIn
          ? Icons.play_arrow_rounded
          : Icons.schedule_rounded;
      windowLabel = null;
      helperText = isLoadError
          ? AppStrings.t(
              'Unable to reach server · tap retry above',
              'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ · แตะลองใหม่ด้านบน',
              'Gagal sambung ke pelayan · ketik cuba lagi di atas',
            )
          : AppStrings.t(
              'No jobs assigned to you today',
              'ยังไม่มี Job Code ที่มอบหมายให้คุณวันนี้',
              'Tiada kod kerja ditetapkan hari ini',
            );
      canTap = false;
      onPressed = null;
    } else if (selectedJob == null) {
      buttonLabel = alreadyClockedIn
          ? AppStrings.t('Start Job', 'เริ่มงาน', 'Mula Kerja')
          : AppStrings.t('Check In', 'เช็คอิน', 'Daftar Masuk');
      buttonIcon = alreadyClockedIn
          ? Icons.play_arrow_rounded
          : Icons.schedule_rounded;
      windowLabel = null;
      helperText = alreadyClockedIn
          ? AppStrings.t(
              'Select your Job Code above to start job',
              'เลือก Job Code ของคุณด้านบนก่อนเริ่มงาน',
              'Pilih Kod Kerja anda di atas untuk mula kerja',
            )
          : AppStrings.t(
              'Select your Job Code above to check in',
              'เลือก Job Code ของคุณด้านบนก่อนเช็คอิน',
              'Pilih Kod Kerja anda di atas untuk daftar masuk',
            );
      canTap = false;
      onPressed = null;
    } else {
      buttonLabel = alreadyClockedIn
          ? AppStrings.t('Start Job', 'เริ่มงาน', 'Mula Kerja')
          : AppStrings.t('Check In', 'เช็คอิน', 'Daftar Masuk');
      buttonIcon = alreadyClockedIn
          ? Icons.play_arrow_rounded
          : Icons.login_rounded;
      windowLabel = alreadyClockedIn
          ? AppStrings.t(
              'Start Job · ${selectedJob!.jobCode}',
              'เริ่มงาน · ${selectedJob!.jobCode}',
              'Mula Kerja · ${selectedJob!.jobCode}',
            )
          : (isAfternoon
                ? AppStrings.t(
                    'Afternoon In · ${selectedJob!.jobCode}',
                    'เข้างานบ่าย · ${selectedJob!.jobCode}',
                    'Masuk Petang · ${selectedJob!.jobCode}',
                  )
                : AppStrings.t(
                    'Morning In · ${selectedJob!.jobCode}',
                    'เข้างานเช้า · ${selectedJob!.jobCode}',
                    'Masuk Pagi · ${selectedJob!.jobCode}',
                  ));
      helperText = alreadyClockedIn
          ? AppStrings.t(
              'Attendance already recorded · tap to start ${selectedJob!.jobCode}',
              'ลงเวลาเข้างานแล้ว · แตะเพื่อเริ่มงาน ${selectedJob!.jobCode}',
              'Kehadiran direkod · ketik untuk mula ${selectedJob!.jobCode}',
            )
          : AppStrings.t(
              'Records photo, attendance & GPS for ${selectedJob!.jobCode}',
              'บันทึกเช็คชื่อ ถ่ายรูป และพิกัด GPS สำหรับ ${selectedJob!.jobCode}',
              'Rekod foto, kehadiran & GPS untuk ${selectedJob!.jobCode}',
            );
      canTap = !actionInProgress;
      onPressed = canTap ? onCheckIn : null;
    }

    final hasActionableJobs = jobs.any((j) => j.isSelectableForCheckIn);
    final showScanReminder =
        active == null &&
        breakSession == null &&
        pendingReport == null &&
        !alreadyClockedIn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pendingReport != null && active == null)
          _pendingReportLockCard(pendingReport)
        else if (breakSession != null && active == null)
          _onBreakBannerCard(breakSession)
        else
          _jobSelectorCard(context, jobs: jobs, active: active),
        if (showScanReminder) ...[
          const SizedBox(height: 10),
          Container(
            key: const Key('technician-scan-reminder-banner'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.warningContainer,
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.55),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.fingerprint_rounded,
                  size: 20,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasActionableJobs
                        ? AppStrings.t(
                            'You have an assigned job — please scan attendance first before starting work.',
                            'มีงานเข้าแล้ว กรุณาไปสแกนเข้างานด้วยก่อนเริ่มงาน',
                            'Anda ada kerja baharu — sila imbas kehadiran dahulu sebelum mula kerja.',
                          )
                        : AppStrings.t(
                            'You have not scanned attendance today — please scan in at the fingerprint device or in the app.',
                            'วันนี้คุณยังไม่ได้สแกนเข้างาน กรุณาไปสแกนนิ้วหรือลงเวลาเข้างานด้วย',
                            'Anda belum mengimbas kehadiran hari ini — sila imbas di mesin cap jari atau aplikasi.',
                          ),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onWarningContainer,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        TimeActionButton(
          label: buttonLabel,
          icon: buttonIcon,
          hint: actionInProgress
              ? stageLabel
              : (windowLabel ?? helperText),
          loading: actionInProgress,
          enabled: canTap,
          onPressed: onPressed,
        ),
        if (active != null && !alreadyTookBreak) ...[
          const SizedBox(height: 14),
          Center(
            child: OutlinedButton.icon(
              key: const Key('technician-break-button'),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.warningContainer,
                foregroundColor: AppColors.onWarningContainer,
                side: BorderSide(
                  color: AppColors.warning.withValues(alpha: 0.55),
                  width: 1.3,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              onPressed: actionInProgress
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      onBreak();
                    },
              icon: Icon(
                Icons.free_breakfast_outlined,
                size: 19,
                color: AppColors.warning,
              ),
              label: Text(
                AppStrings.t(
                  'Take a Break',
                  'พักเบรก / พักเที่ยง',
                  'Rehat Sekejap',
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        if (breakSession != null && active == null) ...[
          const SizedBox(height: 14),
          Container(
            key: const Key('technician-end-from-break-card'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningContainer,
              borderRadius: BorderRadius.circular(AppRadius.surface),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.55),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.t(
                    'On break — would you like to finish work for today?',
                    'กำลังพักอยู่ — วันนี้จะจบงานเลยไหม?',
                    'Sedang rehat — mahu tamat kerja hari ini?',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onWarningContainer,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const Key('technician-end-from-break-button'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.45),
                    ),
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  onPressed: actionInProgress
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          onEndFromBreak(breakSession);
                        },
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: Text(
                    AppStrings.t(
                      'End Shift Now & Write Report',
                      'จบงานเลยและเขียนรายงาน',
                      'Tamat Kerja & Tulis Laporan',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (errorMessage != null && errorMessage!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          StatusBanner(
            variant: StatusVariant.error,
            message: errorMessage!,
          ),
        ],
      ],
    );
  }

  Widget _onBreakBannerCard(TechnicianWorkSession session) {
    return Container(
      key: const Key('technician-on-break-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.surface),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warningContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.free_breakfast_outlined,
              size: 20,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      session.jobCode,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.neutral,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      label: AppStrings.t('ON BREAK', 'กำลังพัก', 'REHAT'),
                      variant: ChipVariant.warning,
                    ),
                  ],
                ),
                if (session.jobTitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    session.jobTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingReportLockCard(TechnicianWorkSession session) {
    return Container(
      key: const Key('technician-pending-report-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.surface),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.assignment_late_outlined,
                  size: 20,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.t(
                        'WORK REPORT REQUIRED',
                        'ต้องเขียนรายงานก่อนเริ่มงานอื่น',
                        'LAPORAN KERJA DIPERLUKAN',
                      ),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${session.jobCode}${session.jobTitle.isNotEmpty ? ' · ${session.jobTitle}' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onWarningContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('open-pending-report-button'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.neutral,
              foregroundColor: AppColors.onNeutral,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            icon: const Icon(Icons.edit_note_rounded, size: 19),
            label: Text(
              AppStrings.t(
                'Write & Submit Report',
                'เขียนและส่งรายงานตอนนี้',
                'Tulis & Hantar Laporan',
              ),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              onWriteReport(session);
            },
          ),
        ],
      ),
    );
  }

  Widget _jobSelectorCard(
    BuildContext context, {
    required List<TechnicianJob> jobs,
    required TechnicianWorkSession? active,
  }) {
    if (active != null) {
      final activeVessel =
          active.vesselName ??
          jobs
              .where((j) => j.id == active.jobId)
              .map((j) => j.vesselName)
              .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
      return Container(
        key: const Key('technician-active-job-card'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.surface),
          border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.7),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.engineering_rounded,
                size: 22,
                color: AppColors.neutral,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        active.jobCode,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.neutral,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusChip(
                        label: AppStrings.t('ON SITE', 'กำลังปฏิบัติงาน', 'BERTUGAS'),
                        variant: ChipVariant.active,
                      ),
                    ],
                  ),
                  if (active.jobTitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      active.jobTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (activeVessel != null && activeVessel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.neutral,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.directions_boat_rounded,
                            size: 15,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              activeVessel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.onNeutral,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (active.checkInAt.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _TechnicianWorkTimer(
                      checkInAtIso: active.checkInAt,
                    ),
                  ],
                  if (active.checkInLatitude != null &&
                      active.checkInLongitude != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'GPS ${active.checkInLatitude!.toStringAsFixed(4)}, ${active.checkInLongitude!.toStringAsFixed(4)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    final myJobsCount = jobs
        .where((j) => j.isSelectableForCheckIn)
        .length;
    final showMyJobsBadge = selectedJob == null && myJobsCount > 0;
    final isLoadError =
        data == null && errorMessage != null && errorMessage!.isNotEmpty;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.surface),
      child: InkWell(
        key: const Key('technician-job-picker'),
        borderRadius: BorderRadius.circular(AppRadius.surface),
        onTap: isLoadError
            ? () {
                HapticFeedback.selectionClick();
                onRetry?.call();
              }
            : jobs.isEmpty
            ? null
            : () async {
                HapticFeedback.selectionClick();
                final result = await Navigator.of(context)
                    .push<TechnicianJobSelectionResult>(
                      MaterialPageRoute(
                        builder: (_) => TechnicianJobsScreen(
                          jobs: jobs,
                          selectedJobId: selectedJob?.id,
                        ),
                      ),
                    );
                if (result == null) return;
                if (result.cleared) {
                  onClearJob();
                } else if (result.job != null) {
                  onSelectJob(result.job!);
                }
              },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.surface),
            border: Border.all(
              color: selectedJob != null
                  ? AppColors.secondary
                  : AppColors.cardBorder,
              width: selectedJob != null ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isLoadError
                              ? AppColors.error.withValues(alpha: 0.12)
                              : AppColors.secondary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isLoadError
                              ? Icons.cloud_off_rounded
                              : selectedJob != null
                              ? Icons.engineering_rounded
                              : Icons.assignment_outlined,
                          size: 20,
                          color: isLoadError
                              ? AppColors.error
                              : AppColors.neutral,
                        ),
                      ),
                      if (showMyJobsBadge)
                        Positioned(
                          right: -5,
                          top: -5,
                          child: Container(
                            key: const Key('technician-my-jobs-badge'),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.surface,
                                width: 1.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.error.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '$myJobsCount',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              AppStrings.t(
                                'JOB CODE',
                                'รหัสงาน (JOB CODE)',
                                'KOD KERJA',
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (showMyJobsBadge) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                child: Text(
                                  AppStrings.t(
                                    '$myJobsCount YOURS',
                                    '$myJobsCount งานของคุณ',
                                    '$myJobsCount KERJA ANDA',
                                  ),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedJob != null
                              ? '${selectedJob!.jobCode}${selectedJob!.title.isNotEmpty ? ' · ${selectedJob!.title}' : ''}'
                              : isLoadError
                              ? AppStrings.t(
                                  'Unable to load jobs — tap to retry',
                                  'โหลดรายการงานไม่สำเร็จ · แตะเพื่อลองใหม่',
                                  'Gagal memuatkan kerja — ketik untuk cuba lagi',
                                )
                              : jobs.isEmpty
                              ? AppStrings.t(
                                  'No jobs available today',
                                  'ยังไม่มีรายการงานในระบบวันนี้',
                                  'Tiada kerja tersedia hari ini',
                                )
                              : AppStrings.t(
                                  'Tap to view all Job Codes (${jobs.length})',
                                  'แตะเพื่อดูและเลือก Job Code (${jobs.length} งาน)',
                                  'Ketik untuk lihat semua Kod Kerja (${jobs.length})',
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: selectedJob != null
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selectedJob != null
                                ? AppColors.neutral
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedJob != null)
                    IconButton(
                      key: const Key('technician-clear-job-button'),
                      tooltip: AppStrings.t(
                        'Unselect job',
                        'ยกเลิกการเลือกงาน',
                        'Nyahpilih kerja',
                      ),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        onClearJob();
                      },
                    ),
                  if (isLoadError)
                    Icon(
                      Icons.refresh_rounded,
                      color: AppColors.error,
                    )
                  else if (jobs.isNotEmpty)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full details of the currently selected or active technician job, rendered
/// inside the bottom activity card below the Check-In button so the primary
/// action stays centered and stable regardless of description length.
class TechnicianSelectedJobDetails extends StatelessWidget {
  const TechnicianSelectedJobDetails({
    super.key,
    required this.job,
    this.isActive = false,
  });

  final TechnicianJob job;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      key: const Key('technician-selected-job-details'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            Text(
              isActive
                  ? AppStrings.t(
                      'ACTIVE JOB DETAILS',
                      'รายละเอียดงานที่กำลังทำ',
                      'BUTIRAN KERJA AKTIF',
                    )
                  : AppStrings.t(
                      'SELECTED JOB DETAILS',
                      'รายละเอียดงานที่เลือก',
                      'BUTIRAN KERJA DIPILIH',
                    ),
              style: textTheme.labelLarge,
            ),
            StatusChip(
              label: job.jobCode,
              variant: ChipVariant.active,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (job.vesselName != null && job.vesselName!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.neutral,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.directions_boat_rounded,
                  size: 15,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    job.vesselName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onNeutral,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (job.title.isNotEmpty)
          Text(
            job.title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.neutral,
            ),
          ),
        if (job.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            job.description,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            if (job.projectName != null && job.projectName!.isNotEmpty)
              _metaItem(Icons.folder_outlined, job.projectName!),
            if (job.scheduleStart != null || job.scheduleEnd != null)
              _metaItem(
                Icons.calendar_today_outlined,
                '${job.scheduleStart ?? '-'} → ${job.scheduleEnd ?? '-'}',
              ),
            if (job.location != null && job.location!.isNotEmpty)
              _metaItem(Icons.location_on_outlined, job.location!),
            _metaItem(Icons.flag_outlined, job.priority.toUpperCase()),
          ],
        ),
      ],
    );
  }

  Widget _metaItem(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: AppColors.textSecondary),
      const SizedBox(width: 4),
      Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    ],
  );
}

/// Today's Technician job session log displayed inside the bottom activity card.
class TechnicianTodaySessionsList extends StatelessWidget {
  const TechnicianTodaySessionsList({
    super.key,
    required this.sessions,
  });

  final List<TechnicianWorkSession> sessions;

  String _fmtTime(String? iso) {
    if (iso == null || iso.isEmpty) return '--:--';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '--:--';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        for (final s in sessions)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: s.isActive ? AppColors.secondary : AppColors.cardBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  s.isActive
                      ? Icons.radio_button_checked
                      : Icons.check_circle_outline,
                  size: 16,
                  color: s.isActive ? AppColors.secondary : AppColors.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s.jobCode}${s.jobTitle.isNotEmpty ? ' · ${s.jobTitle}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_fmtTime(s.checkInAt)} → ${s.isActive ? AppStrings.t('Active', 'กำลังทำงาน', 'Aktif') : _fmtTime(s.checkOutAt)}'
                        '${s.checkInLatitude != null ? ' · GPS ✓' : ''}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (s.durationMinutes != null)
                  Text(
                    '${s.durationMinutes!.round()}m',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutral,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Self-contained 1-second live elapsed work timer for active Technician sessions.
/// Wrapped in [RepaintBoundary] so ticking never repaints the parent Attendance screen.
class _TechnicianWorkTimer extends StatefulWidget {
  const _TechnicianWorkTimer({required this.checkInAtIso});

  final String checkInAtIso;

  @override
  State<_TechnicianWorkTimer> createState() => _TechnicianWorkTimerState();
}

class _TechnicianWorkTimerState extends State<_TechnicianWorkTimer> {
  Timer? _timer;
  DateTime? _startTime;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initStart();
  }

  @override
  void didUpdateWidget(covariant _TechnicianWorkTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checkInAtIso != widget.checkInAtIso) {
      _timer?.cancel();
      _initStart();
    }
  }

  void _initStart() {
    _startTime = DateTime.tryParse(widget.checkInAtIso)?.toLocal();
    _syncElapsed();
    if (_startTime != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(_syncElapsed);
      });
    }
  }

  void _syncElapsed() {
    if (_startTime == null) {
      _elapsed = Duration.zero;
      return;
    }
    final diff = DateTime.now().difference(_startTime!);
    _elapsed = diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        key: const Key('technician-work-timer'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              AppStrings.t('WORKING', 'ทำงานมาแล้ว', 'BEKERJA'),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _format(_elapsed),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: AppColors.neutral,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
