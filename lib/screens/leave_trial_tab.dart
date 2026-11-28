import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../models/payroll_calculator.dart';
import '../services/auth_service.dart';
import '../services/file_download_service.dart';
import '../services/leave_pdf_builder.dart';
import '../services/leave_service.dart';
import '../services/work_trial_store.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_panel.dart';
import '../widgets/status_banner.dart';
import '../widgets/status_chip.dart';
import '../widgets/empty_note.dart';
import '../widgets/fade_slide_entry.dart';
import '../widgets/success_feedback_overlay.dart';
import 'leave_approval_screen.dart';
import 'leave_drafts_screen.dart';

class LeaveTrialTab extends StatefulWidget {
  const LeaveTrialTab({super.key, required this.store});
  final WorkTrialStore store;
  @override
  State<LeaveTrialTab> createState() => _LeaveTrialTabState();
}

class _LeaveTrialTabState extends State<LeaveTrialTab>
    with AutomaticKeepAliveClientMixin {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  LeaveType _type = LeaveType.sick;
  late DateTime _start;
  late DateTime _end;
  bool _singleDay = true;
  bool _busy = true;
  bool _submittingHr = false;
  bool _loadFailed = false;
  bool _exporting = false;
  bool _canApproveLeave = false;
  int _pendingApprovalsCount = 0;
  String? _error;
  List<LeaveDraft> _drafts = [];
  List<LeaveRequestRecord> _submittedLeaves = [];
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    final now = bangkokNow();
    _start = DateTime(now.year, now.month, now.day);
    _end = _start;
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final drafts = await widget.store.loadLeaves();
      final canApprove = await AuthService.canApproveLeave();
      List<LeaveRequestRecord> submitted = const [];
      var pendingCount = 0;
      try {
        if (canApprove) {
          final all = await LeaveService.getLeaveRequests(onlyMine: false);
          pendingCount = all.where((e) => e.isPending).length;
          final user = await AuthService.getSavedUser();
          final myId = user?['id']?.toString().trim();
          final myEmpId = user?['employeeId']?.toString().trim();
          final ids = <String>{
            if (myId != null && myId.isNotEmpty) myId,
            if (myEmpId != null && myEmpId.isNotEmpty) myEmpId,
          };
          submitted = ids.isEmpty
              ? all
              : all.where((r) => ids.contains(r.employeeId)).toList();
        } else {
          submitted = await LeaveService.getLeaveRequests(onlyMine: true);
        }
      } catch (_) {}
      if (mounted) {
        setState(() {
          _drafts = drafts;
          _canApproveLeave = canApprove;
          _pendingApprovalsCount = pendingCount;
          _submittedLeaves = submitted;
          _loadFailed = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loadFailed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _hasOverlappingSubmittedLeave() {
    final s = DateTime(_start.year, _start.month, _start.day);
    final e = DateTime(_end.year, _end.month, _end.day);
    for (final item in _submittedLeaves) {
      if (item.status == 'rejected' || item.status == 'cancelled') continue;
      final is_ = DateTime(item.startDate.year, item.startDate.month, item.startDate.day);
      final ie_ = DateTime(item.endDate.year, item.endDate.month, item.endDate.day);
      if (!e.isBefore(is_) && !s.isAfter(ie_)) {
        return true;
      }
    }
    return false;
  }

  bool _includesWeekend() {
    var cursor = DateTime(_start.year, _start.month, _start.day);
    final end = DateTime(_end.year, _end.month, _end.day);
    while (!cursor.isAfter(end)) {
      if (cursor.weekday == DateTime.saturday ||
          cursor.weekday == DateTime.sunday) {
        return true;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return false;
  }

  List<String> _computeLeaveWarnings() {
    final warnings = <String>[];
    final today = DateTime(
      bangkokNow().year,
      bangkokNow().month,
      bangkokNow().day,
    );
    if (_start.isBefore(today)) {
      warnings.add(
        AppStrings.t(
          'Selected start date is in the past.',
          'วันที่เริ่มลาเป็นวันที่ผ่านมาแล้ว',
          'Tarikh mula cuti telah berlalu.',
        ),
      );
    }
    if (_hasOverlappingSubmittedLeave()) {
      warnings.add(
        AppStrings.t(
          'Overlaps with an existing pending/approved leave request.',
          'ช่วงวันที่ซ้อนทับกับคำขอลาที่รออนุมัติหรืออนุมัติแล้ว',
          'Bertindih dengan permohonan cuti sedia ada.',
        ),
      );
    }
    if (_includesWeekend()) {
      warnings.add(
        AppStrings.t(
          'Selected range includes weekend days (Sat/Sun).',
          'ช่วงวันที่เลือกคร่อมวันเสาร์-อาทิตย์',
          'Julat tarikh termasuk hari minggu (Sabtu/Ahad).',
        ),
      );
    }
    return warnings;
  }

  Future<void> _submitToHr() async {
    if (_busy || _submittingHr || _loadFailed || !_form.currentState!.validate()) {
      return;
    }
    if (_hasOverlappingSubmittedLeave()) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            AppStrings.t(
              'Overlapping Leave Date',
              'วันลาซ้อนทับกับรายการเดิม',
              'Tarikh Cuti Bertindih',
            ),
          ),
          content: Text(
            AppStrings.t(
              'You already have a pending or approved leave covering these dates. Submit anyway?',
              'คุณมีใบลาที่รออนุมัติหรืออนุมัติแล้วในช่วงวันนี้ ต้องการส่งซ้ำหรือไม่?',
              'Anda sudah mempunyai cuti pada tarikh ini. Hantar juga?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(AppStrings.t('Cancel', 'ยกเลิก', 'Batal')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(AppStrings.t('Submit Anyway', 'ยืนยันส่ง', 'Hantar Juga')),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    setState(() {
      _submittingHr = true;
      _error = null;
    });
    try {
      await LeaveService.submitLeaveRequest(
        type: _type,
        start: _start,
        end: _end,
        reason: _reason.text,
      );
      final submitted = await LeaveService.getLeaveRequests(onlyMine: true);
      if (!mounted) return;
      setState(() => _submittedLeaves = submitted);
      _reason.clear();
      await SuccessFeedbackOverlay.show(
        context,
        title: AppStrings.t(
          'Leave Request Sent',
          'ส่งคำขอลาแล้ว',
          'Permohonan Cuti Dihantar',
        ),
        subtitle: AppStrings.t(
          'HR has received your request',
          'ส่งคำขอให้ HR อนุมัติเรียบร้อย',
          'HR telah menerima permohonan anda',
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _submittingHr = false);
    }
  }

  Future<void> _pickDate(bool start) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        _start = selected;
        if (_end.isBefore(selected) || _singleDay) _end = selected;
      } else {
        _end = selected;
      }
    });
  }

  Future<void> _save() async {
    if (_busy || _loadFailed || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await widget.store.addLeave(
        type: _type,
        start: _start,
        end: _end,
        reason: _reason.text,
      );
      final drafts = await widget.store.loadLeaves();
      if (!mounted) return;
      setState(() => _drafts = drafts);
      _reason.clear();
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          persist: false,
          content: Text(
            AppStrings.t(
              'Saved on this device • not submitted to your manager',
              'บันทึกในเครื่องแล้ว • ยังไม่ได้ส่งให้หัวหน้าอนุมัติ',
            ),
          ),
          action: SnackBarAction(
            label: AppStrings.t('View PDF', 'ดูไฟล์ PDF'),
            onPressed: () => _viewPdf(created),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        final raw = error.toString().replaceFirst(
          RegExp(r'^(Bad state|StateError|Exception):\s*'),
          '',
        );
        final friendly = raw.toLowerCase().contains('already overlaps')
            ? AppStrings.t(
                'You already have an active leave draft for these dates. Cancel it first or pick different dates.',
                'คุณมีใบลาที่ยังใช้งานอยู่ในช่วงวันที่นี้แล้ว กรุณายกเลิกใบเดิมก่อนหรือเลือกวันอื่น',
              )
            : raw;
        setState(() => _error = friendly);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _viewPdf(LeaveDraft draft) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final user = await AuthService.getSavedUser();
      if (user == null || user['id']?.toString() != widget.store.userId) {
        throw StateError('Please sign in to download this draft.');
      }
      final prefs = await SharedPreferences.getInstance();
      final rolesJson = prefs.getString('ems.roles');
      final rolesData = rolesJson == null ? <dynamic>[] : jsonDecode(rolesJson);
      final roles = rolesData is List
          ? rolesData.map((role) => role.toString()).toList()
          : <String>[];
      final initialLanguage = LeavePdfLanguage.th;
      final bytes = await buildLeavePdf(
        draft: draft,
        user: user,
        roles: roles,
        language: initialLanguage,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _LeavePdfPreview(
            draft: draft,
            user: user,
            roles: roles,
            initialBytes: bytes,
            initialLanguage: initialLanguage,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not create or open the PDF. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _cancel(LeaveDraft draft) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppStrings.t('Cancel this leave draft?', 'ยกเลิกแบบร่างใบลานี้?'),
        ),
        content: Text(
          AppStrings.isThai
              ? '${AppStrings.leaveTypeLabel(draft.type.label)}: ${calendarDate(draft.start)} ถึง ${calendarDate(draft.end)}\nประวัติใบลานี้จะยังคงเก็บไว้ในเครื่อง'
              : '${draft.type.label}: ${calendarDate(draft.start)} to ${calendarDate(draft.end)}\nThis record will remain on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.t('Back', 'ย้อนกลับ')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.t('Cancel draft', 'ยกเลิกแบบร่าง')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.cancelLeave(draft.id);
      final drafts = await widget.store.loadLeaves();
      if (mounted) setState(() => _drafts = drafts);
    } catch (error) {
      if (mounted) {
        final raw = error.toString().replaceFirst(
          RegExp(r'^(Bad state|StateError|Exception):\s*'),
          '',
        );
        final friendly = raw.toLowerCase().contains('already overlaps')
            ? AppStrings.t(
                'You already have an active leave draft for these dates. Cancel it first or pick different dates.',
                'คุณมีใบลาที่ยังใช้งานอยู่ในช่วงวันที่นี้แล้ว กรุณายกเลิกใบเดิมก่อนหรือเลือกวันอื่น',
              )
            : raw;
        setState(() => _error = friendly);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAllDrafts() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LeaveDraftsScreen(
          store: widget.store,
          onViewPdf: _viewPdf,
        ),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  Widget _dateField({required bool isStart}) {
    final label = isStart
        ? AppStrings.t('Start date', 'วันที่เริ่มลา')
        : AppStrings.t('End date', 'วันที่สิ้นสุด');
    final date = isStart ? _start : _end;
    return OutlinedButton(
      onPressed: _busy || _loadFailed || (!isStart && _singleDay)
          ? null
          : () => _pickDate(isStart),
      style: OutlinedButton.styleFrom(
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.all(AppSpacing.md),
        minimumSize: const Size(0, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            calendarDate(date),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      primary: true,
      padding: EdgeInsets.fromLTRB(16, 16, 16, appTabBottomPadding(context)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_canApproveLeave) ...[
                Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.surface),
                  child: InkWell(
                    key: const Key('leave-tab-approval-shortcut'),
                    borderRadius: BorderRadius.circular(AppRadius.surface),
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LeaveApprovalScreen(),
                        ),
                      );
                      if (mounted) _load();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.surface),
                        border: Border.all(
                          color: _pendingApprovalsCount > 0
                              ? AppColors.secondary.withValues(alpha: 0.65)
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.fact_check_outlined,
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
                                    'Leave Approvals',
                                    'อนุมัติใบลาพนักงาน',
                                    'Kelulusan Cuti',
                                  ),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.neutral,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _pendingApprovalsCount > 0
                                      ? AppStrings.t(
                                          '$_pendingApprovalsCount pending request(s) waiting',
                                          'มีคำขอรออนุมัติ $_pendingApprovalsCount รายการ',
                                          '$_pendingApprovalsCount permohonan menunggu',
                                        )
                                      : AppStrings.t(
                                          'Review employee leave requests',
                                          'ตรวจสอบและอนุมัติคำขอลาพนักงาน',
                                          'Semak permohonan cuti pekerja',
                                        ),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: _pendingApprovalsCount > 0
                                        ? AppColors.secondary
                                        : AppColors.textSecondary,
                                    fontWeight: _pendingApprovalsCount > 0
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_pendingApprovalsCount > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.neutral,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                '$_pendingApprovalsCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onNeutral,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              FadeSlideEntry(
                yOffset: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AmbientPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            AppStrings.t(
                              'Prepare a leave draft',
                              'สร้างแบบร่างใบลา',
                            ),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            AppStrings.t(
                              'Saved on this device only. Drafts aren’t submitted for approval or checked against your leave balance.',
                              'บันทึกไว้ในเครื่องนี้เท่านั้น ยังไม่ได้ส่งอนุมัติหรือหักจากสิทธิวันลาคงเหลือ',
                            ),
                            style: TextStyle(color: AppColors.onNeutralMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                                DropdownButtonFormField<LeaveType>(
                                  isExpanded: true,
                                  initialValue: _type,
                                  decoration: InputDecoration(
                                    labelText: AppStrings.t(
                                      'Leave type',
                                      'ประเภทการลา',
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.category_outlined,
                                    ),
                                  ),
                                  items: [
                                    for (final type in LeaveType.values)
                                      DropdownMenuItem(
                                        value: type,
                                        child: Text(
                                          AppStrings.leaveTypeLabel(type.label),
                                        ),
                                      ),
                                  ],
                                  onChanged: _busy || _loadFailed
                                      ? null
                                      : (value) =>
                                            setState(() => _type = value!),
                                ),
                                const SizedBox(height: 16),
                                if (_singleDay)
                                  _dateField(isStart: true)
                                else
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final start = _dateField(isStart: true);
                                      final end = _dateField(isStart: false);
                                      final minWidth =
                                          MediaQuery.textScalerOf(context)
                                              .scale(13) *
                                          19;
                                      if (constraints.maxWidth < minWidth) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          spacing: AppSpacing.sm,
                                          children: [start, end],
                                        );
                                      }
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        spacing: AppSpacing.sm,
                                        children: [
                                          Expanded(child: start),
                                          Expanded(child: end),
                                        ],
                                      );
                                    },
                                  ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        AppStrings.t(
                                          'One day (single date)',
                                          'ลา 1 วัน (วันเดียว)',
                                        ),
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.neutral,
                                        ),
                                      ),
                                    ),
                                    Switch.adaptive(
                                      value: _singleDay,
                                      activeThumbColor: AppColors.secondary,
                                      activeTrackColor: AppColors.secondary
                                          .withValues(alpha: 0.35),
                                      onChanged: _busy || _loadFailed
                                          ? null
                                          : (value) => setState(() {
                                              _singleDay = value;
                                              if (_singleDay) _end = _start;
                                            }),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  key: const Key('leave-reason'),
                                  controller: _reason,
                                  enabled: !_busy && !_loadFailed,
                                  maxLines: 3,
                                  maxLength: 1000,
                                  decoration: InputDecoration(
                                    labelText: AppStrings.t(
                                      'Reason for leave',
                                      'เหตุผลการลา',
                                    ),
                                    alignLabelWithHint: true,
                                  ),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? AppStrings.t(
                                          'Please enter a reason',
                                          'กรุณากรอกเหตุผลการลา',
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      for (final entry in [
                                        AppStrings.t(
                                          'Medical / Doctor visit',
                                          'พบแพทย์ / พักรักษาตัว',
                                          'Rawatan doktor / Cuti sakit',
                                        ),
                                        AppStrings.t(
                                          'Personal errand',
                                          'ติดธุระส่วนตัว',
                                          'Urusan peribadi',
                                        ),
                                        AppStrings.t(
                                          'Annual vacation',
                                          'พักผ่อนประจำปี',
                                          'Percutian tahunan',
                                        ),
                                      ].asMap().entries) ...[
                                        if (entry.key > 0)
                                          const SizedBox(width: 8),
                                        ActionChip(
                                          visualDensity: VisualDensity.compact,
                                          label: Text(
                                            entry.value,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                            ),
                                          ),
                                          onPressed: _busy || _loadFailed
                                              ? null
                                              : () {
                                                  HapticFeedback.selectionClick();
                                                  setState(
                                                    () => _reason.text =
                                                        entry.value,
                                                  );
                                                },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                ..._computeLeaveWarnings().map(
                                  (msg) => Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: StatusBanner(
                                      variant: StatusVariant.warning,
                                      message: msg,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  key: const Key('submit-leave-hr'),
                                  onPressed: (_busy || _submittingHr || _loadFailed)
                                      ? null
                                      : _submitToHr,
                                  icon: _submittingHr
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.onNeutral,
                                          ),
                                        )
                                      : const Icon(Icons.send_rounded),
                                  label: Text(
                                    AppStrings.t(
                                      'Submit to HR',
                                      'ส่งคำขอลาให้ HR',
                                      'Hantar ke HR',
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.neutral,
                                    foregroundColor: AppColors.onNeutral,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  key: const Key('save-leave'),
                                  onPressed: (_busy || _submittingHr || _loadFailed)
                                      ? null
                                      : _save,
                                  icon: _busy
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.neutral,
                                          ),
                                        )
                                      : const Icon(Icons.save_outlined),
                                  label: Text(
                                    AppStrings.t(
                                      'Save draft on this device',
                                      'บันทึกแบบร่างลงเครื่อง',
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.neutral,
                                    side: BorderSide(color: AppColors.cardBorder),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  StatusBanner(
                                    variant: StatusVariant.error,
                                    message: _error!,
                                  ),
                                ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              if (_loadFailed)
                TextButton(
                  onPressed: _busy ? null : _load,
                  child: Text(
                    AppStrings.t(
                      'Retry loading drafts',
                      'ลองโหลดแบบร่างอีกครั้ง',
                    ),
                  ),
                ),
              if (_submittedLeaves.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  AppStrings.t(
                    'Submitted leave requests (HR)',
                    'คำขอลาที่ส่งให้ HR แล้ว',
                    'Permohonan cuti dihantar (HR)',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ..._submittedLeaves.take(5).map((rec) {
                  final variant = rec.isApproved
                      ? ChipVariant.success
                      : (rec.isRejected || rec.isCancelled)
                      ? ChipVariant.error
                      : ChipVariant.warning;
                  final statusText = rec.isApproved
                      ? AppStrings.t('APPROVED', 'อนุมัติแล้ว', 'DILULUSKAN')
                      : rec.isRejected
                      ? AppStrings.t('REJECTED', 'ไม่อนุมัติ', 'DITOLAK')
                      : rec.isCancelled
                      ? AppStrings.t('CANCELLED', 'ยกเลิกแล้ว', 'DIBATALKAN')
                      : AppStrings.t('PENDING', 'รออนุมัติ', 'MENUNGGU');
                  final range = rec.calendarDays == 1
                      ? calendarDate(rec.startDate)
                      : '${calendarDate(rec.startDate)} → ${calendarDate(rec.endDate)}';
                  return Container(
                    key: Key('submitted-leave-${rec.id}'),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.surface),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                AppStrings.leaveTypeLabel(rec.leaveType.label),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.neutral,
                                ),
                              ),
                            ),
                            StatusChip(label: statusText, variant: variant),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$range (${rec.calendarDays} ${AppStrings.t("day(s)", "วัน", "hari")})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rec.reason,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.neutral,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _exporting
                                ? null
                                : () => _viewPdf(rec.toLeaveDraft()),
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                            label: Text(AppStrings.t('PDF', 'PDF')),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.t('Your leave drafts', 'แบบร่างใบลาของคุณ'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (_drafts.isNotEmpty)
                    TextButton.icon(
                      key: const Key('view-all-leave-drafts'),
                      onPressed: _busy ? null : _openAllDrafts,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.chevron_right_rounded, size: 18),
                      iconAlignment: IconAlignment.end,
                      label: Text(
                        AppStrings.isThai
                            ? 'ดูทั้งหมด (${_drafts.length})'
                            : 'View all (${_drafts.length})',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.t(
                  'Calendar days, including holidays. Not an entitlement balance.',
                  'นับตามวันปฏิทินรวมวันหยุด ไม่ใช่ยอดสิทธิวันลาคงเหลือ',
                ),
              ),
              if (_drafts.isEmpty && !_busy && !_loadFailed)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: EmptyNote(
                    icon: Icons.event_note_outlined,
                    message: AppStrings.t(
                      'No local leave drafts yet.',
                      'ยังไม่มีแบบร่างใบลาในเครื่อง',
                    ),
                  ),
                ),
              for (final draft in _drafts.take(2)) ...[
                const SizedBox(height: 12),
                FadeSlideEntry(
                  yOffset: 8,
                  child: LeaveDraftCard(
                    draft: draft,
                    busy: _busy || _loadFailed,
                    exporting: _exporting,
                    onViewPdf: () => _viewPdf(draft),
                    onCancel: () => _cancel(draft),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeavePdfPreview extends StatefulWidget {
  const _LeavePdfPreview({
    required this.draft,
    required this.user,
    required this.roles,
    required this.initialBytes,
    required this.initialLanguage,
  });

  final LeaveDraft draft;
  final Map<String, dynamic> user;
  final List<String> roles;
  final Uint8List initialBytes;
  final LeavePdfLanguage initialLanguage;

  @override
  State<_LeavePdfPreview> createState() => _LeavePdfPreviewState();
}

class _LeavePdfPreviewState extends State<_LeavePdfPreview> {
  late LeavePdfLanguage _language;
  late Uint8List _bytes;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _language = widget.initialLanguage;
    _bytes = widget.initialBytes;
  }

  String get _filename {
    final rawCode = widget.user['employeeCode']?.toString().trim() ?? '';
    final safeCode = rawCode.replaceAll(RegExp(r'[^0-9A-Za-z_-]'), '');
    final suffix = safeCode.isNotEmpty
        ? safeCode
        : calendarDate(widget.draft.start);
    return _language == LeavePdfLanguage.th
        ? 'ใบลา_$suffix.pdf'
        : 'ใบลา_${suffix}_EN.pdf';
  }

  Future<void> _selectLanguage(LeavePdfLanguage next) async {
    if (next == _language || _switching) return;
    HapticFeedback.selectionClick();
    setState(() => _switching = true);
    try {
      final regenerated = await buildLeavePdf(
        draft: widget.draft,
        user: widget.user,
        roles: widget.roles,
        language: next,
      );
      if (!mounted) return;
      setState(() {
        _language = next;
        _bytes = regenerated;
      });
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _download(BuildContext context) async {
    try {
      final location = await FileDownloadService.downloadFile(
        bytes: _bytes,
        filename: _filename,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded: $location'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not download the PDF. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _print(BuildContext context) async {
    try {
      await Printing.layoutPdf(
        name: _filename,
        format: PdfPageFormat.a4,
        onLayout: (_) async => _bytes,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.t(
                'Could not open print dialog. Please try again.',
                'ไม่สามารถเปิดหน้าต่างพิมพ์ได้ กรุณาลองใหม่อีกครั้ง',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _share(BuildContext context) async {
    try {
      final box = context.findRenderObject() as RenderBox?;
      final bounds = box == null
          ? Rect.zero
          : box.localToGlobal(Offset.zero) & box.size;
      await Printing.sharePdf(
        bytes: _bytes,
        filename: _filename,
        bounds: bounds,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not share the PDF. Please try again.'),
          ),
        );
      }
    }
  }

  Widget _langPill({
    required Key key,
    required LeavePdfLanguage value,
    required String label,
  }) {
    final selected = _language == value;
    return Expanded(
      child: Material(
        color: selected ? AppColors.neutral : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: _switching ? null : () => _selectLanguage(value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: selected ? AppColors.neutral : AppColors.cardBorder,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.onNeutral : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.primary,
    appBar: AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.neutral,
      iconTheme: IconThemeData(color: AppColors.neutral),
      title: Text(AppStrings.t('Leave PDF', 'ไฟล์ PDF ใบลา')),
      actions: [
        IconButton(
          tooltip: AppStrings.t('Print PDF', 'พิมพ์ PDF'),
          icon: const Icon(Icons.print_outlined),
          onPressed: _switching ? null : () => _print(context),
        ),
        IconButton(
          tooltip: AppStrings.t('Download PDF', 'ดาวน์โหลด PDF'),
          icon: const Icon(Icons.download_outlined),
          onPressed: _switching ? null : () => _download(context),
        ),
        IconButton(
          tooltip: AppStrings.t('Share PDF', 'แชร์ PDF'),
          icon: const Icon(Icons.share_outlined),
          onPressed: _switching ? null : () => _share(context),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(
            children: [
              _langPill(
                key: const Key('pdf-lang-th'),
                value: LeavePdfLanguage.th,
                label: 'แบบฟอร์มไทย (TH)',
              ),
              const SizedBox(width: 10),
              _langPill(
                key: const Key('pdf-lang-en'),
                value: LeavePdfLanguage.en,
                label: 'English Form (EN)',
              ),
            ],
          ),
        ),
        Expanded(
          child: _switching
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.secondary),
                )
              : PdfPreview(
                  key: ValueKey(_language),
                  initialPageFormat: PdfPageFormat.a4,
                  build: (_) => _bytes,
                  useActions: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  onError: (_, _) => Center(
                    child: Text(
                      AppStrings.t(
                        'Could not preview the PDF.',
                        'ไม่สามารถแสดงตัวอย่างไฟล์ PDF ได้',
                      ),
                    ),
                  ),
                ),
        ),
      ],
    ),
  );
}
