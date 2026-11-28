import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/fade_slide_entry.dart';
import '../widgets/primary_cta_button.dart';
import '../widgets/session_transition.dart';
import '../widgets/status_banner.dart';
import 'main_shell.dart';

// claude_prompt.txt (v98 Phase 2 -- Full UX/UI Redesign Implementation,
// Stage 3): the approved mobile-stacked / desktop-split-panel composition.
// Authentication is UNCHANGED from v92/v97 -- same `_usernameController`/
// `_passwordController`, same non-empty-only validators, same
// `AuthService.login(username, password)` call, same `_login()` try/
// catch/finally structure.
//
// claude_prompt.txt (v123 -- Implement Bottom Navigation Shell): the
// post-login `pushReplacement` destination changed from `AttendanceScreen`
// directly to `MainShell` (renders AttendanceScreen as its first,
// already-selected tab) -- nothing else in `_login()` changed.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.initialUsername,
    this.lockedAccount,
  });

  /// Optional username pre-filled when arriving from Switch Account.
  final String? initialUsername;

  /// When set (e.g. account inactive > 5 days), hides the username field and
  /// shows an identity card indicating which account's password is being entered.
  final RecentAccount? lockedAccount;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  RecentAccount? _lockedAccount;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _lockedAccount = widget.lockedAccount;
    final prefill =
        widget.lockedAccount?.username.trim() ??
        widget.initialUsername?.trim() ??
        '';
    if (prefill.isNotEmpty) {
      _usernameController.text = prefill;
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();

    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final stopwatch = Stopwatch()..start();

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (!reducedMotion) {
        const minHoldMs = 700;
        final remaining = minHoldMs - stopwatch.elapsedMilliseconds;
        if (remaining > 0) {
          await Future<void>.delayed(Duration(milliseconds: remaining));
        }
      }

      if (!mounted) return;

      Navigator.of(context)
          .pushReplacement(sessionTransition(context, const MainShell()));
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _brandPanel(BuildContext context, {required bool isDesktop}) {
    final top = isDesktop
        ? AppSpacing.hero
        : MediaQuery.paddingOf(context).top + AppSpacing.xl;
    return CustomPaint(
      painter: _LoginBackdrop(
        isDesktop: isDesktop,
        backdropColor: AppColors.ambientGradientStart,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? AppSpacing.hero : AppSpacing.xl,
          top,
          AppSpacing.xl,
          isDesktop ? 204 : AppSpacing.hero,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                AppLogo(size: 36),
                SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    'Cirrus EMS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isDesktop ? AppSpacing.hero : AppSpacing.xxl),
            Text(
              AppStrings.t('Employee\nattendance', 'ระบบลงเวลา\nพนักงาน'),
              style: TextStyle(
                color: Colors.white,
                fontSize: isDesktop ? 56 : 42,
                fontWeight: FontWeight.w800,
                height: 1.12,
                letterSpacing: AppStrings.isThai ? 0 : 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formContent(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Heading
          FadeSlideEntry(
            duration: const Duration(milliseconds: 400),
            delay: const Duration(milliseconds: 80),
            yOffset: 16.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    AppStrings.t('Sign in', 'เข้าสู่ระบบ'),
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: AppStrings.isThai ? 0 : 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.t(
                    'Use your employee account to continue.',
                    'เข้าสู่ระบบด้วยบัญชีพนักงานของคุณเพื่อดำเนินการต่อ',
                  ),
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Locked account identity card OR normal Username field
          if (_lockedAccount != null)
            FadeSlideEntry(
              duration: const Duration(milliseconds: 400),
              delay: const Duration(milliseconds: 150),
              yOffset: 14.0,
              child: Container(
                key: const Key('locked-account-card'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.surface),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.45),
                    width: 1.4,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.avatarBackground,
                          child: Text(
                            _lockedAccount!.name.isNotEmpty
                                ? _lockedAccount!.name.characters.first
                                      .toUpperCase()
                                : 'U',
                            style: TextStyle(
                              color: AppColors.avatarForeground,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.t(
                                  'ENTERING PASSWORD FOR',
                                  'กำลังใส่รหัสผ่านของบัญชี',
                                  'MEMASUKKAN KATA LALUAN UNTUK',
                                ),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: AppStrings.isThai ? 0 : 0.6,
                                  color: AppColors.secondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _lockedAccount!.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.neutral,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _lockedAccount!.employeeCode != null &&
                                        _lockedAccount!
                                            .employeeCode!
                                            .isNotEmpty
                                    ? '${_lockedAccount!.username} · #${_lockedAccount!.employeeCode}'
                                    : _lockedAccount!.username,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const Key('unlock-another-account'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: _loading
                            ? null
                            : () {
                                setState(() {
                                  _lockedAccount = null;
                                  _usernameController.clear();
                                  _passwordController.clear();
                                  _errorMessage = null;
                                });
                              },
                        child: Text(
                          AppStrings.t(
                            'Use another account',
                            'เปลี่ยนไปใช้บัญชีอื่น',
                            'Guna akaun lain',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            FadeSlideEntry(
              duration: const Duration(milliseconds: 400),
              delay: const Duration(milliseconds: 150),
              yOffset: 14.0,
              child: TextFormField(
                controller: _usernameController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enabled: !_loading,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Thai',
                  fontSize: 15,
                  color: AppColors.neutral,
                  letterSpacing: 0.2,
                ),
                decoration: InputDecoration(
                  labelText: AppStrings.t('Username', 'ชื่อผู้ใช้'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (value) {
                  final username = value?.trim() ?? '';
                  if (username.isEmpty) {
                    return AppStrings.t(
                      'Please enter your username.',
                      'กรุณากรอกชื่อผู้ใช้',
                    );
                  }
                  return null;
                },
              ),
            ),
          const SizedBox(height: AppSpacing.lg),

          // Password field
          FadeSlideEntry(
            duration: const Duration(milliseconds: 400),
            delay: const Duration(milliseconds: 210),
            yOffset: 14.0,
            child: TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              enabled: !_loading,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Thai',
                fontSize: 15,
                color: AppColors.neutral,
                letterSpacing: 0.2,
              ),
              decoration: InputDecoration(
                labelText: AppStrings.t('Password', 'รหัสผ่าน'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword
                      ? AppStrings.t('Show password', 'แสดงรหัสผ่าน')
                      : AppStrings.t('Hide password', 'ซ่อนรหัสผ่าน'),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppStrings.t(
                    'Please enter your password.',
                    'กรุณากรอกรหัสผ่าน',
                  );
                }
                return null;
              },
              onFieldSubmitted: (_) {
                if (!_loading) _login();
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (_errorMessage != null) ...[
            StatusBanner(variant: StatusVariant.error, message: _errorMessage!),
            const SizedBox(height: AppSpacing.lg),
          ],

          // CTA button
          FadeSlideEntry(
            duration: const Duration(milliseconds: 400),
            delay: const Duration(milliseconds: 280),
            yOffset: 10.0,
            scaleBegin: 0.95,
            child: PrimaryCtaButton(
              label: AppStrings.t('Sign In', 'เข้าสู่ระบบ'),
              loadingLabel: AppStrings.t('Signing in…', 'กำลังเข้าสู่ระบบ…'),
              loading: _loading,
              onPressed: _login,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);
    final form = Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _formContent(context),
      ),
    );
    final brand = _brandPanel(context, isDesktop: isDesktop);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDesktop
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light.copyWith(
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: isDesktop
            ? SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: math.max(0, constraints.maxHeight - 64),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1080),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.hero),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: brand),
                                  Expanded(
                                    child: ColoredBox(
                                      color: AppColors.surface,
                                      child: Padding(
                                        padding: const EdgeInsets.all(
                                          AppSpacing.hero,
                                        ),
                                        child: Center(child: form),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      brand,
                      ColoredBox(
                        color: AppColors.neutral,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(AppRadius.hero),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.xl,
                              AppSpacing.xl,
                              AppSpacing.xl,
                              AppSpacing.xxl,
                            ),
                            child: form,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _LoginBackdrop extends CustomPainter {
  const _LoginBackdrop({
    required this.isDesktop,
    required this.backdropColor,
  });

  final bool isDesktop;
  final Color backdropColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final center = Offset(
      size.width * (isDesktop ? 0.80 : 0.91),
      size.height * (isDesktop ? 0.83 : 0.43),
    );
    final radius = size.shortestSide * (isDesktop ? 0.42 : 0.40);
    canvas.save();
    canvas.clipRect(bounds);
    canvas.drawRect(bounds, Paint()..color = backdropColor);
    canvas.drawCircle(
      center,
      radius * 1.65,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.secondary.withValues(alpha: 0.26),
            AppColors.secondary.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.65)),
    );

    final line = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke;
    for (final scale in [0.68, 0.88, 1.0, 1.16]) {
      canvas.drawCircle(center, radius * scale, line);
    }

    for (var tick = 0; tick < 48; tick++) {
      final angle = tick * math.pi / 24;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final length = tick % 4 == 0 ? 8.0 : 4.0;
      canvas.drawLine(
        center + direction * (radius - length),
        center + direction * radius,
        line,
      );
    }

    final accent = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    const startAngle = 2.54;
    const sweepAngle = 1.32;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.88),
      startAngle,
      sweepAngle,
      false,
      accent,
    );
    final end = startAngle + sweepAngle;
    canvas.drawCircle(
      center + Offset(math.cos(end), math.sin(end)) * (radius * 0.88),
      4,
      Paint()..color = AppColors.secondary,
    );
    final hands = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.72)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      center + Offset(-radius * 0.21, -radius * 0.54),
      hands,
    );
    canvas.drawLine(
      center,
      center + Offset(radius * 0.32, radius * 0.09),
      hands,
    );
    canvas.drawCircle(center, 3, Paint()..color = AppColors.secondary);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LoginBackdrop oldDelegate) =>
      oldDelegate.isDesktop != isDesktop ||
      oldDelegate.backdropColor != backdropColor;
}
