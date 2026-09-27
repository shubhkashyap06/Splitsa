import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/icon_badge.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // Hardcoded reference values for v1 scaffolding
  static const int _budget = 15000;
  static const int _savedInPots = 3200;
  static const int _spendable = _budget - _savedInPots;
  static const int _youOwe = 410;
  static const int _youAreOwed = 1690;
  static const double _spentPct = ((_budget - _spendable) / _budget * 100);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sunday, 13 Sep', style: AppTextStyles.labelCaps.copyWith(textBaseline: TextBaseline.alphabetic)),
                    const SizedBox(height: AppSpacing.xs),
                    const Text('Hey Shubh 👋', style: AppTextStyles.titleLarge),
                  ],
                ),
                GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: const SplitsaAvatar(
                    name: 'Shubh',
                    tone: AppColors.card,
                    size: 40,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            
            // Hero card: September budget
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label + month total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('SEPTEMBER BUDGET', style: AppTextStyles.labelCaps),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          currencyFormat.format(_budget),
                          style: AppTextStyles.labelCaps.copyWith(color: AppColors.textSecondary, letterSpacing: 0),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppSpacing.md),
                  
                  // Spendable big number (value is in paise for MoneyText)
                  MoneyText(
                    valueInPaise: _spendable * 100,
                    color: AppColors.marigold,
                    heroSize: 44,
                    showDecimals: false,
                  ),
                  
                  const SizedBox(height: AppSpacing.xs),
                  RichText(
                    text: TextSpan(
                      text: 'left to spend · ',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      children: [
                        TextSpan(
                          text: '${currencyFormat.format(_savedInPots)} in pots',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.jade),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Progress bar
                  Container(
                    height: 4,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    alignment: Alignment.centerLeft,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Container(
                          width: constraints.maxWidth * (_spentPct / 100),
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.marigold, Color(0xFFE8962A)],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_spentPct.toInt()}% allocated', style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF5A5A5E), fontSize: 11)),
                      Text('13 days left', style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF5A5A5E), fontSize: 11)),
                    ],
                  ),
                  
                  const SizedBox(height: AppSpacing.lg),
                  Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Owe / Owed row
                  Row(
                    children: [
                      // You owe
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.rust.withValues(alpha: 0.08),
                            border: Border.all(color: AppColors.rust.withValues(alpha: 0.18)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('YOU OWE', style: AppTextStyles.labelCaps),
                              const SizedBox(height: 4),
                              Text(currencyFormat.format(_youOwe), style: AppTextStyles.titleLarge.copyWith(color: AppColors.rust, fontSize: 20)),
                              const SizedBox(height: 2),
                              const Text('to Meera', style: AppTextStyles.bodySmall),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Owed to you
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.marigold.withValues(alpha: 0.08),
                            border: Border.all(color: AppColors.marigold.withValues(alpha: 0.18)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('OWED TO YOU', style: AppTextStyles.labelCaps),
                              const SizedBox(height: 4),
                              Text(currencyFormat.format(_youAreOwed), style: AppTextStyles.titleLarge.copyWith(color: AppColors.marigold, fontSize: 20)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const AvatarStack(
                                    names: ['Aditi', 'Kabir', 'Meera'],
                                    tones: [AppColors.marigold, AppColors.jade, AppColors.rust],
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text('3 friends', style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Remind button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reminder sent to Aditi, Kabir & Meera 🔔')),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                      icon: const Icon(Icons.notifications_none, size: 18),
                      label: const Text('Remind to pay', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            
            // Your Rooms
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Your Rooms', style: AppTextStyles.titleMedium),
                Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            
            // Horizontal scroll for rooms
            SizedBox(
              height: 140,
              child: ListView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                children: [
                  _RoomCard(
                    name: 'Goa Trip',
                    sub: '4 members',
                    balance: 640,
                    icon: Icons.beach_access,
                    onTap: () => context.push('/rooms/1'),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _RoomCard(
                    name: 'Flat 4B',
                    sub: '3 members',
                    balance: -210,
                    icon: Icons.home,
                    onTap: () => context.push('/rooms/2'),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.xl),
            
            // This week's insights
            _TeaserCard(
              title: "This week's insights",
              subtitle: "Spending down 12% · you're a Weekend Spender",
              icon: Icons.bar_chart,
              iconColor: AppColors.textSecondary,
              onTap: () {},
            ),
            
            const SizedBox(height: AppSpacing.md),
            
            // Potli Pick (Nudge)
            _TeaserCard(
              title: "Move ₹340 to Goa Trip?",
              subtitle: "You underspent on food — nice one",
              icon: Icons.auto_awesome,
              iconColor: AppColors.jade,
              onTap: () {},
            ),
            
            // Bottom padding for tab bar
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final String name;
  final String sub;
  final int balance;
  final IconData icon;
  final VoidCallback onTap;

  const _RoomCard({
    required this.name,
    required this.sub,
    required this.balance,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = balance > 0;
    final isNegative = balance < 0;
    final color = isPositive ? AppColors.marigold : (isNegative ? AppColors.rust : AppColors.textSecondary);
    final prefix = isPositive ? '+' : (isNegative ? '−' : '');
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: icon, tone: AppColors.textSecondary, size: 38),
            const Spacer(),
            Text(name, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
            Text(sub, style: AppTextStyles.bodySmall),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                balance == 0 ? 'Settled' : '$prefix₹${balance.abs()}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeaserCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _TeaserCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            IconBadge(icon: icon, tone: iconColor, size: 38),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
