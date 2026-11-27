import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../models/payroll_calculator.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_panel.dart';
import '../widgets/fade_slide_entry.dart';

/// Local pay simulator screen allowing employees to test custom monthly salary,
/// base days (30 / 26 / 22), daily working hours, and hours/minutes worked.
///
/// Purely client-side: never writes to backend or alters employee records.
class PayCalculatorScreen extends StatefulWidget {
  const PayCalculatorScreen({
    super.key,
    this.initialMonthlySalary,
    this.initialRegularMinutes = 0,
  });

  final double? initialMonthlySalary;
  final int initialRegularMinutes;

  @override
  State<PayCalculatorScreen> createState() => _PayCalculatorScreenState();
}

class _PayCalculatorScreenState extends State<PayCalculatorScreen> {
  late final TextEditingController _salaryController;
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;

  int _baseDays = PaySettings.defaultBaseDays;
  static const int _dailyHours = PaySettings.hoursPerDay;

  @override
  void initState() {
    super.initState();
    final hasSalary =
        widget.initialMonthlySalary != null &&
        widget.initialMonthlySalary! > 0;
    _salaryController = TextEditingController(
      text: hasSalary
          ? _formatPlainNumber(widget.initialMonthlySalary!)
          : '16000',
    );
    _hoursController = TextEditingController(
      text: (widget.initialRegularMinutes ~/ 60).toString(),
    );
    _minutesController = TextEditingController(
      text: (widget.initialRegularMinutes % 60).toString(),
    );
  }

  String _formatPlainNumber(double value) =>
      value == value.roundToDouble()
          ? value.round().toString()
          : value.toStringAsFixed(2);

