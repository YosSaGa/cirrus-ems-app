import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../models/payroll_calculator.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';

/// Interactive Cirrus Pay Wallet Card with 3D flip-to-back animation,
/// EMV chip & contactless artwork, pointer-tracking specular sheen,
/// and animated Hide/Show balance toggle.
class PayWalletCard extends StatefulWidget {
  /// Incremented by navigation shells when leaving the Pay tab so any
  /// flipped card returns to its front face before the user comes back.
  static final ValueNotifier<int> resetFrontNotifier = ValueNotifier<int>(0);

  static void resetAllToFront() {
    resetFrontNotifier.value++;
  }

  const PayWalletCard({
    super.key,
    required this.periodLabel,
    required this.periodShort,
    required this.periodEnded,
    required this.busy,
    this.estimate,
    this.holderName,
    this.employeeCode,
    this.department,
    this.employmentType,
    this.employmentStatus,
    this.baseSalary,
    this.startDate,
  });

  final String periodLabel;
  final String periodShort;
  final bool periodEnded;
  final bool busy;
  final PayEstimate? estimate;
  final String? holderName;
  final String? employeeCode;
  final String? department;
  final String? employmentType;
  final String? employmentStatus;
  final double? baseSalary;
  final String? startDate;

  @override
  State<PayWalletCard> createState() => _PayWalletCardState();
}

