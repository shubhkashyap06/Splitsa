/// Design token — typography scale.
///
/// All text styles use system-default San Francisco on iOS/web and Roboto on
/// Android — no custom font bundle required (matches the spec's "body copy
/// stays close to system-default San Francisco sizing").
///
/// Numbers/amounts use tabular figures via FontFeature.tabularFigures().
library;

import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTextStyles {
  // ── Hero money numerals ─────────────────────────────────────────────────
  static TextStyle moneyHero({Color color = AppColors.textPrimary}) => TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w800,
    color: color,
    height: 1.0,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle moneyCurrency({Color color = AppColors.textPrimary}) => TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.0,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle moneyDecimal({Color color = AppColors.textSecondary}) => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: color.withOpacity(0.55),
    height: 1.0,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  // ── Money amounts in lists ───────────────────────────────────────────────
  static TextStyle moneyList({Color color = AppColors.marigold}) => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  // ── Page titles ─────────────────────────────────────────────────────────
  static const TextStyle titleLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  // ── Body ────────────────────────────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySemibold = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // ── Labels ──────────────────────────────────────────────────────────────
  /// Small-caps / all-caps label above hero numbers
  static const TextStyle labelCaps = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.8,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  // ── Buttons ─────────────────────────────────────────────────────────────
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );
}
