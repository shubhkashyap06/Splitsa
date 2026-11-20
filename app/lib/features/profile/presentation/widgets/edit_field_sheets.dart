import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/money.dart';
import '../../../../data/local/local_streams.dart';
import '../../../../data/remote/session.dart';
import '../../../../data/repositories/profile_repository.dart';
import '../../../../shared/widgets/sheets.dart';

/// Single-field edit sheet used for name / UPI / budget.
class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({
    required this.title,
    required this.label,
    required this.initial,
    required this.onSave,
    this.hint,
    this.helper,
    this.keyboardType,
    this.prefixText,
    this.allowClear = false,
  });
  final String title;
  final String label;
  final String initial;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;
  final String? prefixText;
  final bool allowClear;

  /// Returns an error message, or null on success.
  final Future<String?> Function(WidgetRef ref, String value) onSave;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(String value) async {
    final err = await widget.onSave(ref, value);
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DarkSheet(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DarkField(
            controller: _controller,
            label: widget.label,
            hint: widget.hint,
            autofocus: true,
            keyboardType: widget.keyboardType,
            prefixText: widget.prefixText,
            errorText: _error,
            onChanged: (_) => setState(() => _error = null),
          ),
          if (widget.helper != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(widget.helper!, style: AppTextStyles.bodySmall),
          ],
          const SizedBox(height: AppSpacing.xl),
          PillButton(label: 'Save', onPressed: () => _save(_controller.text)),
          if (widget.allowClear && widget.initial.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: () => _save(''),
                child: Text('Remove', style: TextStyle(color: AppColors.rust)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<String?> _guard(Future<void> Function() run) async {
  try {
    await run();
    return null;
  } on ProfileValidationError catch (e) {
    return e.message;
  }
}

abstract final class EditNameSheet {
  static Future<void> show(BuildContext context, String current) =>
      showAppSheet(
        context,
        (_) => _EditSheet(
          title: 'Your name',
          label: 'Display name',
          initial: current,
          helper: 'This is what your roommates see on shared expenses.',
          onSave: (ref, v) => _guard(
            () => ref
                .read(profileRepositoryProvider)
                .update(ref.read(currentUserIdProvider)!, displayName: v),
          ),
        ),
      );
}

abstract final class EditUpiSheet {
  static Future<void> show(
    BuildContext context,
    String? current,
  ) => showAppSheet(
    context,
    (_) => _EditSheet(
      title: 'UPI ID',
      label: 'UPI ID',
      hint: 'name@okbank',
      initial: current ?? '',
      allowClear: true,
      keyboardType: TextInputType.emailAddress,
      helper:
          'Only people in your rooms can see this, so they can pay you back. It never shows on lock-screen notifications.',
      onSave: (ref, v) {
        final me = ref.read(currentUserIdProvider)!;
        return _guard(
          () => v.trim().isEmpty
              ? ref.read(profileRepositoryProvider).update(me, clearUpi: true)
              : ref.read(profileRepositoryProvider).update(me, upiId: v),
        );
      },
    ),
  );
}

abstract final class EditBudgetSheet {
  static Future<void> show(BuildContext context) => showAppSheet(context, (
    ctx,
  ) {
    return Consumer(
      builder: (ctx, ref, _) {
        final current = ref
            .read(myProfileProvider)
            .valueOrNull
            ?.monthlyBudgetPaise;
        return _EditSheet(
          title: 'Monthly budget',
          label: 'Budget',
          hint: '15000',
          prefixText: '₹ ',
          initial: current == null ? '' : '${current ~/ 100}',
          allowClear: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          helper:
              'Home shows what\'s left after spends and money moved to pots.',
          onSave: (ref, v) async {
            final me = ref.read(currentUserIdProvider)!;
            if (v.trim().isEmpty) {
              return _guard(
                () => ref
                    .read(profileRepositoryProvider)
                    .update(me, clearBudget: true),
              );
            }
            final paise = parseRupeesToPaise(v);
            if (paise == null) return 'Enter an amount like 15000';
            return _guard(
              () => ref
                  .read(profileRepositoryProvider)
                  .update(me, monthlyBudgetPaise: paise),
            );
          },
        );
      },
    );
  });
}

/// Notification preferences (NOTIFICATIONS.md §4): Regular-tier toggle +
/// quiet hours. Urgent (direct money requests) is deliberately not
/// switchable here — that's the OS channel's job, never ours to route around.
class NotificationPrefsSheet extends ConsumerWidget {
  const NotificationPrefsSheet({super.key});

  static Future<void> show(BuildContext context) =>
      showAppSheet(context, (_) => const NotificationPrefsSheet());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final me = ref.watch(currentUserIdProvider);
    if (profile == null || me == null) {
      return const DarkSheet(child: SizedBox(height: 120));
    }
    final repo = ref.read(profileRepositoryProvider);
    final hasQuiet =
        profile.quietHoursStart != null && profile.quietHoursEnd != null;

    Future<void> pick(bool start) async {
      final initial =
          _parse(start ? profile.quietHoursStart : profile.quietHoursEnd) ??
          TimeOfDay(hour: start ? 22 : 8, minute: 0);
      final t = await showTimePicker(context: context, initialTime: initial);
      if (t == null) return;
      final s =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      await repo.update(
        me,
        quietStart: start ? s : (profile.quietHoursStart ?? '22:00'),
        quietEnd: start ? (profile.quietHoursEnd ?? '08:00') : s,
      );
    }

    return DarkSheet(
      title: 'Notifications',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Row(
            title: 'Money requests',
            subtitle:
                'When someone asks you to pay — always on, so you never miss one.',
            trailing: Icon(
              Icons.lock_outline,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
          Divider(color: AppColors.cardBorder),
          _Row(
            title: 'Everything else',
            subtitle:
                'New expenses, pot milestones, weekly summaries — delivered silently.',
            trailing: Switch(
              value: profile.notificationsRegularEnabled,
              activeThumbColor: AppColors.marigold,
              onChanged: (v) => repo.update(me, regularNotifications: v),
            ),
          ),
          Divider(color: AppColors.cardBorder),
          _Row(
            title: 'Quiet hours',
            subtitle: hasQuiet
                ? 'Silent updates wait until ${profile.quietHoursEnd}. Money requests still come through.'
                : 'Hold silent updates overnight.',
            trailing: Switch(
              value: hasQuiet,
              activeThumbColor: AppColors.marigold,
              onChanged: (v) => v
                  ? repo.update(me, quietStart: '22:00', quietEnd: '08:00')
                  : repo.update(me, clearQuietHours: true),
            ),
          ),
          if (hasQuiet)
            Row(
              children: [
                TextButton(
                  onPressed: () => pick(true),
                  child: Text('From ${profile.quietHoursStart}'),
                ),
                TextButton(
                  onPressed: () => pick(false),
                  child: Text('Until ${profile.quietHoursEnd}'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static TimeOfDay? _parse(String? hhmm) {
    if (hhmm == null || hhmm.length < 5) return null;
    final h = int.tryParse(hhmm.substring(0, 2));
    final m = int.tryParse(hhmm.substring(3, 5));
    return h == null || m == null ? null : TimeOfDay(hour: h, minute: m);
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodySemibold),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        trailing,
      ],
    ),
  );
}
