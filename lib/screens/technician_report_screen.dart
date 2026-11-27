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
  }) : assert(session != null || job != null);

  final TechnicianWorkSession? session;
  final TechnicianJob? job;

  @override
  State<TechnicianReportScreen> createState() => _TechnicianReportScreenState();
}

class _TechnicianReportScreenState extends State<TechnicianReportScreen> {
  final _descController = TextEditingController();
  final _findingsController = TextEditingController();
  final _recommendController = TextEditingController();
  final List<CapturedPhoto> _photos = [];

  static const int _maxPhotos = 4;

  String _workType = 'service';
  bool _submitting = false;
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
    _descController.addListener(_scheduleSaveDraft);
    _findingsController.addListener(_scheduleSaveDraft);
    _recommendController.addListener(_scheduleSaveDraft);
    _restoreDraft();
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

  void _removePhoto(int index) {
    if (_submitting || index < 0 || index >= _photos.length) return;
    HapticFeedback.selectionClick();
    setState(() => _photos.removeAt(index));
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

    HapticFeedback.mediumImpact();
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final uploadedPhotoKeys = <String>[];
      for (var i = 0; i < _photos.length; i++) {
        final storageKey = await AttendanceService.uploadAttendancePhoto(
          _photos[i],
          const Uuid().v4(),
        );
        uploadedPhotoKeys.add(storageKey);
      }

      await TechnicianService.submitReport(
        sessionId: widget.session?.id ?? '',
        workOrderId: widget.job?.id ?? widget.session?.jobId,
        projectId: widget.job?.projectId,
        workDescription: desc,
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
        _error = e.toString().replaceFirst('Exception: ', '');
        _submitting = false;
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

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
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
                              onPressed: _submitting ? null : _clearDraft,
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
                                itemBuilder: (_, i) => Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.memory(
                                        _photos[i].bytes,
                                        width: 92,
                                        height: 92,
                                        fit: BoxFit.cover,
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
                child: FilledButton.icon(
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
                        ? AppStrings.t(
                            'Submitting Report...',
                            'กำลังส่งรายงาน...',
                            'Menghantar Laporan...',
                          )
                        : AppStrings.t(
                            'Submit Work Report',
                            'ส่งรายงานการทำงาน',
                            'Hantar Laporan Kerja',
                          ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
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
