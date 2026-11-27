import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Lightweight native shimmer skeleton placeholder.
///
/// Uses a single [AnimationController] with a sliding highlight gradient and
/// automatically falls back to a calm static fill when reduced motion is enabled.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = AppRadius.input,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = AppColors.cardBorder.withValues(alpha: 0.55);
    final highlightColor = AppColors.surface.withValues(alpha: 0.85);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    if (reducedMotion) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final slide = _controller.value * 2 - 1;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                begin: Alignment(-1.0 + slide * 1.4, -0.2),
                end: Alignment(1.0 + slide * 1.4, 0.2),
                colors: [baseColor, highlightColor, baseColor],
                stops: const [0.15, 0.5, 0.85],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Reusable card-shaped shimmer skeleton for list items and profile cards.
class ShimmerCardSkeleton extends StatelessWidget {
  const ShimmerCardSkeleton({
    super.key,
    this.height = 112,
    this.borderRadius = AppRadius.surface,
  });

  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const ShimmerBox(width: 140, height: 12, borderRadius: 6),
          if (height >= 72) ...[
            const SizedBox(height: 8),
            const ShimmerBox(height: 16, borderRadius: 8),
          ],
          if (height >= 110) ...[
            const SizedBox(height: 8),
            const ShimmerBox(width: 200, height: 12, borderRadius: 6),
          ],
        ],
      ),
    );
  }
}
