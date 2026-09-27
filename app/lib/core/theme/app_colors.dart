/// Design token — color palette.
/// Every color used in the app MUST come from here; no ad-hoc Color() literals
/// in widget files. Violations should be caught in code review.
///
/// Color discipline enforced (see docs/UI_UX_SPEC.md §1):
///   • [marigold]   — amounts owed TO the user, primary CTAs only
///   • [rust]       — amounts the user owes / negative balances only
///   • [jade]       — savings, Pots numbers, progress elements only
///   • Colors never used as full card/screen background fills outside Pot cards
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Backgrounds ─────────────────────────────────────────────────────────
  static const Color background = Color(0xFF000000); // true black — never tinted
  static const Color card       = Color(0xFF0A0A0B); // card surface
  static const Color cardBorder = Color(0x17FFFFFF); // 9% white hairline

  // ── Text ────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFF8A8A8E); // neutral grey, no warm tint
  static const Color textTertiary  = Color(0xFF5A5A5E);

  // ── Accents (follow the discipline above — wrong job = wrong color) ──────
  static const Color marigold = Color(0xFFF2A73B);
  static const Color rust     = Color(0xFFC1502E);
  static const Color jade     = Color(0xFF2F9E8F);

  // ── Semantic tints (Home hero card's owe/owed sub-boxes only) ───────────
  // Exception to the no-color-fill rule, scoped to exactly those two boxes.
  static const Color marigoldTint   = Color(0x14F2A73B); // 8%
  static const Color marigoldBorder = Color(0x33F2A73B); // 20%
  static const Color rustTint       = Color(0x14C1502E); // 8%
  static const Color rustBorder     = Color(0x33C1502E); // 20%
  static const Color jadeTint       = Color(0x142F9E8F); // 8%

  // ── UI elements ─────────────────────────────────────────────────────────
  static const Color white      = Color(0xFFF5F5F5);
  static const Color black      = Color(0xFF111111); // near-black for light-mode UI
  static const Color inputBg    = Color(0xFFF0F0F2); // light-mode number pad keys
  static const Color inputText  = Color(0xFF111111); // light-mode text

  // ── Tab bar ─────────────────────────────────────────────────────────────
  static const Color tabBarBg     = Color(0xCC121214); // 80% opacity black pill
  static const Color tabBarBorder = Color(0x1AFFFFFF); // 10% white

  // ── Pot card gradients (gradient fills are ONLY allowed on Pot cards) ────
  static const Color potGradientAmberStart = Color(0xFFF2A73B);
  static const Color potGradientAmberEnd   = Color(0xFFE8962A);
  static const Color potGradientJadeStart  = Color(0xFF2F9E8F);
  static const Color potGradientJadeEnd    = Color(0xFF1F7A6E);
  static const Color potGradientRustStart  = Color(0xFFE8763C);
  static const Color potGradientRustEnd    = Color(0xFFC1502E);
}
