import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_slide_entry.dart';

/// Screen allowing employees to choose between application appearance themes.
class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  Timer? _feedbackTimer;
  bool _isChanging = false;
  bool _showUpdated = false;

  Future<void> _selectTheme(AppThemeMode activeMode, AppThemeMode mode) async {
    if (activeMode == mode || _isChanging) return;
    HapticFeedback.selectionClick();

    _feedbackTimer?.cancel();
    setState(() {
      _isChanging = true;
      _showUpdated = false;
    });

    // Keep the loading cue visible long enough to register before the palette switches.
    await Future<void>.delayed(const Duration(milliseconds: 220));
    await ThemeService.setThemeMode(mode);
    if (!mounted) return;

    setState(() {
      _isChanging = false;
      _showUpdated = true;
    });
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showUpdated = false);
    });
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  Widget _buildThemeCard({
    required BuildContext context,
    required AppThemeMode mode,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final palette = AppThemePalette.forMode(mode);

    return FadeSlideEntry(
      yOffset: 8,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.surface),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.surface),
              border: Border.all(
                color: isSelected ? AppColors.secondary : AppColors.cardBorder,
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? AppColors.secondary.withValues(alpha: 0.15)
                      : AppColors.neutral.withValues(alpha: 0.03),
                  blurRadius: isSelected ? 12 : 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Radio Indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.secondary
                          : AppColors.textSecondary.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.secondary,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              AppStrings.themeTitle(mode),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.neutral,
                                letterSpacing: AppStrings.isThai ? 0 : 0.3,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Text(
                                AppStrings.t('ACTIVE', 'กำลังใช้งาน'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.secondary,
                                  letterSpacing: AppStrings.isThai ? 0 : 0.6,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.themeDescription(mode),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Mini Color Swatch preview
                      Wrap(
                        spacing: 8,
                        children: [
                          _colorDot(
                            label: AppStrings.t('Canvas', 'พื้นหลัง'),
                            color: palette.primary,
                          ),
                          _colorDot(
                            label: AppStrings.t('Surface', 'การ์ด'),
                            color: palette.surface,
                          ),
                          _colorDot(
                            label: AppStrings.t('Brand', 'สีหลัก'),
                            color: mode == AppThemeMode.black
                                ? palette.surface
                                : palette.neutral,
                          ),
                          _colorDot(
                            label: AppStrings.t('Accent', 'สีเน้น'),
                            color: palette.secondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _colorDot({required String label, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: AppColors.cardBorder, width: 1),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
        final activeMode = ThemeService.currentMode;
        return Scaffold(
          backgroundColor: AppColors.primary,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.neutral,
            iconTheme: IconThemeData(color: AppColors.neutral),
            title: Text(AppStrings.t('App Theme', 'ธีมแอป')),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.lg),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  child: _isChanging
                      ? Row(
                          key: const ValueKey('theme-changing-feedback'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.secondary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              AppStrings.t('CHANGING THEME', 'กำลังเปลี่ยนธีม'),
                              style: TextStyle(
                                color: AppColors.neutral,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : _showUpdated
                      ? Row(
                          key: const ValueKey('theme-updated-feedback'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              AppStrings.t('THEME UPDATED', 'เปลี่ยนธีมแล้ว'),
                              style: TextStyle(
                                color: AppColors.neutral,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox(key: ValueKey('theme-feedback-empty')),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  appTabBottomPadding(context),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: appContentMaxWidth(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeSlideEntry(
                        yOffset: 6,
                        child: Text(
                          AppStrings.t('APPEARANCE', 'รูปลักษณ์'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: AppStrings.isThai ? 0 : 0.8,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FadeSlideEntry(
                        yOffset: 8,
                        child: Text(
                          AppStrings.t(
                            'Choose the interface theme that best fits your preference and lighting conditions.',
                            'เลือกธีมหน้าจอที่เหมาะกับสไตล์การใช้งานและสภาพแสงของคุณ',
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      for (final mode in AppThemeMode.values) ...[
                        _buildThemeCard(
                          context: context,
                          mode: mode,
                          isSelected: activeMode == mode,
                          onTap: () => _selectTheme(activeMode, mode),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
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
