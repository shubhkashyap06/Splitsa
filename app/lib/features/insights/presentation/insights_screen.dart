import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/icon_badge.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

    final weeklySpend = [
      {'day': 'Mon', 'value': 450, 'current': false},
      {'day': 'Tue', 'value': 200, 'current': false},
      {'day': 'Wed', 'value': 1200, 'current': false},
      {'day': 'Thu', 'value': 300, 'current': false},
      {'day': 'Fri', 'value': 2800, 'current': true},
      {'day': 'Sat', 'value': 4200, 'current': false},
      {'day': 'Sun', 'value': 3100, 'current': false},
    ];
    final maxSpend = weeklySpend.map((e) => e['value'] as int).reduce((a, b) => a > b ? a : b);
    final totalWeeklySpend = weeklySpend.map((e) => e['value'] as int).reduce((a, b) => a + b);

    final categories = [
      {'name': 'Food & Drinks', 'value': 4500, 'icon': Icons.restaurant, 'tone': AppColors.marigold},
      {'name': 'Travel', 'value': 2100, 'icon': Icons.flight, 'tone': AppColors.rust},
      {'name': 'Shopping', 'value': 1800, 'icon': Icons.shopping_bag, 'tone': const Color(0xFF7A86FF)},
      {'name': 'Entertainment', 'value': 1200, 'icon': Icons.movie, 'tone': const Color(0xFF2F9E8F)},
    ];
    final totalCat = categories.map((e) => e['value'] as int).reduce((a, b) => a + b);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 120),
          children: [
            const Text('Insights', style: AppTextStyles.titleLarge),
            const SizedBox(height: 4),
            const Text('This week, at a glance', style: TextStyle(fontSize: 14, color: Color(0xFF8A8A8E))),
            
            const SizedBox(height: AppSpacing.xxl),

            // Persona Card
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0B),
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const IconBadge(icon: Icons.celebration, tone: AppColors.marigold, size: 46),
                      const SizedBox(width: AppSpacing.md),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('YOUR PERSONA', style: AppTextStyles.labelCaps.copyWith(color: const Color(0xFF8A8A8E), fontSize: 10)),
                          const SizedBox(height: 2),
                          const Text('Weekend Spender 🎈', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF5F5F5))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    '70% of your spends land on Fri–Sun. Small weekday habits could pad your Goa Trip pot nicely.',
                    style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF8A8A8E)),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.xxl),

            // Weekly Trend
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0B),
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
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
                          Text('SPENT THIS WEEK', style: AppTextStyles.labelCaps.copyWith(color: const Color(0xFF8A8A8E), fontSize: 10)),
                          const SizedBox(height: 4),
                          Text(currencyFormat.format(totalWeeklySpend), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFFF5F5F5))),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2F9E8F).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text('↓ 12% vs last', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2F9E8F))),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  SizedBox(
                    height: 160,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: weeklySpend.map((d) {
                        final val = d['value'] as int;
                        final current = d['current'] as bool;
                        final pct = val / maxSpend;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      heightFactor: pct,
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: current ? AppColors.marigold : Colors.white.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(100),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  (d['day'] as String).substring(0, 1),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: current ? AppColors.marigold : const Color(0xFF5A5A5E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.xxl),

            // Category Breakdown
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0B),
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Where it went', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFF5F5F5))),
                      SizedBox(
                        height: 28,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: categories.map((c) {
                            return Align(
                              widthFactor: 0.7,
                              child: Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: (c['tone'] as Color).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF0A0A0B), width: 2),
                                ),
                                alignment: Alignment.center,
                                child: Icon(c['icon'] as IconData, color: c['tone'] as Color, size: 13),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Stacked Bar
                  Container(
                    height: 12,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(100)),
                    child: Row(
                      children: categories.map((c) {
                        return Expanded(
                          flex: c['value'] as int,
                          child: Container(color: c['tone'] as Color),
                        );
                      }).toList(),
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Category List
                  ...categories.map((c) {
                    final pct = ((c['value'] as int) / totalCat * 100).round();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        children: [
                          IconBadge(icon: c['icon'] as IconData, tone: c['tone'] as Color, size: 34),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: Text(c['name'] as String, style: const TextStyle(fontSize: 14, color: Color(0xFFF5F5F5)))),
                          Text('$pct%', style: const TextStyle(fontSize: 13, color: Color(0xFF8A8A8E))),
                          const SizedBox(width: AppSpacing.md),
                          SizedBox(
                            width: 64,
                            child: Text(
                              currencyFormat.format(c['value']),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFF5F5F5)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.xxl),

            // Savings Rate
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0B),
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Row(
                children: [
                  const IconBadge(icon: Icons.savings, tone: Color(0xFF2F9E8F), size: 44),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Savings rate', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFF5F5F5))),
                        Text('You saved 18% of what you earned', style: TextStyle(fontSize: 13, color: Color(0xFF8A8A8E))),
                      ],
                    ),
                  ),
                  const Text('18%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF2F9E8F))),
                ],
              ),
            ),
            
          ],
        ),
      ),
    );
  }
}
