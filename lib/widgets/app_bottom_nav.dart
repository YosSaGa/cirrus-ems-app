import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';

/// Shared destinations keep the mobile navigation and desktop rail in sync.
List<({IconData icon, String label})> get appNavDestinations => [
  (
    icon: Icons.event_available_rounded,
    label: AppStrings.t('Attendance', 'ลงเวลา'),
  ),
  (
    icon: Icons.history_rounded,
    label: AppStrings.t('History', 'ประวัติ'),
  ),
  (
    icon: Icons.calculate_outlined,
    label: AppStrings.t('Pay & Leave', 'ค่าแรงและลา'),
  ),
  (
    icon: Icons.account_circle_rounded,
    label: AppStrings.t('Profile', 'โปรไฟล์'),
  ),
];

class AppBottomNav extends StatefulWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav>
    with SingleTickerProviderStateMixin {
  late double _fromPosition;
  late double _currentPosition;
  late AnimationController _bounceController;
  int? _pressedIndex;

  @override
  void initState() {
    super.initState();
    _fromPosition = widget.currentIndex.toDouble();
    _currentPosition = widget.currentIndex.toDouble();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
  }

  @override
  void didUpdateWidget(AppBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _fromPosition = _currentPosition;
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _triggerBounce() {
    _bounceController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeService.themeModeNotifier,
        LanguageService.languageNotifier,
      ]),
      builder: (context, _) {
        final destinations = appNavDestinations;
        final reducedMotion = MediaQuery.disableAnimationsOf(context);
        final height = 72 + MediaQuery.textScalerOf(context).scale(12) * 2.3;
        return RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.0),
                  AppColors.primary.withValues(alpha: 0.88),
                  AppColors.primary,
                ],
                stops: const [0.0, 0.34, 0.62],
              ),
            ),
            child: SafeArea(
              minimum: const EdgeInsets.only(bottom: 8),
              child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: 1,
            child: Container(
              width: AppBreakpoints.isTablet(context) ? 520 : null,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth =
                      constraints.maxWidth / destinations.length;
                  return TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: widget.currentIndex.toDouble(),
                      end: widget.currentIndex.toDouble(),
                    ),
                    duration: reducedMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 360),
                    curve: Curves.easeOutCubic,
                    builder: (context, position, _) {
                      _currentPosition = position;
                      final target = widget.currentIndex.toDouble();
                      final distance = (target - _fromPosition).abs();
                      final double t;
                      if (distance < 0.001) {
                        t = 1.0;
                      } else {
                        t = ((position - _fromPosition) / (target - _fromPosition))
                            .clamp(0.0, 1.0);
                      }

                      final fromIndex = _fromPosition.round().clamp(
                        0,
                        appNavDestinations.length - 1,
                      );
                      final activeIconIndex = (t < 0.5)
                          ? fromIndex
                          : widget.currentIndex;

                      final sinkProgress = reducedMotion
                          ? 0.0
                          : math.sin(t * math.pi);
                      final sinkY = 22.0 * sinkProgress;
                      final bubbleScale = reducedMotion
                          ? 1.0
                          : (1.0 - 0.28 * sinkProgress).clamp(0.5, 1.0);

                      final isPressed = _pressedIndex == widget.currentIndex;
                      final pressSink = isPressed ? 6.0 : 0.0;
                      final pressScale = isPressed ? 0.93 : 1.0;

                      return AnimatedBuilder(
                        animation: _bounceController,
                        builder: (context, _) {
                          final bounceVal = _bounceController.value;
                          final bounceSink = reducedMotion
                              ? 0.0
                              : math.sin(bounceVal * math.pi) * 10.0;
                          final bounceScale = reducedMotion
                              ? 1.0
                              : (1.0 - math.sin(bounceVal * math.pi) * 0.1);

                          final totalY = sinkY + pressSink + bounceSink;
                          final totalScale = bubbleScale * pressScale * bounceScale;

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _NavigationSurface(
                                      center: itemWidth * (position + 0.5),
                                      surfaceColor: AppColors.surface,
                                      shadowColor: AppColors.bottomNavShadow,
                                    ),
                                  ),
                                ),
                              ),
                          Positioned(
                            left: itemWidth * (position + 0.5) - 26,
                            top: totalY,
                            child: IgnorePointer(
                              child: ExcludeSemantics(
                                child: Transform.scale(
                                  scale: totalScale,
                                  child: Container(
                                    key: const Key('nav-selection-bubble'),
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: AppColors.bottomNavBubble,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.bottomNavBubble
                                              .withValues(alpha: 0.18),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      appNavDestinations[activeIconIndex].icon,
                                      key: ValueKey(activeIconIndex),
                                      color: AppColors.bottomNavIcon,
                                      size: 25,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Row(
                              children: List.generate(appNavDestinations.length, (
                                index,
                              ) {
                                final item = appNavDestinations[index];
                                final isTarget = widget.currentIndex == index;
                                final isOrigin =
                                    fromIndex == index &&
                                    fromIndex != widget.currentIndex;

                                double iconOpacity;
                                Offset textOffset;
                                Color textColor;
                                FontWeight textWeight;

                                if (reducedMotion) {
                                  iconOpacity = isTarget ? 0.0 : 1.0;
                                  textOffset = isTarget
                                      ? const Offset(0, -0.65)
                                      : Offset.zero;
                                  textColor = isTarget
                                      ? AppColors.neutral
                                      : AppColors.textSecondary;
                                  textWeight = isTarget
                                      ? FontWeight.w700
                                      : FontWeight.w500;
                                } else if (isTarget) {
                                  if (t < 0.55) {
                                    iconOpacity = 1.0;
                                    textOffset = Offset.zero;
                                    textColor = AppColors.textSecondary;
                                    textWeight = FontWeight.w500;
                                  } else {
                                    final progress = ((t - 0.55) / 0.45).clamp(
                                      0.0,
                                      1.0,
                                    );
                                    iconOpacity = 1.0 - progress;
                                    textOffset = Offset(0, -0.65 * progress);
                                    textColor = progress > 0.5
                                        ? AppColors.neutral
                                        : AppColors.textSecondary;
                                    textWeight = progress > 0.5
                                        ? FontWeight.w700
                                        : FontWeight.w500;
                                  }
                                } else if (isOrigin) {
                                  if (t < 0.45) {
                                    iconOpacity = 0.0;
                                    textOffset = const Offset(0, -0.65);
                                    textColor = AppColors.neutral;
                                    textWeight = FontWeight.w700;
                                  } else {
                                    final progress = ((t - 0.45) / 0.45).clamp(
                                      0.0,
                                      1.0,
                                    );
                                    iconOpacity = progress;
                                    textOffset = Offset(
                                      0,
                                      -0.65 * (1.0 - progress),
                                    );
                                    textColor = progress > 0.5
                                        ? AppColors.textSecondary
                                        : AppColors.neutral;
                                    textWeight = progress > 0.5
                                        ? FontWeight.w500
                                        : FontWeight.w700;
                                  }
                                } else {
                                  iconOpacity = 1.0;
                                  textOffset = Offset.zero;
                                  textColor = AppColors.textSecondary;
                                  textWeight = FontWeight.w500;
                                }

                                return Expanded(
                                  child: Semantics(
                                    selected: isTarget,
                                    button: true,
                                    label: item.label,
                                    onTap: () {
                                      if (index == widget.currentIndex) {
                                        _triggerBounce();
                                      }
                                      widget.onTap(index);
                                    },
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        key: ValueKey('nav-item-$index'),
                                        borderRadius: BorderRadius.circular(24),
                                        excludeFromSemantics: true,
                                        onTapDown: (_) => setState(
                                          () => _pressedIndex = index,
                                        ),
                                        onTapUp: (_) => setState(
                                          () => _pressedIndex = null,
                                        ),
                                        onTapCancel: () => setState(
                                          () => _pressedIndex = null,
                                        ),
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() => _pressedIndex = null);
                                          if (index == widget.currentIndex) {
                                            _triggerBounce();
                                          }
                                          widget.onTap(index);
                                        },
                                        child: ExcludeSemantics(
                                          child: Column(
                                            children: [
                                              const SizedBox(height: 40),
                                              SizedBox(
                                                height: 23,
                                                child: iconOpacity > 0.001
                                                    ? Opacity(
                                                        opacity: iconOpacity,
                                                        child: Icon(
                                                          item.icon,
                                                          color: AppColors
                                                              .textSecondary,
                                                          size: 23,
                                                        ),
                                                      )
                                                    : const SizedBox.shrink(),
                                              ),
                                              const SizedBox(height: 7),
                                              Transform.translate(
                                                offset: Offset(
                                                  textOffset.dx,
                                                  textOffset.dy * 20,
                                                ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 2,
                                                      ),
                                                  child: Text(
                                                    item.label,
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    style: TextStyle(
                                                      color: textColor,
                                                      fontSize: 12,
                                                      height: 1.1,
                                                      fontWeight: textWeight,
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
                                );
                              }),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
              ),
            ),
          ),
        ),
        ),
        );
      },
    );
  }
}

class _NavigationSurface extends CustomPainter {
  const _NavigationSurface({
    required this.center,
    required this.surfaceColor,
    required this.shadowColor,
  });

  final double center;
  final Color surfaceColor;
  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 28.0;
    const radius = 26.0;
    // The notch follows the same interpolated center as the floating bubble.
    final halfNotch = (size.width / 8 - 4).clamp(24.0, 32.0);
    final start = center - halfNotch;
    final end = center + halfNotch;
    final leftRadius = math.min(radius, math.max(0.0, start));
    final rightRadius = math.min(radius, math.max(0.0, size.width - end));
    final path = Path()
      ..moveTo(0, top + leftRadius)
      ..quadraticBezierTo(0, top, leftRadius, top)
      ..lineTo(start, top)
      ..cubicTo(
        center - halfNotch * 0.55,
        top,
        center - halfNotch * 0.65,
        60,
        center,
        60,
      )
      ..cubicTo(
        center + halfNotch * 0.65,
        60,
        center + halfNotch * 0.55,
        top,
        end,
        top,
      )
      ..lineTo(size.width - rightRadius, top)
      ..quadraticBezierTo(size.width, top, size.width, top + rightRadius)
      ..lineTo(size.width, size.height - radius)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - radius,
        size.height,
      )
      ..lineTo(radius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - radius)
      ..close();
    canvas.drawShadow(
      path,
      shadowColor,
      5,
      false,
    );
    canvas.drawPath(path, Paint()..color = surfaceColor);
  }

  @override
  bool shouldRepaint(_NavigationSurface oldDelegate) =>
      oldDelegate.center != center ||
      oldDelegate.surfaceColor != surfaceColor ||
      oldDelegate.shadowColor != shadowColor;
}
