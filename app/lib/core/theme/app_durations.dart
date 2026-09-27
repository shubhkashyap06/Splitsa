/// Design token — animation durations and curves.
///
/// Every animated widget uses values from here so the motion system
/// stays consistent with the spec (docs/UI_UX_SPEC.md §5).
library;

import 'package:flutter/animation.dart';

abstract final class AppDurations {
  static const Duration veryFast = Duration(milliseconds: 120);
  static const Duration fast     = Duration(milliseconds: 200);
  static const Duration normal   = Duration(milliseconds: 300);
  static const Duration slow     = Duration(milliseconds: 450);
  static const Duration verySlow = Duration(milliseconds: 600);

  /// Used for bottom sheet spring entrance
  static const Duration sheetEntrance = Duration(milliseconds: 380);

  /// Odometer/money roll animation
  static const Duration moneyRoll = Duration(milliseconds: 900);

  /// Confetti burst after settle-up success
  static const Duration confetti = Duration(milliseconds: 1400);
}

abstract final class AppCurves {
  /// iOS spring-style ease — matches motion/react's [0.16, 1, 0.3, 1] cubic-bezier
  static const Curve springy    = Cubic(0.16, 1.0, 0.3, 1.0);

  /// Slightly bouncier — for tab bar bubble slide and card fan-out
  static const Curve bounce     = Cubic(0.34, 1.56, 0.64, 1.0);

  /// Standard ease for text/opacity fades
  static const Curve easeOut    = Curves.easeOut;
  static const Curve linear     = Curves.linear;
}
