import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/widgets/sheets.dart';
import '../../../pots/presentation/widgets/contribute_sheet.dart';
import '../../../pots/presentation/widgets/create_pot_sheet.dart';
import '../../../recommendations/recommendation_models.dart';
import '../../application/insights_providers.dart';

/// Savings nudge ("Potli Pick") sheet. Computed by the local logic engine
/// (PRODUCT_LOGIC.md §3) — works offline on both platforms, no "ML" claim.
class NudgeSheet extends ConsumerWidget {
  const NudgeSheet({super.key, required this.nudge});
  final SavingsNudge nudge;

  static Future<void> show(BuildContext context, SavingsNudge nudge) =>
      showAppSheet(context, (_) => NudgeSheet(nudge: nudge));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(nudgeTargetPotProvider);

    return TweenAnimationBuilder<double>(
      // Rubber-band spring entrance.
      tween: Tween(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.elasticOut,
      builder: (ctx, s, child) => Transform.scale(
        scale: s,
        alignment: Alignment.bottomCenter,
        child: child,
      ),
      child: DarkSheet(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.jade.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                "You're a ${personaLabel(nudge.persona)}",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.jade,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              nudge.headline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              nudge.subtext,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              formatPaise(nudge.recommendedAmountPaise),
              style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w800,
                color: AppColors.jade,
              ),
            ),
            if (target != null)
              Text(
                '→ ${target.name}',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            const SizedBox(height: AppSpacing.xxxl),
            PillButton(
              label: target == null ? 'Start a pot for it' : 'Move it',
              color: AppColors.jade,
              foreground: AppColors.onBtn,
              onPressed: () {
                final root = Navigator.of(context, rootNavigator: true).context;
                Navigator.of(context).pop();
                if (target == null) {
                  CreatePotSheet.show(root, personal: true);
                } else {
                  ContributeSheet.show(
                    root,
                    potId: target.id,
                    initialAmountPaise: nudge.recommendedAmountPaise,
                  );
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinePillButton(
              label: 'Not now, bestie',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
