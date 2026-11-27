import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Decorative sculpted backdrop; all readable content stays above the artwork.
class AmbientPanel extends StatelessWidget {
  const AmbientPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.centered = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final gradientStart = AppColors.ambientGradientStart;
    final secondary = AppColors.secondary;
    final onNeutralMuted = AppColors.onNeutralMuted;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: centered
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            gradientStart,
                            Color.lerp(gradientStart, secondary, 0.14)!,
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            gradientStart,
                            gradientStart,
                            Color.lerp(gradientStart, secondary, 0.26)!,
                          ],
                        ),
                ),
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _SculptedBackdrop(
                      gradientStart: gradientStart,
                      secondary: secondary,
                      onNeutralMuted: onNeutralMuted,
                      centered: centered,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class _SculptedBackdrop extends CustomPainter {
  const _SculptedBackdrop({
    required this.gradientStart,
    required this.secondary,
    required this.onNeutralMuted,
    required this.centered,
  });

  final Color gradientStart;
  final Color secondary;
  final Color onNeutralMuted;
  final bool centered;

  @override
  void paint(Canvas canvas, Size size) {
    if (centered) {
      final center = Offset(size.width * 0.5, size.height * 0.28);
      final glowRadius = size.width * 0.62;
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            secondary.withValues(alpha: 0.26),
            secondary.withValues(alpha: 0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.48, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius));
      canvas.drawCircle(center, glowRadius, glowPaint);

      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = secondary.withValues(alpha: 0.10);
      canvas.drawCircle(center, size.width * 0.34, ringPaint);
      canvas.drawCircle(
        center,
        size.width * 0.54,
        ringPaint..color = onNeutralMuted.withValues(alpha: 0.06),
      );
      return;
    }

    final center = Offset(size.width * 1.02, size.height * 0.45);
    final radius = size.height * 0.7;
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.45, -0.6),
        colors: [
          secondary.withValues(alpha: 0.38),
          secondary.withValues(alpha: 0.08),
          gradientStart.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
    final ribbon = Paint()
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..strokeWidth = size.height * 0.18
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          secondary.withValues(alpha: 0.28),
          onNeutralMuted.withValues(alpha: 0.06),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 1.04, size.height * 0.3),
        width: size.width * 0.62,
        height: size.height * 1.45,
      ),
      ribbon,
    );
  }

  @override
  bool shouldRepaint(_SculptedBackdrop oldDelegate) =>
      oldDelegate.gradientStart != gradientStart ||
      oldDelegate.secondary != secondary ||
      oldDelegate.onNeutralMuted != onNeutralMuted ||
      oldDelegate.centered != centered;
}
