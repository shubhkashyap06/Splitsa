import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/widgets/sheets.dart';
import '../../../recommendations/logic_engine/debt_simplifier.dart';
import '../../domain/room_ledger.dart';

/// "ⓘ Simplified" disclosure (PRODUCT_LOGIC.md §2): raw pairwise debts from
/// the feed above the simplified result, so the number is never a black box.
class SimplifiedSheet extends StatelessWidget {
  const SimplifiedSheet({
    super.key,
    required this.raw,
    required this.simplified,
    required this.nameOf,
  });

  final List<PairwiseDebt> raw;
  final List<Settlement> simplified;
  final String Function(String id) nameOf;

  static Future<void> show(
    BuildContext context, {
    required List<PairwiseDebt> raw,
    required List<Settlement> simplified,
    required String Function(String id) nameOf,
  }) => showAppSheet(
    context,
    (_) => SimplifiedSheet(raw: raw, simplified: simplified, nameOf: nameOf),
  );

  @override
  Widget build(BuildContext context) {
    final saved = raw.length - simplified.length;
    final explainer = simplified.isEmpty
        ? 'Everyone\'s even — nothing to settle.'
        : saved > 0
        ? 'Instead of ${raw.length} separate payment${raw.length == 1 ? '' : 's'}, '
              'this gets everyone even in ${simplified.length}.'
        : 'These are already the fewest payments that get everyone even.';

    return DarkSheet(
      title: 'How we got here',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(explainer, style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppSpacing.xl),
          Text('FROM THE EXPENSES', style: AppTextStyles.labelCaps),
          const SizedBox(height: AppSpacing.sm),
          if (raw.isEmpty)
            Text('No open debts.', style: AppTextStyles.bodySmall)
          else
            for (final d in raw)
              _Line(
                from: nameOf(d.fromId),
                to: nameOf(d.toId),
                paise: d.amountPaise,
                dim: true,
              ),
          const SizedBox(height: AppSpacing.xl),
          Text('SIMPLIFIED', style: AppTextStyles.labelCaps),
          const SizedBox(height: AppSpacing.sm),
          if (simplified.isEmpty)
            Text('All settled 🎉', style: AppTextStyles.bodySmall)
          else
            for (final s in simplified)
              _Line(
                from: nameOf(s.payerId),
                to: nameOf(s.payeeId),
                paise: s.amountPaise,
              ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.from,
    required this.to,
    required this.paise,
    this.dim = false,
  });
  final String from;
  final String to;
  final int paise;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.bodyMedium.copyWith(
      color: dim ? AppColors.textSecondary : AppColors.textPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$from → $to',
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            formatPaise(paise),
            style: AppTextStyles.moneyList(
              color: dim ? AppColors.textSecondary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
