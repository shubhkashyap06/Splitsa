import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/money.dart';
import '../../../../data/remote/session.dart';
import '../../../../data/repositories/pot_repository.dart';
import '../../../../shared/widgets/sheets.dart';
import '../../application/pot_providers.dart';
import 'create_pot_sheet.dart';

/// "Add money to a Pot" — the `/quick-add?type=pot-contribution` sheet and
/// every Pot card's add-funds button (UI_UX_SPEC.md §4). No category, no
/// split: just a pot and an amount.
class ContributeSheet extends ConsumerStatefulWidget {
  const ContributeSheet({super.key, this.potId, this.initialAmountPaise});
  final String? potId;
  final int? initialAmountPaise;

  static Future<bool?> show(
    BuildContext context, {
    String? potId,
    int? initialAmountPaise,
  }) => showAppSheet<bool>(
    context,
    (_) =>
        ContributeSheet(potId: potId, initialAmountPaise: initialAmountPaise),
  );

  @override
  ConsumerState<ContributeSheet> createState() => _ContributeSheetState();
}

class _ContributeSheetState extends ConsumerState<ContributeSheet> {
  late String? _potId = widget.potId;
  late final _amount = TextEditingController(
    text: widget.initialAmountPaise == null
        ? ''
        : '${widget.initialAmountPaise! ~/ 100}',
  );
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final me = ref.read(currentUserIdProvider);
    final paise = parseRupeesToPaise(_amount.text);
    if (me == null || _potId == null) return;
    if (paise == null || paise == 0) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    try {
      await ref
          .read(potRepositoryProvider)
          .contribute(potId: _potId!, userId: me, amountPaise: paise);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${formatPaise(paise)} moved to your pot 🌱'),
          backgroundColor: AppColors.card,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PotValidationError catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pots = ref.watch(potViewsProvider) ?? const <PotView>[];
    if (_potId == null && pots.length == 1) _potId = pots.first.pot.id;

    if (pots.isEmpty) {
      return DarkSheet(
        title: 'Add to a pot',
        child: EmptyState(
          icon: Icons.spa_outlined,
          title: 'No pots yet',
          body: 'Create a pot first — a goal to save towards.',
          actionLabel: 'Create a pot',
          onAction: () {
            final root = Navigator.of(context, rootNavigator: true).context;
            Navigator.of(context).pop();
            CreatePotSheet.show(root, personal: true);
          },
        ),
      );
    }

    return DarkSheet(
      title: 'Add to a pot',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WHICH POT?', style: AppTextStyles.labelCaps),
          const SizedBox(height: AppSpacing.sm),
          for (final v in pots)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: GestureDetector(
                onTap: () => setState(() => _potId = v.pot.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: v.pot.id == _potId
                        ? AppColors.jade.withValues(alpha: 0.1)
                        : AppColors.textPrimary.withValues(alpha: 0.04),
                    border: Border.all(
                      color: v.pot.id == _potId
                          ? AppColors.jade.withValues(alpha: 0.5)
                          : AppColors.textPrimary.withValues(alpha: 0.07),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          v.pot.name,
                          style: AppTextStyles.bodySemibold,
                        ),
                      ),
                      Text(
                        formatPaise(v.savedPaise),
                        style: AppTextStyles.moneyList(color: AppColors.jade),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          DarkField(
            controller: _amount,
            label: 'Amount',
            hint: '500',
            prefixText: '₹ ',
            autofocus: widget.initialAmountPaise == null,
            errorText: _error,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: AppSpacing.xl),
          PillButton(
            label: 'Move it',
            color: AppColors.jade,
            foreground: AppColors.onBtn,
            onPressed: _potId == null ? null : _save,
          ),
        ],
      ),
    );
  }
}
