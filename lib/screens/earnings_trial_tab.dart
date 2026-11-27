import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/payroll_calculator.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/payroll_service.dart';
import '../services/work_trial_store.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_slide_entry.dart';
import '../widgets/pay_wallet_card.dart';
import '../widgets/status_banner.dart';
import 'pay_calculator_screen.dart';

class EarningsTrialTab extends StatefulWidget {
  const EarningsTrialTab({super.key, required this.store});
  final WorkTrialStore store;
  @override
  State<EarningsTrialTab> createState() => _EarningsTrialTabState();
}

class _EarningsTrialTabState extends State<EarningsTrialTab>
    with AutomaticKeepAliveClientMixin {
  DateTime _month = DateTime(bangkokNow().year, bangkokNow().month);
  bool _busy = false;
  bool _noScans = false;
  String? _error;
  PayEstimate? _estimate;
  String? _holderName;
  String? _employeeCode;
  String? _department;
  String? _employmentType;
  String? _employmentStatus;
  double? _baseSalary;
  double? _directHourlyRate;
  String? _startDate;
  List<PayrollAdjustmentItem> _payrollItems = const [];

  List<Map<String, dynamic>> _lastScans = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    AttendanceService.attendanceUpdatedNotifier.addListener(
      _onAttendanceUpdated,
    );
    _loadSavedIdentity();
    _loadPayrollConfig();
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculate());
  }

  @override
  void dispose() {
    AttendanceService.attendanceUpdatedNotifier.removeListener(
      _onAttendanceUpdated,
    );
    super.dispose();
  }

  void _onAttendanceUpdated() {
    if (!mounted) return;
    _loadPayrollConfig();
    _calculate();
  }

  PaySettings get _activePaySettings => PaySettings.forEmployeeSalary(
    _baseSalary,
    hourlyRateBaht: _directHourlyRate,
  );

  Future<void> _loadPayrollConfig() async {
    final cfg = await PayrollService.getMyPayrollConfig();
    if (!mounted) return;
    final rateChanged =
        cfg.hourlyRate != _directHourlyRate ||
        (cfg.salary != null && cfg.salary != _baseSalary);
    setState(() {
      _directHourlyRate = cfg.hourlyRate;
      if (cfg.salary != null) _baseSalary = cfg.salary;
      if (cfg.department != null && (_department == null || _department!.isEmpty)) {
        _department = cfg.department;
      }
      if (cfg.employmentType != null &&
          (_employmentType == null || _employmentType!.isEmpty)) {
        _employmentType = cfg.employmentType;
      }
      if (cfg.startDate != null && (_startDate == null || _startDate!.isEmpty)) {
        _startDate = cfg.startDate;
      }
      _payrollItems = cfg.items;
      if (rateChanged && _estimate != null) {
        _estimate = calculateScanPay(_lastScans, _month, _activePaySettings);
      }
    });
  }

  void _applyUserMap(Map<String, dynamic> user) {
    final rawSalary = user['salary'];
    final parsedSalary = rawSalary is num
        ? rawSalary.toDouble()
        : double.tryParse(rawSalary?.toString() ?? '');
    final salaryChanged = parsedSalary != _baseSalary;
    setState(() {
      _holderName = user['name']?.toString();
      _employeeCode = user['employeeCode']?.toString();
      _department = user['department']?.toString();
      _employmentType = user['employmentType']?.toString();
      _employmentStatus = user['employmentStatus']?.toString();
      _baseSalary = parsedSalary;
      _startDate = user['startDate']?.toString();
      if (salaryChanged && _estimate != null) {
        _estimate = calculateScanPay(_lastScans, _month, _activePaySettings);
      }
    });
  }

  Future<void> _loadSavedIdentity() async {
    final cached = await AuthService.getSavedUser();
    if (!mounted) return;
    if (cached != null) {
      _applyUserMap(cached);
    }
    if (cached == null || !cached.containsKey('salary')) {
      try {
        final me = await AuthService.fetchMe();
        final fresh = me['user'];
        if (mounted && fresh is Map<String, dynamic>) {
          _applyUserMap(fresh);
        }
      } catch (_) {
        // Keep cached identity silently if /auth/me is unavailable.
      }
    }
  }

  Future<void> _calculate() async {
    if (_busy) return;
    final period = _month;
    setState(() {
      _busy = true;
      _error = null;
      _estimate = null;
      _noScans = false;
    });
    try {
      final scans = await AttendanceService.getMyScans(
        from: period,
        to: DateTime(period.year, period.month + 1, 0),
      );
      if (!mounted || period != _month) return;
      final result = calculateScanPay(scans, period, _activePaySettings);
      setState(() {
        _lastScans = scans;
        _noScans = scans.isEmpty;
        _estimate = result;
      });
    } catch (error) {
      if (mounted && period == _month) {
        setState(() => _error = 'Could not read scans: $error');
      }
    } finally {
      if (mounted && period == _month) setState(() => _busy = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _calculate();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final now = bangkokNow();
    final ended = _month.isBefore(DateTime(now.year, now.month));
    final text = Theme.of(context).textTheme;
    final period = AppStrings.formatMonthYear(_month.year, _month.month);
    final periodShort =
        '${_month.month.toString().padLeft(2, '0')}/${(_month.year % 100).toString().padLeft(2, '0')}';
    final estimate = _estimate;
    return RefreshIndicator(
      color: AppColors.secondary,
      onRefresh: _calculate,
      child: SingleChildScrollView(
        primary: true,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 16, 16, appTabBottomPadding(context)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeSlideEntry(
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: AppStrings.t(
                                  'Previous month',
                                  'เดือนก่อนหน้า',
                                ),
                                onPressed: _busy
                                    ? null
                                    : () => _changeMonth(-1),
                                icon: const Icon(Icons.chevron_left_rounded),
                              ),
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  transitionBuilder: (child, anim) =>
                                      FadeTransition(
                                        opacity: anim,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0, 0.14),
                                            end: Offset.zero,
                                          ).animate(anim),
                                          child: child,
                                        ),
                                      ),
                                  child: Text(
                                    period,
                                    key: ValueKey(period),
                                    textAlign: TextAlign.center,
                                    style: text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: AppStrings.t(
                                  'Next month',
                                  'เดือนถัดไป',
                                ),
                                onPressed: _busy ? null : () => _changeMonth(1),
                                icon: const Icon(Icons.chevron_right_rounded),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                          child: PayWalletCard(
                            periodLabel: period,
                            periodShort: periodShort,
                            periodEnded: ended,
                            busy: _busy,
                            estimate: estimate,
                            holderName: _holderName,
                            employeeCode: _employeeCode,
                            department: _department,
                            employmentType: _employmentType,
                            employmentStatus: _employmentStatus,
                            baseSalary: _baseSalary,
                            startDate: _startDate,
                          ),
                        ),
                        if (estimate != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _PayMetricTile(
                                    key: const Key('verified-hours-tile'),
                                    icon: Icons.verified_outlined,
                                    label: AppStrings.t(
                                      'Verified hours counted',
                                      'ชั่วโมงทำงานที่ยืนยันแล้ว',
                                    ),
                                    value: AppStrings.formatHoursMinutes(
                                      estimate.regularMinutes,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _PayMetricTile(
                                    key: const Key('bonus-time-tile'),
                                    icon: Icons.bolt_rounded,
                                    label: AppStrings.t(
                                      'Bonus time after 17:00',
                                      'เวลาโบนัสหลัง 17:00 น.',
                                    ),
                                    value: AppStrings.formatHoursMinutes(
                                      estimate.otMinutes,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final settings =
                                        estimate?.settings ??
                                        _activePaySettings;
                                    final isDirect = settings.isDirectHourly;
                                    final isSalary = settings.isSalaryBased;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isDirect
                                              ? AppStrings.t(
                                                  'Hourly wage rate',
                                                  'อัตราค่าแรงรายชั่วโมง',
                                                )
                                              : isSalary
                                              ? AppStrings.t(
                                                  'Salary-based hourly rate',
                                                  'อัตราค่าแรงจากฐานเงินเดือน',
                                                )
                                              : AppStrings.t(
                                                  'Fixed daily wage estimate',
                                                  'อัตราค่าแรงรายวันทดลอง',
                                                ),
                                          style: text.bodySmall?.copyWith(
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: AppStrings.isThai
                                                ? 0
                                                : 0.4,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          (isDirect || isSalary)
                                              ? '${formatBaht(settings.hourlySatang)}${AppStrings.isThai ? ' / ชม.' : ' / hr'}'
                                              : (AppStrings.isThai
                                                    ? '${formatBaht(PaySettings.trialDailyWageBaht * 100)} / ${PaySettings.hoursPerDay} ชม.'
                                                    : '${formatBaht(PaySettings.trialDailyWageBaht * 100)} / ${PaySettings.hoursPerDay}h'),
                                          style: text.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.neutral,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isDirect
                                              ? AppStrings.t(
                                                  'Configured by HR / Admin / Accountant',
                                                  'กำหนดอัตราโดยฝ่ายบุคคล / บัญชี',
                                                )
                                              : isSalary
                                              ? (AppStrings.isThai
                                                    ? '${formatBaht((settings.monthlySalaryBaht! * 100).round())} ÷ ${settings.baseDays} วัน ÷ ${settings.dailyHours} ชม.'
                                                    : '${formatBaht((settings.monthlySalaryBaht! * 100).round())} ÷ ${settings.baseDays} days ÷ ${settings.dailyHours}h')
                                              : (AppStrings.isThai
                                                    ? '${formatBaht(PaySettings.trial.hourlySatang)}/ชม. · ประมาณการเท่านั้น'
                                                    : '${formatBaht(PaySettings.trial.hourlySatang)}/hr · Estimate only'),
                                          style: text.bodySmall?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              OutlinedButton.icon(
                                key: const Key('calculate-pay'),
                                onPressed: _busy ? null : _calculate,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.neutral,
                                  backgroundColor: AppColors.primary,
                                  minimumSize: const Size(0, 40),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  side: BorderSide(color: AppColors.cardBorder),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.pill,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                ),
                                icon: _busy
                                    ? const SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.refresh_rounded,
                                        size: 18,
                                      ),
                                label: Text(
                                  AppStrings.t('Refresh', 'รีเฟรช'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                StatusBanner(variant: StatusVariant.error, message: _error!),
              ],
              if (estimate != null) ...[
                if (_noScans) ...[
                  const SizedBox(height: AppSpacing.md),
                  StatusBanner(
                    variant: StatusVariant.info,
                    message: AppStrings.t(
                      'No scans found. There are no verified hours to estimate pay.',
                      'ไม่พบประวัติสแกน จึงยังไม่มีชั่วโมงทำงานสำหรับประมาณการค่าแรง',
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Card(
                  margin: EdgeInsets.zero,
                  child: ExpansionTile(
                    leading: const Icon(Icons.calculate_outlined),
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(
                      AppStrings.t('How this is calculated', 'วิธีคำนวณ'),
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    children: [_PayBreakdown(estimate: estimate)],
                  ),
                ),
                if (_payrollItems.any((i) => i.isActive)) ...[
                  const SizedBox(height: AppSpacing.md),
                  _PayrollDeductionsCard(
                    summary: PayrollNetSummary.calculate(
                      grossSatang: estimate.regularSatang,
                      items: _payrollItems,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: AppSpacing.md),
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const Key('open-pay-calculator'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PayCalculatorScreen(
                          initialMonthlySalary: _baseSalary,
                          initialRegularMinutes: estimate?.regularMinutes ?? 0,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.tune_rounded,
                            size: 20,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.t(
                                  'Pay Simulator',
                                  'คำนวณค่าแรงเอง',
                                ),
                                style: text.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.neutral,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppStrings.t(
                                  'Test custom salary, base days & hours',
                                  'ลองปรับเงินเดือน วันฐาน หรือชั่วโมงทำงาน',
                                ),
                                style: text.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                          size: 22,
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
    ),
    );
  }
}

class _PayMetricTile extends StatelessWidget {
  const _PayMetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: AppColors.secondary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              height: 1.05,
              fontWeight: FontWeight.w800,
              color: AppColors.neutral,
              letterSpacing: 0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _PayBreakdown extends StatelessWidget {
  const _PayBreakdown({required this.estimate});

  final PayEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final issueDates = estimate.issueDates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.md,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xs,
              children: [
                if (estimate.settings.isSalaryBased) ...[
                  Text(
                    AppStrings.isThai
                        ? 'ฐานเงินเดือน ${formatBaht((estimate.settings.monthlySalaryBaht! * 100).round())} ÷ ${estimate.settings.baseDays} วัน ÷ ${estimate.settings.dailyHours} ชม. = ${formatBaht(estimate.settings.hourlySatang)}/ชม.'
                        : 'Base salary ${formatBaht((estimate.settings.monthlySalaryBaht! * 100).round())} ÷ ${estimate.settings.baseDays} days ÷ ${estimate.settings.dailyHours}h = ${formatBaht(estimate.settings.hourlySatang)}/hr',
                    style: text.bodySmall?.copyWith(
                      color: AppColors.neutral,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                Text(
                  AppStrings.t(
                    'Hourly rate × verified time before 17:00',
                    'อัตราต่อชั่วโมง × เวลาทำงานที่ยืนยันแล้วก่อน 17:00 น.',
                  ),
                  style: text.bodySmall,
                ),
                Text(
                  AppStrings.isThai
                      ? '${formatBaht(estimate.settings.hourlySatang)}/ชม. '
                            '× ${AppStrings.formatHoursMinutes(estimate.regularMinutes)}'
                      : '${formatBaht(estimate.settings.hourlySatang)}/hr '
                            '× ${formatWorkMinutes(estimate.regularMinutes)}',
                  style: text.titleSmall?.copyWith(color: AppColors.neutral),
                ),
                Text(
                  '= ${formatBaht(estimate.regularSatang)}',
                  style: text.titleLarge?.copyWith(
                    color: AppColors.neutral,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        Text(
          AppStrings.t(
            'Only complete scan pairs count. Time after 17:00 '
                'is tracked separately as bonus time.',
            'นับเฉพาะคู่สแกนเข้า-ออกที่ครบถ้วน เวลาหลัง 17:00 น. จะแยกบันทึกเป็นเวลาโบนัส',
          ),
          style: text.bodySmall,
        ),
        if (issueDates.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.input),
            child: ExpansionTile(
              backgroundColor: AppColors.warningContainer,
              collapsedBackgroundColor: AppColors.warningContainer,
              textColor: AppColors.onWarningContainer,
              collapsedTextColor: AppColors.onWarningContainer,
              iconColor: AppColors.onWarningContainer,
              collapsedIconColor: AppColors.onWarningContainer,
              shape: const Border(),
              collapsedShape: const Border(),
              leading: const Icon(Icons.warning_amber_rounded, size: 20),
              title: Text(
                AppStrings.isThai
                    ? 'วันที่ต้องตรวจสอบ (${issueDates.length})'
                    : 'Scans need review (${issueDates.length})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.t(
                    'Incomplete pairs are skipped. If scans overlap across '
                        'work dates, both dates are excluded.',
                    'คู่สแกนที่ไม่ครบจะถูกข้าม และหากมีเวลาสแกนซ้อนทับข้ามวัน จะไม่นับทั้งสองวัน',
                  ),
                  style: text.bodySmall?.copyWith(
                    color: AppColors.onWarningContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final date in issueDates)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          child: Text(
                            date,
                            style: text.bodySmall?.copyWith(
                              color: AppColors.onWarningContainer,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PayrollDeductionsCard extends StatelessWidget {
  const _PayrollDeductionsCard({required this.summary});
  final PayrollNetSummary summary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      key: const Key('payroll-deductions-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 18,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  AppStrings.t(
                    'Deductions & Estimated Net Pay',
                    'รายการหักและยอดสุทธิโดยประมาณ',
                  ),
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _lineRow(
              context,
              label: AppStrings.t('Gross hourly pay', 'ค่าแรงตามชั่วโมง (ก่อนหัก)'),
              value: formatBaht(summary.grossSatang),
              valueColor: AppColors.neutral,
            ),
            const SizedBox(height: 6),
            for (final line in summary.lines) ...[
              _lineRow(
                context,
                label: line.item.isPercent
                    ? '${line.item.name} (${line.item.amount == line.item.amount.truncateToDouble() ? line.item.amount.toStringAsFixed(0) : line.item.amount}%)'
                    : line.item.name,
                value:
                    '${line.item.isDeduction ? '-' : '+'}${formatBaht(line.satang)}',
                valueColor: line.item.isDeduction
                    ? AppColors.error
                    : AppColors.secondary,
              ),
              const SizedBox(height: 6),
            ],
            Divider(color: AppColors.cardBorder, height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.t('Estimated Net Pay', 'ยอดสุทธิโดยประมาณ'),
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.neutral,
                  ),
                ),
                Text(
                  formatBaht(summary.netSatang),
                  key: const Key('payroll-net-pay-value'),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineRow(
    BuildContext context, {
    required String label,
    required String value,
    required Color valueColor,
  }) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: text.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
