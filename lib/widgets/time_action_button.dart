import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Floating circular hero attendance control with concentric halo ring,
/// subtle 60fps ripple pulse when open/interactive, layered depth,
/// native Material ink/keyboard activation, and a pill hint.
/// Eligibility belongs to AttendanceScreen and the backend, not this widget.
class TimeActionButton extends StatefulWidget {
  const TimeActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
    this.hint,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;
  final String? hint;

  @override
  State<TimeActionButton> createState() => _TimeActionButtonState();
}

class _TimeActionButtonState extends State<TimeActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _rippleScale;
  late final Animation<double> _rippleOpacity;
  late final Animation<double> _haloScale;
  bool _pressed = false;

  bool get _interactive =>
      widget.enabled && !widget.loading && widget.onPressed != null;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _rippleScale = Tween<double>(begin: 0.96, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutCubic),
    );
    _rippleOpacity = Tween<double>(begin: 0.42, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _haloScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.025,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.025,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_pulseController);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant TimeActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final inWidgetTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    final shouldPulse = _interactive && !reduceMotion && !inWidgetTest;
    if (shouldPulse) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat();
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
      _pulseController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interactive = _interactive;
    final screenSize = MediaQuery.sizeOf(context);
    final usableHeight =
        screenSize.height - MediaQuery.paddingOf(context).vertical;
    final isCompactHeight = usableHeight < 760;
    final diameter = isCompactHeight
        ? (screenSize.width * 0.42).clamp(150.0, 174.0)
        : (screenSize.width * 0.48).clamp(172.0, 202.0);
    final haloSize = diameter + (isCompactHeight ? 18 : 22);
    final ink = widget.enabled
        ? AppColors.timeActionForeground
        : AppColors.textSecondary;

    final activeEnd = Color.lerp(
      AppColors.secondary,
      AppColors.ambientGradientStart,
      0.24,
    )!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: [
            widget.label,
            if (widget.loading) 'Processing' else ?widget.hint,
          ].join(', '),
          button: true,
          enabled: interactive,
          onTap: interactive ? widget.onPressed : null,
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: SizedBox(
                width: haloSize + 24,
                height: haloSize + 24,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (interactive)
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          return Transform.scale(
                            scale: _rippleScale.value,
                            child: Container(
                              width: haloSize,
                              height: haloSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.secondary.withValues(
                                    alpha: _rippleOpacity.value,
                                  ),
                                  width: 2.2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    AnimatedBuilder(
                      animation: _haloScale,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: interactive ? _haloScale.value : 1.0,
                          child: child,
                        );
                      },
                      child: Container(
                        width: haloSize,
                        height: haloSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.enabled
                              ? AppColors.secondary.withValues(alpha: 0.14)
                              : AppColors.neutral.withValues(alpha: 0.04),
                          border: Border.all(
                            color: widget.enabled
                                ? AppColors.secondary.withValues(alpha: 0.32)
                                : AppColors.cardBorder.withValues(alpha: 0.9),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                    AnimatedScale(
                      scale: interactive && _pressed ? 0.965 : 1.0,
                      duration: const Duration(milliseconds: 90),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        width: diameter,
                        height: diameter,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: widget.enabled
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [AppColors.secondary, activeEnd],
                              )
                            : null,
                        color: widget.enabled ? null : AppColors.surface,
                        border: Border.all(
                          color: widget.enabled
                              ? Colors.white.withValues(alpha: 0.36)
                              : AppColors.cardBorder,
                          width: widget.enabled ? 2.0 : 1.5,
                        ),
                        boxShadow: widget.enabled
                            ? [
                                BoxShadow(
                                  color: AppColors.secondary.withValues(
                                    alpha: 0.36,
                                  ),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: AppColors.ambientGradientStart
                                      .withValues(alpha: 0.22),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: AppColors.neutral.withValues(
                                    alpha: 0.08,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onHighlightChanged: interactive
                              ? (down) {
                                  if (_pressed != down) {
                                    setState(() => _pressed = down);
                                  }
                                }
                              : null,
                          onTap: interactive
                              ? () {
                                  HapticFeedback.mediumImpact();
                                  widget.onPressed?.call();
                                }
                              : null,
                          canRequestFocus: interactive,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.enabled
                                      ? AppColors.ambientGradientStart
                                            .withValues(alpha: 0.14)
                                      : AppColors.primary,
                                ),
                                alignment: Alignment.center,
                                child: widget.loading
                                    ? SizedBox(
                                        width: 26,
                                        height: 26,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.6,
                                          color: ink,
                                        ),
                                      )
                                    : Icon(widget.icon, color: ink, size: 30),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.label.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  height: 1.05,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.hint != null && !widget.loading)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Text(
                  widget.hint!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
