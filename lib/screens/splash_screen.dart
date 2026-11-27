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
    with SingleTickerProviderStateMixin {
  _SplashPhase _phase = _SplashPhase.checking;
  String? _errorMessage;
  bool _restoring = false;

  late final AnimationController _introController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _rippleProgress;
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
    _rippleProgress = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.10, 0.72, curve: Curves.easeOutCubic),
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
        if (mounted) _introController.forward();
      });
    } else {
      _introController.value = 1.0;
    }

    _restore();
  }

  @override
  void dispose() {
    _introController.dispose();
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
        setState(() {
          _phase = _SplashPhase.connectionUnavailable;
          _errorMessage = result.message;
        });
        break;
    }
  }

  void _retry() {
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
                    // Logo + expanding luminous turquoise halo ring (zero saveLayer)
                    RepaintBoundary(
                      child: SizedBox(
                        width: 170,
                        height: 170,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _rippleProgress,
                              builder: (_, _) {
                                final ripple = _rippleProgress.value;
                                if (ripple <= 0.0 || ripple >= 1.0) {
                                  return const SizedBox.shrink();
                                }
                                return Transform.scale(
                                  scale: 0.78 + ripple * 0.82,
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.secondary.withValues(
                                          alpha: (1.0 - ripple) * 0.45,
                                        ),
                                        width: 2.0,
                                      ),
                                    ),
                                  ),
                                );
                              },
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 120,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              minHeight: 3.5,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          AppStrings.t('Preparing your workspace…', 'กำลังเตรียมพื้นที่ทำงาน…'),
          style: TextStyle(fontSize: 12.5, color: AppColors.onNeutralMuted),
        ),
      ],
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
