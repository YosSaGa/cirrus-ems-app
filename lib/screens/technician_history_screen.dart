import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/technician_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_box.dart';
import '../widgets/status_banner.dart';
import '../widgets/status_chip.dart';

/// Displays past Technician work sessions and their submitted work reports.
/// Accessible from Settings strictly for `Technician` and `Admin` roles.
class TechnicianHistoryScreen extends StatefulWidget {
  const TechnicianHistoryScreen({super.key});

  @override
  State<TechnicianHistoryScreen> createState() =>
      _TechnicianHistoryScreenState();
}

class _TechnicianHistoryScreenState extends State<TechnicianHistoryScreen> {
  bool _loading = true;
  String? _error;
  bool _isAdmin = false;
  bool _onlyMine = false;
  String _statusFilter = 'all';
  List<TechnicianHistoryItem> _items = const [];
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await TechnicianService.getHistory();
      if (!mounted) return;
      setState(() {
        _isAdmin = res.isAdmin;
        _items = res.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<TechnicianHistoryItem> get _filtered {
    final q = _query.trim().toLowerCase();
    return _items.where((item) {
      if (_isAdmin && _onlyMine && !item.isMine) return false;
      if (_statusFilter == 'completed' &&
          item.jobStatusAtCheckout != 'completed') {
        return false;
      }
      if (_statusFilter == 'in_progress' &&
          item.jobStatusAtCheckout == 'completed') {
        return false;
      }
      if (q.isEmpty) return true;
      return item.jobCode.toLowerCase().contains(q) ||
          item.jobTitle.toLowerCase().contains(q) ||
          item.technicianName.toLowerCase().contains(q) ||
          (item.workDescription?.toLowerCase().contains(q) ?? false) ||
          (item.reportNumber?.toLowerCase().contains(q) ?? false);
    }).toList(growable: false);
  }

  String _fmtDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '-';
    final d = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final t = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$d · $t';
  }

  String _fmtTime(String? iso) {
    if (iso == null || iso.isEmpty) return '--:--';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.neutral,
        elevation: 0,
        title: Text(
          AppStrings.t(
            'Job & Report History',
            'ประวัติงานและรายงานช่าง',
            'Sejarah Kerja & Laporan',
          ),
          style: TextStyle(
            color: AppColors.neutral,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: AppStrings.t('Refresh', 'รีเฟรช', 'Muat semula'),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.secondary,
          onRefresh: _load,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: AppStrings.t(
                          'Search job code, report, or technician...',
                          'ค้นหารหัสงาน รายงาน หรือชื่อช่าง...',
                          'Cari kod kerja, laporan, atau juruteknik...',
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                        ),
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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text(
                            AppStrings.t('All', 'ทั้งหมด', 'Semua'),
                          ),
                          selected: _statusFilter == 'all',
                          onSelected: (_) =>
                              setState(() => _statusFilter = 'all'),
                        ),
                        ChoiceChip(
                          label: Text(
                            AppStrings.t('Completed', 'เสร็จสิ้น', 'Selesai'),
                          ),
                          selected: _statusFilter == 'completed',
                          onSelected: (_) =>
                              setState(() => _statusFilter = 'completed'),
                        ),
                        ChoiceChip(
                          label: Text(
                            AppStrings.t(
                              'In Progress',
                              'กำลังทำต่อ',
                              'Berjalan',
                            ),
                          ),
                          selected: _statusFilter == 'in_progress',
                          onSelected: (_) =>
                              setState(() => _statusFilter = 'in_progress'),
                        ),
                        if (_isAdmin) ...[
                          ChoiceChip(
                            label: Text(
                              AppStrings.t(
                                'All Technicians',
                                'ช่างทุกคน',
                                'Semua Juruteknik',
                              ),
                            ),
                            selected: !_onlyMine,
                            onSelected: (_) => setState(() => _onlyMine = false),
                          ),
                          ChoiceChip(
                            label: Text(
                              AppStrings.t(
                                'My Jobs Only',
                                'เฉพาะงานของฉัน',
                                'Kerja Saya',
                              ),
                            ),
                            selected: _onlyMine,
                            onSelected: (_) => setState(() => _onlyMine = true),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: const [
                          ShimmerCardSkeleton(height: 120),
                          SizedBox(height: 12),
                          ShimmerCardSkeleton(height: 120),
                        ],
                      )
                    : _error != null
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          StatusBanner(
                            variant: StatusVariant.error,
                            message: _error!,
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: OutlinedButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: Text(
                                AppStrings.t('Retry', 'ลองใหม่', 'Cuba lagi'),
                              ),
                            ),
                          ),
                        ],
                      )
                    : items.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(32),
                        children: [
                          Icon(
                            Icons.history_toggle_off_rounded,
                            size: 48,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            AppStrings.t(
                              'No job reports recorded yet.',
                              'ยังไม่มีประวัติงานและรายงานช่างในระบบ',
                              'Tiada sejarah kerja dan laporan lagi.',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: items.length,
                        itemBuilder: (_, i) => _historyCard(items[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyCard(TechnicianHistoryItem item) {
    final isCompleted = item.jobStatusAtCheckout == 'completed';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      item.jobCode,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.neutral,
                      ),
                    ),
                    StatusChip(
                      label: isCompleted
                          ? AppStrings.t('COMPLETED', 'เสร็จสิ้น', 'SELESAI')
                          : AppStrings.t('IN PROGRESS', 'กำลังทำต่อ', 'BERJALAN'),
                      variant: isCompleted
                          ? ChipVariant.success
                          : ChipVariant.active,
                    ),
                  ],
                ),
              ),
              if (item.durationMinutes != null)
                Text(
                  '${item.durationMinutes!.round()} min',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          if (item.jobTitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.jobTitle,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral.withValues(alpha: 0.9),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              _metaChip(
                Icons.schedule_rounded,
                '${_fmtDateTime(item.checkInAt)} → ${_fmtTime(item.checkOutAt)}',
              ),
              if (_isAdmin)
                _metaChip(Icons.person_outline, item.technicianName),
              if (item.hasGps)
                _metaChip(Icons.location_on_outlined, 'GPS ✓'),
              if (item.photoCount > 0)
                _metaChip(
                  Icons.photo_camera_outlined,
                  AppStrings.t(
                    '${item.photoCount} ${item.photoCount == 1 ? 'photo' : 'photos'}',
                    '${item.photoCount} รูป',
                    '${item.photoCount} foto',
                  ),
                ),
            ],
          ),
          Divider(height: 20, color: AppColors.cardBorder),
          if (item.hasReport) ...[
            Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 15,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 6),
                Text(
                  item.reportNumber ??
                      AppStrings.t('WORK REPORT', 'รายงานการทำงาน', 'LAPORAN KERJA'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.neutral,
                  ),
                ),
                if (item.workType != null && item.workType!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    '· ${item.workType!.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.workDescription ?? '',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.neutral,
              ),
            ),
            if (item.findings != null && item.findings!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${AppStrings.t('Problems', 'ปัญหาที่พบ', 'Masalah')}: ${item.findings}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral,
                  ),
                ),
              ),
            ],
            if (item.recommendations != null &&
                item.recommendations!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${AppStrings.t('Next steps', 'งานค้างต่อ', 'Cadangan')}: ${item.recommendations}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ] else
            Text(
              AppStrings.t(
                'Report pending submission',
                'ยังไม่ได้ส่งรายงานสำหรับรอบนี้',
                'Laporan belum dihantar',
              ),
              style: TextStyle(
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                color: AppColors.warning,
              ),
            ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) => Row(
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
