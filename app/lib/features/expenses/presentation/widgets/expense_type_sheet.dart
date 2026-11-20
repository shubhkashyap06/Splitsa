import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../rooms/application/room_providers.dart';
import '../../../rooms/presentation/widgets/room_icons.dart';
import '../../../rooms/presentation/widgets/room_invite_sheet.dart';

enum ExpenseType { split, personal }

class ExpenseContext {
  const ExpenseContext({required this.type, this.roomId});
  final ExpenseType type;
  final String? roomId;
}

class ExpenseTypeSheet extends ConsumerStatefulWidget {
  const ExpenseTypeSheet({super.key, this.initialType});
  final ExpenseType? initialType;

  static Future<ExpenseContext?> show(
    BuildContext context, {
    ExpenseType? initialType,
  }) {
    return showModalBottomSheet<ExpenseContext>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExpenseTypeSheet(initialType: initialType),
    );
  }

  @override
  ConsumerState<ExpenseTypeSheet> createState() => _ExpenseTypeSheetState();
}

class _ExpenseTypeSheetState extends ConsumerState<ExpenseTypeSheet> {
  late ExpenseType? _type = widget.initialType;
  String? _roomId;

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(roomSummariesProvider) ?? const <RoomSummary>[];
    // Most recently active room first — the quick-add "last used" default.
    if (_type == ExpenseType.split && _roomId == null && rooms.length == 1) {
      _roomId = rooms.first.room.id;
    }
    final canContinue =
        _type == ExpenseType.personal ||
        (_type == ExpenseType.split && _roomId != null);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xxxl,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Add expense', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: _typeCard(
                      ExpenseType.split,
                      'Split',
                      'With friends',
                      Icons.group_outlined,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _typeCard(
                      ExpenseType.personal,
                      'Personal',
                      'Just me',
                      Icons.account_balance_wallet_outlined,
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: _type == ExpenseType.split
                    ? Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WHICH GROUP?',
                              style: AppTextStyles.labelCaps.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (rooms.isEmpty)
                              _NoRoomsHint(
                                onCreate: () {
                                  final root = Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).context;
                                  Navigator.of(context).pop();
                                  RoomInviteSheet.showCreateOrJoin(root);
                                },
                              )
                            else
                              for (final r in rooms) _roomTile(r),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: canContinue
                      ? () => Navigator.of(
                          context,
                        ).pop(ExpenseContext(type: _type!, roomId: _roomId))
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.btn,
                    foregroundColor: AppColors.onBtn,
                    disabledBackgroundColor: AppColors.btn.withValues(
                      alpha: 0.25,
                    ),
                    disabledForegroundColor: AppColors.onBtn.withValues(
                      alpha: 0.25,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: Text('Continue', style: AppTextStyles.button),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeCard(ExpenseType type, String title, String sub, IconData icon) {
    final active = _type == type;
    return GestureDetector(
      onTap: () => setState(() {
        _type = type;
        if (type == ExpenseType.personal) _roomId = null;
      }),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: active
              ? AppColors.marigold.withValues(alpha: 0.12)
              : AppColors.textPrimary.withValues(alpha: 0.05),
          border: Border.all(
            color: active
                ? AppColors.marigold.withValues(alpha: 0.5)
                : AppColors.textPrimary.withValues(alpha: 0.08),
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
                color: active
                    ? AppColors.marigold.withValues(alpha: 0.18)
                    : AppColors.textPrimary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: active ? AppColors.marigold : AppColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppTextStyles.bodySemibold.copyWith(
                color: active ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            Text(
              sub,
              style: AppTextStyles.bodySmall.copyWith(
                color: active
                    ? AppColors.textSecondary
                    : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roomTile(RoomSummary r) {
    final active = _roomId == r.room.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: () => setState(() => _roomId = r.room.id),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: active
                ? AppColors.marigold.withValues(alpha: 0.1)
                : AppColors.textPrimary.withValues(alpha: 0.04),
            border: Border.all(
              color: active
                  ? AppColors.marigold.withValues(alpha: 0.4)
                  : AppColors.textPrimary.withValues(alpha: 0.07),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.marigold.withValues(alpha: 0.15)
                      : AppColors.textPrimary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  roomIcon(r.room.icon),
                  color: active ? AppColors.marigold : AppColors.textSecondary,
                  size: 17,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.room.name,
                      style: AppTextStyles.bodySemibold.copyWith(
                        color: active
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${r.memberIds.length} member${r.memberIds.length == 1 ? '' : 's'}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (active)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
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

class _NoRoomsHint extends StatelessWidget {
  const _NoRoomsHint({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.07),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'No rooms yet — make one to split with friends.',
              style: AppTextStyles.bodySmall,
            ),
          ),
          TextButton(
            onPressed: onCreate,
            child: Text('Create', style: TextStyle(color: AppColors.marigold)),
          ),
        ],
      ),
    );
  }
}
