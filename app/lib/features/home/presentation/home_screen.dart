import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/money.dart';
import '../../../data/local/local_streams.dart';
import '../../../data/remote/session.dart';
import '../../../data/sync/sync_engine.dart';
import '../../../data/sync/sync_providers.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/icon_badge.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/motion.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/widgets/sheets.dart';
import '../../expenses/presentation/add_flow.dart';
import '../../insights/application/insights_providers.dart';
import '../../insights/presentation/widgets/nudge_sheet.dart';
import '../../recommendations/recommendation_models.dart';
import '../../profile/presentation/widgets/edit_field_sheets.dart';
import '../../rooms/application/room_providers.dart';
import '../../rooms/presentation/widgets/room_icons.dart';
import '../../rooms/presentation/widgets/room_invite_sheet.dart';
import '../application/home_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.quickAddType});

  /// Set by the `/quick-add?type=…` deep link (already allow-listed).
  final String? quickAddType;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _handledQuickAdd;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLaunchQuickAdd();
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    _maybeLaunchQuickAdd();
  }

  void _maybeLaunchQuickAdd() {
    final type = widget.quickAddType;
    if (type == null || type == _handledQuickAdd) return;
    _handledQuickAdd = type;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go('/home'); // clear the query so a rebuild doesn't relaunch
      startAddFlow(context, ref, quickAddType: type);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final firstName = (profile?.displayName ?? '').split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.jade,
          backgroundColor: AppColors.card,
          onRefresh: () => ref.read(syncSchedulerProvider).syncNow(),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            children: [
              RiseIn(child: _Header(firstName: firstName)),
              const SizedBox(height: AppSpacing.xxl),
              const RiseIn(index: 1, child: _BudgetHeroCard()),
              const SizedBox(height: AppSpacing.xxl),
              const RiseIn(index: 2, child: _RoomsStrip()),
              const SizedBox(height: AppSpacing.xl),
              const RiseIn(index: 3, child: _SpendingSummaryCard()),
              const RiseIn(index: 4, child: _InsightsTeaser()),
              const SizedBox(height: AppSpacing.md),
              const RiseIn(index: 5, child: _PotliPickCard()),
              const SizedBox(height: 120), // clears the floating tab bar
            ],
          ),
        ),
      ),
    );
  }
}

// ── 1. Header ─────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  const _Header({required this.firstName});
  final String firstName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserIdProvider) ?? '';
    final pending = ref.watch(pendingRowIdsProvider).valueOrNull?.length ?? 0;
    final phase = ref.watch(syncStatusProvider).valueOrNull?.phase;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    DateFormat('EEEE, d MMM').format(DateTime.now()),
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (pending > 0 || phase == SyncPhase.offline) ...[
                    const SizedBox(width: AppSpacing.sm),
                    _SyncChip(
                      pending: pending,
                      offline: phase == SyncPhase.offline,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                firstName.isEmpty ? _greeting() : '${_greeting()}, $firstName',
                style: AppTextStyles.titleLarge.copyWith(letterSpacing: -0.8),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.push('/profile'),
          child: SplitsaAvatar(
            name: firstName.isEmpty ? '?' : firstName,
            tone: toneFor(me),
            size: 44,
          ),
        ),
      ],
    );
  }
}

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 5) return 'Up late';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  if (h < 22) return 'Good evening';
  return 'Good night';
}

class _SyncChip extends StatelessWidget {
  const _SyncChip({required this.pending, required this.offline});
  final int pending;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final label = offline
        ? (pending > 0 ? 'Offline · $pending to sync' : 'Offline')
        : '$pending syncing';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            offline ? Icons.cloud_off : Icons.sync,
            size: 11,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }
}

// ── 2. Hero card — monthly budget ─────────────────────────────────────────

