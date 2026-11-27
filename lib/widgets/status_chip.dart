import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// claude_prompt.txt (v98 Phase 1 blueprint, approved): a short-label
// glanceable indicator -- distinct from StatusBanner, which is kept for
// longer explanatory text. A chip and a multi-line banner solve different
// problems; collapsing them would be the kind of no-benefit abstraction
// this round's own instructions warn against. `active` is visually
// distinct from the semantic variants -- it is the one place besides the
// primary CTA that the secondary teal appears, reserved for "this window
// is live right now", per the blueprint's "do not use the secondary
// turquoise indiscriminately".
enum ChipVariant { success, warning, error, info, active }

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.variant,
    this.icon,
  });

  final String label;
  final ChipVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (variant) {
      ChipVariant.success => (
        AppColors.successContainer,
        AppColors.onSuccessContainer,
      ),
      ChipVariant.warning => (
        AppColors.warningContainer,
        AppColors.onWarningContainer,
      ),
      ChipVariant.error => (
        AppColors.errorContainer,
        AppColors.onErrorContainer,
      ),
      ChipVariant.info => (AppColors.infoContainer, AppColors.onInfoContainer),
      ChipVariant.active => (
        AppColors.secondary.withValues(alpha: 0.16),
        AppColors.neutral,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
