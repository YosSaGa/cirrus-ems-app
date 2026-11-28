import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../models/payroll_calculator.dart';
import '../services/auth_service.dart';
import '../services/leave_service.dart';
import '../services/work_trial_store.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_note.dart';
import '../widgets/shimmer_box.dart';
import '../widgets/status_banner.dart';
import '../widgets/status_chip.dart';
import '../widgets/success_feedback_overlay.dart';

/// HR / Admin / Manager screen to review, approve, or reject employee leave
/// requests via `GET /leave`, `POST /leave/:id/approve`, `POST /leave/:id/reject`.
class LeaveApprovalScreen extends StatefulWidget {
  const LeaveApprovalScreen({super.key});

  @override
  State<LeaveApprovalScreen> createState() => _LeaveApprovalScreenState();
}

class _LeaveApprovalScreenState extends State<LeaveApprovalScreen> {
  bool _loading = true;
  bool _authorized = false;
  String? _error;
  String _filter = 'pending'; // pending | approved | rejected | all
  List<LeaveRequestRecord> _items = const [];
  final Set<String> _processingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final allowed = await AuthService.canApproveLeave();
      if (!mounted) return;
      if (!allowed) {
        setState(() {
          _authorized = false;
          _loading = false;
        });
        return;
      }
      final list = await LeaveService.getLeaveRequests(onlyMine: false);
      if (!mounted) return;
      setState(() {
        _authorized = true;
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _authorized = true;
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _approve(LeaveRequestRecord item) async {
    if (_processingIds.contains(item.id)) return;
    setState(() => _processingIds.add(item.id));
    try {
      await LeaveService.approveLeave(
        item.id,
        payrollTreatment: item.leaveType == LeaveType.unpaid
            ? 'unpaid'
            : 'paid',
      );
      if (!mounted) return;
      await SuccessFeedbackOverlay.show(
        context,
        title: AppStrings.t(
          'Approved',
          'อนุมัติเรียบร้อย',
          'Diluluskan',
        ),
        subtitle: item.employeeName,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
    } finally {
      if (mounted) setState(() => _processingIds.remove(item.id));
    }
  }

  Future<void> _reject(LeaveRequestRecord item) async {
    if (_processingIds.contains(item.id)) return;
    final reasonText = await showDialog<String>(
      context: context,
      builder: (_) => _RejectReasonDialog(item: item),
    );
    if (reasonText == null || !mounted) return;
    setState(() => _processingIds.add(item.id));
    try {
      await LeaveService.rejectLeave(
        item.id,
        reason: reasonText.isEmpty ? null : reasonText,
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              AppStrings.t(
                'Rejected ${item.employeeName}',
                'ไม่อนุมัติคำขอลาของ ${item.employeeName} แล้ว',
                'Permohonan ${item.employeeName} ditolak',
              ),
            ),
          ),
        );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
    } finally {
      if (mounted) setState(() => _processingIds.remove(item.id));
    }
  }

  List<LeaveRequestRecord> get _filteredItems {
    if (_filter == 'all') return _items;
    return _items.where((e) => e.status == _filter).toList(growable: false);
  }

  ChipVariant _statusVariant(String status) {
    switch (status) {
      case 'approved':
        return ChipVariant.success;
      case 'rejected':
      case 'cancelled':
        return ChipVariant.error;
      default:
        return ChipVariant.warning;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return AppStrings.t('APPROVED', 'อนุมัติแล้ว', 'DILULUSKAN');
      case 'rejected':
        return AppStrings.t('REJECTED', 'ไม่อนุมัติ', 'DITOLAK');
      case 'cancelled':
        return AppStrings.t('CANCELLED', 'ยกเลิกแล้ว', 'DIBATALKAN');
      default:
        return AppStrings.t('PENDING', 'รออนุมัติ', 'MENUNGGU');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _items.where((e) => e.isPending).length;
    final items = _filteredItems;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          AppStrings.t(
            'Leave Approvals',
            'อนุมัติใบลาพนักงาน',
            'Kelulusan Cuti',
          ),
          style: TextStyle(color: AppColors.neutral),
        ),
        actions: [
          IconButton(
            tooltip: AppStrings.t('Refresh', 'รีเฟรช', 'Muat semula'),
            onPressed: _loading ? null : _load,
            icon: Icon(Icons.refresh_rounded, color: AppColors.neutral),
          ),
        ],
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                ShimmerBox(height: 120),
                SizedBox(height: 12),
                ShimmerBox(height: 120),
              ],
            )
          : !_authorized
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: StatusBanner(
                key: const Key('leave-approval-denied'),
                variant: StatusVariant.error,
                title: AppStrings.t(
                  'Access Restricted',
                  'ไม่มีสิทธิ์เข้าถึง',
                  'Akses Terhad',
                ),
                message: AppStrings.t(
                  'Only HR, Admin, Manager, or Owner accounts can review leave requests.',
                  'เฉพาะบัญชี HR, Admin, Manager หรือ Owner เท่านั้นที่อนุมัติใบลาได้',
                  'Hanya akaun HR, Admin, Manager atau Owner boleh meluluskan cuti.',
                ),
              ),
            )
          : RefreshIndicator(
              color: AppColors.secondary,
              onRefresh: _load,
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        _filterPill(
                          'pending',
                          AppStrings.t(
                            'Pending ($pendingCount)',
                            'รออนุมัติ ($pendingCount)',
                            'Menunggu ($pendingCount)',
                          ),
                        ),
                        const SizedBox(width: 8),
                        _filterPill(
                          'approved',
                          AppStrings.t('Approved', 'อนุมัติแล้ว', 'Diluluskan'),
                        ),
                        const SizedBox(width: 8),
                        _filterPill(
                          'rejected',
                          AppStrings.t('Rejected', 'ไม่อนุมัติ', 'Ditolak'),
                        ),
                        const SizedBox(width: 8),
                        _filterPill(
                          'all',
                          AppStrings.t(
                            'All (${_items.length})',
                            'ทั้งหมด (${_items.length})',
                            'Semua (${_items.length})',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: StatusBanner(
                        variant: StatusVariant.error,
                        message: _error!,
                      ),
                    ),
                  Expanded(
                    child: items.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                              EmptyNote(
                                icon: Icons.event_available_rounded,
                                message: AppStrings.t(
                                  'No leave requests in this view.',
                                  'ไม่มีคำขอลาในหมวดนี้',
                                  'Tiada permohonan cuti dalam paparan ini.',
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: items.length,
                            itemBuilder: (_, i) => _buildCard(items[i]),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _filterPill(String key, String label) {
    final selected = _filter == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _filter = key);
      },
      selectedColor: AppColors.neutral,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
        color: selected ? AppColors.onNeutral : AppColors.neutral,
      ),
      side: BorderSide(
        color: selected ? AppColors.neutral : AppColors.cardBorder,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }

  Widget _buildCard(LeaveRequestRecord item) {
    final busy = _processingIds.contains(item.id);
    final range = item.calendarDays == 1
        ? calendarDate(item.startDate)
        : '${calendarDate(item.startDate)} → ${calendarDate(item.endDate)}';

    return Container(
      key: Key('leave-approval-card-${item.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.avatarBackground,
                child: Text(
                  item.employeeName.isNotEmpty
                      ? item.employeeName.characters.first.toUpperCase()
                      : 'E',
                  style: TextStyle(
                    color: AppColors.avatarForeground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.employeeName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.neutral,
                      ),
                    ),
                    if (item.employeeCode != null)
                      Text(
                        '#${item.employeeCode}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              StatusChip(
                label: _statusLabel(item.status),
                variant: _statusVariant(item.status),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.event_note_rounded,
                size: 16,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${AppStrings.leaveTypeLabel(item.leaveType.label)} · $range (${item.calendarDays} ${AppStrings.t("day(s)", "วัน", "hari")})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.reason,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          if (item.reviewNote != null && item.reviewNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${AppStrings.t("Note", "หมายเหตุ", "Catatan")}: ${item.reviewNote}',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (item.isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: Key('reject-leave-${item.id}'),
                    onPressed: busy ? null : () => _reject(item),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(AppStrings.t('Reject', 'ไม่อนุมัติ', 'Tolak')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    key: Key('approve-leave-${item.id}'),
                    onPressed: busy ? null : () => _approve(item),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.neutral,
                      foregroundColor: AppColors.onNeutral,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    icon: busy
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onNeutral,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(AppStrings.t('Approve', 'อนุมัติ', 'Luluskan')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog({required this.item});

  final LeaveRequestRecord item;

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.surface),
      ),
      title: Text(
        AppStrings.t(
          'Reject Leave Request?',
          'ไม่อนุมัติคำขอลา?',
          'Tolak Permohonan Cuti?',
        ),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.neutral,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${item.employeeName} · ${calendarDate(item.startDate)} → ${calendarDate(item.endDate)}',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: AppStrings.t(
                'Reason (optional)',
                'เหตุผล (ไม่บังคับ)',
                'Sebab (pilihan)',
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(AppStrings.t('Cancel', 'ยกเลิก', 'Batal')),
        ),
        FilledButton(
          key: Key('confirm-reject-leave-${item.id}'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(_reasonCtrl.text.trim()),
          child: Text(AppStrings.t('Reject', 'ไม่อนุมัติ', 'Tolak')),
        ),
      ],
    );
  }
}
