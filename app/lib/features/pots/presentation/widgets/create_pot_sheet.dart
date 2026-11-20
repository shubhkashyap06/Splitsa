import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/money.dart';
import '../../../../data/remote/session.dart';
import '../../../../data/repositories/pot_repository.dart';
import '../../../../shared/widgets/sheets.dart';
import '../../../rooms/application/room_providers.dart';

class CreatePotSheet extends ConsumerStatefulWidget {
  const CreatePotSheet({super.key, this.personal = false});

  /// Lock to a personal pot (the "Your Potli" empty state).
  final bool personal;

  static Future<void> show(BuildContext context, {bool personal = false}) =>
      showAppSheet(context, (_) => CreatePotSheet(personal: personal));

  @override
  ConsumerState<CreatePotSheet> createState() => _CreatePotSheetState();
}

class _CreatePotSheetState extends ConsumerState<CreatePotSheet> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  String? _roomId; // null = personal
  int _gradient = 0;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final me = ref.read(currentUserIdProvider);
    if (me == null) return;
    final targetText = _target.text.trim();
    final target = targetText.isEmpty ? null : parseRupeesToPaise(targetText);
    if (targetText.isNotEmpty && target == null) {
      setState(() => _error = 'Target should be an amount like 5000');
      return;
    }
    try {
      await ref
          .read(potRepositoryProvider)
          .createPot(
            userId: me,
            name: _name.text,
            roomId: _roomId,
            targetAmountPaise: target,
            gradientIndex: _gradient,
          );
      if (mounted) Navigator.of(context).pop();
    } on PotValidationError catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(roomSummariesProvider) ?? const <RoomSummary>[];

    return DarkSheet(
      title: widget.personal ? 'Your Potli' : 'New pot',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DarkField(
            controller: _name,
            label: 'Name',
            hint: 'Goa trip, new phone, rainy day…',
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: AppSpacing.lg),
          DarkField(
            controller: _target,
            label: 'Target (optional)',
            hint: '50000',
            prefixText: '₹ ',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() => _error = null),
          ),
          if (!widget.personal && rooms.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('WHO\'S SAVING?', style: AppTextStyles.labelCaps),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _Choice(
                  label: 'Just me',
                  selected: _roomId == null,
                  onTap: () => setState(() => _roomId = null),
                ),
                for (final r in rooms)
                  _Choice(
                    label: r.room.name,
                    selected: _roomId == r.room.id,
                    onTap: () => setState(() => _roomId = r.room.id),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('COLOUR', style: AppTextStyles.labelCaps),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (var i = 0; i < kPotGradients.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _gradient = i),
                  child: Container(
                    margin: const EdgeInsets.only(right: AppSpacing.sm),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i == _gradient
                            ? AppColors.btn
                            : Colors.transparent,
                        width: 2,
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Color(
                            0xFF000000 |
                                int.parse(
                                  kPotGradients[i].$1.substring(1),
                                  radix: 16,
                                ),
                          ),
                          Color(
                            0xFF000000 |
                                int.parse(
                                  kPotGradients[i].$2.substring(1),
                                  radix: 16,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.rust),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          PillButton(label: 'Create pot', onPressed: _create),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.btn
            : AppColors.textPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.onBtn : AppColors.textSecondary,
        ),
      ),
    ),
  );
}
