import 'package:flutter/material.dart';

/// Clean native Flutter entry animation with fade and slide/scale.
/// Uses [AnimationController] with an [Interval] curve to simulate a stagger
/// delay — no [Future.delayed], so pending timers never leak in widget tests.
/// Respects [MediaQuery.disableAnimationsOf].
class FadeSlideEntry extends StatefulWidget {
  const FadeSlideEntry({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
    this.delay = Duration.zero,
    this.yOffset = 14.0,
    this.xOffset = 0.0,
    this.scaleBegin = 1.0,
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final double yOffset;
  final double xOffset;
  final double scaleBegin;
  final Curve curve;

  @override
  State<FadeSlideEntry> createState() => _FadeSlideEntryState();
}

class _FadeSlideEntryState extends State<FadeSlideEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    final totalMs =
        widget.delay.inMilliseconds + widget.duration.inMilliseconds;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );

    // Interval maps the "active" portion of the timeline after the delay.
    final delayRatio = totalMs > 0
        ? widget.delay.inMilliseconds / totalMs
        : 0.0;

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(delayRatio, 1.0, curve: widget.curve),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        final v = _animation.value;
        if (v >= 1.0) {
          return child!;
        }
        Widget result = FadeTransition(
          opacity: _animation,
          child: Transform.translate(
            offset: Offset(
              (1.0 - v) * widget.xOffset,
              (1.0 - v) * widget.yOffset,
            ),
            child: child,
          ),
        );
        if (widget.scaleBegin != 1.0) {
          result = Transform.scale(
            scale: widget.scaleBegin + (1.0 - widget.scaleBegin) * v,
            child: result,
          );
        }
        return result;
      },
    );
  }
}
