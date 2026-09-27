/// MoneyText — animated odometer widget for money amounts.
///
/// When [value] changes, digits roll from old → new rather than snapping.
/// Matches the reference prototype's animated Money component (ui.tsx).
///
/// Layout: ₹{whole}.{decimals} where the ₹ symbol and decimal part are
/// rendered smaller and lighter than the whole number — per the spec's
/// "₹7,854.43" style.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_durations.dart';

class MoneyText extends StatefulWidget {
  const MoneyText({
    super.key,
    required this.valueInPaise,
    this.color = AppColors.textPrimary,
    this.heroSize = 44.0,
    this.showDecimals = true,
    this.showSign = false,
  });

  /// Amount in paise (₹ × 100).
  final int valueInPaise;
  final Color color;

  /// Font size for the whole-rupee part. ₹ symbol is 62%, decimals 42%.
  final double heroSize;
  final bool showDecimals;

  /// Prepends + for positive values (for balance displays).
  final bool showSign;

  @override
  State<MoneyText> createState() => _MoneyTextState();
}

class _MoneyTextState extends State<MoneyText> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _animation;
  late double _from;
  late double _to;

  @override
  void initState() {
    super.initState();
    _from = widget.valueInPaise / 100.0;
    _to   = _from;
    _ctrl = AnimationController(vsync: this, duration: AppDurations.moneyRoll);
    _animation = Tween<double>(begin: _from, end: _to)
        .animate(CurvedAnimation(parent: _ctrl, curve: AppCurves.springy));
  }

  @override
  void didUpdateWidget(MoneyText old) {
    super.didUpdateWidget(old);
    if (old.valueInPaise != widget.valueInPaise) {
      _from = _animation.value;
      _to   = widget.valueInPaise / 100.0;
      _animation = Tween<double>(begin: _from, end: _to)
          .animate(CurvedAnimation(parent: _ctrl, curve: AppCurves.springy));
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

  static final _inr = NumberFormat('#,##,##0', 'en_IN');

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final total     = _animation.value;
        final negative  = total < 0;
        final abs       = total.abs();
        final whole     = abs.floor();
        final decimals  = ((abs - whole) * 100).round();
        final sign      = widget.showSign && !negative ? '+' : (negative ? '−' : '');

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // ₹ symbol
            Text(
              '${sign}₹',
              style: AppTextStyles.moneyCurrency(color: widget.color)
                  .copyWith(fontSize: widget.heroSize * 0.62),
            ),
            // Whole number
            Text(
              _inr.format(whole),
              style: AppTextStyles.moneyHero(color: widget.color)
                  .copyWith(fontSize: widget.heroSize),
            ),
            // Decimals
            if (widget.showDecimals)
              Text(
                '.${decimals.toString().padLeft(2, '0')}',
                style: AppTextStyles.moneyDecimal(color: widget.color)
                    .copyWith(fontSize: widget.heroSize * 0.42),
              ),
          ],
        );
      },
    );
  }
}

/// Compact money chip — for balance chips in room cards and settlement rows.
/// Non-animated (static display, no odometer).
class MoneyChip extends StatelessWidget {
  const MoneyChip({
    super.key,
    required this.amountPaise,
    this.showSign = true,
  });

  final int amountPaise;
  final bool showSign;

  static final _inr = NumberFormat('#,##,##0', 'en_IN');

  @override
  Widget build(BuildContext context) {
    final positive = amountPaise >= 0;
    final color    = amountPaise == 0
        ? AppColors.textSecondary
        : positive ? AppColors.marigold : AppColors.rust;
    final abs      = amountPaise.abs();
    final rupees   = abs ~/ 100;
    final sign     = showSign
        ? (amountPaise == 0 ? '' : positive ? '+' : '−')
        : '';

    return Text(
      '${sign}₹${_inr.format(rupees)}',
      style: AppTextStyles.moneyList(color: color),
    );
  }
}
