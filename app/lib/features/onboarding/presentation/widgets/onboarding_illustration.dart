/// Onboarding illustrations — simple, clean Flutter CustomPaint illustrations.
/// No image assets needed; drawn entirely with Flutter primitives.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

enum IllustrationType { split, settle, save }

class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({super.key, required this.type});
  final IllustrationType type;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: CustomPaint(
        painter: switch (type) {
          IllustrationType.split  => _SplitPainter(),
          IllustrationType.settle => _SettlePainter(),
          IllustrationType.save   => _SavePainter(),
        },
      ),
    );
  }
}

// ── Split illustration ────────────────────────────────────────────────────────
// Three overlapping circles (avatars) with a receipt card between them
class _SplitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Background glow
    final glowPaint = Paint()
      ..color = AppColors.marigold.withOpacity(0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    canvas.drawCircle(Offset(cx, cy), 100, glowPaint);

    // Receipt card
    final cardPaint = Paint()..color = const Color(0xFF0A0A0B);
    final cardBorderPaint = Paint()
      ..color = AppColors.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 130, height: 160),
      const Radius.circular(20),
    );
    canvas.drawRRect(cardRect, cardPaint);
    canvas.drawRRect(cardRect, cardBorderPaint);

    // Lines on the receipt
    final linePaint = Paint()
      ..color = AppColors.cardBorder
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final y = cy - 40 + i * 22.0;
      canvas.drawLine(Offset(cx - 45, y), Offset(cx + 20, y), linePaint);
      // Amount dots on right
      final dotPaint = Paint()..color = AppColors.marigold.withOpacity(0.5 + i * 0.12);
      canvas.drawLine(Offset(cx + 28, y), Offset(cx + 48, y), dotPaint..strokeWidth = 2);
    }

    // Three avatar circles
    const avatarColors = [AppColors.marigold, Color(0xFF7A86FF), AppColors.jade];
    const positions = [
      Offset(-55, -65),
      Offset(55, -65),
      Offset(0, 85),
    ];
    final avatarPaint = Paint();
    for (int i = 0; i < 3; i++) {
      avatarPaint.color = avatarColors[i].withOpacity(0.9);
      canvas.drawCircle(Offset(cx + positions[i].dx, cy + positions[i].dy), 22, avatarPaint);
      avatarPaint
        ..color = Colors.black.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(cx + positions[i].dx, cy + positions[i].dy), 22, avatarPaint);
      avatarPaint
        ..style = PaintingStyle.fill
        ..color = avatarColors[i];
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Settle illustration ───────────────────────────────────────────────────────
// UPI arrow swoosh from one avatar to another
class _SettlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final glowPaint = Paint()
      ..color = AppColors.jade.withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    canvas.drawCircle(Offset(cx, cy), 90, glowPaint);

    // From avatar
    final fromPaint = Paint()..color = AppColors.rust.withOpacity(0.8);
    canvas.drawCircle(Offset(cx - 70, cy), 26, fromPaint);

    // To avatar
    final toPaint = Paint()..color = AppColors.marigold.withOpacity(0.9);
    canvas.drawCircle(Offset(cx + 70, cy), 26, toPaint);

    // Curved arrow
    final arrowPath = Path()
      ..moveTo(cx - 44, cy)
      ..cubicTo(cx - 10, cy - 40, cx + 10, cy - 40, cx + 44, cy);

    final arrowPaint = Paint()
      ..color = AppColors.marigold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(arrowPath, arrowPaint);

    // Arrowhead
    final headPaint = Paint()..color = AppColors.marigold;
    final headPath = Path()
      ..moveTo(cx + 50, cy)
      ..lineTo(cx + 40, cy - 7)
      ..lineTo(cx + 40, cy + 7)
      ..close();
    canvas.drawPath(headPath, headPaint);

    // Amount chip
    final chipPaint = Paint()..color = AppColors.marigold.withOpacity(0.15);
    final chipBorderPaint = Paint()
      ..color = AppColors.marigold.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final chipRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 50), width: 80, height: 30),
      const Radius.circular(15),
    );
    canvas.drawRRect(chipRect, chipPaint);
    canvas.drawRRect(chipRect, chipBorderPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: '₹230',
        style: TextStyle(color: AppColors.marigold, fontSize: 14, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(cx - textPainter.width / 2, cy + 50 - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Save illustration ─────────────────────────────────────────────────────────
// Abstract ascending-arc progress ring (not a piggy bank — per spec)
class _SavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Background ring
    final bgPaint = Paint()
      ..color = AppColors.jade.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: 140, height: 140),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    // Progress arc (62%)
    final progressPaint = Paint()
      ..color = AppColors.jade
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: 140, height: 140),
      math.pi * 0.75,
      math.pi * 1.5 * 0.62,
      false,
      progressPaint,
    );

    // Traveling spark at arc tip
    final sparkAngle = math.pi * 0.75 + math.pi * 1.5 * 0.62;
    final sparkX = cx + 70 * math.cos(sparkAngle);
    final sparkY = cy + 70 * math.sin(sparkAngle);
    final sparkPaint = Paint()
      ..color = AppColors.jade
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(sparkX, sparkY), 6, sparkPaint);

    // Center text (62%)
    final textPainter = TextPainter(
      text: const TextSpan(
        children: [
          TextSpan(
            text: '62%',
            style: TextStyle(color: AppColors.jade, fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(cx - textPainter.width / 2, cy - textPainter.height / 2));

    // Label below
    final labelPainter = TextPainter(
      text: const TextSpan(
        text: 'there',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(canvas, Offset(cx - labelPainter.width / 2, cy + 16));
  }

  @override
  bool shouldRepaint(_) => false;
}
