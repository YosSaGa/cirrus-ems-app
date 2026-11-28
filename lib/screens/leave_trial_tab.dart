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
import '../services/work_trial_store.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_panel.dart';
import '../widgets/status_banner.dart';
import '../widgets/empty_note.dart';
import '../widgets/fade_slide_entry.dart';
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
  bool _loadFailed = false;
  bool _exporting = false;
  String? _error;
  List<LeaveDraft> _drafts = [];
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
      if (mounted) {
        setState(() {
          _drafts = drafts;
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
                                if (_start.isBefore(
                                  DateTime(
                                    bangkokNow().year,
                                    bangkokNow().month,
                                    bangkokNow().day,
                                  ),
                                )) ...[
                                  const SizedBox(height: 8),
                                  StatusBanner(
                                    variant: StatusVariant.warning,
                                    message: AppStrings.t(
                                      'Selected start date is in the past. Please double-check the date.',
                                      'วันที่เริ่มลาเป็นวันที่ผ่านมาแล้ว กรุณาตรวจสอบวันที่อีกครั้ง',
                                      'Tarikh mula cuti telah berlalu. Sila semak semula tarikh.',
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  key: const Key('save-leave'),
                                  onPressed: _busy || _loadFailed
                                      ? null
                                      : _save,
                                  icon: _busy
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.onNeutral,
                                          ),
                                        )
                                      : const Icon(Icons.save_outlined),
                                  label: Text(
                                    AppStrings.t(
                                      'Save draft on this device',
                                      'บันทึกแบบร่างลงเครื่อง',
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
