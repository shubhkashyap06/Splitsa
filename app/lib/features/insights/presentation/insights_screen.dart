import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/icon_badge.dart';
import '../../recommendations/recommendation_models.dart';
import '../application/insights_providers.dart';
import 'widgets/nudge_sheet.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(insightsProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            120,
          ),
          children: [
            Text('Insights', style: AppTextStyles.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Your last four weeks, at a glance',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xxl),
            if (data == null)
              const SizedBox(height: 200)
            else ...[
              _PersonaCard(data: data),
              if (data.nudge != null) ...[
                const SizedBox(height: AppSpacing.md),
                _NudgeRow(nudge: data.nudge!),
              ],
              const SizedBox(height: AppSpacing.xxl),
              _WeeklyTrend(data: data),
              const SizedBox(height: AppSpacing.xxl),
              _Categories(totals: data.features.categoryTotalsPaise),
            ],
          ],
        ),
      ),
    );
  }
}

class _PersonaCard extends StatelessWidget {
  const _PersonaCard({required this.data});
  final InsightsData data;

  IconData get _icon => switch (data.persona) {
    SpendPersona.weekendSpender => Icons.celebration,
    SpendPersona.bulkBuyer => Icons.shopping_cart,
    SpendPersona.consistent => Icons.timeline,
    SpendPersona.highFixedCost => Icons.home,
    SpendPersona.coldStart => Icons.spa_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: AppColors.cardShadow,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(icon: _icon, tone: AppColors.marigold, size: 46),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR PERSONA',
                        style: AppTextStyles.labelCaps.copyWith(fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        personaLabel(data.persona),
                        style: AppTextStyles.titleSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              personaExplainer(data.persona, data.features),
              style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single soft light sweep across the card on first build.
class _Shimmer extends StatelessWidget {
  const _Shimmer({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -1, end: 2),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeInOut,
      builder: (ctx, t, c) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment(t - 1, -0.3),
          end: Alignment(t, 0.3),
          colors: [
            Colors.transparent,
            AppColors.textPrimary.withValues(alpha: 0.06),
            Colors.transparent,
          ],
        ).createShader(rect),
        child: c,
      ),
      child: child,
    );
  }
}

class _NudgeRow extends StatelessWidget {
  const _NudgeRow({required this.nudge});
  final SavingsNudge nudge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => NudgeSheet.show(context, nudge),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: AppColors.cardShadow,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            IconBadge(icon: Icons.auto_awesome, tone: AppColors.jade, size: 38),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Potli Pick · ${formatPaise(nudge.recommendedAmountPaise)}',
                    style: AppTextStyles.bodySemibold,
                  ),
                  Text(nudge.headline, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _WeeklyTrend extends StatelessWidget {
  const _WeeklyTrend({required this.data});
  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    final weeks = data.weeklyTrendOldestFirst;
    final maxSpend = weeks.fold<int>(0, (m, v) => v > m ? v : m);
    final wow = data.weekOverWeek;
    const labels = ['3w ago', '2w ago', 'Last wk', 'This wk'];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.cardShadow,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SPENT THIS WEEK',
                    style: AppTextStyles.labelCaps.copyWith(fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatPaise(data.thisWeekPaise),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (wow != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '${wow <= 0 ? '↓' : '↑'} ${(wow.abs() * 100).round()}% vs last',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (maxSpend == 0)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'No spends logged yet — they\'ll chart here.',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < weeks.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                // Bars grow up from the baseline on load.
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    begin: 0,
                                    end: (weeks[i] / maxSpend).clamp(0.02, 1.0),
                                  ),
                                  duration: Duration(
                                    milliseconds: 600 + i * 80,
                                  ),
                                  curve: Curves.easeOutCubic,
                                  builder: (ctx, h, _) => FractionallySizedBox(
                                    heightFactor: h,
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: i == weeks.length - 1
                                            ? AppColors.marigold
                                            : AppColors.textPrimary.withValues(
                                                alpha: 0.12,
                                              ),
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              i < labels.length ? labels[i] : '',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: i == weeks.length - 1
                                    ? AppColors.marigold
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories({required this.totals});
  final Map<String, int> totals;

  @override
  Widget build(BuildContext context) {
    final entries = totals.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sum = entries.fold<int>(0, (s, e) => s + e.value);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.cardShadow,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where it went', style: AppTextStyles.titleSmall),
          const SizedBox(height: AppSpacing.lg),
          if (entries.isEmpty)
            const EmptyStateLine()
          else
            for (final e in entries.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconBadge(
                          icon: categoryIcon(e.key),
                          tone: AppColors.textSecondary,
                          size: 32,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            categoryLabel(e.key),
                            style: AppTextStyles.bodySemibold,
                          ),
                        ),
                        Text(
                          formatPaise(e.value),
                          style: AppTextStyles.moneyList(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: sum == 0 ? 0 : e.value / sum,
                        minHeight: 4,
                        color: AppColors.marigold,
                        backgroundColor: AppColors.textPrimary.withValues(
                          alpha: 0.07,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class EmptyStateLine extends StatelessWidget {
  const EmptyStateLine({super.key});
  @override
  Widget build(BuildContext context) => Text(
    'Log a spend and your breakdown appears here.',
    style: AppTextStyles.bodySmall,
  );
}
