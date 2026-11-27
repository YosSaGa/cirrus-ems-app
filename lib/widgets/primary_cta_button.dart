import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// claude_prompt.txt (v98 Phase 1 blueprint, approved): the one true
// primary-action style in the app -- deep navy fill, white text, full pill
// shape, the single soft colored shadow reserved for this element alone. Used
// for every state where there is exactly one unmistakable next action: Sign In
// (Login) and Check In / Retry (Attendance) -- never for corrective/
// secondary actions like Discard or "Try again", which use
// PrimaryActionButton's outlined secondary style instead. Turquoise stays an
// accent, not a button fill.
class PrimaryCtaButton extends StatelessWidget {
  const PrimaryCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = loading ? null : onPressed;

    final Widget child;
    if (loading) {
      final spinner = SizedBox(
        width: loadingLabel != null ? 18 : 24,
        height: loadingLabel != null ? 18 : 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: AppColors.onNeutral,
        ),
      );
      child = loadingLabel != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                spinner,
                const SizedBox(width: 10),
                Text(loadingLabel!),
              ],
            )
          : spinner;
    } else {
      child = Text(label);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.input),
        boxShadow: effectiveOnPressed == null ? null : appCtaShadow,
      ),
      child: FilledButton(onPressed: effectiveOnPressed, child: child),
    );
  }
}
