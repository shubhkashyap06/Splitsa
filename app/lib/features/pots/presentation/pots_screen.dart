import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/money.dart';
import '../../../data/remote/session.dart';
import '../../../data/repositories/pot_repository.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/widgets/sheets.dart';
import '../application/pot_providers.dart';
import 'widgets/contribute_sheet.dart';
import 'widgets/create_pot_sheet.dart';

class PotsScreen extends ConsumerStatefulWidget {
  const PotsScreen({super.key});

  @override
  ConsumerState<PotsScreen> createState() => _PotsScreenState();
}

class _PotsScreenState extends ConsumerState<PotsScreen> {
  bool _fanned = false;

  @override
  Widget build(BuildContext context) {
    final views = ref.watch(potViewsProvider);
    final potli = views?.where((v) => v.isPersonal).firstOrNull;
    final stack = views?.where((v) => v != potli).toList() ?? const <PotView>[];

    const cardH = 208.0;
    const peek = 104.0;
    final stackHeight = _fanned
        ? (cardH + 16) * (stack.length + 1)
        : (stack.isEmpty ? 90.0 : cardH + peek * (stack.length - 1) + 90 + 16);

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
            Text('Savings', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.xxl),
            if (views == null)
              const SizedBox(height: 156)
            else if (potli == null)
              EmptyState(
                icon: Icons.spa_outlined,
                title: 'Start your Potli',
                body:
                    'A personal goal — a trip, a gadget, a rainy-day fund. Potli Picks send spare money here.',
                actionLabel: 'Create my Potli',
                onAction: () => CreatePotSheet.show(context, personal: true),
              )
            else
              _PotliCard(view: potli),
            const SizedBox(height: AppSpacing.xxxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pots', style: AppTextStyles.titleSmall),
                if (stack.length > 1)
                  GestureDetector(
                    onTap: () => setState(() => _fanned = !_fanned),
                    child: Text(
                      _fanned ? 'Stack' : 'Fan out',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: stackHeight,
              child: Stack(
                children: [
                  for (var idx = 0; idx < stack.length; idx++)
                    AnimatedPositioned(
                      key: ValueKey(stack[idx].pot.id),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutBack,
                      top: _fanned ? idx * (cardH + 16) : idx * peek,
                      left: 0,
                      right: 0,
                      child: AnimatedScale(
                        scale: _fanned ? 1.0 : 1 - idx * 0.02,
                        alignment: Alignment.topCenter,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutBack,
                        child: GestureDetector(
                          onVerticalDragEnd: (d) {
                            if ((d.primaryVelocity ?? 0) > 200 && !_fanned) {
                              setState(() => _fanned = true);
                            }
                            if ((d.primaryVelocity ?? 0) < -200 && _fanned) {
                              setState(() => _fanned = false);
                            }
                          },
                          child: _PotCard(view: stack[idx], height: cardH),
                        ),
                      ),
                    ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    top: stack.isEmpty
                        ? 0
                        : (_fanned
                              ? stack.length * (cardH + 16)
                              : (stack.length - 1) * peek + cardH + 16),
                    left: 0,
                    right: 0,
                    child: const _NewPotCard(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PotliCard extends ConsumerWidget {
  const _PotliCard({required this.view});
  final PotView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pct = view.progressPct;
    return GestureDetector(
      onTap: () => ContributeSheet.show(context, potId: view.pot.id),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: AppColors.cardShadow,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          children: [
            ProgressRing(
              progress: pct ?? 0,
              size: 116,
              color: AppColors.jade,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    pct == null ? '—' : '${pct.round()}%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    pct == null ? 'no target' : 'there',
                    style: AppTextStyles.labelCaps.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR POTLI',
                    style: AppTextStyles.labelCaps.copyWith(fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    view.pot.name,
                    style: AppTextStyles.bodySemibold,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      text: formatPaise(view.savedPaise),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.jade,
                      ),
                      children: [
                        if (view.pot.targetAmountPaise != null)
                          TextSpan(
                            text:
                                ' / ${formatPaise(view.pot.targetAmountPaise!)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.normal,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Tap to add money', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _hex(String hex) {
  final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return v == null ? AppColors.marigold : Color(0xFF000000 | v);
}

class _PotCard extends ConsumerWidget {
  const _PotCard({required this.view, required this.height});
  final PotView view;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pot = view.pot;
    final pct = view.progressPct;
    final me = ref.watch(currentUserIdProvider);
    final meta = pot.targetDate != null
        ? 'by ${DateFormat('d MMM').format(pot.targetDate!)}'
        : (pct != null
              ? '${pct.round()}% there'
              : (view.roomName ?? 'Personal'));

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_hex(pot.gradientStart), _hex(pot.gradientEnd)],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -32,
            top: -40,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -48,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        pot.name.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      meta,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  formatPaise(view.savedPaise),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pot.targetAmountPaise == null
                      ? (view.roomName != null
                            ? 'Group pot · ${view.roomName}'
                            : 'No target — just stacking')
                      : 'of ${formatPaise(pot.targetAmountPaise!)}${pct == null ? '' : ' · ${pct.round()}%'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    _CardIconButton(
                      icon: Icons.add,
                      tooltip: 'Add money',
                      onTap: () => ContributeSheet.show(context, potId: pot.id),
                    ),
                    if (pot.userId == me)
                      _CardIconButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Delete pot',
                        onTap: () => _confirmDelete(context, ref),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Delete "${view.pot.name}"?',
          style: AppTextStyles.titleSmall,
        ),
        content: Text(
          'The pot disappears for everyone. Money already moved stays wherever you actually keep it.',
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
    if (ok == true) {
      await ref.read(potRepositoryProvider).deletePot(view.pot.id);
    }
  }
}

class _CardIconButton extends StatelessWidget {
  const _CardIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 17, color: Colors.white),
      ),
    ),
  );
}

/// Dashed-feeling outline card at the back of the stack that gently pulses.
class _NewPotCard extends StatefulWidget {
  const _NewPotCard();

  @override
  State<_NewPotCard> createState() => _NewPotCardState();
}

class _NewPotCardState extends State<_NewPotCard>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => CreatePotSheet.show(context),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (ctx, child) => Container(
          height: 90,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: AppColors.textPrimary.withValues(
                alpha: 0.15 + 0.2 * _pulse.value,
              ),
            ),
          ),
          child: child,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 22, color: AppColors.textSecondary),
            SizedBox(height: 4),
            Text(
              'New Pot',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