class _PayWalletCardState extends State<PayWalletCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  bool _isFlipped = false;
  bool _hideBalance = false;
  Alignment _sheenAlignment = const Alignment(-0.44, -0.64);

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
    );
    PayWalletCard.resetFrontNotifier.addListener(_resetToFront);
  }

  void _resetToFront() {
    if (!mounted || !_isFlipped) return;
    setState(() => _isFlipped = false);
    _flipController.value = 0.0;
  }

  @override
  void dispose() {
    PayWalletCard.resetFrontNotifier.removeListener(_resetToFront);
    _flipController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    HapticFeedback.lightImpact();
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    setState(() => _isFlipped = !_isFlipped);
    if (reduceMotion) {
      _flipController.value = _isFlipped ? 1.0 : 0.0;
      return;
    }
    if (_isFlipped) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
  }

  void _updateSheen(Offset localPos, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final dx = ((localPos.dx / size.width) * 2 - 1).clamp(-1.0, 1.0);
    final dy = ((localPos.dy / size.height) * 2 - 1).clamp(-1.0, 1.0);
    setState(() => _sheenAlignment = Alignment(dx, dy));
  }

  void _resetSheen() {
    setState(() => _sheenAlignment = const Alignment(-0.44, -0.64));
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final estimate = widget.estimate;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final cardHeight = (cardWidth / 1.586).clamp(210.0, 250.0);

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onHover: reduceMotion
              ? null
              : (event) => _updateSheen(
                  event.localPosition,
                  Size(cardWidth, cardHeight),
                ),
          onExit: reduceMotion ? null : (_) => _resetSheen(),
          child: GestureDetector(
            key: const Key('pay-wallet-card'),
            onTap: _toggleFlip,
            child: Semantics(
              button: true,
              label: _isFlipped
                  ? 'Pay card back side. Tap to flip to front.'
                  : 'Pay card front side. Tap to flip to details.',
              child: SizedBox(
                height: cardHeight,
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _flipAnimation,
                    builder: (context, _) {
                      final angle = _flipAnimation.value * math.pi;
                      final showBack = angle >= math.pi / 2;
                      final matrix = Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateY(angle);

                      return Transform(
                        alignment: Alignment.center,
                        transform: matrix,
                        child: showBack
                            ? Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.rotationY(math.pi),
                                child: _buildCardShell(
                                  child: _buildBackContent(estimate),
                                ),
                              )
                            : _buildCardShell(
                                child: _buildFrontContent(estimate),
                              ),
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

  Widget _buildCardShell({required Widget child}) {
    return ValueListenableBuilder<PayCardStyle>(
      valueListenable: ThemeService.payCardStyleNotifier,
      builder: (context, cardStyle, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: cardStyle.gradientStart.withValues(alpha: 0.34),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: cardStyle.gradientColors,
                      ),
                    ),
                  ),
                ),
                // Sculpted subtle accent glow & diagonal metallic sheen
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: _sheenAlignment,
                          radius: 1.15,
                          colors: [
                            Colors.white.withValues(alpha: 0.18),
                            cardStyle.accentColor.withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.42, 0.8],
                        ),
                      ),
                    ),
                  ),
                ),
                // Fine metallic rim highlight
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFrontContent(PayEstimate? estimate) {
    final holder = (widget.holderName ?? '').trim().isNotEmpty
        ? widget.holderName!.trim().toUpperCase()
        : 'CIRRUS EMPLOYEE';
    final empCode = (widget.employeeCode ?? '').trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: EMV Chip + Contactless + Period label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _EmvChip(),
                  SizedBox(width: 10),
                  _ContactlessGlyph(),
                ],
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Text(
                    widget.periodEnded
                        ? AppStrings.t(
                            'Period ended · Estimate only',
                            'สิ้นสุดรอบแล้ว · ประมาณการเท่านั้น',
                          )
                        : AppStrings.t(
                            'Period open · Running estimate',
                            'รอบปัจจุบัน · ประมาณการต่อเนื่อง',
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.onNeutralMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: AppStrings.isThai ? 0 : 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Middle: Balance Display
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (estimate != null) ...[
                Row(
                  children: [
                    Text(
                      AppStrings.t('Estimated base pay', 'ประมาณการค่าแรงพื้นฐาน'),
                      style: TextStyle(
                        color: AppColors.onNeutralMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: AppStrings.isThai ? 0 : 0.4,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      key: const Key('toggle-hide-balance'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _hideBalance = !_hideBalance);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          _hideBalance
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 15,
                          color: AppColors.onNeutralMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    end: estimate.regularSatang.toDouble(),
                  ),
                  duration:
                      (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
                      ? Duration.zero
                      : const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedSatang, _) => ValueListenableBuilder<PayCardStyle>(
                    valueListenable: ThemeService.payCardStyleNotifier,
                    builder: (context, cardStyle, _) => AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: Align(
                        key: ValueKey(_hideBalance),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _hideBalance
                              ? 'THB ••••••'
                              : formatBaht(animatedSatang.round()),
                          style: TextStyle(
                            color: cardStyle.accentColor,
                            fontSize: 36,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  widget.busy
                      ? AppStrings.t('Reading scans…', 'กำลังอ่านประวัติสแกน…')
                      : AppStrings.t(
                          'Estimate unavailable',
                          'ไม่สามารถคำนวณได้',
                        ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),

          // Bottom Row: Employee + Emp Code (when available) + Period + Cirrus Mark
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.t('EMPLOYEE', 'พนักงาน'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: AppStrings.isThai ? 0 : 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      holder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              if (empCode.isNotEmpty) ...[
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.t('EMP CODE', 'รหัสพนักงาน'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: AppStrings.isThai ? 0 : 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      empCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.t('PERIOD', 'รอบเดือน'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.48),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: AppStrings.isThai ? 0 : 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.periodShort,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CIRRUS',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    AppStrings.t('TAP TO FLIP', 'แตะเพื่อพลิกการ์ด'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: AppStrings.isThai ? 0 : 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatEmploymentLabel() {
    String humanize(String raw) => raw
        .trim()
        .replaceAll('_', '-')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.toUpperCase())
        .join(' ');

    final type = (widget.employmentType ?? '').trim();
    final status = (widget.employmentStatus ?? '').trim();
    final parts = <String>[
      if (type.isNotEmpty) humanize(type),
      if (status.isNotEmpty) humanize(status),
    ];
    return parts.isEmpty ? 'NOT PROVIDED' : parts.join(' · ');
  }

  static const _monthsUpper = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  String _formatStartDate() {
    final raw = (widget.startDate ?? '').trim();
    if (raw.isEmpty) return AppStrings.t('NOT PROVIDED', 'ไม่ระบุ');
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw.toUpperCase();
    final day = parsed.day.toString().padLeft(2, '0');
    if (AppStrings.isThai) {
      return '$day ${AppStrings.monthShort(parsed.month)} ${parsed.year}';
    }
    return '$day ${_monthsUpper[parsed.month - 1]} ${parsed.year}';
  }

  String _formatBaseSalary() {
    final salary = widget.baseSalary;
    if (salary == null || !salary.isFinite || salary <= 0) return 'NOT SET';
    return formatBaht((salary * 100).round());
  }

  Widget _buildBackContent(PayEstimate? estimate) {
    final department = (widget.department ?? '').trim().isNotEmpty
        ? widget.department!.trim().toUpperCase()
        : 'NOT PROVIDED';
    final employment = _formatEmploymentLabel();
    final baseSalary = _formatBaseSalary();
    final startDate = _formatStartDate();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        // Magnetic stripe bar
        Container(
          height: 34,
          color: Colors.black.withValues(alpha: 0.55),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerRight,
          child: Text(
            AppStrings.t(
              'CIRRUS EMS · PAY CARD DETAILS',
              'CIRRUS EMS · ข้อมูลบัตรค่าแรง',
            ),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: AppStrings.isThai ? 0 : 1.4,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _BackStatTile(
                        label: AppStrings.t('BASE SALARY', 'ฐานเงินเดือน'),
                        value: baseSalary,
                        valueColor: widget.baseSalary != null &&
                                widget.baseSalary! > 0
                            ? AppColors.secondary
                            : Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BackStatTile(
                        label: AppStrings.t('DEPARTMENT', 'แผนก'),
                        value: department,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _BackStatTile(
                        label: AppStrings.t('EMPLOYMENT', 'ประเภทการจ้างงาน'),
                        value: employment,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BackStatTile(
                        label: AppStrings.t('START DATE', 'วันเริ่มงาน'),
                        value: startDate,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        AppStrings.t(
                          'TRIAL ESTIMATE · NOT APPROVED PAYROLL',
                          'ประมาณการทดลอง · ไม่ใช่สลิปเงินเดือนจริง',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: AppStrings.isThai ? 0 : 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 12,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppStrings.t('TAP TO RETURN', 'แตะเพื่อกลับด้าน'),
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: AppStrings.isThai ? 0 : 0.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BackStatTile extends StatelessWidget {
  const _BackStatTile({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmvChip extends StatelessWidget {
  const _EmvChip();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: SizedBox(
        width: 34,
        height: 26,
        child: CustomPaint(painter: _EmvChipPainter()),
      ),
    );
  }
}

class _EmvChipPainter extends CustomPainter {
  const _EmvChipPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF4E3AB), Color(0xFFC9A544), Color(0xFF8F6F22)],
      ).createShader(rect);
    canvas.drawRRect(rrect, fillPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black.withValues(alpha: 0.24);
    canvas.drawRRect(rrect, borderPaint);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = Colors.black.withValues(alpha: 0.30);

    final w = size.width;
    final h = size.height;
    canvas.drawLine(Offset(0, h * 0.33), Offset(w * 0.32, h * 0.33), linePaint);
    canvas.drawLine(Offset(0, h * 0.67), Offset(w * 0.32, h * 0.67), linePaint);
    canvas.drawLine(Offset(w * 0.68, h * 0.33), Offset(w, h * 0.33), linePaint);
    canvas.drawLine(Offset(w * 0.68, h * 0.67), Offset(w, h * 0.67), linePaint);
    canvas.drawLine(
      Offset(w * 0.32, h * 0.14),
      Offset(w * 0.32, h * 0.86),
      linePaint,
    );
    canvas.drawLine(
      Offset(w * 0.68, h * 0.14),
      Offset(w * 0.68, h * 0.86),
      linePaint,
    );
    canvas.drawLine(
      Offset(w * 0.32, h * 0.50),
      Offset(w * 0.68, h * 0.50),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ContactlessGlyph extends StatelessWidget {
  const _ContactlessGlyph();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: SizedBox(
        width: 18,
        height: 18,
        child: CustomPaint(painter: _ContactlessPainter()),
      ),
    );
  }
}

class _ContactlessPainter extends CustomPainter {
  const _ContactlessPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.65);

    final center = Offset(size.width * 0.15, size.height * 0.5);
    for (final factor in [0.28, 0.52, 0.76]) {
      final radius = size.width * factor;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 4.2,
        math.pi / 2.1,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
