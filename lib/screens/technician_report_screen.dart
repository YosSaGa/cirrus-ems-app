import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../l10n/app_strings.dart';
import '../models/captured_photo.dart';
import '../services/attendance_service.dart';
import '../services/technician_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_panel.dart';
import '../widgets/status_banner.dart';
import 'attendance_camera_screen.dart';

/// Mandatory work report screen opened immediately after a Technician checks out
/// (Lunch Break Out or End of Day / Leave). Until submitted, the technician is
/// blocked from selecting or checking in to another job.
class TechnicianReportScreen extends StatefulWidget {
  const TechnicianReportScreen({
    super.key,
    this.session,
    this.job,
    this.mandatory = false,
  }) : assert(session != null || job != null);

  final TechnicianWorkSession? session;
  final TechnicianJob? job;
  final bool mandatory;

  @override
  State<TechnicianReportScreen> createState() => _TechnicianReportScreenState();
}

class _TechnicianReportScreenState extends State<TechnicianReportScreen>
    with WidgetsBindingObserver {
  bool get _isLocked => widget.mandatory || widget.session != null;
  final _descController = TextEditingController();
  final _findingsController = TextEditingController();
  final _recommendController = TextEditingController();
  final List<CapturedPhoto> _photos = [];
  final Map<CapturedPhoto, String> _uploadedPhotoKeys = {};

  static const int _maxPhotos = 4;

  String _workType = 'service';
  bool _submitting = false;
  double _uploadProgress = 0.0;
  String? _submitStageLabel;
  String? _error;
  Timer? _draftDebounce;
  bool _draftRestored = false;

  String get _draftKey =>
      'ems.reportDraft.${widget.session?.id ?? widget.job?.id ?? 'default'}';

  static const _workTypes = <(String, String, String, String)>[
    ('service', 'Service', 'บริการ/ตรวจเช็ค', 'Servis'),
    ('repair', 'Repair', 'ซ่อมแซม', 'Baiki'),
    ('maintenance', 'Maintenance', 'บำรุงรักษา', 'Penyelenggaraan'),
    ('inspection', 'Inspection', 'ตรวจสอบ', 'Pemeriksaan'),
    ('installation', 'Installation', 'ติดตั้ง', 'Pemasangan'),
    ('other', 'Other', 'อื่นๆ', 'Lain-lain'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _descController.addListener(_scheduleSaveDraft);
    _findingsController.addListener(_scheduleSaveDraft);
    _recommendController.addListener(_scheduleSaveDraft);
    _restoreDraft();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _draftDebounce?.cancel();
      _saveDraftNow();
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null || raw.isEmpty || !mounted) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final desc = (decoded['desc'] ?? '').toString();
      final findings = (decoded['findings'] ?? '').toString();
      final recommend = (decoded['recommend'] ?? '').toString();
      final workType = (decoded['workType'] ?? 'service').toString();
      if (desc.isEmpty && findings.isEmpty && recommend.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _workType = _workTypes.any((t) => t.$1 == workType)
            ? workType
            : 'service';
        _descController.text = desc;
        _findingsController.text = findings;
        _recommendController.text = recommend;
        _draftRestored = true;
      });
    } catch (_) {}
  }

  void _scheduleSaveDraft() {
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 400), _saveDraftNow);
  }

  Future<void> _saveDraftNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final desc = _descController.text;
      final findings = _findingsController.text;
      final recommend = _recommendController.text;
      if (desc.trim().isEmpty &&
          findings.trim().isEmpty &&
          recommend.trim().isEmpty) {
        await prefs.remove(_draftKey);
        return;
      }
      await prefs.setString(
        _draftKey,
        jsonEncode({
          'workType': _workType,
          'desc': desc,
          'findings': findings,
          'recommend': recommend,
        }),
      );
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    _draftDebounce?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _workType = 'service';
      _descController.clear();
      _findingsController.clear();
      _recommendController.clear();
      _draftRestored = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftDebounce?.cancel();
    _descController.dispose();
    _findingsController.dispose();
    _recommendController.dispose();
    super.dispose();
  }

  String _fmtTime(String? iso) {
    if (iso == null || iso.isEmpty) return '--:--';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _addPhoto() async {
    if (_submitting || _photos.length >= _maxPhotos) return;
    HapticFeedback.lightImpact();
    final photo = await Navigator.of(context).push<CapturedPhoto>(
      MaterialPageRoute(builder: (_) => const AttendanceCameraScreen()),
    );
    if (!mounted || photo == null) return;
    setState(() {
      _photos.add(photo);
      _error = null;
    });
  }

  Future<void> _confirmClearDraft() async {
    if (_submitting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('confirm-clear-draft-dialog'),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.surface),
        ),
        title: Text(
          AppStrings.t(
            'Clear Saved Draft?',
            'ล้างข้อความที่พิมพ์ค้างไว้?',
            'Padam Draf Tersimpan?',
          ),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.neutral,
          ),
        ),
        content: Text(
          AppStrings.t(
            'This will erase all text entered in this work report.',
            'ข้อความที่พิมพ์ไว้ทั้งหมดในรายงานนี้จะถูกลบออก',
            'Semua teks yang ditaip dalam laporan ini akan dipadamkan.',
          ),
          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppStrings.t('Cancel', 'ยกเลิก', 'Batal')),
          ),
          FilledButton(
            key: const Key('confirm-clear-draft-button'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppStrings.t('Clear', 'ล้างข้อความ', 'Padam')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _clearDraft();
    }
  }

  Future<bool> _confirmLeaveWithPhotos() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('confirm-leave-report-dialog'),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.surface),
        ),
        title: Text(
          AppStrings.t(
            'Discard Attached Photos?',
            'ออกโดยไม่ส่งรูปที่แนบไว้?',
            'Buang Foto Dilampirkan?',
          ),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.neutral,
          ),
        ),
        content: Text(
          AppStrings.t(
            'You have ${_photos.length} attached photo(s). Your text is auto-saved, but photos will be lost if you leave now.',
            'คุณแนบรูปไว้ ${_photos.length} รูป ข้อความจะถูกบันทึกไว้ให้อัตโนมัติ แต่รูปถ่ายจะหายไปหากออกตอนนี้',
            'Anda mempunyai ${_photos.length} foto dilampirkan. Teks disimpan secara automatik, tetapi foto akan hilang jika anda keluar sekarang.',
          ),
          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppStrings.t('Stay', 'อยู่ต่อ', 'Kekal')),
          ),
          FilledButton(
            key: const Key('confirm-leave-report-button'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppStrings.t('Leave', 'ออกเลย', 'Keluar')),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _removePhoto(int index) {
    if (_submitting || index < 0 || index >= _photos.length) return;
    HapticFeedback.selectionClick();
    setState(() {
      final removed = _photos.removeAt(index);
      _uploadedPhotoKeys.remove(removed);
    });
  }

  Future<void> _previewPhoto(int index) async {
    if (index < 0 || index >= _photos.length) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (dlgCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${index + 1} / ${_photos.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  key: const Key('preview-delete-photo-button'),
                  tooltip: AppStrings.t(
                    'Delete photo',
                    'ลบรูปภาพ',
                    'Padam foto',
                  ),
                  onPressed: _submitting
                      ? null
                      : () {
                          Navigator.of(dlgCtx).pop();
                          _removePhoto(index);
                        },
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                ),
                IconButton(
                  tooltip: AppStrings.t('Close', 'ปิด', 'Tutup'),
                  onPressed: () => Navigator.of(dlgCtx).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.72,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image.memory(
                    _photos[index].bytes,
                    fit: BoxFit.contain,
                    cacheWidth:
                        (MediaQuery.sizeOf(context).width *
                                MediaQuery.devicePixelRatioOf(context))
                            .round()
                            .clamp(400, 2048),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final desc = _descController.text.trim();
    if (desc.length < 5) {
      setState(() {
        _error = AppStrings.t(
          'Please describe the work completed (at least 5 characters).',
          'กรุณากรอกรายละเอียดงานที่ทำอย่างน้อย 5 ตัวอักษร',
          'Sila nyatakan kerja yang dilakukan (sekurang-kurangnya 5 aksara).',
        );
      });
      return;
    }

    final jobCode = widget.session?.jobCode ?? widget.job?.jobCode ?? '-';
    final workTypeTuple = _workTypes.firstWhere(
      (t) => t.$1 == _workType,
      orElse: () => _workTypes.first,
    );
    final workTypeLabel = AppStrings.t(
      workTypeTuple.$2,
      workTypeTuple.$3,
      workTypeTuple.$4,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('confirm-submit-report-dialog'),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.surface),
        ),
        title: Text(
          AppStrings.t(
            'Submit Work Report?',
            'ยืนยันส่งรายงานการทำงาน?',
            'Hantar Laporan Kerja?',
          ),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.neutral,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$jobCode · $workTypeLabel',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.neutral,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.t(
                'Photos attached: ${_photos.length}/$_maxPhotos',
                'รูปภาพที่แนบ: ${_photos.length}/$_maxPhotos รูป',
                'Foto dilampirkan: ${_photos.length}/$_maxPhotos',
              ),
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            if (_photos.isEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  AppStrings.t(
                    'No work photos attached. You cannot edit this report after submission.',
                    'ยังไม่ได้แนบรูปภาพการทำงาน และจะไม่สามารถแก้ไขหลังส่งแล้ว',
                    'Tiada foto kerja dilampirkan. Laporan tidak boleh diedit selepas dihantar.',
                  ),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.neutral,
                    side: BorderSide(color: AppColors.cardBorder),
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(
                    AppStrings.t('Cancel', 'กลับไปแก้ไข', 'Batal'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  key: const Key('confirm-submit-report-button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.neutral,
                    foregroundColor: AppColors.onNeutral,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(
                    AppStrings.t('Submit', 'ยืนยันส่ง', 'Hantar'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _submitting) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _submitting = true;
      _uploadProgress = _photos.isEmpty ? 0.45 : 0.08;
      _error = null;
      _submitStageLabel = _photos.isNotEmpty
          ? AppStrings.t(
              'Uploading photo 1/${_photos.length}...',
              'กำลังอัปโหลดรูป 1/${_photos.length}...',
              'Memuat naik foto 1/${_photos.length}...',
            )
          : AppStrings.t(
              'Submitting Report...',
              'กำลังส่งรายงาน...',
              'Menghantar Laporan...',
            );
    });

    try {
      final uploadedPhotoKeys = <String>[];
      for (var i = 0; i < _photos.length; i++) {
        final photo = _photos[i];
        final cached = _uploadedPhotoKeys[photo];
        if (cached == null && mounted) {
          setState(() {
            _submitStageLabel = AppStrings.t(
              'Uploading photo ${i + 1}/${_photos.length}...',
              'กำลังอัปโหลดรูป ${i + 1}/${_photos.length}...',
              'Memuat naik foto ${i + 1}/${_photos.length}...',
            );
          });
        }
        final storageKey =
            cached ??
            await AttendanceService.uploadAttendancePhoto(
              photo,
              const Uuid().v4(),
            );
        _uploadedPhotoKeys[photo] = storageKey;
        uploadedPhotoKeys.add(storageKey);
        if (mounted) {
          setState(() {
            _uploadProgress = (i + 1) / (_photos.length + 1);
          });
        }
      }

      if (mounted) {
        setState(() {
          _uploadProgress = 0.92;
          _submitStageLabel = AppStrings.t(
            'Submitting Report...',
            'กำลังส่งรายงาน...',
            'Menghantar Laporan...',
          );
        });
      }

      await TechnicianService.submitReport(
        sessionId: widget.session?.id ?? '',
        jobStatusAtCheckout: widget.session?.jobStatusAtCheckout,
        workOrderId: widget.job?.id ?? widget.session?.jobId,
        projectId: widget.job?.projectId,
        workDescription: () {
          final lateMins = widget.session?.reportLateMinutes() ?? 0;
          if (lateMins <= 0) return desc;
          return '$desc\n\n[ส่งรายงานช้า / Late Report: +$lateMins min (เกินกำหนด 07:00 น.)]';
        }(),
        workType: _workType,
        findings: _findingsController.text.trim().isEmpty
            ? null
            : _findingsController.text.trim(),
        recommendations: _recommendController.text.trim().isEmpty
            ? null
            : _recommendController.text.trim(),
        photos: uploadedPhotoKeys,
      );
      _draftDebounce?.cancel();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_draftKey);
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppStrings.friendlyError(e);
        _submitting = false;
        _uploadProgress = 0.0;
        _submitStageLabel = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final j = widget.job;
    final jobCode = s?.jobCode ?? j!.jobCode;
    final jobTitle = s?.jobTitle ?? j!.title;
    final vesselName = s?.vesselName ?? j?.vesselName;

    return PopScope(
      canPop: !_isLocked && !_submitting && _photos.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _submitting) return;
        if (_isLocked) {
          HapticFeedback.heavyImpact();
          final messenger = ScaffoldMessenger.maybeOf(context);
          messenger?.hideCurrentSnackBar();
          messenger?.showSnackBar(
            SnackBar(
              key: const Key('report-locked-snackbar'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.neutral,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              content: Text(
                AppStrings.t(
                  'Please complete and submit this work report before leaving.',
                  'กรุณากรอกและส่งรายงานการทำงานให้เสร็จก่อนออกจากหน้านี้',
                  'Sila lengkapkan dan hantar laporan kerja ini sebelum keluar.',
                ),
                style: TextStyle(
                  color: AppColors.onNeutral,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
          return;
        }
        final nav = Navigator.of(context);
        final leave = await _confirmLeaveWithPhotos();
        if (leave && mounted) {
          nav.pop(false);
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        automaticallyImplyLeading: !_isLocked,
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          AppStrings.t(
            'Work Report',
            'เขียนรายงานการทำงาน',
            'Laporan Kerja',
          ),
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
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AmbientPanel(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (s != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                                border: Border.all(
                                  color: AppColors.warning.withValues(alpha: 0.8),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.assignment_late_outlined,
                                    size: 13,
                                    color: Colors.amber.shade200,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    AppStrings.t(
                                      'REQUIRED BEFORE NEXT JOB',
                                      'ต้องส่งรายงานก่อนเริ่มงานถัดไป',
                                      'WAJIB SEBELUM KERJA SETERUSNYA',
                                    ),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.amber.shade100,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                                border: Border.all(color: AppColors.secondary),
                              ),
                              child: Text(
                                AppStrings.t(
                                  'WORK REPORT',
                                  'รายงานการทำงาน',
                                  'LAPORAN KERJA',
                                ),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Text(
                            jobCode,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          if (vesselName != null && vesselName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.directions_boat_rounded,
                                  size: 14,
                                  color: AppColors.secondary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  vesselName,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (jobTitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              jobTitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.onNeutralMuted,
                              ),
                            ),
                          ],
                          if (s != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${_fmtTime(s.checkInAt)} → ${_fmtTime(s.checkOutAt)}'
                              '${s.durationMinutes != null ? ' · ${s.durationMinutes!.round()} min' : ''}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (s != null) ...[
                      _ReportDeadlineBanner(session: s),
                      const SizedBox(height: 12),
                    ],
                    if (_error != null) ...[
                      StatusBanner(
                        variant: StatusVariant.error,
                        message: _error!,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_draftRestored) ...[
                      Container(
                        key: const Key('report-draft-restored-banner'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          border: Border.all(
                            color: AppColors.secondary.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.restore_rounded,
                              size: 18,
                              color: AppColors.neutral,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                AppStrings.t(
                                  'Restored your saved draft',
                                  'กู้คืนข้อความที่พิมพ์ค้างไว้แล้ว',
                                  'Draf tersimpan dipulihkan',
                                ),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.neutral,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _submitting ? null : _confirmClearDraft,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 32),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                              child: Text(
                                AppStrings.t('Clear', 'ล้าง', 'Padam'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.neutral,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _sectionCard(
                      title: AppStrings.t(
                        'WORK TYPE',
                        'ประเภทงานที่ทำ',
                        'JENIS KERJA',
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in _workTypes)
                            ChoiceChip(
                              label: Text(AppStrings.t(t.$2, t.$3, t.$4)),
                              selected: _workType == t.$1,
                              onSelected: _submitting
                                  ? null
                                  : (_) {
                                      setState(() => _workType = t.$1);
                                      _scheduleSaveDraft();
                                    },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(
                      title: AppStrings.t(
                        'WORK SUMMARY *',
                        'รายละเอียดงานที่ทำ *',
                        'RINGKASAN KERJA *',
                      ),
                      child: TextField(
                        key: const Key('report-description-field'),
                        controller: _descController,
                        enabled: !_submitting,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: AppStrings.t(
                            'Describe what you inspected, repaired, or completed...',
                            'ระบุสิ่งที่ทำ ตรวจเช็ค ซ่อมแซม หรือความคืบหน้าของงาน...',
                            'Nyatakan apa yang diperiksa, dibaiki atau disiapkan...',
                          ),
                          filled: true,
                          fillColor: AppColors.primary,
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
                    const SizedBox(height: 12),
                    _sectionCard(
                      title: AppStrings.t(
                        'WORK PHOTOS (${_photos.length}/$_maxPhotos)',
                        'รูปภาพการทำงาน (${_photos.length}/$_maxPhotos)',
                        'FOTO KERJA (${_photos.length}/$_maxPhotos)',
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_photos.isNotEmpty) ...[
                            SizedBox(
                              height: 92,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _photos.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (_, i) => TweenAnimationBuilder<double>(
                                  key: ValueKey(_photos[i]),
                                  tween: Tween<double>(begin: 0.82, end: 1.0),
                                  duration:
                                      (MediaQuery.maybeDisableAnimationsOf(
                                            context,
                                          ) ??
                                          false)
                                      ? Duration.zero
                                      : const Duration(milliseconds: 220),
                                  curve: Curves.easeOutBack,
                                  builder: (context, value, child) => Opacity(
                                    opacity: value.clamp(0.0, 1.0),
                                    child: Transform.scale(
                                      scale: value,
                                      child: child,
                                    ),
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      GestureDetector(
                                        key: Key('report-photo-thumb-$i'),
                                        onTap: () => _previewPhoto(i),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: Image.memory(
                                            _photos[i].bytes,
                                            width: 92,
                                            height: 92,
                                            fit: BoxFit.cover,
                                            cacheWidth:
                                                (92 *
                                                        MediaQuery.devicePixelRatioOf(
                                                          context,
                                                        ))
                                                    .round()
                                                    .clamp(92, 400),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () => _removePhoto(i),
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.7,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close_rounded,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          OutlinedButton.icon(
                            key: const Key('add-report-photo-button'),
                            onPressed:
                                (_submitting || _photos.length >= _maxPhotos)
                                ? null
                                : _addPhoto,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.neutral,
                              side: BorderSide(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              backgroundColor: AppColors.secondary.withValues(
                                alpha: 0.08,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.input,
                                ),
                              ),
                            ),
                            icon: Icon(
                              Icons.add_a_photo_outlined,
                              size: 18,
                              color: AppColors.neutral,
                            ),
                            label: Text(
                              _photos.length >= _maxPhotos
                                  ? AppStrings.t(
                                      'Maximum $_maxPhotos photos attached',
                                      'แนบรูปครบ $_maxPhotos รูปแล้ว',
                                      'Maksimum $_maxPhotos foto dilampirkan',
                                    )
                                  : AppStrings.t(
                                      'Take Work Photo',
                                      'ถ่ายรูปการทำงาน',
                                      'Ambil Foto Kerja',
                                    ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(
                      title: AppStrings.t(
                        'PROBLEMS / ISSUES ENCOUNTERED',
                        'ปัญหาที่พบระหว่างทำงาน',
                        'MASALAH / ISU YANG DIHADAPI',
                      ),
                      child: TextField(
                        key: const Key('report-findings-field'),
                        controller: _findingsController,
                        enabled: !_submitting,
                        maxLines: 3,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: AppStrings.t(
                            'Describe any problems, faults, or missing parts encountered (leave blank if none)...',
                            'ระบุปัญหาที่เจอ อาการเสีย หรืออะไหล่ที่ขาดระหว่างทำงาน (เว้นว่างได้หากไม่มี)...',
                            'Nyatakan masalah, kerosakan atau alat ganti yang diperlukan (kosongkan jika tiada)...',
                          ),
                          filled: true,
                          fillColor: AppColors.primary,
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
                    const SizedBox(height: 12),
                    _sectionCard(
                      title: AppStrings.t(
                        'NEXT STEPS / RECOMMENDATIONS (OPTIONAL)',
                        'งานค้างต่อ / ข้อเสนอแนะ (ไม่บังคับ)',
                        'CADANGAN / LANGKAH SETERUSNYA (PILIHAN)',
                      ),
                      child: TextField(
                        controller: _recommendController,
                        enabled: !_submitting,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: AppStrings.t(
                            'Remaining tasks for afternoon or next visit...',
                            'สิ่งที่ต้องทำต่อช่วงบ่ายหรือรอบถัดไป...',
                            'Tugasan berbaki untuk petang atau lawatan seterusnya...',
                          ),
                          filled: true,
                          fillColor: AppColors.primary,
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
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FilledButton.icon(
                        key: const Key('submit-technician-report-button'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.neutral,
                          foregroundColor: AppColors.onNeutral,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.onNeutral,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          _submitting
                              ? (_submitStageLabel ??
                                    AppStrings.t(
                                      'Submitting Report...',
                                      'กำลังส่งรายงาน...',
                                      'Menghantar Laporan...',
                                    ))
                              : AppStrings.t(
                                  'Submit Work Report',
                                  'ส่งรายงานการทำงาน',
                                  'Hantar Laporan Kerja',
                                ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (_submitting)
                        IgnorePointer(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AnimatedFractionallySizedBox(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              widthFactor: _uploadProgress.clamp(0.0, 1.0),
                              heightFactor: 1.0,
                              child: Container(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.28,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) =>
      Container(
        padding: const EdgeInsets.all(14),
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
}

/// Self-contained deadline banner so its 30s ticker never rebuilds the form.
class _ReportDeadlineBanner extends StatefulWidget {
  const _ReportDeadlineBanner({required this.session});

  final TechnicianWorkSession session;

  @override
  State<_ReportDeadlineBanner> createState() => _ReportDeadlineBannerState();
}

class _ReportDeadlineBannerState extends State<_ReportDeadlineBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatLateDuration(int minutes) {
    if (minutes < 60) {
      return AppStrings.t('$minutes min', '$minutes นาที', '$minutes minit');
    }
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return AppStrings.t(
      '${h}h ${m}m ($minutes min)',
      '$h ชม. $m นาที ($minutes นาที)',
      '${h}j ${m}m ($minutes minit)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final lateMinutes = widget.session.reportLateMinutes();
    if (lateMinutes > 0) {
      return Container(
        key: const Key('report-late-banner'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Icon(Icons.timer_off_outlined, size: 20, color: AppColors.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppStrings.t(
                  'Overdue by ${_formatLateDuration(lateMinutes)} (past 07:00 deadline)',
                  'ส่งรายงานเกินกำหนด 07:00 น. แล้ว ${_formatLateDuration(lateMinutes)}',
                  'Lewat ${_formatLateDuration(lateMinutes)} (melepasi had 07:00)',
                ),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final remaining = widget.session.reportRemainingTime();
    if (remaining == null) return const SizedBox.shrink();
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    return Container(
      key: const Key('report-deadline-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: 20, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppStrings.t(
                'Submit before 07:00 tomorrow (${h}h ${m}m left)',
                'กรุณาส่งรายงานก่อน 07:00 น. วันถัดไป (เหลือ $h ชม. $m นาที)',
                'Hantar sebelum 07:00 esok (baki ${h}j ${m}m)',
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
    );
  }
}
