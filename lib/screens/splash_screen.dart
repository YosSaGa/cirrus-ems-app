import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/primary_cta_button.dart';
import '../widgets/session_transition.dart';
import '../widgets/status_banner.dart';
import 'login_screen.dart';
import 'main_shell.dart';

enum _SplashPhase { checking, connectionUnavailable }

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.minDisplayDuration = Duration.zero,
  });

  /// Minimum time to showcase the animated brand intro before navigating away.
  /// Defaults to [Duration.zero] so unit/widget tests complete deterministically.
  final Duration minDisplayDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  _SplashPhase _phase = _SplashPhase.checking;
  String? _errorMessage;
  String? _cachedName;
  bool _restoring = false;

  late final AnimationController _introController;
  late final AnimationController _ambientController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textProgress;
  late final Animation<double> _barProgress;
  late final Animation<double> _statusOpacity;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _logoScale = Tween<double>(begin: 0.68, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );
    _logoOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
    );
    _textProgress = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.24, 0.66, curve: Curves.easeOutCubic),
    );
    _barProgress = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.36, 0.74, curve: Curves.easeOutCubic),
    );
    _statusOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.50, 0.85, curve: Curves.easeOut),
    );

    if (widget.minDisplayDuration > Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _introController.forward();
        if (!MediaQuery.disableAnimationsOf(context)) {
          _ambientController.repeat();
        }
      });
    } else {
      _introController.value = 1.0;
    }

    _loadCachedGreeting();
    _restore();
  }

  Future<void> _loadCachedGreeting() async {
    try {
      final user = await AuthService.getSavedUser();
      final raw = user?['name']?.toString().trim() ?? '';
      if (raw.isEmpty || !mounted) return;
      final firstToken = raw.split(RegExp(r'\s+')).first.trim();
      if (firstToken.isNotEmpty) {
        setState(() => _cachedName = firstToken);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _introController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  Future<void> _restore({bool skipMinDelay = false}) async {
    if (_restoring) return;
    _restoring = true;

    final stopwatch = Stopwatch()..start();

    if (mounted) {
      setState(() {
        _phase = _SplashPhase.checking;
        _errorMessage = null;
      });
    }

    final result = await AuthService.checkSession();

    if (!mounted) {
      _restoring = false;
      return;
    }

    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (!skipMinDelay &&
        !reducedMotion &&
        widget.minDisplayDuration > Duration.zero &&
        result.status != SessionRestorationStatus.connectionUnavailable) {
      final remaining =
          widget.minDisplayDuration.inMilliseconds -
          stopwatch.elapsedMilliseconds;
      if (remaining > 0) {
        await Future<void>.delayed(Duration(milliseconds: remaining));
      }
    }

    _restoring = false;
    if (!mounted) return;

    final useSmoothRoute =
        widget.minDisplayDuration > Duration.zero && !reducedMotion;

    switch (result.status) {
      case SessionRestorationStatus.authenticated:
        Navigator.of(context).pushReplacement(
          useSmoothRoute
              ? splashRevealTransition(context, const MainShell())
              : MaterialPageRoute(builder: (_) => const MainShell()),
        );
        break;
      case SessionRestorationStatus.unauthenticated:
        Navigator.of(context).pushReplacement(
          useSmoothRoute
              ? splashRevealTransition(context, const LoginScreen())
              : MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        break;
      case SessionRestorationStatus.connectionUnavailable:
        _ambientController.stop();
        setState(() {
          _phase = _SplashPhase.connectionUnavailable;
          _errorMessage = result.message;
        });
        break;
    }
  }

  void _retry() {
    if (widget.minDisplayDuration > Duration.zero &&
        !MediaQuery.disableAnimationsOf(context)) {
      _ambientController.repeat();
    }
    _restore(skipMinDelay: true);
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion && _introController.value < 1.0) {
      _introController.value = 1.0;
    }

    final bgStart = AppColors.splashBackground;
    final bgEnd = Color.lerp(bgStart, AppColors.secondary, 0.16)!;

    final logoBadge = RepaintBoundary(
      child: Container(
        width: 124,
        height: 124,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.38),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withValues(alpha: 0.22),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const AppLogo(size: 76),
      ),
    );

    final titleBlock = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Cirrus EMS',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _barProgress,
          builder: (_, _) => Container(
            width: 48 * _barProgress.value,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          AppStrings.t(
            'Workforce Management',
            'ระบบลงเวลาและบริหารงานพนักงาน',
          ),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.onNeutralMuted,
            letterSpacing: AppStrings.isThai ? 0 : 0.6,
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: bgStart,
      body: Stack(
        children: [
          // Ambient Deep Navy + Turquoise radial aura backdrop
          Positioned.fill(
            child: RepaintBoundary(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.18),
                    radius: 1.05,
                    colors: [bgEnd, bgStart, bgStart],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo + Marine Sonar Pulse + Orbital Gradient Ring (zero saveLayer)
                    RepaintBoundary(
                      child: SizedBox(
                        width: 210,
                        height: 210,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: _ambientController,
                                builder: (_, _) => CustomPaint(
                                  painter: _SonarOrbitalPainter(
                                    progress: _ambientController.value,
                                    accent: AppColors.secondary,
                                    showSweep:
                                        _phase == _SplashPhase.checking &&
                                        !reducedMotion,
                                  ),
                                ),
                              ),
                            ),
                            ScaleTransition(
                              scale: _logoScale,
                              child: FadeTransition(
                                opacity: _logoOpacity,
                                child: logoBadge,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FadeTransition(
                      opacity: _textProgress,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.14),
                          end: Offset.zero,
                        ).animate(_textProgress),
                        child: titleBlock,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.hero),
                    if (_phase == _SplashPhase.connectionUnavailable)
                      _connectionErrorContent()
                    else
                      FadeTransition(
                        opacity: _statusOpacity,
                        child: _checkingContent(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkingContent() {
    final greeting = _cachedName != null
        ? AppStrings.t(
            'Welcome back, $_cachedName',
            'ยินดีต้อนรับกลับ, $_cachedName',
            'Selamat kembali, $_cachedName',
          )
        : AppStrings.t(
            'Connecting to Cirrus EMS…',
            'กำลังเชื่อมต่อ Cirrus EMS…',
            'Menyambung ke Cirrus EMS…',
          );
    return Container(
      key: const Key('splash-status-pill'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SplashWaveDots(
            animation: _ambientController,
            color: AppColors.secondary,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              greeting,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onNeutralMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _connectionErrorContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusBanner(
          variant: StatusVariant.error,
          title: AppStrings.t('Connection Problem', 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้'),
          message:
              _errorMessage ??
              AppStrings.t(
                'The server cannot currently be reached. Please check your '
                    'connection and try again.',
                'ไม่สามารถติดต่อเซิร์ฟเวอร์ได้ในขณะนี้ กรุณาตรวจสอบการเชื่อมต่อแล้วลองใหม่',
              ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryCtaButton(
          label: AppStrings.t('Retry', 'ลองอีกครั้ง'),
          loading: _restoring,
          onPressed: _restoring ? null : _retry,
        ),
      ],
    );
  }
}

class _SonarOrbitalPainter extends CustomPainter {
  const _SonarOrbitalPainter({
    required this.progress,
    required this.accent,
    required this.showSweep,
  });

  final double progress;
  final Color accent;
  final bool showSweep;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Subtle concentric instrument track
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = accent.withValues(alpha: 0.14);
    canvas.drawCircle(center, 68, trackPaint);
    canvas.drawCircle(center, 88, trackPaint..color = accent.withValues(alpha: 0.08));

    if (!showSweep) return;

    // Two staggered marine sonar pulse rings radiating outward
    for (final phaseShift in const [0.0, 0.5]) {
      final t = (progress + phaseShift) % 1.0;
      final radius = 62.0 + t * 40.0;
      final alpha = ((1.0 - t) * (1.0 - t) * 0.42).clamp(0.0, 1.0);
      final pulsePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = accent.withValues(alpha: alpha);
      canvas.drawCircle(center, radius, pulsePaint);
    }

    // Rotating orbital gradient arc around the logo rim
    const orbitalRadius = 66.0;
    final rect = Rect.fromCircle(center: center, radius: orbitalRadius);
    final startAngle = progress * 2 * math.pi - math.pi / 2;
    final sweepAngle = math.pi * 0.65;

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: sweepAngle,
        colors: [
          accent.withValues(alpha: 0.0),
          accent.withValues(alpha: 0.45),
          accent,
        ],
        stops: const [0.0, 0.55, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(rect);
    canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);

    // Glowing head dot at the tip of the orbital arc
    final tipAngle = startAngle + sweepAngle;
    final tip = Offset(
      center.dx + orbitalRadius * math.cos(tipAngle),
      center.dy + orbitalRadius * math.sin(tipAngle),
    );
    canvas.drawCircle(
      tip,
      3.2,
      Paint()..color = accent.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(covariant _SonarOrbitalPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent ||
      oldDelegate.showSweep != showSweep;
}

class _SplashWaveDots extends StatelessWidget {
  const _SplashWaveDots({required this.animation, required this.color});

  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (animation.value * 2 * math.pi) - (i * 0.85);
            final wave = (math.sin(phase) + 1) / 2; // 0..1
            return Container(
              margin: EdgeInsets.only(right: i == 2 ? 0 : 4),
              width: 5.5,
              height: 5.5,
              transform: Matrix4.translationValues(0, -wave * 3.0, 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.45 + wave * 0.55),
              ),
            );
          }),
        );
      },
    );
  }
}
