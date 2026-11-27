import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../models/payroll_calculator.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_slide_entry.dart';
import '../widgets/pay_wallet_card.dart';
import 'theme_settings_screen.dart';

/// Appearance menu inside Settings: houses App Theme and Pay Card Style.
class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  String _cardStyleName(PayCardStyle style) =>
      AppStrings.isThai ? style.nameTh : style.nameEn;

  Widget _groupCard(List<Widget> children) => Container(
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
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );

  Widget _menuRow({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? badge,
    required VoidCallback onTap,
  }) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.secondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutral,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null) ...[badge, const SizedBox(width: 8)],
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeService.themeModeNotifier,
        ThemeService.payCardStyleNotifier,
        ThemeService.textScaleNotifier,
        ThemeService.hapticsEnabledNotifier,
        LanguageService.languageNotifier,
      ]),
      builder: (context, _) {
        final activeMode = ThemeService.currentMode;
        final activeCard = ThemeService.currentPayCardStyle;
        final activeScale = ThemeService.currentTextScale;
        final hapticsOn = ThemeService.hapticsEnabled;
        return Scaffold(
          backgroundColor: AppColors.primary,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.neutral,
            iconTheme: IconThemeData(color: AppColors.neutral),
            title: Text(AppStrings.t('Appearance', 'รูปลักษณ์')),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
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
                      FadeSlideEntry(
                        yOffset: 8,
                        child: _groupCard([
                          _menuRow(
                            icon: Icons.palette_outlined,
                            title: AppStrings.t('App Theme', 'ธีมแอป'),
                            subtitle: AppStrings.themeTitle(activeMode),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ThemeSettingsScreen(),
                                ),
                              );
                            },
                          ),
                          Divider(color: AppColors.cardBorder, height: 1),
                          _menuRow(
                            icon: Icons.credit_card_rounded,
                            title: AppStrings.t(
                              'Pay Card Style',
                              'สีบัตรค่าแรง',
                            ),
                            subtitle: _cardStyleName(activeCard),
                            badge: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    activeCard.gradientStart,
                                    activeCard.accentColor,
                                  ],
                                ),
                                border: Border.all(
                                  color: AppColors.cardBorder,
                                  width: 1,
                                ),
                              ),
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const PayCardStyleScreen(),
                                ),
                              );
                            },
                          ),
                        ]),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Display & Feel card (Text Size + Haptic Feedback)
                      FadeSlideEntry(
                        yOffset: 10,
                        child: _groupCard([
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.text_fields_rounded,
                                        size: 20,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            AppStrings.t(
                                              'Text Size',
                                              'ขนาดตัวอักษร',
                                              'Saiz Teks',
                                            ),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.neutral,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            AppStrings.t(
                                              'Adjust reading comfort across the app',
                                              'ปรับขนาดตัวอักษรให้อ่านสบายตาทั้งแอป',
                                              'Laraskan keselesaan bacaan aplikasi',
                                            ),
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    for (final scale in AppTextScale.values)
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            right:
                                                scale ==
                                                    AppTextScale.values.last
                                                ? 0
                                                : 6,
                                          ),
                                          child: ChoiceChip(
                                            key: Key('text-scale-${scale.key}'),
                                            selected: activeScale == scale,
                                            showCheckmark: false,
                                            label: Center(
                                              child: Text(
                                                AppStrings.isThai
                                                    ? scale.labelTh
                                                    : AppStrings.isMalay
                                                    ? scale.labelMs
                                                    : scale.labelEn,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: activeScale == scale
                                                      ? AppColors.onNeutral
                                                      : AppColors.neutral,
                                                ),
                                              ),
                                            ),
                                            selectedColor: AppColors.neutral,
                                            backgroundColor: AppColors.primary,
                                            onSelected: (_) {
                                              if (ThemeService.hapticsEnabled) {
                                                HapticFeedback.selectionClick();
                                              }
                                              ThemeService.setTextScale(scale);
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Divider(color: AppColors.cardBorder, height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.vibration_rounded,
                                    size: 20,
                                    color: AppColors.secondary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppStrings.t(
                                          'Haptic Feedback',
                                          'การสั่นตอบสนอง',
                                          'Maklum Balas Haptik',
                                        ),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.neutral,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        AppStrings.t(
                                          'Subtle vibration on taps and switches',
                                          'สั่นเบาๆ เมื่อแตะปุ่มหรือสลับเมนู',
                                          'Getaran halus apabila mengetik butang',
                                        ),
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  key: const Key('haptics-toggle'),
                                  value: hapticsOn,
                                  activeTrackColor: AppColors.secondary,
                                  onChanged: (v) {
                                    if (v) HapticFeedback.selectionClick();
                                    ThemeService.setHapticsEnabled(v);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ]),
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

/// Interactive Pay Wallet Card customizer: live 3D card preview on top,
/// circular color swatches below that update the card in real-time.
class PayCardStyleScreen extends StatefulWidget {
  const PayCardStyleScreen({super.key});

  @override
  State<PayCardStyleScreen> createState() => _PayCardStyleScreenState();
}

class _PayCardStyleScreenState extends State<PayCardStyleScreen> {
  String? _holderName;
  String? _employeeCode;
  String? _department;
  String? _employmentType;
  String? _employmentStatus;
  double? _baseSalary;
  String? _startDate;

  @override
  void initState() {
    super.initState();
    _loadUserPreview();
  }

  Future<void> _loadUserPreview() async {
    final user = await AuthService.getSavedUser();
    if (!mounted || user == null) return;
    final rawSalary = user['salary'];
    setState(() {
      _holderName = user['name']?.toString();
      _employeeCode = user['employeeCode']?.toString();
      _department = user['department']?.toString();
      _employmentType = user['employmentType']?.toString();
      _employmentStatus = user['employmentStatus']?.toString();
      _baseSalary = rawSalary is num
          ? rawSalary.toDouble()
          : double.tryParse(rawSalary?.toString() ?? '');
      _startDate = user['startDate']?.toString();
    });
  }

  Future<void> _selectStyle(PayCardStyle style) async {
    if (style == ThemeService.currentPayCardStyle) return;
    HapticFeedback.selectionClick();
    await ThemeService.setPayCardStyle(style);
  }

  @override
  Widget build(BuildContext context) {
    final now = bangkokNow();
    final period = AppStrings.formatMonthYear(now.year, now.month);
    final periodShort =
        '${now.month.toString().padLeft(2, '0')}/${(now.year % 100).toString().padLeft(2, '0')}';
    final previewEstimate = PayEstimate(
      regularMinutes: 160 * 60,
      otMinutes: 0,
      settings: PaySettings.forEmployeeSalary(_baseSalary ?? 16000),
    );

    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeService.payCardStyleNotifier,
        ThemeService.themeModeNotifier,
        LanguageService.languageNotifier,
      ]),
      builder: (context, _) {
        final active = ThemeService.currentPayCardStyle;
        final activeName = AppStrings.isThai ? active.nameTh : active.nameEn;

        return Scaffold(
          backgroundColor: AppColors.primary,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.neutral,
            iconTheme: IconThemeData(color: AppColors.neutral),
            title: Text(AppStrings.t('Pay Card Style', 'สีบัตรค่าแรง')),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
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
                      // Live interactive 3D PayWalletCard preview
                      FadeSlideEntry(
                        yOffset: 8,
                        child: PayWalletCard(
                          periodLabel: period,
                          periodShort: periodShort,
                          periodEnded: false,
                          busy: false,
                          estimate: previewEstimate,
                          holderName: _holderName ?? 'CIRRUS EMPLOYEE',
                          employeeCode: _employeeCode ?? '260831',
                          department: _department,
                          employmentType: _employmentType,
                          employmentStatus: _employmentStatus,
                          baseSalary: _baseSalary ?? 16000,
                          startDate: _startDate,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Active style label + circular color swatches
                      FadeSlideEntry(
                        yOffset: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(
                              AppRadius.surface,
                            ),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Column(
                            children: [
                              Text(
                                AppStrings.t(
                                  'SELECT CARD COLOR',
                                  'เลือกสีบัตรของคุณ',
                                ),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: AppStrings.isThai ? 0 : 0.9,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                activeName,
                                key: const Key('active-card-style-name'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.neutral,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  for (final style in PayCardStyle.values)
                                    _ColorSwatchCircle(
                                      key: Key('card-swatch-${style.key}'),
                                      style: style,
                                      selected: style == active,
                                      onTap: () => _selectStyle(style),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                AppStrings.t(
                                  'Tap the card above to flip and preview both sides.',
                                  'แตะที่บัตรด้านบนเพื่อพลิกดูทั้งด้านหน้าและด้านหลัง',
                                ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
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
            ),
          ),
        );
      },
    );
  }
}

class _ColorSwatchCircle extends StatelessWidget {
  const _ColorSwatchCircle({
    super.key,
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final PayCardStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(3.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? style.accentColor : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [style.gradientStart, style.gradientEnd],
            ),
            boxShadow: [
              BoxShadow(
                color: style.gradientStart.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: selected
              ? Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: style.accentColor,
                )
              : Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: style.accentColor.withValues(alpha: 0.85),
                  ),
                ),
        ),
      ),
    );
  }
}
