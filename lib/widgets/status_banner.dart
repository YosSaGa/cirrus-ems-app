import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// claude_prompt.txt (v97 -- Cirrus EMS Complete UX/UI Redesign): the widget
// that directly answers the v97-Phase-1 audit's H1/H2 findings -- every
// non-actionable Attendance state ("completed", "no active window",
// "unrecognized window", "pending retry") previously rendered as
// visually-identical plain Text. This widget gives each state a distinct
// icon + color so the screen's status is legible at a glance, WITHOUT
// changing which branch is reached or what text it shows -- callers pass
// the exact same strings the prior plain-Text branches used.
enum StatusVariant { success, warning, error, info }

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.message,
    required this.variant,
    this.title,
    this.icon,
  });

  final String message;
  final StatusVariant variant;
  final String? title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (
      Color background,
      Color foreground,
      IconData defaultIcon,
    ) = switch (variant) {
      StatusVariant.success => (
        AppColors.successContainer,
        AppColors.onSuccessContainer,
        Icons.check_circle,
      ),
      StatusVariant.warning => (
        AppColors.warningContainer,
        AppColors.onWarningContainer,
        Icons.error_outline,
      ),
      StatusVariant.error => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.report_problem_outlined,
      ),
      StatusVariant.info => (
        AppColors.infoContainer,
        AppColors.onInfoContainer,
        Icons.info_outline,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, color: foreground, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                Text(
                  message,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