class _BudgetHeroCard extends ConsumerWidget {
  const _BudgetHeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(budgetSnapshotProvider);
    final debts = ref.watch(myDebtsProvider);
    final profiles = ref.watch(profilesByIdProvider).valueOrNull ?? const {};
    final me = ref.watch(currentUserIdProvider);
    final month = DateFormat('MMMM').format(DateTime.now()).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.cardShadow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$month BUDGET', style: AppTextStyles.labelCaps),
              GestureDetector(
                onTap: () => EditBudgetSheet.show(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    snap?.budgetPaise == null
                        ? 'Set budget'
                        : formatPaise(snap!.budgetPaise!),
                    style: AppTextStyles.labelCaps.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (snap == null)
            const SizedBox(height: 60)
          else if (snap.budgetPaise == null)
            _NoBudget(spentPaise: snap.spentPaise)
          else
            _BudgetNumbers(snap: snap),
          const SizedBox(height: AppSpacing.lg),
          Divider(
            color: AppColors.textPrimary.withValues(alpha: 0.06),
            height: 1,
          ),
          const SizedBox(height: AppSpacing.lg),
          _OweRow(debts: debts, profiles: profiles, me: me),
          const SizedBox(height: AppSpacing.lg),
          _RemindButton(debts: debts, profiles: profiles),
        ],
      ),
    );
  }
}

