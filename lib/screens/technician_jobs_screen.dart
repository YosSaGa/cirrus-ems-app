import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../services/technician_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_panel.dart';

List<String> _parseCrewNames(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  final seen = <String>{};
  final names = <String>[];
  for (final part in raw.split(',')) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) continue;
    final key = trimmed.toLowerCase();
    if (seen.add(key)) names.add(trimmed);
  }
  return names;
}

String _formatCompactCrew(List<String> names) {
  if (names.isEmpty) return '';
  if (names.length <= 2) return names.join(', ');
  return '${names[0]}, ${names[1]} +${names.length - 2}';
}

/// Result returned from [TechnicianJobsScreen] / [TechnicianJobDetailScreen].
class TechnicianJobSelectionResult {
  const TechnicianJobSelectionResult._({this.job, this.cleared = false});

  factory TechnicianJobSelectionResult.selected(TechnicianJob job) =>
      TechnicianJobSelectionResult._(job: job);

  factory TechnicianJobSelectionResult.cleared() =>
      const TechnicianJobSelectionResult._(cleared: true);

  final TechnicianJob? job;
  final bool cleared;
}

/// Full-page list of all Job Codes for Technician / Admin mode.
/// Jobs assigned to the logged-in user (`isMine == true`) are highlighted and
/// pinned at the top; tapping any job opens [TechnicianJobDetailScreen].
class TechnicianJobsScreen extends StatefulWidget {
  const TechnicianJobsScreen({
    super.key,
    required this.jobs,
    this.selectedJobId,
  });

  final List<TechnicianJob> jobs;
  final String? selectedJobId;

  @override
  State<TechnicianJobsScreen> createState() => _TechnicianJobsScreenState();
}

