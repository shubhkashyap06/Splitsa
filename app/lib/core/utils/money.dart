import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';

final _rupees0 = NumberFormat.currency(
  symbol: '₹',
  decimalDigits: 0,
  locale: 'en_IN',
);
final _rupees2 = NumberFormat.currency(
  symbol: '₹',
  decimalDigits: 2,
  locale: 'en_IN',
);

/// ₹1,23,450 — whole rupees unless there are paise, then ₹1,234.50.
String formatPaise(int paise, {bool forceDecimals = false}) {
  final abs = paise.abs();
  final text = (forceDecimals || abs % 100 != 0)
      ? _rupees2.format(abs / 100)
      : _rupees0.format(abs ~/ 100);
  return paise < 0 ? '−$text' : text;
}

/// Parses user-typed rupees ("230", "230.5", "1,200") into paise.
/// Returns null for anything that isn't a non-negative amount.
int? parseRupeesToPaise(String raw) {
  final cleaned = raw.replaceAll(',', '').replaceAll('₹', '').trim();
  if (cleaned.isEmpty) return null;
  final match = RegExp(r'^\d{1,9}(\.\d{0,2})?$').firstMatch(cleaned);
  if (match == null) return null;
  final parts = cleaned.split('.');
  final whole = int.parse(parts[0]);
  final frac = parts.length > 1 ? parts[1].padRight(2, '0') : '00';
  return whole * 100 + int.parse(frac.isEmpty ? '0' : frac);
}

final _indianGrouping = NumberFormat.decimalPattern('en_IN');

/// Groups a half-typed rupee amount for display while keeping what the user
/// typed after the dot: "11464" → "11,464", "1200." → "1,200.", "" → "0".
String groupRupeeInput(String raw) {
  if (raw.isEmpty) return '0';
  final dot = raw.indexOf('.');
  final whole = dot < 0 ? raw : raw.substring(0, dot);
  final grouped = whole.isEmpty
      ? '0'
      : _indianGrouping.format(int.tryParse(whole) ?? 0);
  return dot < 0 ? grouped : '$grouped${raw.substring(dot)}';
}

/// Stable per-person avatar tone, so "Aditi" is the same color everywhere.
Color toneFor(String id) {
  final tones = [
    AppColors.marigold,
    AppColors.jade,
    AppColors.rust,
    Color(0xFF7A86FF),
    Color(0xFFB98AE0),
    Color(0xFF8A8A8E),
  ];
  var h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return tones[h % tones.length];
}

/// Category key → icon, shared by every feed/list.
IconData categoryIcon(String key) => switch (key) {
  'food' => Icons.restaurant,
  'travel' => Icons.flight,
  'home' || 'rent' || 'electricity' || 'wifi' || 'gas' => Icons.home,
  'entertainment' => Icons.celebration,
  'health' => Icons.favorite,
  'shopping' => Icons.shopping_bag,
  _ => Icons.receipt_long,
};

String categoryLabel(String key) => switch (key) {
  'food' => 'Food & Drinks',
  'travel' => 'Travel',
  'home' => 'Home',
  'rent' => 'Rent',
  'electricity' => 'Electricity',
  'wifi' => 'WiFi',
  'gas' => 'Gas',
  'subscriptions' => 'Subscriptions',
  'entertainment' => 'Fun',
  'health' => 'Health',
  'shopping' => 'Shopping',
  _ => 'Other',
};

/// "Today", "Yesterday", "Fri", "12 Sep".
String relativeDay(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return DateFormat.E().format(d);
  return DateFormat('d MMM').format(d);
}
