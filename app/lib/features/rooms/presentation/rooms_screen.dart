import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/money.dart';
import '../../../data/local/local_streams.dart';
import '../../../data/sync/sync_providers.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/icon_badge.dart';
import '../../../shared/widgets/sheets.dart';
import '../application/room_providers.dart';
import 'widgets/room_icons.dart';
import 'widgets/room_invite_sheet.dart';

class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key, this.joinCode});

  /// From a `/join?code=…` deep link (already pattern-validated).
  final String? joinCode;

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  String? _handledCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeOpenJoin();
  }

  @override
  void didUpdateWidget(RoomsScreen old) {
    super.didUpdateWidget(old);
    _maybeOpenJoin();
  }

  void _maybeOpenJoin() {
    final code = widget.joinCode;
    if (code == null || code == _handledCode) return;
    _handledCode = code;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go('/rooms');
      RoomInviteSheet.showCreateOrJoin(context, joinCode: code);
    });
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(roomSummariesProvider);
    final profiles = ref.watch(profilesByIdProvider).valueOrNull ?? const {};

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.marigold,
          backgroundColor: AppColors.card,
          onRefresh: () => ref.read(syncSchedulerProvider).syncNow(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              120,
            ),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Rooms', style: AppTextStyles.titleLarge),
                  IconButton(
                    tooltip: 'Create or join a room',
                    onPressed: () => RoomInviteSheet.showCreateOrJoin(context),
                    icon: Icon(Icons.add, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (rooms == null)
                const SizedBox.shrink()
              else if (rooms.isEmpty)
                EmptyState(
                  icon: Icons.group_add_outlined,
                  title: 'Your rooms will live here',
                  body:
                      'A room is your flat, trip or friend group — everyone logs spends, Splitsa does the maths.',
                  actionLabel: 'Create or join a room',
                  onAction: () => RoomInviteSheet.showCreateOrJoin(context),
                )
              else
                for (final r in rooms)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _RoomRow(
                      summary: r,
                      names: [
                        for (final id in r.memberIds)
                          profiles[id]?.displayName ?? '?',
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({required this.summary, required this.names});
  final RoomSummary summary;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final net = summary.myNetPaise;
    final color = net > 0
        ? AppColors.marigold
        : (net < 0 ? AppColors.rust : AppColors.textSecondary);
    final label = net == 0
        ? 'Settled'
        : net > 0
        ? 'You\'re owed ${formatPaise(net)}'
        : 'You owe ${formatPaise(-net)}';

    return GestureDetector(
      onTap: () => context.go('/rooms/${summary.room.id}'),
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
            IconBadge(
              icon: roomIcon(summary.room.icon),
              tone: AppColors.textSecondary,
              size: 44,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.room.name,
                    style: AppTextStyles.bodySemibold,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: AppTextStyles.bodySmall.copyWith(color: color),
                  ),
                ],
              ),
            ),
            AvatarStack(
              names: names,
              tones: [for (final id in summary.memberIds) toneFor(id)],
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
