import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_slide_entry.dart';

/// Screen allowing employees to switch the app display language between
/// English and Thai without affecting backend data or calculations.
class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  Timer? _feedbackTimer;
  bool _isChanging = false;
  bool _showUpdated = false;

  Future<void> _selectLanguage(
    AppLanguage activeLanguage,
    AppLanguage target,
  ) async {
    if (activeLanguage == target || _isChanging) return;
    HapticFeedback.selectionClick();

    _feedbackTimer?.cancel();
    setState(() {
      _isChanging = true;
      _showUpdated = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 180));
    await LanguageService.setLanguage(target);
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

  Widget _buildLanguageCard({
    required AppLanguage language,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final badgeCode = switch (language) {
      AppLanguage.en => 'EN',
      AppLanguage.th => 'TH',
      AppLanguage.ms => 'MS',
    };

    return FadeSlideEntry(
      yOffset: 8,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('language-option-${language.code}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.surface),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 16,
            ),
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
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.neutral.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeCode,
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansThai',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutral,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    language.nativeName,
                    style: TextStyle(
                      fontFamily: language == AppLanguage.th
                          ? 'IBMPlexSansThai'
                          : null,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutral,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      AppStrings.t('ACTIVE', 'กำลังใช้งาน'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary,
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeService.themeModeNotifier,
        LanguageService.languageNotifier,
      ]),
      builder: (context, _) {
        final activeLanguage = LanguageService.currentLanguage;
        return Scaffold(
          backgroundColor: AppColors.primary,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.neutral,
            iconTheme: IconThemeData(color: AppColors.neutral),
            title: Text(AppStrings.t('Language', 'ภาษา')),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.lg),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  child: _isChanging
                      ? Row(
                          key: const ValueKey('language-changing-feedback'),
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
                              AppStrings.t('UPDATING', 'กำลังเปลี่ยนภาษา'),
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
                          key: const ValueKey('language-updated-feedback'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              AppStrings.t('UPDATED', 'เปลี่ยนภาษาแล้ว'),
                              style: TextStyle(
                                color: AppColors.neutral,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox(
                          key: ValueKey('language-feedback-empty'),
                        ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
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
                          AppStrings.t('DISPLAY LANGUAGE', 'ภาษาที่แสดงผล'),
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
                            'Choose your preferred app language.',
                            'เลือกภาษาที่ต้องการแสดงผลในแอป',
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      for (final language in AppLanguage.values) ...[
                        _buildLanguageCard(
                          language: language,
                          isSelected: activeLanguage == language,
                          onTap: () =>
                              _selectLanguage(activeLanguage, language),
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
