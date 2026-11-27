import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// claude_prompt.txt (Update Flutter App Logo): replaces the previous
// generic icon-in-a-colored-box placeholder (a Secondary-teal rounded
// square behind Icons.bolt_rounded) with the actual brand asset at
// `lib/assets/Cirrus_app_logo.svg`. That asset already paints its own
// dark rounded-square background (matching the v98-era rationale this
// file used to document -- a single mark legible against either the
// light Primary surface or the dark Neutral hero band), so no extra
// Container/decoration is layered behind it here. `size` keeps its
// existing meaning (a square of `size` x `size`), so every call site
// (SplashScreen, LoginScreen) needed no change.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'lib/assets/Cirrus_app_logo.svg',
      width: size,
      height: size,
    );
  }
}
