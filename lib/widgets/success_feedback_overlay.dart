import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_preferences_service.dart';
import '../theme/app_theme.dart';

/// Displays a sleek animated marine-teal confirmation overlay with optional
/// haptic and sound feedback, then auto-dismisses cleanly.
class SuccessFeedbackOverlay {
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    IconData icon = Icons.check_rounded,
  }) async {
    if (AppPreferencesService.hapticsEnabled) {
      HapticFeedback.mediumImpact();
    }
    if (AppPreferencesService.soundEffectsEnabled) {
      SystemSound.play(SystemSoundType.click);
    }

    if (!context.mounted) return;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'success',
      barrierColor: Colors.black.withValues(alpha: 0.42),
      transitionDuration: reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, _) {
        return _SuccessDialogBody(
          title: title,
          subtitle: subtitle,
          icon: icon,
        );
      },
      transitionBuilder: (_, animation, _, child) {
        if (reducedMotion) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
  }
}

class _SuccessDialogBody extends StatefulWidget {
  const _SuccessDialogBody({
    required this.title,
    this.subtitle,
    required this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  State<_SuccessDialogBody> createState() => _SuccessDialogBodyState();
}

class _SuccessDialogBodyState extends State<_SuccessDialogBody> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1250), () {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RepaintBoundary(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 36),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.hero),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.45),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.18),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ],
            ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: 0.16),
                  border: Border.all(color: AppColors.secondary, width: 2),
                ),
                child: Icon(widget.icon, size: 36, color: AppColors.secondary),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.neutral,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (widget.subtitle != null &&
                  widget.subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  widget.subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }
}
