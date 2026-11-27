import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A brief reveal after an explicit sign-in or sign-out.
Route<void> sessionTransition(BuildContext context, Widget destination) {
  final duration = MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 260);

  return PageRouteBuilder<void>(
    transitionDuration: duration,
    pageBuilder: (_, _, _) => destination,
    transitionsBuilder: (_, animation, _, child) {
      if (duration == Duration.zero) return child;

      final opacity = animation.drive(
        Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
      );
      // Keep the previous account screen covered as the new page fades in.
      return ColoredBox(
        color: AppColors.primary,
        child: FadeTransition(opacity: opacity, child: child),
      );
    },
  );
}

/// Seamless GPU-composited fade + gentle rise from the dark Splash screen
/// into the destination screen (zero fractional-scale re-rasterization jank).
Route<void> splashRevealTransition(BuildContext context, Widget destination) {
  final duration = MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 340);

  return PageRouteBuilder<void>(
    transitionDuration: duration,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, _, _) => RepaintBoundary(child: destination),
    transitionsBuilder: (_, animation, _, child) {
      if (duration == Duration.zero) return child;

      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
      );
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.025),
        end: Offset.zero,
      ).animate(curved);

      return FadeTransition(
        opacity: curved,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}
