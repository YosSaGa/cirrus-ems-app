import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/payroll_calculator.dart';
import '../services/work_trial_store.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_note.dart';
import '../widgets/fade_slide_entry.dart';
import '../widgets/status_banner.dart';

enum _LeaveDraftFilter { all, active, cancelled }

/// Dedicated screen displaying all local leave drafts with status filtering
/// (All / Active / Cancelled), PDF preview, and draft cancellation.
class LeaveDraftsScreen extends StatefulWidget {
  const LeaveDraftsScreen({
    super.key,
    required this.store,
    required this.onViewPdf,
  });

  final WorkTrialStore store;
  final Future<void> Function(LeaveDraft draft) onViewPdf;

  @override
  State<LeaveDraftsScreen> createState() => _LeaveDraftsScreenState();
}

class _LeaveDraftsScreenState extends State<LeaveDraftsScreen> {
  _LeaveDraftFilter _filter = _LeaveDraftFilter.all;
  bool _busy = true;
  bool _exporting = false;
  String? _error;
  List<LeaveDraft> _drafts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final drafts = await widget.store.loadLeaves();
      if (mounted) setState(() => _drafts = drafts);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleViewPdf(LeaveDraft draft) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await widget.onViewPdf(draft);
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
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<LeaveDraft> get _filteredDrafts {
    switch (_filter) {
      case _LeaveDraftFilter.all:
        return _drafts;
      case _LeaveDraftFilter.active:
        return _drafts.where((d) => !d.cancelled).toList();
      case _LeaveDraftFilter.cancelled:
        return _drafts.where((d) => d.cancelled).toList();
    }
  }

  Widget _filterPill({
    required _LeaveDraftFilter value,
    required String label,
    required int count,
  }) {
    final selected = _filter == value;
    return Expanded(
      child: Material(
        color: selected ? AppColors.neutral : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: () => setState(() => _filter = value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: selected ? AppColors.neutral : AppColors.cardBorder,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$label ($count)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
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
  Widget build(BuildContext context) {
    final activeCount = _drafts.where((d) => !d.cancelled).length;
    final cancelledCount = _drafts.where((d) => d.cancelled).length;
    final visible = _filteredDrafts;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(AppStrings.t('All Leave Drafts', 'แบบร่างใบลาทั้งหมด')),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      _filterPill(
                        value: _LeaveDraftFilter.all,
                        label: AppStrings.t('All', 'ทั้งหมด'),
                        count: _drafts.length,
                      ),
                      const SizedBox(width: 8),
                      _filterPill(
                        value: _LeaveDraftFilter.active,
                        label: AppStrings.t('Active', 'ใช้งานอยู่'),
                        count: activeCount,
                      ),
                      const SizedBox(width: 8),
                      _filterPill(
                        value: _LeaveDraftFilter.cancelled,
                        label: AppStrings.t('Cancelled', 'ยกเลิกแล้ว'),
                        count: cancelledCount,
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: StatusBanner(
                      variant: StatusVariant.error,
                      message: _error!,
                    ),
                  ),
                Expanded(
                  child: _busy && _drafts.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : visible.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: EmptyNote(
                              icon: Icons.event_note_outlined,
                              message: _filter == _LeaveDraftFilter.all
                                  ? AppStrings.t(
                                      'No local leave drafts yet.',
                                      'ยังไม่มีแบบร่างใบลาในเครื่อง',
                                    )
                                  : _filter == _LeaveDraftFilter.active
                                  ? AppStrings.t(
                                      'No active leave drafts.',
                                      'ไม่มีแบบร่างใบลาที่ใช้งานอยู่',
                                    )
                                  : AppStrings.t(
                                      'No cancelled leave drafts.',
                                      'ไม่มีแบบร่างใบลาที่ยกเลิกแล้ว',
                                    ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final draft = visible[index];
                            return FadeSlideEntry(
                              yOffset: 6,
                              child: LeaveDraftCard(
                                draft: draft,
                                busy: _busy,
                                exporting: _exporting,
                                onViewPdf: () => _handleViewPdf(draft),
                                onCancel: () => _cancel(draft),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact reusable leave draft card with View PDF & Cancel Draft on one row.
class LeaveDraftCard extends StatelessWidget {
  const LeaveDraftCard({
    super.key,
    required this.draft,
    required this.busy,
    required this.exporting,
    required this.onViewPdf,
    required this.onCancel,
  });

  final LeaveDraft draft;
  final bool busy;
  final bool exporting;
  final VoidCallback onViewPdf;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.leaveTypeLabel(draft.type.label),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: draft.cancelled
                      ? AppColors.cardBorder
                      : AppColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  draft.cancelled
                      ? AppStrings.t('Cancelled', 'ยกเลิกแล้ว')
                      : AppStrings.t('Local draft', 'แบบร่างในเครื่อง'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: draft.cancelled
                        ? AppColors.textSecondary
                        : AppColors.neutral,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.date_range_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  AppStrings.isThai
                      ? '${calendarDate(draft.start)} ถึง ${calendarDate(draft.end)} • ${draft.calendarDays} วัน'
                      : '${calendarDate(draft.start)} to ${calendarDate(draft.end)} • ${draft.calendarDays} ${draft.calendarDays == 1 ? 'day' : 'days'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral,
                  ),
                ),
              ),
            ],
          ),
          if (draft.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                draft.reason,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: AppColors.neutral),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: busy || exporting ? null : onViewPdf,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                label: Text(AppStrings.t('View PDF', 'ดูไฟล์ PDF')),
              ),
              if (!draft.cancelled)
                TextButton.icon(
                  onPressed: busy ? null : onCancel,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    Icons.cancel_outlined,
                    size: 16,
                    color: AppColors.error,
                  ),
                  label: Text(
                    AppStrings.t('Cancel draft', 'ยกเลิกแบบร่าง'),
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