  @override
  void dispose() {
    _salaryController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _reset() {
    HapticFeedback.selectionClick();
    final hasSalary =
        widget.initialMonthlySalary != null &&
        widget.initialMonthlySalary! > 0;
    setState(() {
      _baseDays = PaySettings.defaultBaseDays;
      _salaryController.text = hasSalary
          ? _formatPlainNumber(widget.initialMonthlySalary!)
          : '16000';
      _hoursController.text = (widget.initialRegularMinutes ~/ 60).toString();
      _minutesController.text = (widget.initialRegularMinutes % 60).toString();
    });
  }

  void _addHours(int deltaHours) {
    HapticFeedback.selectionClick();
    final next = (_parsedHours + deltaHours).clamp(0, 999);
    setState(() => _hoursController.text = next.toString());
  }

  void _setHours(int hours, [int minutes = 0]) {
    HapticFeedback.selectionClick();
    setState(() {
      _hoursController.text = hours.toString();
      _minutesController.text = minutes.toString();
    });
  }

  void _fillMonthHours() {
    HapticFeedback.selectionClick();
    setState(() {
      _hoursController.text = (widget.initialRegularMinutes ~/ 60).toString();
      _minutesController.text = (widget.initialRegularMinutes % 60).toString();
    });
  }

  double get _parsedSalary =>
      double.tryParse(_salaryController.text.replaceAll(',', '').trim()) ?? 0;

  int get _parsedHours =>
      (int.tryParse(_hoursController.text.trim()) ?? 0).clamp(0, 999);

  int get _parsedMinutes =>
      (int.tryParse(_minutesController.text.trim()) ?? 0).clamp(0, 59);

  int get _totalMinutes => _parsedHours * 60 + _parsedMinutes;

  double get _hourlyBaht {
    if (_parsedSalary <= 0 || _baseDays <= 0 || _dailyHours <= 0) return 0;
    return _parsedSalary / _baseDays / _dailyHours;
  }

  int get _hourlySatang => (_hourlyBaht * 100).round();
  int get _dailySatang => (_hourlyBaht * _dailyHours * 100).round();
  int get _fullMonthHours => _baseDays * _dailyHours;
  int get _estimatedSatang => (_totalMinutes * _hourlyBaht * 100 / 60).round();

  Widget _quickChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? AppColors.neutral : AppColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.neutral : AppColors.cardBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.onNeutral : AppColors.neutral,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeService.themeModeNotifier,
        LanguageService.languageNotifier,
      ]),
      builder: (context, _) {
        final text = Theme.of(context).textTheme;
        return Scaffold(
          backgroundColor: AppColors.primary,
          appBar: AppBar(
            title: Text(AppStrings.t('Pay Simulator', 'คำนวณค่าแรงเอง')),
            actions: [
              IconButton(
                tooltip: AppStrings.t('Reset', 'รีเซ็ต'),
                onPressed: _reset,
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: appContentMaxWidth(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Live result card
                      FadeSlideEntry(
                        yOffset: 8,
                        child: AmbientPanel(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.t(
                                  'SIMULATED ESTIMATE',
                                  'ยอดประมาณการจำลอง',
                                ),
                                style: text.labelSmall?.copyWith(
                                  color: AppColors.onNeutralMuted,
                                  letterSpacing: AppStrings.isThai ? 0 : 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                key: const Key('sim-result-amount'),
                                formatBaht(_estimatedSatang),
                                style: text.displaySmall?.copyWith(
                                  fontSize: 38,
                                  height: 1.08,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.secondary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Divider(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: [
                                  Expanded(
                                    child: _SimStatItem(
                                      label: AppStrings.t(
                                        'Hourly rate',
                                        'อัตราต่อชั่วโมง',
                                      ),
                                      value:
                                          '${formatBaht(_hourlySatang)}${AppStrings.isThai ? '/ชม.' : '/hr'}',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _SimStatItem(
                                      label: AppStrings.t(
                                        'Daily rate ($_dailyHours${AppStrings.isThai ? ' ชม.' : 'h'})',
                                        'อัตราต่อวัน ($_dailyHours ชม.)',
                                      ),
                                      value: formatBaht(_dailySatang),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                AppStrings.t(
                                  'Simulation only · Does not change your payroll or database.',
                                  'สำหรับทดลองคำนวณเท่านั้น · ไม่เปลี่ยนแปลงข้อมูลในระบบ',
                                ),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.onNeutralMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Salary & Rate Input Card
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                key: const Key('sim-salary-input'),
                                controller: _salaryController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[\d.,]'),
                                  ),
                                ],
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: AppStrings.t(
                                    'Monthly salary (THB)',
                                    'ฐานเงินเดือน (บาท)',
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.payments_outlined,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                AppStrings.t(
                                  'Base days per month (÷ 8h/day standard)',
                                  'จำนวนวันฐานต่อเดือน (มาตรฐาน 8 ชม./วัน)',
                                ),
                                style: text.labelMedium,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final days in PaySettings.baseDayOptions)
                                    _quickChip(
                                      label: AppStrings.isThai
                                          ? '$days วัน'
                                          : '$days days',
                                      selected: _baseDays == days,
                                      onTap: () {
                                        final wasFullMonth =
                                            _parsedHours == _fullMonthHours &&
                                            _parsedMinutes == 0;
                                        setState(() {
                                          _baseDays = days;
                                          if (wasFullMonth) {
                                            _hoursController.text =
                                                _fullMonthHours.toString();
                                          }
                                        });
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Working Time Card
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    AppStrings.t(
                                      'Working time to simulate',
                                      'เวลาทำงานที่ต้องการคำนวณ',
                                    ),
                                    style: text.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    AppStrings.formatHoursMinutes(_totalMinutes),
                                    style: text.labelMedium?.copyWith(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      key: const Key('sim-hours-input'),
                                      controller: _hoursController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(3),
                                      ],
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        labelText: AppStrings.t(
                                          'Hours',
                                          'ชั่วโมง',
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: TextField(
                                      key: const Key('sim-minutes-input'),
                                      controller: _minutesController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(2),
                                      ],
                                      onChanged: (raw) {
                                        final parsed = int.tryParse(raw.trim());
                                        if (parsed != null && parsed > 59) {
                                          _minutesController.value =
                                              const TextEditingValue(
                                                text: '59',
                                                selection:
                                                    TextSelection.collapsed(
                                                      offset: 2,
                                                    ),
                                              );
                                        }
                                        setState(() {});
                                      },
                                      decoration: InputDecoration(
                                        labelText: AppStrings.t(
                                          'Minutes (0-59)',
                                          'นาที (0-59)',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _quickChip(
                                    label: AppStrings.t(
                                      '+8h (1 day)',
                                      '+8 ชม. (1 วัน)',
                                    ),
                                    selected: false,
                                    onTap: () => _addHours(8),
                                  ),
                                  _quickChip(
                                    label: AppStrings.isThai
                                        ? 'เต็มเดือน ($_fullMonthHours ชม.)'
                                        : 'Full month (${_fullMonthHours}h)',
                                    selected:
                                        _parsedHours == _fullMonthHours &&
                                        _parsedMinutes == 0,
                                    onTap: () => _setHours(_fullMonthHours),
                                  ),
                                  if (widget.initialRegularMinutes > 0)
                                    _quickChip(
                                      label: AppStrings.isThai
                                          ? 'เดือนนี้ (${AppStrings.formatHoursMinutes(widget.initialRegularMinutes)})'
                                          : 'This month (${formatWorkMinutes(widget.initialRegularMinutes)})',
                                      selected:
                                          _totalMinutes ==
                                          widget.initialRegularMinutes,
                                      onTap: _fillMonthHours,
                                    ),
                                ],
                              ),
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
        );
      },
    );
  }
}

class _SimStatItem extends StatelessWidget {
  const _SimStatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.onNeutralMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