class _NoBudget extends StatelessWidget {
  const _NoBudget({required this.spentPaise});
  final int spentPaise;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MoneyText(
          valueInPaise: spentPaise,
          color: AppColors.textPrimary,
          heroSize: 44,
          showDecimals: false,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'spent this month · set a budget to see what\'s left',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _BudgetNumbers extends StatelessWidget {
  const _BudgetNumbers({required this.snap});
  final BudgetSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final spendable = snap.spendablePaise!;
    final over = spendable < 0;
    final pct = (snap.allocatedFraction * 100).round();

    return Row(
      children: [
        Breathing(
          depth: 0.03,
          period: const Duration(seconds: 5),
          child: ProgressRing(
            progress: pct.toDouble(),
            size: 116,
            color: over ? AppColors.rust : AppColors.jade,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$pct%',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text('used', style: AppTextStyles.labelSmall),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                over ? 'Over budget by' : 'Left this month',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: MoneyText(
                  valueInPaise: spendable.abs(),
                  color: over ? AppColors.rust : AppColors.textPrimary,
                  heroSize: 36,
                  showDecimals: false,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  text: 'of ${formatPaise(snap.budgetPaise!)} · ',
                  style: AppTextStyles.bodySmall,
                  children: [
                    TextSpan(
                      text: '${formatPaise(snap.savedInPotsPaise)} saved',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.jade,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${snap.daysLeft} day${snap.daysLeft == 1 ? '' : 's'} to go',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OweRow extends StatelessWidget {
  const _OweRow({
    required this.debts,
    required this.profiles,
    required this.me,
  });
  final MyDebts? debts;
  final Map<String, dynamic> profiles;
  final String? me;

  @override
  Widget build(BuildContext context) {
    final d = debts;
    final creditors =
        d?.iOwe.map((t) => t.$2.payeeId).toSet().toList() ?? const [];
    final debtors =
        d?.owedToMe.map((t) => t.$2.payerId).toSet().toList() ?? const [];
    String name(String id) => profiles[id]?.displayName as String? ?? 'Someone';

    final oweLabel = creditors.isEmpty
        ? 'nobody — nice'
        : 'to ${name(creditors.first).split(' ').first}'
              '${creditors.length > 1 ? ' +${creditors.length - 1}' : ''}';

    return Row(
      children: [
        Expanded(
          child: _TintBox(
            label: 'YOU OWE',
            amount: d?.totalIOwe ?? 0,
            color: AppColors.rust,
            tint: AppColors.rustTint,
            border: AppColors.rustBorder,
            footer: Text(
              oweLabel,
              style: AppTextStyles.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _TintBox(
            label: 'OWED TO YOU',
            amount: d?.totalOwedToMe ?? 0,
            color: AppColors.marigold,
            tint: AppColors.marigoldTint,
            border: AppColors.marigoldBorder,
            footer: debtors.isEmpty
                ? Text('all square', style: AppTextStyles.bodySmall)
                : Row(
                    children: [
                      AvatarStack(
                        names: [for (final id in debtors) name(id)],
                        tones: [for (final id in debtors) toneFor(id)],
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${debtors.length} friend${debtors.length == 1 ? '' : 's'}',
                          style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _TintBox extends StatelessWidget {
  const _TintBox({
    required this.label,
    required this.amount,
    required this.color,
    required this.tint,
    required this.border,
    required this.footer,
  });
  final String label;
  final int amount;
  final Color color;
  final Color tint;
  final Color border;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: tint,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelCaps),
          const SizedBox(height: 4),
          Text(
            formatPaise(amount),
            style: AppTextStyles.titleLarge.copyWith(
              color: color,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 2),
          footer,
        ],
      ),
    );
  }
}

/// "Remind to pay". Push delivery (FCM/Web Push) needs project credentials
/// that aren't configured yet, so this copies a ready-to-send reminder for
/// the group chat instead of pretending a notification went out.
class _RemindButton extends ConsumerWidget {
  const _RemindButton({required this.debts, required this.profiles});
  final MyDebts? debts;
  final Map<String, dynamic> profiles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owed = debts?.owedToMe ?? const [];
    final upi = ref.watch(myProfileProvider).valueOrNull?.upiId;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: owed.isEmpty
            ? null
            : () async {
                final lines = <String>[
                  for (final (_, t) in owed)
                    '• ${(profiles[t.payerId]?.displayName as String?) ?? 'Someone'}: ${formatPaise(t.amountPaise)}',
                ];
                final text = [
                  'Quick nudge from Splitsa 🙏',
                  ...lines,
                  if (upi != null) 'UPI: $upi',
                ].join('\n');
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  showToast(
                    context,
                    'Reminder copied — paste it in your group chat 🔔',
                  );
                }
              },
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.btn,
          foregroundColor: AppColors.onBtn,
          disabledBackgroundColor: AppColors.textPrimary.withValues(
            alpha: 0.08,
          ),
          disabledForegroundColor: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        icon: Icon(
          owed.isEmpty ? Icons.check : Icons.notifications_none,
          size: 18,
        ),
        label: Text(
          owed.isEmpty ? 'All square 🎉' : 'Nudge them kindly',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ── 3. Your Rooms ─────────────────────────────────────────────────────────

class _RoomsStrip extends ConsumerWidget {
  const _RoomsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomSummariesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => context.go('/rooms'),
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your Rooms', style: AppTextStyles.titleMedium),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (rooms == null)
          const SizedBox(height: 164)
        else if (rooms.isEmpty)
          EmptyState(
            icon: Icons.group_add_outlined,
            title: 'No rooms yet',
            body:
                'Make one for your flat or trip, or join with a code from a friend.',
            actionLabel: 'Create or join a room',
            onAction: () => RoomInviteSheet.showCreateOrJoin(context),
          )
        else
          SizedBox(
            height: 164,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: rooms.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (ctx, i) {
                final r = rooms[i];
                return _RoomCard(
                  name: r.room.name,
                  sub:
                      '${r.memberIds.length} member${r.memberIds.length == 1 ? '' : 's'}',
                  balancePaise: r.myNetPaise,
                  icon: roomIcon(r.room.icon),
                  onTap: () => context.go('/rooms/${r.room.id}'),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.name,
    required this.sub,
    required this.balancePaise,
    required this.icon,
    required this.onTap,
  });
  final String name;
  final String sub;
  final int balancePaise;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = balancePaise > 0
        ? AppColors.marigold
        : (balancePaise < 0 ? AppColors.rust : AppColors.textSecondary);
    final label = balancePaise == 0
        ? 'Settled'
        : '${balancePaise > 0 ? '+' : '−'}${formatPaise(balancePaise.abs())}';

    return PressSpring(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: AppColors.cardShadow,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: icon, tone: AppColors.textSecondary, size: 38),
            const Spacer(),
            Text(
              name,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(sub, style: AppTextStyles.bodySmall),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                label,
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

// ── 3a. Spending summary (PRODUCT_LOGIC.md §4) ────────────────────────────

class _SpendingSummaryCard extends ConsumerStatefulWidget {
  const _SpendingSummaryCard();

  @override
  ConsumerState<_SpendingSummaryCard> createState() =>
      _SpendingSummaryCardState();
}

class _SpendingSummaryCardState extends ConsumerState<_SpendingSummaryCard> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(insightsProvider).valueOrNull;
    if (_dismissed || data == null || data.thisWeekPaise == 0) {
      return const SizedBox.shrink();
    }
    final diff = data.thisWeekPaise - data.lastWeekPaise;
    final top = data.summary.topCategory;
    final comparison = data.lastWeekPaise == 0
        ? 'Top spend: ${categoryLabel(top)}'
        : '${formatPaise(diff.abs())} ${diff >= 0 ? 'more' : 'less'} than last week · top: ${categoryLabel(top)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: _TeaserCard(
        title: 'This week · ${formatPaise(data.thisWeekPaise)} logged',
        subtitle: comparison,
        icon: Icons.receipt_long,
        iconColor: AppColors.textSecondary,
        onTap: () => context.go('/insights'),
        trailing: GestureDetector(
          onTap: () => setState(() => _dismissed = true),
          child: Icon(Icons.close, size: 18, color: AppColors.textTertiary),
        ),
      ),
    );
  }
}

// ── 4. This week's insights ───────────────────────────────────────────────

class _InsightsTeaser extends ConsumerWidget {
  const _InsightsTeaser();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(insightsProvider).valueOrNull;
    String subtitle = 'Log a few spends to see your patterns';
    if (data != null) {
      final wow = data.weekOverWeek;
      final trend = wow == null
          ? null
          : 'Spending ${wow <= 0 ? 'down' : 'up'} ${(wow.abs() * 100).round()}%';
      final persona = data.persona == SpendPersona.coldStart
          ? null
          : "you're a ${personaLabel(data.persona).replaceAll(RegExp(r' \S+$'), '')}";
      subtitle = [trend, persona].whereType<String>().join(' · ');
      if (subtitle.isEmpty) {
        subtitle = 'Keep logging — patterns show up after a week or two';
      }
    }
    return _TeaserCard(
      title: "This week's insights",
      subtitle: subtitle,
      icon: Icons.bar_chart,
      iconColor: AppColors.textSecondary,
      onTap: () => context.go('/insights'),
    );
  }
}

// ── 5. Potli Pick ─────────────────────────────────────────────────────────

class _PotliPickCard extends ConsumerWidget {
  const _PotliPickCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(insightsProvider).valueOrNull;
    final target = ref.watch(nudgeTargetPotProvider);
    final nudge = data?.nudge;

    if (nudge == null) {
      return _TeaserCard(
        title: 'Potli Pick',
        subtitle:
            'Keep logging — your first savings pick lands after a full week.',
        icon: Icons.auto_awesome,
        iconColor: AppColors.jade,
        onTap: () => context.go('/insights'),
      );
    }
    final where = target?.name ?? 'savings';
    return _TeaserCard(
      title: 'Move ${formatPaise(nudge.recommendedAmountPaise)} to $where?',
      subtitle: nudge.headline,
      icon: Icons.auto_awesome,
      iconColor: AppColors.jade,
      onTap: () => NudgeSheet.show(context, nudge),
    );
  }
}

class _TeaserCard extends StatelessWidget {
  const _TeaserCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.trailing,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return PressSpring(
      onTap: onTap,
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
            IconBadge(icon: icon, tone: iconColor, size: 38),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(subtitle, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
          ],
        ),
      ),
    );
  }
}
