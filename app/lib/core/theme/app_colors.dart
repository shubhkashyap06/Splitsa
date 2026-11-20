/// Design tokens — colour, for both the Day and Night themes.
///
/// Every colour comes from here; widgets never hard-code a hex value.
/// `AppColors.x` reads from the active [SplitsaPalette], which the app root
/// swaps when the theme changes (and rebuilds the tree), so the same call
/// site paints correctly in both themes. See docs/UI_UX_SPEC.md §1.
///
/// Colour discipline — each accent has exactly one job:
///   • [marigold] (apricot)    — money owed TO the user
///   • [rust]     (terracotta) — money the user owes / negative balances
///   • [jade]     (sage)       — savings, Pots, progress
///   • lilac / sky             — decoration only, never money
library;

import 'package:flutter/material.dart';

class SplitsaPalette {
  const SplitsaPalette({
    required this.brightness,
    required this.background,
    required this.card,
    required this.cardBorder,
    required this.fog,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.btn,
    required this.onBtn,
    required this.marigold,
    required this.marigoldInk,
    required this.marigoldTint,
    required this.rust,
    required this.rustInk,
    required this.rustTint,
    required this.jade,
    required this.jadeInk,
    required this.jadeTint,
    required this.lilacTint,
    required this.lilacInk,
    required this.skyTint,
    required this.skyInk,
    required this.glass,
    required this.glow,
    required this.cardShadow,
  });

  final Brightness brightness;
  final Color background;
  final Color card;
  final Color cardBorder;
  final Color fog;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color btn;
  final Color onBtn;
  final Color marigold;
  final Color marigoldInk;
  final Color marigoldTint;
  final Color rust;
  final Color rustInk;
  final Color rustTint;
  final Color jade;
  final Color jadeInk;
  final Color jadeTint;
  final Color lilacTint;
  final Color lilacInk;
  final Color skyTint;
  final Color skyInk;
  final Color glass;
  final Color glow;
  final List<BoxShadow> cardShadow;

  /// Day — warm mist, white cards, soft shadows.
  static const day = SplitsaPalette(
    brightness: Brightness.light,
    background: Color(0xFFF5F3EE),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0x0A17171A),
    fog: Color(0xFFECEAE4),
    textPrimary: Color(0xFF17171A),
    textSecondary: Color(0xFF5F5F66),
    textTertiary: Color(0xFF75757C),
    btn: Color(0xFF17171A),
    onBtn: Color(0xFFFFFFFF),
    marigold: Color(0xFF95590B),
    marigoldInk: Color(0xFF7A4A0C),
    marigoldTint: Color(0xFFFBEBD6),
    rust: Color(0xFFA9452C),
    rustInk: Color(0xFF8A3A26),
    rustTint: Color(0xFFFBE6DE),
    jade: Color(0xFF2F7D6D),
    jadeInk: Color(0xFF235F53),
    jadeTint: Color(0xFFDCEEE8),
    lilacTint: Color(0xFFE9E4F8),
    lilacInk: Color(0xFF4A3F86),
    skyTint: Color(0xFFDCEAF7),
    skyInk: Color(0xFF2C5C8A),
    glass: Color(0xC7FFFFFF),
    glow: Color(0xFFF6D7B4),
    cardShadow: [
      BoxShadow(color: Color(0x0A17171A), blurRadius: 1, offset: Offset(0, 1)),
      BoxShadow(
        color: Color(0x0F17171A),
        blurRadius: 40,
        offset: Offset(0, 18),
      ),
    ],
  );

  /// Night — deep charcoal (not pure black), lifted cards, softened accents.
  static const night = SplitsaPalette(
    brightness: Brightness.dark,
    background: Color(0xFF0F0F12),
    card: Color(0xFF1A1A1F),
    cardBorder: Color(0x14FFFFFF),
    fog: Color(0xFF26262C),
    textPrimary: Color(0xFFF2F1EC),
    textSecondary: Color(0xFFA9A9B1),
    textTertiary: Color(0xFF8E8E96),
    btn: Color(0xFFF2F1EC),
    onBtn: Color(0xFF121214),
    marigold: Color(0xFFF2B66D),
    marigoldInk: Color(0xFFE8C9A0),
    marigoldTint: Color(0x24F2B66D),
    rust: Color(0xFFF29A80),
    rustInk: Color(0xFFEBB5A5),
    rustTint: Color(0x24F08A6E),
    jade: Color(0xFF6CC4AE),
    jadeInk: Color(0xFFA8DDD0),
    jadeTint: Color(0x246CC4AE),
    lilacTint: Color(0x29B4A8F0),
    lilacInk: Color(0xFFC9C0F2),
    skyTint: Color(0x247AAADC),
    skyInk: Color(0xFFA8C8EA),
    glass: Color(0xB81C1C21),
    glow: Color(0xFF3B3466),
    cardShadow: [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 40,
        offset: Offset(0, 18),
      ),
    ],
  );
}

