import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/money.dart';
import '../../../../data/local/database.dart';
import '../../../../data/local/local_streams.dart';
import '../../../../data/remote/session.dart';
import '../../../../shared/widgets/avatar_widget.dart';
import '../../../../shared/widgets/sheets.dart';
import '../../application/room_providers.dart';
import 'settle_sheet.dart';
import 'simplified_sheet.dart';

/// Settle Up list: "who pays whom" after simplification, with the same
/// ⓘ Simplified disclosure as Room Detail. Rows where *you* pay open the
/// light-mode Settle sheet; the rest are informational.
class SettleListSheet extends ConsumerWidget {
  const SettleListSheet({super.key, required this.roomId});
  final String roomId;

  static Future<void> show(BuildContext context, {required String roomId}) =>
      showAppSheet(context, (_) => SettleListSheet(roomId: roomId));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(roomDetailProvider(roomId));
    final profiles =
        ref.watch(profilesByIdProvider).valueOrNull ??
        const <String, ProfilesTableData>{};
    final me = ref.watch(currentUserIdProvider);
    String name(String id) => nameFor(id, me, profiles);

    if (detail == null) return const DarkSheet(child: SizedBox(height: 120));

    final transfers = [...detail.transfers]
      ..sort((a, b) {
        int rank(s) => s.payerId == me ? 0 : (s.payeeId == me ? 1 : 2);
        return rank(a).compareTo(rank(b));
      });

    return DarkSheet(
      title: 'Settle up',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  transfers.isEmpty
                      ? 'Everyone\'s even in ${detail.room.name}.'
                      : 'Fewest payments to get everyone even.',
                  style: AppTextStyles.bodySmall,
                ),
              ),
              TextButton.icon(
                onPressed: () => SimplifiedSheet.show(
                  context,
                  raw: detail.rawDebts,
                  simplified: detail.transfers,
                  nameOf: name,
                ),
                icon: Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                label: Text('Simplified', style: AppTextStyles.bodySmall),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (transfers.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text('All settled 🎉', style: AppTextStyles.titleSmall),
              ),
            ),
          for (final t in transfers)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _TransferRow(
                fromName: name(t.payerId),
                toName: name(t.payeeId),
                avatarId: t.payerId == me ? t.payeeId : t.payerId,
                avatarName:
                    profiles[t.payerId == me ? t.payeeId : t.payerId]
                        ?.displayName ??
                    '?',
                amountPaise: t.amountPaise,
                color: t.payerId == me
                    ? AppColors.rust
                    : (t.payeeId == me
                          ? AppColors.marigold
                          : AppColors.textSecondary),
                onTap: t.payerId != me
                    ? null
                    : () {
                        // This sheet's context dies on pop — open the next
                        // sheet from the (still-mounted) root navigator.
                        final rootContext = Navigator.of(
                          context,
                          rootNavigator: true,
                        ).context;
                        Navigator.of(context).pop();
                        SettleSheet.show(
                          rootContext,
                          roomId: roomId,
                          roomName: detail.room.name,
                          payeeId: t.payeeId,
                          payeeName: profiles[t.payeeId]?.displayName ?? 'them',
                          owedPaise: t.amountPaise,
                        );
                      },
              ),
            ),
        ],
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({
    required this.fromName,
    required this.toName,
    required this.avatarId,
    required this.avatarName,
    required this.amountPaise,
    required this.color,
    required this.onTap,
  });
  final String fromName;
  final String toName;
  final String avatarId;
  final String avatarName;
  final int amountPaise;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: AppColors.cardShadow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            SplitsaAvatar(name: avatarName, tone: toneFor(avatarId), size: 36),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                '$fromName → $toName',
                style: AppTextStyles.bodySemibold,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              formatPaise(amountPaise),
              style: AppTextStyles.moneyList(color: color),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
