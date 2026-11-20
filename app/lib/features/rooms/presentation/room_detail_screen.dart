import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/money.dart';
import '../../../data/local/database.dart';
import '../../../data/local/local_streams.dart';
import '../../../data/remote/session.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/icon_badge.dart';
import '../../../shared/widgets/sheets.dart';
import '../../expenses/presentation/add_flow.dart';
import '../application/room_providers.dart';
import 'widgets/room_icons.dart';
import 'widgets/room_invite_sheet.dart';
import 'widgets/settle_list_sheet.dart';
import 'widgets/simplified_sheet.dart';

class RoomDetailScreen extends ConsumerWidget {
  const RoomDetailScreen({super.key, required this.roomId});
  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(roomDetailProvider(roomId));
    final profiles =
        ref.watch(profilesByIdProvider).valueOrNull ??
        const <String, ProfilesTableData>{};
    final me = ref.watch(currentUserIdProvider);
    String name(String id) => nameFor(id, me, profiles);

    if (detail == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background),
        body: Center(
          child: Text('Loading room…', style: AppTextStyles.bodySmall),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
              children: [
                _TopBar(
                  onBack: () =>
                      context.canPop() ? context.pop() : context.go('/rooms'),
                  onInvite: () => RoomInviteSheet.showInvite(
                    context,
                    roomId: roomId,
                    roomName: detail.room.name,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    IconBadge(
                      icon: roomIcon(detail.room.icon),
                      tone: AppColors.marigold,
                      size: 46,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detail.room.name,
                            style: AppTextStyles.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${detail.memberIds.length} member${detail.memberIds.length == 1 ? '' : 's'}',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    AvatarStack(
                      names: [
                        for (final id in detail.memberIds)
                          profiles[id]?.displayName ?? '?',
                      ],
                      tones: [for (final id in detail.memberIds) toneFor(id)],
                      size: 26,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                _BalanceStrip(detail: detail, me: me, name: name),
                const SizedBox(height: AppSpacing.xl),
                if (detail.feed.isEmpty)
                  EmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: 'No expenses yet',
                    body: detail.memberIds.length < 2
                        ? 'Invite your people with the + up top, then add the first one, bestie.'
                        : 'Add the first one, bestie.',
                    actionLabel: 'Add an expense',
                    onAction: () => startAddFlow(context, ref, roomId: roomId),
                  )
                else
                  for (final item in detail.feed)
                    _FeedCard(
                      key: ValueKey(item.expense.id),
                      item: item,
                      payerName: name(item.expense.paidBy),
                      splitNames: [
                        for (final id in item.splitUserIds)
                          profiles[id]?.displayName ?? '?',
                      ],
                      splitIds: item.splitUserIds,
                      canDelete: item.expense.paidBy == me,
                      onDelete: () =>
                          _confirmDelete(context, ref, item.expense),
                    ),
                const SizedBox(height: 120),
              ],
            ),
            Positioned(
              bottom: AppSpacing.xxl,
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              child: FilledButton(
                onPressed: () => SettleListSheet.show(context, roomId: roomId),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.btn,
                  foregroundColor: AppColors.onBtn,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 10,
                  shadowColor: AppColors.textPrimary.withValues(alpha: 0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                child: Text('Settle Up', style: AppTextStyles.button),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ExpensesTableData e,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Delete this expense?', style: AppTextStyles.titleSmall),
        content: Text(
          '"${e.description}" (${formatPaise(e.amountPaise)}) will be removed for everyone in the room.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.rust)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(expenseRepositoryProvider)
          .deleteSharedExpense(
            e.id,
            byUserId: ref.read(currentUserIdProvider) ?? '',
          );
    } on ExpenseValidationError catch (err) {
      if (context.mounted) showToast(context, err.message);
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.onInvite});
  final VoidCallback onBack;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.arrow_back,
              color: AppColors.textPrimary,
              size: 18,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Invite people',
          onPressed: onInvite,
          icon: Icon(
            Icons.person_add_alt,
            color: AppColors.textSecondary,
            size: 22,
          ),
        ),
      ],
    );
  }
}

class _BalanceStrip extends StatelessWidget {
  const _BalanceStrip({
    required this.detail,
    required this.me,
    required this.name,
  });
  final RoomDetail detail;
  final String? me;
  final String Function(String) name;

  @override
  Widget build(BuildContext context) {
    final iOwe = detail.transfers.where((t) => t.payerId == me).toList();
    final owedToMe = detail.transfers.where((t) => t.payeeId == me).toList();

    final InlineSpan text;
    if (iOwe.isNotEmpty) {
      final t = iOwe.first;
      text = TextSpan(
        children: [
          TextSpan(text: 'You owe ${name(t.payeeId)} '),
          TextSpan(
            text: formatPaise(t.amountPaise),
            style: _amount(AppColors.rust),
          ),
          if (iOwe.length > 1) TextSpan(text: ' +${iOwe.length - 1} more'),
        ],
      );
    } else if (owedToMe.isNotEmpty) {
      final total = owedToMe.fold<int>(0, (s, t) => s + t.amountPaise);
      text = TextSpan(
        children: [
          TextSpan(
            text: owedToMe.length == 1
                ? '${name(owedToMe.first.payerId)} owes you '
                : 'You\'re owed ',
          ),
          TextSpan(
            text: formatPaise(total),
            style: _amount(AppColors.marigold),
          ),
        ],
      );
    } else {
      text = const TextSpan(text: 'All settled up 🎉');
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.cardShadow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                children: [text],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => SimplifiedSheet.show(
              context,
              raw: detail.rawDebts,
              simplified: detail.transfers,
              nameOf: name,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.textSecondary,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'SIMPLIFIED',
                    style: AppTextStyles.labelCaps.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static TextStyle _amount(Color c) => TextStyle(
    color: c,
    fontWeight: FontWeight.bold,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// One expense. Animates in with a soft upward slide + fade.
class _FeedCard extends StatelessWidget {
  const _FeedCard({
    super.key,
    required this.item,
    required this.payerName,
    required this.splitNames,
    required this.splitIds,
    required this.canDelete,
    required this.onDelete,
  });
  final FeedItem item;
  final String payerName;
  final List<String> splitNames;
  final List<String> splitIds;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final delta = item.myDeltaPaise;
    final color = !item.involvesMe || delta == 0
        ? AppColors.textSecondary
        : (delta > 0 ? AppColors.marigold : AppColors.rust);
    final amountText = !item.involvesMe
        ? formatPaise(item.expense.amountPaise)
        : delta == 0
        ? 'even'
        : '${delta > 0 ? '+' : '−'}${formatPaise(delta.abs())}';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (ctx, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: GestureDetector(
          onLongPress: canDelete ? onDelete : null,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: AppColors.cardShadow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                IconBadge(
                  icon: categoryIcon(item.expense.category),
                  tone: color,
                  size: 40,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.expense.description,
                              style: AppTextStyles.bodySemibold,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.pending) ...[
                            const SizedBox(width: 6),
                            const PendingMark(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$payerName paid ${formatPaise(item.expense.amountPaise)} · ${relativeDay(item.expense.createdAt)}',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      AvatarStack(
                        names: splitNames,
                        tones: [for (final id in splitIds) toneFor(id)],
                        size: 22,
                      ),
                    ],
                  ),
                ),
                Text(amountText, style: AppTextStyles.moneyList(color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
