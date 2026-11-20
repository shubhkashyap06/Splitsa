/// Onboarding illustrations — three small, looping, calm animations built
/// from shapes (no image assets), matching the redesign canvas:
///   split  — a bill card pops in while "who paid" chips float around it
///   settle — a swipe-to-settle pill that slides, fills, and checks itself
///   save   — a sage ring fills while a seedling sprouts two leaves
/// All of them sit on the active Day/Night palette and honour reduce-motion.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/motion.dart';

enum IllustrationType { split, settle, save }

class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({super.key, required this.type});
  final IllustrationType type;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 300,
      child: switch (type) {
        IllustrationType.split => const _SplitArt(),
        IllustrationType.settle => const _SettleArt(),
        IllustrationType.save => const _SaveArt(),
      },
    );
  }
}

/// Pops in with a springy overshoot after [delay].
class _Pop extends StatefulWidget {
  const _Pop({required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  State<_Pop> createState() => _PopState();
}

class _PopState extends State<_Pop> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    return ScaleTransition(
      scale: CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: _c, child: widget.child),
    );
  }
}

Widget _chip(
  String text, {
  required Color bg,
  required Color fg,
  Widget? lead,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      boxShadow: AppColors.cardShadow,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (lead != null) ...[lead, const SizedBox(width: 8)],
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ],
    ),
  );
}

Widget _dot(Color c, [double s = 26]) => Container(
  width: s,
  height: s,
  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
);

// ── 1. Split ─────────────────────────────────────────────────────────────

