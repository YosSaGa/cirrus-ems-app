import 'package:flutter/material.dart';

// claude_prompt.txt (v98 Phase 2, Stage 2 "Shared Widgets" -- restructuring
// primary_action_button.dart): now exclusively the SECONDARY/corrective
// action style -- outlined pill, neutral border/text, 48px tall (per the
// approved v98 Phase 1 blueprint §E) -- used for Discard and every "Try
// again" affordance. The one true primary action (Sign In / Check In /
// Retry) now uses the new `PrimaryCtaButton` instead; this widget's old
// `tonal` flag is removed since every remaining caller wants the same
// secondary treatment -- keeping an unused parameter around would be
// exactly the kind of no-benefit abstraction this round's instructions
// warn against.
class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          )
        : Text(label);

    return OutlinedButton(onPressed: loading ? null : onPressed, child: child);
  }
}
