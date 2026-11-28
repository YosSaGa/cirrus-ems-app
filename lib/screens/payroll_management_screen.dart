import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../models/payroll_calculator.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../services/payroll_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_slide_entry.dart';
import '../widgets/shimmer_box.dart';
import '../widgets/status_banner.dart';

/// HR / Admin / Accountant Payroll & Deductions Management screen.
///
/// Allows authorized roles (`HR Officer`, `Admin`, `Accountant`, `Owner`) to:
/// - Configure each employee's direct hourly rate (`hr.compensation`) or base salary
/// - Add, edit, toggle, and delete recurring deductions & earnings
///   (Accommodation / ค่าที่พัก, Social Security / ค่าประกันสังคม,
///   Work Insurance / ค่าประกันงาน, or custom items) in PostgreSQL.
class PayrollManagementScreen extends StatefulWidget {
  const PayrollManagementScreen({super.key});

  @override
  State<PayrollManagementScreen> createState() =>
      _PayrollManagementScreenState();
}

class _PayrollManagementScreenState extends State<PayrollManagementScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = true;
  bool _authorized = false;
  String? _error;
  List<EmployeePayrollProfile> _employees = const [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<EmployeePayrollProfile> get _filteredEmployees {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _employees;
    return _employees.where((e) {
      return e.name.toLowerCase().contains(q) ||
          (e.employeeCode?.toLowerCase().contains(q) ?? false) ||
          (e.department?.toLowerCase().contains(q) ?? false);
    }).toList(growable: false);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final allowed = await AuthService.canManagePayroll();
    if (!mounted) return;
    if (!allowed) {
      setState(() {
        _authorized = false;
        _loading = false;
      });
      return;
    }
    try {
      final list = await PayrollService.getEmployeesPayroll();
      if (!mounted) return;
      setState(() {
        _authorized = true;
        _employees = list;
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

  Future<void> _openEmployeeDetail(EmployeePayrollProfile profile) async {
    HapticFeedback.selectionClick();
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _EmployeePayrollEditorScreen(profile: profile),
      ),
    );
    if (changed == true && mounted) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageService.languageNotifier,
      builder: (context, _, _) {
        return Scaffold(
          backgroundColor: AppColors.primary,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.neutral,
            iconTheme: IconThemeData(color: AppColors.neutral),
            title: Text(
              AppStrings.t(
                'Payroll & Deductions',
                'จัดการค่าแรงและรายการหัก',
              ),
            ),
            actions: [
              IconButton(
                tooltip: AppStrings.t('Refresh', 'รีเฟรช'),
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: _loading
                ? _buildSkeleton()
                : !_authorized
                ? _buildForbidden()
                : RefreshIndicator(
                    color: AppColors.secondary,
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        appTabBottomPadding(context),
                      ),
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: appContentMaxWidth(context),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeaderBanner(),
                                const SizedBox(height: AppSpacing.md),
                                TextField(
                                  key: const Key('payroll-employee-search'),
                                  controller: _searchCtrl,
                                  onChanged: (v) =>
                                      setState(() => _searchQuery = v),
                                  decoration: InputDecoration(
                                    hintText: AppStrings.t(
                                      'Search employee name or code…',
                                      'ค้นหาชื่อหรือรหัสพนักงาน…',
                                      'Cari nama atau kod pekerja…',
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                    ),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.close_rounded,
                                            ),
                                            onPressed: () {
                                              _searchCtrl.clear();
                                              setState(() => _searchQuery = '');
                                            },
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                if (_error != null) ...[
                                  StatusBanner(
                                    message: _error!,
                                    variant: StatusVariant.error,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                ],
                                if (_filteredEmployees.isEmpty &&
                                    _error == null)
                                  Card(
                                    margin: EdgeInsets.zero,
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        AppStrings.t(
                                          'No employees found.',
                                          'ไม่พบข้อมูลพนักงาน',
                                        ),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  ..._filteredEmployees.map(
                                    (emp) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: _EmployeePayrollCard(
                                        profile: emp,
                                        onTap: () => _openEmployeeDetail(emp),
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
          ),
        );
      },
    );
  }

  Widget _buildSkeleton() => Padding(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      children: const [
        ShimmerCardSkeleton(height: 82),
        SizedBox(height: 12),
        ShimmerCardSkeleton(height: 92),
        SizedBox(height: 10),
        ShimmerCardSkeleton(height: 92),
      ],
    ),
  );

  Widget _buildForbidden() => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 42,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                AppStrings.t('Permission required', 'ไม่มีสิทธิ์เข้าถึง'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppStrings.t(
                  'Only HR, Admin, and Accountant roles can manage hourly rates and payroll deductions.',
                  'เฉพาะสิทธิ์ HR, Admin และ Accountant เท่านั้นที่สามารถเพิ่ม แก้ไข หรือลบอัตราค่าแรงและรายการหักได้',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildHeaderBanner() => FadeSlideEntry(
    yOffset: 8,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.neutral,
        borderRadius: BorderRadius.circular(AppRadius.surface),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.admin_panel_settings_outlined,
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
                    'HR · Admin · Accountant',
                    'สิทธิ์ HR · Admin · Accountant',
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.t(
                    'Tap an employee to set hourly rate & manage deductions (Accommodation, Social Security, Work Insurance).',
                    'แตะชื่อพนักงานเพื่อตั้งค่าเรทต่อชั่วโมง และเพิ่ม/แก้/ลบ ค่าที่พัก ประกันสังคม ค่าประกันงาน',
                  ),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.onNeutral.withValues(alpha: 0.88),
                    height: 1.35,
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

class _EmployeePayrollCard extends StatelessWidget {
  const _EmployeePayrollCard({
    required this.profile,
    required this.onTap,
  });

  final EmployeePayrollProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final settings = profile.effectivePaySettings;
    final activeDeductions = profile.items
        .where((i) => i.isActive && i.isDeduction)
        .length;
    final rateLabel = profile.hourlyRate != null && profile.hourlyRate! > 0
        ? '${formatBaht(settings.hourlySatang)}/hr (${AppStrings.t('Direct', 'รายชม.')})'
        : '${formatBaht(settings.hourlySatang)}/hr';

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.surface),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: AppColors.secondary.withValues(alpha: 0.14),
                child: Text(
                  profile.name.isNotEmpty
                      ? profile.name.characters.first.toUpperCase()
                      : 'E',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.neutral,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.neutral,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile.employeeCode != null)
                          Text(
                            '#${profile.employeeCode}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _MiniBadge(
                          text: rateLabel,
                          highlight: true,
                        ),
                        _MiniBadge(
                          text: activeDeductions > 0
                              ? AppStrings.t(
                                  '$activeDeductions deductions',
                                  'หัก $activeDeductions รายการ',
                                )
                              : AppStrings.t('No deductions', 'ยังไม่มีรายการหัก'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.text, this.highlight = false});
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.secondary.withValues(alpha: 0.14)
            : AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: highlight
              ? AppColors.secondary.withValues(alpha: 0.35)
              : AppColors.cardBorder,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.neutral,
        ),
      ),
    );
  }
}

class _EmployeePayrollEditorScreen extends StatefulWidget {
  const _EmployeePayrollEditorScreen({required this.profile});
  final EmployeePayrollProfile profile;

  @override
  State<_EmployeePayrollEditorScreen> createState() =>
      _EmployeePayrollEditorScreenState();
}

class _EmployeePayrollEditorScreenState
    extends State<_EmployeePayrollEditorScreen> {
  late TextEditingController _hourlyCtrl;
  late TextEditingController _salaryCtrl;
  late List<PayrollAdjustmentItem> _items;
  late String _savedHourlyText;
  late String _savedSalaryText;
  bool _savingRate = false;
  bool _dirty = false;

  bool get _hasUnsavedRates =>
      _hourlyCtrl.text.trim() != _savedHourlyText ||
      _salaryCtrl.text.trim() != _savedSalaryText;

  @override
  void initState() {
    super.initState();
    _savedHourlyText =
        widget.profile.hourlyRate != null && widget.profile.hourlyRate! > 0
        ? _formatNum(widget.profile.hourlyRate!)
        : '';
    _savedSalaryText =
        widget.profile.salary != null && widget.profile.salary! > 0
        ? _formatNum(widget.profile.salary!)
        : '';
    _hourlyCtrl = TextEditingController(text: _savedHourlyText);
    _salaryCtrl = TextEditingController(text: _savedSalaryText);
    _items = List<PayrollAdjustmentItem>.from(widget.profile.items);
  }

  @override
  void dispose() {
    _hourlyCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  String _formatNum(double v) =>
      v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Future<void> _saveRates() async {
    final rawHourly = _hourlyCtrl.text.trim();
    final rawSalary = _salaryCtrl.text.trim();
    final hourly = rawHourly.isEmpty ? null : double.tryParse(rawHourly);
    final salary = rawSalary.isEmpty ? null : double.tryParse(rawSalary);

    if (rawHourly.isNotEmpty && (hourly == null || hourly <= 0)) {
      _showSnack(
        AppStrings.t('Enter a valid hourly rate', 'กรุณากรอกเรทต่อชั่วโมงให้ถูกต้อง'),
      );
      return;
    }
    if (rawSalary.isNotEmpty && (salary == null || salary < 0)) {
      _showSnack(
        AppStrings.t('Enter a valid monthly salary', 'กรุณากรอกฐานเงินเดือนให้ถูกต้อง'),
      );
      return;
    }

    if (hourly != null && hourly > 5000) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppStrings.t('Confirm high hourly rate', 'ยืนยันอัตราค่าแรงสูง')),
          content: Text(
            AppStrings.isThai
                ? 'คุณกรอกอัตราค่าแรง ${formatBaht((hourly * 100).round())}/ชม. ต้องการบันทึกใช่หรือไม่?'
                : 'You entered ${formatBaht((hourly * 100).round())}/hr. Are you sure you want to save this rate?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(AppStrings.t('Cancel', 'ยกเลิก')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(AppStrings.t('Save', 'บันทึก')),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _savingRate = true);
    try {
      await PayrollService.updateEmployeeRate(
        employeeId: widget.profile.employeeId,
        hourlyRate: hourly,
        salary: salary,
        updateHourlyRate: true,
        updateSalary: true,
      );
      _savedHourlyText = rawHourly;
      _savedSalaryText = rawSalary;
      _dirty = true;
      HapticFeedback.lightImpact();
      if (!mounted) return;
      _showSnack(
        AppStrings.t('Saved pay rate to database', 'บันทึกอัตราค่าแรงลงฐานข้อมูลแล้ว'),
      );
    } catch (e) {
      if (mounted) {
        _showSnack(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _savingRate = false);
    }
  }

  Future<void> _openItemDialog({
    PayrollAdjustmentItem? existing,
    String? presetCode,
    String? presetName,
    String presetCalcMode = 'fixed',
    String presetAmount = '',
    String presetMaxCap = '',
  }) async {
    final nameCtrl = TextEditingController(
      text: existing?.name ?? presetName ?? '',
    );
    final amountCtrl = TextEditingController(
      text: existing != null ? _formatNum(existing.amount) : presetAmount,
    );
    final capCtrl = TextEditingController(
      text: existing?.maxCap != null
          ? _formatNum(existing!.maxCap!)
          : presetMaxCap,
    );
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    var componentType = existing?.componentType ?? 'deduction';
    var calcMode = existing?.calcMode ?? presetCalcMode;
    var saving = false;
    String? dialogError;

    // Warn when adding a duplicate preset/item code or name
    if (existing == null && (presetCode != null || presetName != null)) {
      final hasDuplicate = _items.any(
        (i) =>
            (presetCode != null &&
                i.code.toUpperCase() == presetCode.toUpperCase()) ||
            (presetName != null &&
                i.name.trim().toLowerCase() ==
                    presetName.trim().toLowerCase()),
      );
      if (hasDuplicate) {
        dialogError = AppStrings.t(
          'A similar item already exists for this employee. Check before adding a duplicate.',
          'พนักงานคนนี้มีรายการนี้อยู่แล้ว กรุณาตรวจสอบก่อนเพิ่มซ้ำ',
        );
      }
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.surface),
          ),
          title: Text(
            existing == null
                ? AppStrings.t('Add payroll item', 'เพิ่มรายการหัก / เพิ่ม')
                : AppStrings.t('Edit payroll item', 'แก้ไขรายการ'),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.neutral,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: AppStrings.t('Item name', 'ชื่อรายการ'),
                    hintText: AppStrings.t(
                      'e.g. Accommodation, Social Security',
                      'เช่น ค่าที่พัก, ค่าประกันสังคม, ค่าประกันงาน',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(AppStrings.t('Deduction (-)', 'รายการหัก (-)')),
                      selected: componentType == 'deduction',
                      onSelected: (_) =>
                          setDialogState(() => componentType = 'deduction'),
                    ),
                    ChoiceChip(
                      label: Text(AppStrings.t('Earning (+)', 'รายการเพิ่ม (+)')),
                      selected: componentType == 'earning',
                      onSelected: (_) =>
                          setDialogState(() => componentType = 'earning'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(AppStrings.t('Fixed (THB)', 'ยอดคงที่ (บาท)')),
                      selected: calcMode == 'fixed',
                      onSelected: (_) =>
                          setDialogState(() => calcMode = 'fixed'),
                    ),
                    ChoiceChip(
                      label: Text(AppStrings.t('Percent (%)', 'เปอร์เซ็นต์ (%)')),
                      selected: calcMode == 'percent',
                      onSelected: (_) =>
                          setDialogState(() => calcMode = 'percent'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: calcMode == 'percent'
                        ? AppStrings.t('Rate (%)', 'อัตรา (%)')
                        : AppStrings.t('Amount (THB)', 'จำนวนเงิน (บาท)'),
                  ),
                ),
                if (calcMode == 'percent') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: capCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: AppStrings.t(
                        'Max cap (THB, optional)',
                        'เพดานสูงสุด (บาท, ไม่บังคับ)',
                      ),
                      hintText: '750',
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(
                    labelText: AppStrings.t('Note (optional)', 'หมายเหตุ (ถ้ามี)'),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    dialogError!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(dialogCtx).pop(false),
              child: Text(AppStrings.t('Cancel', 'ยกเลิก')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.neutral,
                foregroundColor: AppColors.onNeutral,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      if (saving) return;
                final name = nameCtrl.text.trim();
                final amt = double.tryParse(amountCtrl.text.trim());
                final capText = capCtrl.text.trim();
                final cap = capText.isEmpty ? null : double.tryParse(capText);
                if (name.isEmpty) {
                  setDialogState(
                    () => dialogError = AppStrings.t(
                      'Please enter an item name.',
                      'กรุณากรอกชื่อรายการ',
                    ),
                  );
                  return;
                }
                if (amt == null || amt < 0) {
                  setDialogState(
                    () => dialogError = AppStrings.t(
                      'Please enter a valid non-negative amount.',
                      'กรุณากรอกจำนวนเงินให้ถูกต้อง (ไม่ติดลบ)',
                    ),
                  );
                  return;
                }
                if (calcMode == 'percent' && amt > 100) {
                  setDialogState(
                    () => dialogError = AppStrings.t(
                      'Percentage must be between 0 and 100%.',
                      'เปอร์เซ็นต์ต้องอยู่ระหว่าง 0 ถึง 100%',
                    ),
                  );
                  return;
                }
                if (calcMode == 'percent' &&
                    capText.isNotEmpty &&
                    (cap == null || cap < 0)) {
                  setDialogState(
                    () => dialogError = AppStrings.t(
                      'Please enter a valid max cap.',
                      'กรุณากรอกเพดานสูงสุดให้ถูกต้อง',
                    ),
                  );
                  return;
                }
                setDialogState(() {
                  saving = true;
                  dialogError = null;
                });
                try {
                  if (existing == null) {
                    final created = await PayrollService.addEmployeeItem(
                      employeeId: widget.profile.employeeId,
                      code: presetCode ?? 'CUSTOM',
                      name: name,
                      componentType: componentType,
                      calcMode: calcMode,
                      amount: amt,
                      maxCap: calcMode == 'percent' ? cap : null,
                      notes: notesCtrl.text.trim(),
                    );
                    if (mounted) {
                      setState(() {
                        _items.add(created);
                        _dirty = true;
                      });
                    }
                  } else {
                    final updated = await PayrollService.updateEmployeeItem(
                      itemId: existing.id,
                      name: name,
                      componentType: componentType,
                      calcMode: calcMode,
                      amount: amt,
                      maxCap: calcMode == 'percent' ? cap : null,
                      clearMaxCap: calcMode != 'percent' || cap == null,
                      notes: notesCtrl.text.trim(),
                    );
                    if (mounted) {
                      setState(() {
                        final idx = _items.indexWhere(
                          (x) => x.id == existing.id,
                        );
                        if (idx >= 0) _items[idx] = updated;
                        _dirty = true;
                      });
                    }
                  }
                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop(true);
                } catch (e) {
                  if (dialogCtx.mounted) {
                    setDialogState(() => saving = false);
                  }
                  if (mounted) {
                    _showSnack(e.toString().replaceFirst('Exception: ', ''));
                  }
                }
              },
              child: Text(AppStrings.t('Save', 'บันทึก')),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _toggleActive(PayrollAdjustmentItem item, bool value) async {
    try {
      final updated = await PayrollService.updateEmployeeItem(
        itemId: item.id,
        isActive: value,
      );
      if (!mounted) return;
      setState(() {
        final idx = _items.indexWhere((x) => x.id == item.id);
        if (idx >= 0) _items[idx] = updated;
        _dirty = true;
      });
    } catch (e) {
      if (mounted) _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteItem(PayrollAdjustmentItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.surface),
        ),
        title: Text(
          AppStrings.t('Delete payroll item?', 'ลบรายการนี้หรือไม่?'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.neutral,
          ),
        ),
        content: Text(
          AppStrings.isThai
              ? 'ต้องการลบ "${item.name}" ออกจาก ${widget.profile.name} ใช่หรือไม่?'
              : 'Remove "${item.name}" from ${widget.profile.name}? This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppStrings.t('Cancel', 'ยกเลิก')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppStrings.t('Delete', 'ลบ')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await PayrollService.deleteEmployeeItem(item.id);
      if (!mounted) return;
      setState(() {
        _items.removeWhere((x) => x.id == item.id);
        _dirty = true;
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _handleBack() async {
    if (_hasUnsavedRates) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.surface),
          ),
          title: Text(
            AppStrings.t('Unsaved changes', 'มีการแก้ไขที่ยังไม่บันทึก'),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.neutral,
            ),
          ),
          content: Text(
            AppStrings.t(
              'You modified the pay rate without tapping Save rate. Discard changes?',
              'คุณแก้ไขอัตราค่าแรงแต่ยังไม่ได้กดบันทึก ต้องการออกโดยไม่บันทึกใช่ไหม?',
            ),
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(AppStrings.t('Stay', 'อยู่ต่อ')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(AppStrings.t('Discard', 'ออกโดยไม่บันทึก')),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }
    if (mounted) Navigator.of(context).pop(_dirty);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.primary,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.neutral,
          iconTheme: IconThemeData(color: AppColors.neutral),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _handleBack,
          ),
          title: Text(widget.profile.name),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              appTabBottomPadding(context),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: appContentMaxWidth(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 0. Live Net Preview Card (240h full-month estimate)
                    Builder(
                      builder: (_) {
                        final hVal = double.tryParse(_hourlyCtrl.text.trim());
                        final sVal = double.tryParse(_salaryCtrl.text.trim());
                        final effectiveSettings = PaySettings.forEmployeeSalary(
                          sVal,
                          hourlyRateBaht: hVal,
                        );
                        final grossSatang =
                            effectiveSettings.isDirectHourly
                            ? effectiveSettings.hourlySatang * 240
                            : (sVal != null && sVal > 0
                                  ? (sVal * 100).round()
                                  : effectiveSettings.hourlySatang * 240);
                        final netSummary = PayrollNetSummary.calculate(
                          grossSatang: grossSatang,
                          items: _items,
                        );
                        return Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.neutral,
                            borderRadius: BorderRadius.circular(
                              AppRadius.surface,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppStrings.t(
                                        'LIVE NET PREVIEW (FULL MONTH 240H)',
                                        'ตัวอย่างยอดสุทธิเต็มเดือน (240 ชม.)',
                                      ),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                        color: AppColors.onNeutral.withValues(
                                          alpha: 0.72,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formatBaht(netSummary.netSatang),
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${AppStrings.t('Gross', 'ก่อนหัก')}: ${formatBaht(netSummary.grossSatang)}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.onNeutral.withValues(
                                        alpha: 0.85,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${AppStrings.t('Deductions', 'หักรวม')}: -${formatBaht(netSummary.totalDeductionsSatang)}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFFCA5A5),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // 1. Hourly Rate & Base Salary Card
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              AppStrings.t(
                                'HOURLY RATE & BASE SALARY',
                                'อัตราค่าแรงรายชั่วโมง & ฐานเงินเดือน',
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _hourlyCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: AppStrings.t(
                                  'Direct Hourly Rate (THB / hr)',
                                  'อัตราค่าแรงรายชั่วโมง (บาท/ชม.)',
                                ),
                                hintText: AppStrings.t(
                                  'Leave blank to derive from salary ÷ 30 ÷ 8',
                                  'เว้นว่างหากคำนวณจาก เงินเดือน ÷ 30 ÷ 8',
                                ),
                                prefixIcon: const Icon(Icons.schedule_rounded),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _salaryCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: AppStrings.t(
                                  'Monthly Base Salary (THB)',
                                  'ฐานเงินเดือนรายเดือน (บาท)',
                                ),
                                prefixIcon: const Icon(Icons.payments_outlined),
                              ),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: _savingRate ? null : _saveRates,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.neutral,
                                foregroundColor: AppColors.onNeutral,
                                minimumSize: const Size(0, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                              ),
                              icon: _savingRate
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.onNeutral,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined, size: 18),
                              label: Text(
                                AppStrings.t('Save rate', 'บันทึกอัตราค่าแรง'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // 2. Quick Add Standard Deductions
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    AppStrings.t(
                                      'DEDUCTIONS & ADJUSTMENTS',
                                      'รายการหักและปรับปรุงค่าแรง',
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _openItemDialog(),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: Text(AppStrings.t('Add', 'เพิ่ม')),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.home_outlined,
                                    size: 16,
                                  ),
                                  label: Text(
                                    AppStrings.t(
                                      '+ Accommodation',
                                      '+ ค่าที่พัก',
                                    ),
                                  ),
                                  onPressed: () => _openItemDialog(
                                    presetCode: 'ACCOMMODATION',
                                    presetName: AppStrings.t(
                                      'Accommodation',
                                      'ค่าที่พัก',
                                    ),
                                    presetCalcMode: 'fixed',
                                    presetAmount: '1500',
                                  ),
                                ),
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.shield_outlined,
                                    size: 16,
                                  ),
                                  label: Text(
                                    AppStrings.t(
                                      '+ Social Security (5%)',
                                      '+ ค่าประกันสังคม (5%)',
                                    ),
                                  ),
                                  onPressed: () => _openItemDialog(
                                    presetCode: 'SOCIAL_SECURITY',
                                    presetName: AppStrings.t(
                                      'Social Security',
                                      'ค่าประกันสังคม',
                                    ),
                                    presetCalcMode: 'percent',
                                    presetAmount: '5',
                                    presetMaxCap: '750',
                                  ),
                                ),
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.verified_user_outlined,
                                    size: 16,
                                  ),
                                  label: Text(
                                    AppStrings.t(
                                      '+ Work Insurance',
                                      '+ ค่าประกันงาน',
                                    ),
                                  ),
                                  onPressed: () => _openItemDialog(
                                    presetCode: 'WORK_INSURANCE',
                                    presetName: AppStrings.t(
                                      'Work Insurance',
                                      'ค่าประกันงาน',
                                    ),
                                    presetCalcMode: 'fixed',
                                    presetAmount: '500',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (_items.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Text(
                                  AppStrings.t(
                                    'No deductions configured yet. Tap a preset above to add.',
                                    'ยังไม่มีรายการหัก กดปุ่มลัดด้านบนเพื่อเพิ่มได้เลย',
                                  ),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              )
                            else
                              ..._items.map((item) => _buildItemRow(item)),
                          ],
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
  }

  Widget _buildItemRow(PayrollAdjustmentItem item) {
    final amountText = item.isPercent
        ? '${_formatNum(item.amount)}%${item.maxCap != null ? ' (max ${formatBaht((item.maxCap! * 100).round())})' : ''}'
        : formatBaht((item.amount * 100).round());
    final sign = item.isDeduction ? '-' : '+';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Switch.adaptive(
            value: item.isActive,
            activeTrackColor: AppColors.secondary,
            onChanged: (v) => _toggleActive(item, v),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: item.isActive
                        ? AppColors.neutral
                        : AppColors.textSecondary,
                    decoration: item.isActive
                        ? null
                        : TextDecoration.lineThrough,
                  ),
                ),
                Text(
                  '$sign$amountText',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: item.isDeduction
                        ? AppColors.error
                        : AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: AppStrings.t('Edit', 'แก้ไข'),
            icon: Icon(Icons.edit_outlined, size: 18, color: AppColors.neutral),
            onPressed: () => _openItemDialog(existing: item),
          ),
          IconButton(
            tooltip: AppStrings.t('Delete', 'ลบ'),
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: AppColors.error,
            ),
            onPressed: () => _deleteItem(item),
          ),
        ],
      ),
    );
  }
}