abstract final class AppColors {
  /// Set by the app root before each build of the tree (see main.dart).
  static SplitsaPalette current = SplitsaPalette.day;

  static bool get isNight => current.brightness == Brightness.dark;

  // ── Surfaces ──────────────────────────────────────────────────────────
  static Color get background => current.background;
  static Color get card => current.card;
  static Color get cardBorder => current.cardBorder;
  static Color get fog => current.fog;
  static List<BoxShadow> get cardShadow => current.cardShadow;
  static Color get glow => current.glow;

  // ── Text ──────────────────────────────────────────────────────────────
  static Color get textPrimary => current.textPrimary;
  static Color get textSecondary => current.textSecondary;
  static Color get textTertiary => current.textTertiary;

  // ── Buttons (the one solid pill: ink in Day, cream in Night) ──────────
  static Color get btn => current.btn;
  static Color get onBtn => current.onBtn;

  // ── Money accents (names kept from v1 so call sites stay readable) ────
  static Color get marigold => current.marigold;
  static Color get marigoldInk => current.marigoldInk;
  static Color get marigoldTint => current.marigoldTint;
  static Color get marigoldBorder => current.marigoldTint;
  static Color get rust => current.rust;
  static Color get rustInk => current.rustInk;
  static Color get rustTint => current.rustTint;
  static Color get rustBorder => current.rustTint;
  static Color get jade => current.jade;
  static Color get jadeInk => current.jadeInk;
  static Color get jadeTint => current.jadeTint;

  // ── Decoration only ───────────────────────────────────────────────────
  static Color get lilacTint => current.lilacTint;
  static Color get lilacInk => current.lilacInk;
  static Color get skyTint => current.skyTint;
  static Color get skyInk => current.skyInk;

  // ── Legacy aliases (v1 call sites) ────────────────────────────────────
  static Color get white => current.btn;
  static Color get black => current.onBtn;
  static Color get inputBg => current.card;
  static Color get inputText => current.textPrimary;
  static Color get tabBarBg => current.glass;
  static Color get tabBarBorder => current.cardBorder;

  // ── Pot card gradients (gradients live ONLY on Pot cards) ─────────────
  static const Color potGradientAmberStart = Color(0xFFF4B979);
  static const Color potGradientAmberEnd = Color(0xFFE8925A);
  static const Color potGradientJadeStart = Color(0xFF7FBFAE);
  static const Color potGradientJadeEnd = Color(0xFF2F7D6D);
  static const Color potGradientRustStart = Color(0xFFB9B0EC);
  static const Color potGradientRustEnd = Color(0xFF8E84D6);

  /// The standard soft card: rounded, shadowed in Day, hairlined in Night.
  static BoxDecoration cardDecoration({double radius = 24, Color? color}) =>
      BoxDecoration(
        color: color ?? card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: cardBorder),
        boxShadow: cardShadow,
      );
}
