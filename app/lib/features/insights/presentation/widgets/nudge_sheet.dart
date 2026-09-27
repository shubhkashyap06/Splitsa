import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../recommendations/recommendation_models.dart';

/// Savings nudge bottom sheet — shows a savings recommendation
/// from the RecommendationEngine (v1: LogicRecommendationEngine).
class NudgeSheet extends StatelessWidget {
  const NudgeSheet({super.key, required this.nudge});
  final SavingsNudge nudge;

  static Future<void> show(BuildContext context, SavingsNudge nudge) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NudgeSheet(nudge: nudge),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountRupees = (nudge.recommendedAmountPaise / 100).round();
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');
    final formattedAmount = currencyFormat.format(amountRupees);

    final personaLabel = switch (nudge.persona) {
      SpendPersona.weekendSpender => 'Weekend Spender 🎈',
      SpendPersona.bulkBuyer => 'Bulk Buyer 🛒',
      SpendPersona.consistent => 'Steady Spender 📊',
      SpendPersona.highFixedCost => 'Fixed-Cost Heavy 🏠',
      SpendPersona.coldStart => 'New User ✨',
    };

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0B),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.xxxl),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Persona badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2F9E8F).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                "You're a $personaLabel",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2F9E8F),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Subtext from nudge
            Text(
              nudge.subtext,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF8A8A8E)),
            ),

            const SizedBox(height: AppSpacing.md),

            Text(
              nudge.headline,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFFF5F5F5)),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Big amount
            Text(
              formattedAmount,
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2F9E8F),
              ),
            ),

            const SizedBox(height: AppSpacing.xxxl),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      // Accept nudge — move to pot
                      context.pop();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2F9E8F),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                    child: const Text('Move it', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF5F5F5),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                    child: const Text('Not now, bestie', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
