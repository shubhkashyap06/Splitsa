import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/icon_badge.dart';
import '../../../shared/widgets/avatar_widget.dart';

class RoomDetailScreen extends ConsumerWidget {
  const RoomDetailScreen({
    super.key,
    required this.roomId,
  });

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hardcoded feed for scaffolding
    final feed = [
      {
        'id': '1',
        'desc': 'Pizza and garlic bread',
        'who': 'Meera',
        'when': 'Yesterday',
        'amount': 450,
        'owed': false,
        'cat': Icons.local_pizza,
      },
      {
        'id': '2',
        'desc': 'Uber to Airport',
        'who': 'Kabir',
        'when': 'Fri',
        'amount': 220,
        'owed': true,
        'cat': Icons.directions_car,
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
              children: [
                // App Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 18),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        // Open Room Invite sheet
                      },
                      child: const Icon(Icons.add, color: AppColors.textSecondary, size: 24),
                    ),
                  ],
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                // Header
                Row(
                  children: [
                    const IconBadge(icon: Icons.beach_access, tone: AppColors.marigold, size: 46),
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Goa Trip', style: AppTextStyles.titleMedium),
                        const Text('4 members', style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: AppSpacing.xl),
                
                // Balance Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          text: 'You owe Aditi ',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                          children: [
                            TextSpan(
                              text: '₹230',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.rust, fontWeight: FontWeight.bold, fontFeatures: const [FontFeature.tabularFigures()]),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // Show simplified disclosure
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 12),
                              const SizedBox(width: 4),
                              Text('SIMPLIFIED', style: AppTextStyles.labelCaps.copyWith(fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: AppSpacing.xl),
                
                // Feed
                ...feed.map((f) {
                  final bool owed = f['owed'] as bool;
                  final color = owed ? AppColors.marigold : AppColors.rust;
                  final prefix = owed ? '+' : '−';
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          IconBadge(
                            icon: f['cat'] as IconData,
                            tone: color,
                            size: 40,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f['desc'] as String,
                                  style: AppTextStyles.bodySemibold,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${f['who']} paid · ${f['when']}',
                                  style: AppTextStyles.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                const AvatarStack(
                                  names: ['Meera', 'Aditi', 'Shubh'],
                                  tones: [AppColors.rust, AppColors.marigold, AppColors.textSecondary],
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$prefix₹${f['amount']}',
                            style: AppTextStyles.moneyList(color: color),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                
                // Bottom padding for sticky button
                const SizedBox(height: 120),
              ],
            ),
            
            // Sticky Settle Button
            Positioned(
              bottom: AppSpacing.xxl,
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              child: FilledButton(
                onPressed: () {
                  // Push settle sheet
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.marigold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 10,
                  shadowColor: AppColors.marigold.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                child: const Text('Settle Up', style: AppTextStyles.button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
