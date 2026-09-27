import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';

enum ExpenseType { split, personal }

class ExpenseContext {
  final ExpenseType type;
  final String? roomId;
  ExpenseContext({required this.type, this.roomId});
}

class ExpenseTypeSheet extends StatefulWidget {
  const ExpenseTypeSheet({super.key});
  
  static Future<ExpenseContext?> show(BuildContext context) {
    return showModalBottomSheet<ExpenseContext>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ExpenseTypeSheet(),
    );
  }

  @override
  State<ExpenseTypeSheet> createState() => _ExpenseTypeSheetState();
}

class _ExpenseTypeSheetState extends State<ExpenseTypeSheet> {
  ExpenseType? _type;
  String? _roomId;

  // Mock rooms data for scaffolding
  final _rooms = [
    {'id': '1', 'name': 'Goa Trip', 'sub': '4 members', 'icon': Icons.beach_access},
    {'id': '2', 'name': 'Flat 4B', 'sub': '3 members', 'icon': Icons.home},
  ];

  @override
  Widget build(BuildContext context) {
    final canContinue = _type == ExpenseType.personal || (_type == ExpenseType.split && _roomId != null);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0E),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xxxl),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('Add expense', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.xl),
            
            // Type Cards
            Row(
              children: [
                Expanded(child: _buildTypeCard(ExpenseType.split, 'Split', 'With friends', Icons.group_outlined)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _buildTypeCard(ExpenseType.personal, 'Personal', 'Just me', Icons.account_balance_wallet_outlined)),
              ],
            ),
            
            // Room Picker (Animated)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: _type == ExpenseType.split
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('WHICH GROUP?', style: AppTextStyles.labelCaps.copyWith(color: AppColors.textSecondary)),
                          const SizedBox(height: AppSpacing.md),
                          ..._rooms.map((r) => _buildRoomTile(r)),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            
            const SizedBox(height: AppSpacing.xl),
            
            // Continue Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: canContinue
                    ? () => context.pop(ExpenseContext(type: _type!, roomId: _roomId))
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.marigold,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppColors.marigold.withValues(alpha: 0.25),
                  disabledForegroundColor: Colors.black.withValues(alpha: 0.25),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                child: const Text('Continue', style: AppTextStyles.button),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeCard(ExpenseType type, String title, String sub, IconData icon) {
    final active = _type == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _type = type;
          if (type == ExpenseType.personal) _roomId = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: active ? AppColors.marigold.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: active ? AppColors.marigold.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08),
            width: active ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: active ? AppColors.marigold.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: active ? AppColors.marigold : AppColors.textSecondary, size: 20),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTextStyles.bodySemibold.copyWith(color: active ? AppColors.textPrimary : const Color(0xFFA0A0A5))),
            Text(sub, style: AppTextStyles.bodySmall.copyWith(color: active ? AppColors.textSecondary : const Color(0xFF5A5A5E))),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomTile(Map<String, dynamic> r) {
    final id = r['id'] as String;
    final active = _roomId == id;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: () => setState(() => _roomId = id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: active ? AppColors.marigold.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: active ? AppColors.marigold.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.07)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: active ? AppColors.marigold.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(r['icon'] as IconData, color: active ? AppColors.marigold : AppColors.textSecondary, size: 17),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['name'] as String, style: AppTextStyles.bodySemibold.copyWith(color: active ? AppColors.textPrimary : const Color(0xFFA0A0A5))),
                    Text(r['sub'] as String, style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF5A5A5E))),
                  ],
                ),
              ),
              if (active)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.marigold,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
