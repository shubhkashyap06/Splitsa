/// Design token — typography scale.
///
/// Plus Jakarta Sans everywhere (set as the theme font in app_theme.dart, so
/// these styles inherit it). Colours read from the active Day/Night palette.
///
/// Numbers/amounts use tabular figures via FontFeature.tabularFigures().
library;

import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTextStyles {
  // ── Hero money numerals ─────────────────────────────────────────────────
  static TextStyle moneyHero({Color? color}) => TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.6,
    color: color ?? AppColors.textPrimary,
    height: 1.0,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle moneyCurrency({Color? color}) => TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: color ?? AppColors.textPrimary,
    height: 1.0,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle moneyDecimal({Color? color}) => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: (color ?? AppColors.textSecondary).withValues(alpha: 0.55),
    height: 1.0,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  // ── Money amounts in lists ───────────────────────────────────────────────
  static TextStyle moneyList({Color? color}) => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: color ?? AppColors.marigold,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  // ── Page titles ─────────────────────────────────────────────────────────
  static TextStyle get titleLarge => TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get titleMedium => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static TextStyle get titleSmall => TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  // ── Body ────────────────────────────────────────────────────────────────
  static TextStyle get bodyLarge => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodySemibold => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyMedium => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle get bodySmall => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // ── Labels ──────────────────────────────────────────────────────────────
  /// Small-caps / all-caps label above hero numbers
  static TextStyle get labelCaps => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.8,
  );

  static TextStyle get labelSmall => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  // ── Buttons ─────────────────────────────────────────────────────────────
  static TextStyle get button =>
      TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.1);

  static TextStyle get buttonSmall =>
      TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1);
}
