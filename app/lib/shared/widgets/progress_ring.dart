/// ProgressRing — jade circular progress ring with elastic fill + traveling spark.
///
/// Ported from the reference prototype's ProgressRing component (ui.tsx).
/// Used on the Savings & Pots screen for the "Your Potli" personal goal.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_durations.dart';

class ProgressRing extends StatefulWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 116.0,
    this.color = AppColors.jade,
    this.strokeWidth = 9.0,
    this.child,
  });

  /// 0–100
  final double progress;
  final double size;
  final Color color;
  final double strokeWidth;
  final Widget? child;

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progress = Tween<double>(begin: 0, end: widget.progress.clamp(0, 100))
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(ProgressRing old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      _progress = Tween<double>(begin: _progress.value, end: widget.progress.clamp(0, 100))
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, child) => CustomPaint(
          painter: _RingPainter(
            progress: _progress.value,
            color: widget.color,
            strokeWidth: widget.strokeWidth,
          ),
          child: child,
        ),
        child: widget.child != null
            ? Center(child: widget.child)
            : null,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center  = Offset(size.width / 2, size.height / 2);
    final radius  = (size.width - strokeWidth) / 2;
    const startAngle = -math.pi / 2; // 12 o'clock

    // Background track
    final trackPaint = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final sweep = 2 * math.pi * (progress / 100);
    if (sweep > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        progressPaint,
      );

      // Traveling spark at the arc's leading edge
      final sparkAngle = startAngle + sweep;
      final sparkX = center.dx + radius * math.cos(sparkAngle);
      final sparkY = center.dy + radius * math.sin(sparkAngle);
      final sparkPaint = Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(sparkX, sparkY), strokeWidth * 0.6, sparkPaint);
      // Solid center on top of glow
      canvas.drawCircle(Offset(sparkX, sparkY), strokeWidth * 0.35, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