class _SplitArt extends StatelessWidget {
  const _SplitArt();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 60,
          top: 46,
          child: _Pop(
            child: Container(
              width: 180,
              height: 208,
              padding: const EdgeInsets.all(20),
              decoration: AppColors.cardDecoration(radius: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PIZZA NIGHT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .6,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹1,350',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Divider(color: AppColors.fog, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Each',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '₹450',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      _dot(const Color(0xFFF4C99A)),
                      const SizedBox(width: 6),
                      _dot(const Color(0xFFA9D3C6)),
                      const SizedBox(width: 6),
                      _dot(const Color(0xFFC9C0EE)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 18,
          child: Floating(
            amplitude: 10,
            child: _Pop(
              delay: const Duration(milliseconds: 350),
              child: _chip(
                'Aditi paid',
                bg: AppColors.card,
                fg: AppColors.textPrimary,
                lead: _dot(const Color(0xFFF4C99A), 20),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 140,
          child: Floating(
            amplitude: 8,
            phase: .4,
            rotate: .06,
            period: const Duration(seconds: 5),
            child: _Pop(
              delay: const Duration(milliseconds: 550),
              child: _chip(
                '+₹900 back',
                bg: AppColors.jadeTint,
                fg: AppColors.jadeInk,
              ),
            ),
          ),
        ),
        Positioned(
          left: 18,
          bottom: 4,
          child: Floating(
            amplitude: 9,
            phase: .7,
            child: _Pop(
              delay: const Duration(milliseconds: 750),
              child: _chip(
                'split 3 ways',
                bg: AppColors.lilacTint,
                fg: AppColors.lilacInk,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 2. Settle ────────────────────────────────────────────────────────────

class _SettleArt extends StatefulWidget {
  const _SettleArt();

  @override
  State<_SettleArt> createState() => _SettleArtState();
}

class _SettleArtState extends State<_SettleArt>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 0 → 1 → hold → 0 over one loop, eased like a thumb drag.
  double _slide(double t) {
    if (t < .12) return 0;
    if (t < .55) return Curves.easeInOutCubic.transform((t - .12) / .43);
    if (t < .8) return 1;
    return 1 - Curves.easeInOutCubic.transform((t - .8) / .2);
  }

  @override
  Widget build(BuildContext context) {
    const trackW = 268.0;
    const knob = 56.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 40,
          child: _Pop(
            child: Container(
              width: 270,
              padding: const EdgeInsets.all(22),
              decoration: AppColors.cardDecoration(radius: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You pay Aditi',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹230',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'via any UPI app',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          child: AnimatedBuilder(
            animation: _c,
            builder: (ctx, _) {
              final p = Motion.reduced(ctx) ? 0.0 : _slide(_c.value);
              final checked =
                  !Motion.reduced(ctx) && _c.value > .5 && _c.value < .82;
              return SizedBox(
                width: trackW,
                height: 64,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.fog,
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                    Positioned(
                      left: 4,
                      top: 4,
                      bottom: 4,
                      child: Container(
                        width: knob + p * (trackW - knob - 8),
                        decoration: BoxDecoration(
                          color: AppColors.marigoldTint,
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        'Swipe to settle',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 4 + p * (trackW - knob - 8),
                      top: 4,
                      child: Container(
                        width: knob,
                        height: knob,
                        decoration: BoxDecoration(
                          color: AppColors.btn,
                          shape: BoxShape.circle,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            checked
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                            key: ValueKey(checked),
                            color: AppColors.onBtn,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── 3. Save ──────────────────────────────────────────────────────────────

class _SaveArt extends StatefulWidget {
  const _SaveArt();

  @override
  State<_SaveArt> createState() => _SaveArtState();
}

class _SaveArtState extends State<_SaveArt>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Breathing(
          child: Container(
            width: 230,
            height: 230,
            decoration: BoxDecoration(
              color: AppColors.jadeTint,
              shape: BoxShape.circle,
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _c,
          builder: (ctx, _) {
            final t = Motion.reduced(ctx) ? 1.0 : _c.value;
            return CustomPaint(
              size: const Size(190, 190),
              painter: _SproutPainter(
                ring:
                    Curves.easeOutCubic.transform((t / .75).clamp(0, 1)) * .68,
                stem: Curves.easeOutBack.transform(
                  ((t - .12) / .5).clamp(0, 1),
                ),
                leafA: Curves.easeOutBack.transform(
                  ((t - .45) / .3).clamp(0, 1),
                ),
                leafB: Curves.easeOutBack.transform(
                  ((t - .55) / .3).clamp(0, 1),
                ),
                track: AppColors.fog,
                sage: AppColors.jade,
              ),
            );
          },
        ),
        Positioned(
          bottom: 6,
          child: _Pop(
            delay: const Duration(milliseconds: 1500),
            child: _chip(
              '₹340 saved this week',
              bg: AppColors.card,
              fg: AppColors.jadeInk,
            ),
          ),
        ),
      ],
    );
  }
}

class _SproutPainter extends CustomPainter {
  _SproutPainter({
    required this.ring,
    required this.stem,
    required this.leafA,
    required this.leafB,
    required this.track,
    required this.sage,
  });
  final double ring;
  final double stem;
  final double leafA;
  final double leafB;
  final Color track;
  final Color sage;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, stroke..color = track);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * ring,
      false,
      stroke..color = sage,
    );

    // Stem grows from the bottom.
    final base = c + const Offset(0, 46);
    final top = base - Offset(0, 54 * stem);
    canvas.drawLine(
      base,
      top,
      Paint()
        ..color = sage
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    void leaf(double grow, double dir, Color color, double y) {
      if (grow <= 0) return;
      final anchor = base - Offset(0, y);
      canvas.save();
      canvas.translate(anchor.dx, anchor.dy);
      canvas.scale(grow);
      final path = Path()
        ..moveTo(0, 0)
        ..cubicTo(0, -18, dir * 14, -28, dir * 32, -28)
        ..cubicTo(dir * 32, -10, dir * 18, 0, 0, 0)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
      canvas.restore();
    }

    leaf(leafA, 1, const Color(0xFF7FBFAE), 40);
    leaf(leafB, -1, const Color(0xFFA9D3C6), 28);
  }

  @override
  bool shouldRepaint(_SproutPainter old) =>
      old.ring != ring ||
      old.stem != stem ||
      old.leafA != leafA ||
      old.leafB != leafB;
}