class _TechnicianJobsScreenState extends State<TechnicianJobsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TechnicianJob> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.jobs;
    return widget.jobs.where((j) {
      return j.jobCode.toLowerCase().contains(q) ||
          j.title.toLowerCase().contains(q) ||
          j.description.toLowerCase().contains(q) ||
          (j.vesselName?.toLowerCase().contains(q) ?? false) ||
          (j.projectName?.toLowerCase().contains(q) ?? false) ||
          (j.assignedToName?.toLowerCase().contains(q) ?? false);
    }).toList(growable: false);
  }

  Future<bool> _confirmSelectJob(BuildContext context, TechnicianJob job) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        key: const Key('confirm-job-selection-dialog'),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(22, 16, 12, 8),
        actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
        title: Row(
          children: [
            Expanded(
              child: Text(
                AppStrings.t(
                  'Confirm Job Selection',
                  'ยืนยันการเลือกงาน',
                  'Sahkan Pilihan Kerja',
                ),
                style: TextStyle(
                  color: AppColors.neutral,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            IconButton(
              key: const Key('close-select-job-dialog-button'),
              icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.of(dialogCtx).pop(false),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.t(
                'Are you sure you want to work on this job?',
                'ท่านต้องการเลือกทำงานนี้ใช่ไหม?',
                'Adakah anda pasti mahu memilih kerja ini?',
              ),
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.jobCode,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.neutral,
                    ),
                  ),
                  if (job.vesselName != null &&
                      job.vesselName!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.directions_boat_rounded,
                            size: 14,
                            color: AppColors.neutral,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              job.vesselName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.neutral,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (job.title.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      job.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    key: const Key('cancel-select-job-button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.neutral,
                      side: BorderSide(color: AppColors.cardBorder, width: 1.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    onPressed: () => Navigator.of(dialogCtx).pop(false),
                    child: Text(
                      AppStrings.t('No', 'ไม่ใช่', 'Tidak'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: FilledButton(
                    key: const Key('confirm-select-job-button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.neutral,
                      foregroundColor: AppColors.onNeutral,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    onPressed: () => Navigator.of(dialogCtx).pop(true),
                    child: Text(
                      AppStrings.t(
                        'Yes, Select',
                        'ใช่, เลือกงานนี้',
                        'Ya, Pilih',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _openDetail(TechnicianJob job) async {
    HapticFeedback.selectionClick();
    final result = await Navigator.of(context)
        .push<TechnicianJobSelectionResult>(
          MaterialPageRoute(
            builder: (_) => TechnicianJobDetailScreen(
              job: job,
              isSelected: widget.selectedJobId == job.id,
            ),
          ),
        );
    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _filtered;
    final myJobs = all
        .where(
          (j) =>
              j.isMine && !j.isSubmittedAwaitingClose && !j.isClosedOnBackend,
        )
        .toList(growable: false);
    final otherJobs = all
        .where(
          (j) =>
              !j.isMine && !j.isSubmittedAwaitingClose && !j.isClosedOnBackend,
        )
        .toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          AppStrings.t('All Job Codes', 'รายการ Job Code ทั้งหมด', 'Semua Kod Kerja'),
          style: TextStyle(
            color: AppColors.neutral,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: AppStrings.t(
                    'Search job code, vessel, title, or technician...',
                    'ค้นหารหัสงาน ชื่อเรือ ชื่องาน หรือชื่อช่าง...',
                    'Cari kod kerja, kapal, tajuk, atau juruteknik...',
                  ),
                  prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (myJobs.isNotEmpty) ...[
                    _sectionHeader(
                      AppStrings.t(
                        'ASSIGNED TO YOU (${myJobs.length})',
                        'งานที่มอบหมายให้คุณ (${myJobs.length})',
                        'TUGASAN ANDA (${myJobs.length})',
                      ),
                      accent: true,
                    ),
                    const SizedBox(height: 8),
                    for (final job in myJobs) _jobTile(job),
                    const SizedBox(height: 16),
                  ],
                  if (otherJobs.isNotEmpty) ...[
                    _sectionHeader(
                      AppStrings.t(
                        'OTHER JOBS (${otherJobs.length})',
                        'งานอื่นในระบบ (${otherJobs.length})',
                        'KERJA LAIN (${otherJobs.length})',
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final job in otherJobs) _jobTile(job),
                    const SizedBox(height: 16),
                  ],
                  if (myJobs.isEmpty && otherJobs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                      child: Center(
                        child: Text(
                          _query.trim().isEmpty
                              ? AppStrings.t(
                                  'No open jobs right now. Completed jobs are in Job & Report History.',
                                  'ไม่มีงานค้างในตอนนี้ ดูงานที่ทำเสร็จแล้วได้ในประวัติงานและรายงาน',
                                  'Tiada kerja terbuka buat masa ini. Kerja selesai ada di Sejarah Kerja & Laporan.',
                                )
                              : AppStrings.t(
                                  'No matching jobs found.',
                                  'ไม่พบรายการ Job Code ที่ค้นหา',
                                  'Tiada kod kerja ditemui.',
                                ),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priorityPill(String priority) {
    final p = priority.trim().toLowerCase();
    final Color tint;
    final Color textColor;
    switch (p) {
      case 'urgent':
      case 'critical':
        tint = const Color(0xFFEF4444);
        textColor = Colors.red.shade100;
        break;
      case 'high':
        tint = const Color(0xFFF97316);
        textColor = Colors.orange.shade100;
        break;
      case 'medium':
        tint = const Color(0xFF38BDF8);
        textColor = Colors.lightBlue.shade100;
        break;
      default:
        tint = Colors.white;
        textColor = Colors.white.withValues(alpha: 0.9);
    }
    final hasAccent = p == 'urgent' || p == 'critical' || p == 'high' || p == 'medium';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: hasAccent ? 0.24 : 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: hasAccent
            ? Border.all(color: tint.withValues(alpha: 0.85))
            : null,
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }

  Widget _heroDetailRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(
      children: [
        Icon(icon, size: 15, color: AppColors.secondary),
        const SizedBox(width: 7),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.onNeutralMuted,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _sectionHeader(String title, {bool accent = false}) => Row(
    children: [
      if (accent) ...[
        Icon(Icons.star_rounded, size: 16, color: AppColors.secondary),
        const SizedBox(width: 6),
      ],
      Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: accent ? AppColors.neutral : AppColors.textSecondary,
        ),
      ),
    ],
  );

  Widget _jobTile(TechnicianJob job) {
    final isSelected = widget.selectedJobId == job.id;
    final isMine = job.isMine;

    if (!isMine) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.cardBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('job-item-${job.jobCode}'),
            onTap: () => _openDetail(job),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.neutral.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.assignment_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              job.jobCode,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.neutral,
                              ),
                            ),
                            if (job.assignedToName != null &&
                                job.assignedToName!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '· ${_formatCompactCrew(_parseCrewNames(job.assignedToName))}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (job.title.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            job.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (job.vesselName != null &&
                            job.vesselName!.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
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
                                  size: 14,
                                  color: AppColors.secondary,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    job.vesselName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.onNeutral,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: isSelected
              ? Border.all(color: AppColors.secondary, width: 2.2)
              : null,
          boxShadow: [
            BoxShadow(
              color: AppColors.ambientGradientStart.withValues(alpha: 0.20),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: Key('job-item-${job.jobCode}'),
              onTap: () async {
                HapticFeedback.selectionClick();
                if (isSelected) {
                  Navigator.of(context).pop(
                    TechnicianJobSelectionResult.cleared(),
                  );
                } else {
                  final confirmed = await _confirmSelectJob(context, job);
                  if (confirmed && mounted) {
                    Navigator.of(context).pop(
                      TechnicianJobSelectionResult.selected(job),
                    );
                  }
                }
              },
              child: AmbientPanel(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: AppColors.secondary.withValues(alpha: 0.8),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.engineering_rounded,
                                size: 13,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                AppStrings.t(
                                  'YOUR JOB',
                                  'งานของคุณ',
                                  'KERJA ANDA',
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.secondary,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            job.status.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _priorityPill(job.priority),
                        const Spacer(),
                        InkWell(
                          key: Key('job-details-${job.jobCode}'),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            final nav = Navigator.of(context);
                            final res = await nav
                                .push<TechnicianJobSelectionResult>(
                                  MaterialPageRoute(
                                    builder: (_) => TechnicianJobDetailScreen(
                                      job: job,
                                      isSelected: isSelected,
                                    ),
                                  ),
                                );
                            if (res != null && mounted) {
                              nav.pop(res);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  AppStrings.t(
                                    'Details',
                                    'รายละเอียด',
                                    'Butiran',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.check_circle_rounded,
                            size: 22,
                            color: AppColors.secondary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      job.jobCode,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (job.vesselName != null &&
                        job.vesselName!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _VesselHeroBanner(vesselName: job.vesselName!),
                    ],
                    if (job.title.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        job.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                    if (job.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        job.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                    if (job.scheduleStart != null ||
                        job.scheduleEnd != null ||
                        (job.assignedToName != null &&
                            job.assignedToName!.isNotEmpty) ||
                        (job.projectName != null &&
                            job.projectName!.isNotEmpty &&
                            job.projectName!.trim().toLowerCase() !=
                                (job.vesselName ?? '').trim().toLowerCase()) ||
                        (job.location != null &&
                            job.location!.isNotEmpty)) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (job.scheduleStart != null ||
                                job.scheduleEnd != null)
                              _heroDetailRow(
                                Icons.calendar_today_outlined,
                                AppStrings.t('Schedule', 'กำหนดการ', 'Jadual'),
                                '${job.scheduleStart ?? '-'} → ${job.scheduleEnd ?? '-'}',
                              ),
                            if (job.assignedToName != null &&
                                job.assignedToName!.isNotEmpty)
                              _heroDetailRow(
                                Icons.people_outline_rounded,
                                AppStrings.t('Tech', 'ช่าง', 'Juruteknik'),
                                _formatCompactCrew(
                                  _parseCrewNames(job.assignedToName),
                                ),
                              ),
                            if (job.projectName != null &&
                                job.projectName!.isNotEmpty &&
                                job.projectName!.trim().toLowerCase() !=
                                    (job.vesselName ?? '').trim().toLowerCase())
                              _heroDetailRow(
                                Icons.folder_outlined,
                                AppStrings.t('Project', 'โปรเจกต์', 'Projek'),
                                job.projectName!,
                              ),
                            if (job.location != null &&
                                job.location!.isNotEmpty)
                              _heroDetailRow(
                                Icons.location_on_outlined,
                                AppStrings.t('Location', 'สถานที่', 'Lokasi'),
                                job.location!,
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          isSelected
                              ? AppStrings.t(
                                  'Selected · Tap to unselect',
                                  'เลือกไว้แล้ว · แตะเพื่อยกเลิก',
                                  'Dipilih · Ketik untuk nyahpilih',
                                )
                              : AppStrings.t(
                                  'Tap to select for check-in',
                                  'แตะเพื่อเลือกเช็คอินทันที',
                                  'Ketik untuk pilih daftar masuk',
                                ),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: AppColors.secondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dedicated detail screen showing full job information and allowing the owner
/// to select the job for Check-In.
class TechnicianJobDetailScreen extends StatefulWidget {
  const TechnicianJobDetailScreen({
    super.key,
    required this.job,
    this.isSelected = false,
  });

  final TechnicianJob job;
  final bool isSelected;

  @override
  State<TechnicianJobDetailScreen> createState() =>
      _TechnicianJobDetailScreenState();
}

class _TechnicianJobDetailScreenState extends State<TechnicianJobDetailScreen> {
  late TechnicianJob _job = widget.job;
  String? _currentUserName;

  TechnicianJob get job => _job;
  bool get isSelected => widget.isSelected;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadFullDetail();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getSavedUser();
    if (!mounted) return;
    final name = user?['name']?.toString().trim();
    if (name != null && name.isNotEmpty) {
      setState(() => _currentUserName = name);
    }
  }

  Future<void> _loadFullDetail() async {
    final full = await TechnicianService.getJobDetail(
      _job.id,
      fallback: _job,
    );
    if (!mounted || full == null) return;
    setState(() => _job = full);
  }

  @override
  Widget build(BuildContext context) {
    final scheduleText = (job.scheduleStart != null || job.scheduleEnd != null)
        ? '${job.scheduleStart ?? '-'} → ${job.scheduleEnd ?? '-'}'
        : AppStrings.t('Not specified', 'ไม่ระบุ', 'Tidak dinyatakan');

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          AppStrings.t('Job Details', 'รายละเอียดงาน', 'Butiran Kerja'),
          style: TextStyle(
            color: AppColors.neutral,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AmbientPanel(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (job.isMine)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withValues(
                                      alpha: 0.22,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.pill,
                                    ),
                                    border: Border.all(
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                  child: Text(
                                    AppStrings.t(
                                      'YOUR JOB',
                                      'งานของคุณ',
                                      'KERJA ANDA',
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: job.isSubmittedAwaitingClose
                                      ? AppColors.success.withValues(alpha: 0.24)
                                      : Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                  border: job.isSubmittedAwaitingClose
                                      ? Border.all(
                                          color: AppColors.success.withValues(
                                            alpha: 0.85,
                                          ),
                                        )
                                      : null,
                                ),
                                child: Text(
                                  job.isSubmittedAwaitingClose
                                      ? AppStrings.t(
                                          'REPORT SUBMITTED ✓',
                                          'ส่งรายงานแล้ว ✓',
                                          'LAPORAN DIHANTAR ✓',
                                        )
                                      : job.status.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            job.jobCode,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (job.vesselName != null &&
                              job.vesselName!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _VesselHeroBanner(vesselName: job.vesselName!),
                          ],
                          if (job.title.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              job.title,
                              style: TextStyle(
                                fontSize: 15.5,
                                color: Colors.white.withValues(alpha: 0.92),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _infoCard(
                      title: AppStrings.t(
                        'JOB DESCRIPTION',
                        'รายละเอียดงาน',
                        'PENERANGAN KERJA',
                      ),
                      child: Text(
                        job.description.isNotEmpty
                            ? job.description
                            : AppStrings.t(
                                'No additional description provided.',
                                'ไม่มีรายละเอียดเพิ่มเติม',
                                'Tiada penerangan tambahan.',
                              ),
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.5,
                          color: AppColors.neutral,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _infoCard(
                      title: AppStrings.t(
                        'INFORMATION',
                        'ข้อมูลเพิ่มเติม',
                        'MAKLUMAT',
                      ),
                      child: Column(
                        children: [
                          if (job.vesselName != null &&
                              job.vesselName!.isNotEmpty) ...[
                            _metaRow(
                              Icons.directions_boat_outlined,
                              AppStrings.t('Vessel', 'เรือ', 'Kapal'),
                              job.vesselName!,
                            ),
                            const Divider(height: 20),
                          ],
                          if (job.projectName != null &&
                              job.projectName!.isNotEmpty) ...[
                            _metaRow(
                              Icons.folder_outlined,
                              AppStrings.t('Project', 'โปรเจกต์', 'Projek'),
                              job.projectName!,
                            ),
                            const Divider(height: 20),
                          ],
                          _metaRow(
                            Icons.calendar_today_outlined,
                            AppStrings.t('Schedule', 'กำหนดการ', 'Jadual'),
                            scheduleText,
                          ),
                          if (job.location != null &&
                              job.location!.isNotEmpty) ...[
                            const Divider(height: 20),
                            _metaRow(
                              Icons.location_on_outlined,
                              AppStrings.t('Location', 'สถานที่', 'Lokasi'),
                              job.location!,
                            ),
                          ],
                          const Divider(height: 20),
                          _metaRow(
                            Icons.flag_outlined,
                            AppStrings.t('Priority', 'ความสำคัญ', 'Keutamaan'),
                            job.priority.toUpperCase(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _assignedCrewCard(),
                    if (job.hasVesselOrEquipmentDetails) ...[
                      const SizedBox(height: 12),
                      KeyedSubtree(
                        key: const Key('job-vessel-equipment-card'),
                        child: _infoCard(
                          title: AppStrings.t(
                            'VESSEL & EQUIPMENT',
                            'ข้อมูลเรือและอุปกรณ์',
                            'KAPAL & PERALATAN',
                          ),
                          child: _vesselEquipmentRows(job),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: job.isSubmittedAwaitingClose
                  ? Container(
                      key: const Key('job-submitted-awaiting-close-banner'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              AppStrings.t(
                                'Work report submitted — awaiting supervisor to close this work order.',
                                'ส่งรายงานการทำงานเรียบร้อยแล้ว — รอแอดมินปิดใบงานในระบบ',
                                'Laporan kerja telah dihantar — menunggu penyelia menutup arahan kerja ini.',
                              ),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.neutral,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : job.isMine
                  ? (isSelected
                        ? SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              key: const Key('unselect-job-button'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: AppColors.surface,
                                foregroundColor: AppColors.error,
                                side: BorderSide(
                                  color: AppColors.error.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                              ),
                              icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                                size: 18,
                              ),
                              label: Text(
                                AppStrings.t(
                                  'Unselect This Job',
                                  'ยกเลิกการเลือกงานนี้',
                                  'Nyahpilih Kerja Ini',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: () => Navigator.of(context).pop(
                                TechnicianJobSelectionResult.cleared(),
                              ),
                            ),
                          )
                        : SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton.icon(
                              key: const Key('select-job-for-checkin-button'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.neutral,
                                foregroundColor: AppColors.onNeutral,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                              ),
                              icon: const Icon(
                                Icons.check_circle_outline,
                                size: 18,
                              ),
                              label: Text(
                                AppStrings.t(
                                  'Select This Job for Check-In',
                                  'เลือกงานนี้เพื่อเช็คอิน',
                                  'Pilih Kerja Ini untuk Daftar Masuk',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: () => Navigator.of(context).pop(
                                TechnicianJobSelectionResult.selected(job),
                              ),
                            ),
                          ))
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              AppStrings.t(
                                'This job is assigned to another technician (view only).',
                                'งานนี้มอบหมายให้ช่างคนอื่น (ดูรายละเอียดได้อย่างเดียว)',
                                'Kerja ini ditugaskan kepada juruteknik lain (paparan sahaja).',
                              ),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({required String title, required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.surface),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );

  Widget _assignedCrewCard() {
    final parsed = _parseCrewNames(job.assignedToName);
    final crew = parsed.isNotEmpty
        ? parsed
        : (job.isMine
              ? <String>[_currentUserName ?? AppStrings.t('You', 'คุณ', 'Anda')]
              : const <String>[]);
    final title = crew.isNotEmpty
        ? AppStrings.t(
            'ASSIGNED CREW (${crew.length})',
            'ทีมช่างที่รับผิดชอบ (${crew.length} คน)',
            'PASUKAN DITUGASKAN (${crew.length})',
          )
        : AppStrings.t(
            'ASSIGNED CREW',
            'ทีมช่างที่รับผิดชอบ',
            'PASUKAN DITUGASKAN',
          );

    bool isMe(String name) {
      if (crew.length == 1 && job.isMine) return true;
      final me = _currentUserName?.trim().toLowerCase();
      if (me == null || me.isEmpty) return false;
      final n = name.trim().toLowerCase();
      return n == me || n.contains(me) || me.contains(n);
    }

    return Container(
      key: const Key('job-assigned-crew-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.surface),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.groups_rounded,
                size: 16,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (crew.isEmpty)
            Text(
              AppStrings.t('Unassigned', 'ยังไม่ระบุช่าง', 'Belum ditetapkan'),
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final member in crew)
                  Builder(
                    builder: (_) {
                      final mine = isMe(member);
                      final initial = member.isNotEmpty
                          ? member.characters.first.toUpperCase()
                          : '?';
                      return Container(
                        padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
                        decoration: BoxDecoration(
                          color: mine
                              ? AppColors.secondary.withValues(alpha: 0.14)
                              : AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: mine
                                ? AppColors.secondary
                                : AppColors.cardBorder,
                            width: mine ? 1.3 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: mine
                                  ? AppColors.avatarBackground
                                  : AppColors.secondary.withValues(alpha: 0.2),
                              child: Text(
                                initial,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: mine
                                      ? AppColors.avatarForeground
                                      : AppColors.neutral,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              member,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: mine
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: AppColors.neutral,
                              ),
                            ),
                            if (mine) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.neutral,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                child: Text(
                                  AppStrings.t('YOU', 'คุณ', 'ANDA'),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.onNeutral,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(icon, size: 18, color: AppColors.textSecondary),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.neutral,
          ),
        ),
      ),
    ],
  );

  Widget _vesselEquipmentRows(TechnicianJob job) {
    final rows = <Widget>[];
    void addRow(IconData icon, String label, String value) {
      if (rows.isNotEmpty) rows.add(const Divider(height: 20));
      rows.add(_metaRow(icon, label, value));
    }

    if (job.vesselType != null && job.vesselType!.isNotEmpty) {
      addRow(
        Icons.sailing_outlined,
        AppStrings.t('Vessel Type', 'ประเภทเรือ', 'Jenis Kapal'),
        job.vesselType!,
      );
    }
    if (job.vesselModel != null && job.vesselModel!.isNotEmpty) {
      addRow(
        Icons.directions_boat_filled_outlined,
        AppStrings.t(
          'Vessel Model / Builder',
          'รุ่น / ผู้ต่อเรือ',
          'Model Kapal',
        ),
        job.vesselModel!,
      );
    }
    if (job.vesselRegistration != null && job.vesselRegistration!.isNotEmpty) {
      addRow(
        Icons.badge_outlined,
        AppStrings.t('Registration / IMO', 'ทะเบียน / รหัสเรือ', 'Pendaftaran'),
        job.vesselRegistration!,
      );
    }
    if (job.assetName != null && job.assetName!.isNotEmpty) {
      final cat = (job.assetCategory != null && job.assetCategory!.isNotEmpty)
          ? ' (${job.assetCategory})'
          : '';
      addRow(
        Icons.precision_manufacturing_outlined,
        AppStrings.t('Equipment / Asset', 'อุปกรณ์ / เครื่องจักร', 'Peralatan'),
        '${job.assetName!}$cat',
      );
    } else if (job.assetCategory != null && job.assetCategory!.isNotEmpty) {
      addRow(
        Icons.category_outlined,
        AppStrings.t('Equipment Type', 'ประเภทอุปกรณ์', 'Jenis Peralatan'),
        job.assetCategory!,
      );
    }
    if (job.assetModel != null && job.assetModel!.isNotEmpty) {
      addRow(
        Icons.build_outlined,
        AppStrings.t('Equipment Model', 'รุ่นอุปกรณ์', 'Model Peralatan'),
        job.assetModel!,
      );
    }
    if (job.assetSerial != null && job.assetSerial!.isNotEmpty) {
      addRow(
        Icons.qr_code_2_rounded,
        AppStrings.t('Serial / Code', 'หมายเลขเครื่อง / รหัส', 'No. Siri'),
        job.assetSerial!,
      );
    }

    return Column(children: rows);
  }
}

/// High-contrast Vessel badge used inside dark navy hero cards.
class _VesselHeroBanner extends StatelessWidget {
  const _VesselHeroBanner({required this.vesselName});

  final String vesselName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.directions_boat_rounded,
            size: 18,
            color: Color(0xFF0A2233),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              vesselName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
                color: Color(0xFF0A2233),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
