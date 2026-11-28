import 'package:flutter/material.dart';

/// Wraps a tappable child with a subtle spring press-scale (`0.96 -> 1.0`)
/// while respecting the OS reduced-motion setting.
class BouncyTap extends StatefulWidget {
  const BouncyTap({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.965 : 1.0,
        duration: Duration(milliseconds: _pressed ? 90 : 180),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
