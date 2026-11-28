import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

/// Celebratory dialog shown when a technician completes a job (`completed`)
/// and submits the mandatory work report. Runs a single finite confetti burst
/// + elastic icon pop-in (respecting reduced motion) and never loops.
class JobCompletedDialog extends StatefulWidget {
  const JobCompletedDialog({super.key, required this.jobCode});

  final String jobCode;

  @override
  State<JobCompletedDialog> createState() => _JobCompletedDialogState();
}

class _JobCompletedDialogState extends State<JobCompletedDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _iconScale;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _iconScale = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('job-completed-dialog'),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.surface),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 112,
            width: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => CustomPaint(
                      size: const Size(220, 112),
                      painter: _ConfettiBurstPainter(
                        progress: _controller.value,
                        colors: [
                          AppColors.secondary,
                          AppColors.success,
                          const Color(0xFFF5B73B),
                          AppColors.neutral,
                        ],
                      ),
                    ),
                  ),
                ),
                ScaleTransition(
                  scale: _iconScale,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.successContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.celebration_rounded,
                      color: AppColors.success,
                      size: 34,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.t(
              'Job Completed!',
              'ยินดีด้วย! จบงานเรียบร้อยแล้ว',
              'Tahniah! Kerja Selesai',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.neutral,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.t(
              '${widget.jobCode} is completed and your work report has been submitted. Great work!',
              'งาน ${widget.jobCode} เสร็จสมบูรณ์และส่งรายงานเรียบร้อยแล้ว เก่งมากครับ!',
              '${widget.jobCode} telah selesai dan laporan kerja dihantar. Syabas!',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('job-completed-ok-button'),
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.neutral,
              foregroundColor: AppColors.onNeutral,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            child: Text(
              AppStrings.t('Great!', 'เยี่ยมเลย', 'Bagus!'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfettiBurstPainter extends CustomPainter {
  const _ConfettiBurstPainter({required this.progress, required this.colors});

  final double progress;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final ease = Curves.easeOutCubic.transform(progress);
    final opacity = progress < 0.65
        ? 1.0
        : (1.0 - (progress - 0.65) / 0.35).clamp(0.0, 1.0);
    if (opacity <= 0.0) return;

    final paint = Paint()..style = PaintingStyle.fill;
    const count = 18;
    for (var i = 0; i < count; i++) {
      final angle = (i / count) * math.pi * 2 + (i.isEven ? 0.14 : -0.11);
      final radius = (34.0 + (i % 3) * 20.0) * ease;
      final gravityY = 18.0 * progress * progress;
      final dx = center.dx + math.cos(angle) * radius;
      final dy = center.dy + math.sin(angle) * radius * 0.72 + gravityY;

      paint.color = colors[i % colors.length].withValues(alpha: opacity * 0.9);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(angle + progress * 3.2);
      if (i % 3 == 0) {
        canvas.drawCircle(Offset.zero, 2.8, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-3.5, -2.0, 7.0, 4.0),
            const Radius.circular(1.2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
