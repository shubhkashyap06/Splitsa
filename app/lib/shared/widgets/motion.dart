/// Motion kit — the app's shared animation vocabulary (UI_UX_SPEC.md §5).
///
///   Press   — tap targets spring to 96%, overshoot, settle
///   Rise    — content fades up into place, staggered by index
///   Float   — idle decorative bob (empty states, onboarding chips)
///   Breathe — slow scale pulse for savings/progress surfaces
///
/// All of them respect the OS "reduce motion" setting.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

abstract final class Motion {
  /// Soft spring with a touch of overshoot — sheets, cards, presses.
  static const Curve spring = Cubic(0.2, 0.8, 0.2, 1.06);
  static const Curve settle = Cubic(0.2, 0.8, 0.2, 1);
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 420);
  static const Duration slow = Duration(milliseconds: 700);

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Scales its child to 96% while pressed and springs back on release.
class PressSpring extends StatefulWidget {
  const PressSpring({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
  });
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<PressSpring> createState() => _PressSpringState();
}

class _PressSpringState extends State<PressSpring> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: _down ? Motion.quick : Motion.medium,
          curve: _down ? Curves.easeOut : Motion.spring,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Fades + slides its child up into place, delayed by [index] × 60ms.
class RiseIn extends StatefulWidget {
  const RiseIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 18,
  });
  final Widget child;
  final int index;
  final double offset;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Motion.slow);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: 60 * widget.index), () {
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
    final t = CurvedAnimation(parent: _c, curve: Motion.settle);
    return AnimatedBuilder(
      animation: t,
      builder: (ctx, child) => Opacity(
        opacity: t.value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - t.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Gentle idle bob — decoration only, never on something you read.
class Floating extends StatefulWidget {
  const Floating({
    super.key,
    required this.child,
    this.amplitude = 6,
    this.period = const Duration(seconds: 4),
    this.phase = 0,
    this.rotate = 0,
  });
  final Widget child;
  final double amplitude;
  final Duration period;

  /// 0–1 offset so neighbouring floaters don't move in lockstep.
  final double phase;

  /// Max tilt in radians (0 = no tilt).
  final double rotate;

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period)
    ..value = widget.phase
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (ctx, child) {
        final s = math.sin(_c.value * 2 * math.pi);
        return Transform.translate(
          offset: Offset(0, -widget.amplitude * s),
          child: Transform.rotate(angle: widget.rotate * s, child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Slow scale pulse (1.0 ↔ 1+[depth]) for savings and progress.
class Breathing extends StatefulWidget {
  const Breathing({
    super.key,
    required this.child,
    this.depth = 0.06,
    this.period = const Duration(seconds: 4),
  });
  final Widget child;
  final double depth;
  final Duration period;

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period)
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    return ScaleTransition(
      scale: Tween(
        begin: 1.0,
        end: 1 + widget.depth,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

/// Soft blurred colour blob that drifts slowly behind content.
class GlowBlob extends StatelessWidget {
  const GlowBlob({
    super.key,
    required this.color,
    this.size = 280,
    this.opacity = 0.45,
  });
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Floating(
        amplitude: 12,
        period: const Duration(seconds: 12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
