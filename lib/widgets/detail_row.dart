import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// claude_prompt.txt (v98 Phase 2, Stage 2 "Shared Widgets" -- restructuring
// info_row.dart into detail_row.dart): a genuine restructure, not just a
// rename. v97's InfoRow was a label/value pair meant to sit inside a
// bordered Card; the v98 design has no bordered cards at all (blueprint
// §B/§C), so this becomes a borderless, optionally icon-led row -- callers
// separate rows with a plain `Divider(height: 1)` rather than this widget
// owning its own border. Preserves the exact nullable/fallback semantics
// every existing call site (Profile's "User Information", Attendance's
// "Last check-in") already relied on, and keeps the v97 audit's overflow/
// maxLines guard (finding M4) -- every value here is Backend- or
// user-sourced, not a fixed string.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, this.value, this.icon});

  final String label;
  final String? value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final displayValue = (value == null || value!.isEmpty)
        ? 'Not provided'
        : value!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
          ],
          SizedBox(
            width: icon != null ? 104 : 128,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              displayValue,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
