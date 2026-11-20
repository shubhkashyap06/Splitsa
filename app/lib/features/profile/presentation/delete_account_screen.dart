import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/money.dart';
import '../../../data/remote/session.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../shared/widgets/sheets.dart';
import '../../rooms/application/room_providers.dart';

/// Delete Account flow (UI_UX_SPEC.md §4, PRODUCT_LOGIC.md §6):
///   1. Blocked while any room has a non-zero balance — settle first, or
///      explicitly forfeit what you're *owed* (never what you owe).
///   2. Plain-language explainer of what's deleted vs kept anonymized.
///   3. Type-to-confirm (email — Splitsa signs in with email OTP) + a solid
///      rust pill. Tap, not swipe: rare and deliberate.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirm = TextEditingController();
  bool _forfeit = false;
  bool _deleting = false;
  String? _error;
  List<BlockingBalance>? _serverBlocking;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete(String email) async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(accountRepositoryProvider)
          .deleteAccount(confirmEmail: _confirm.text, forfeitOwed: _forfeit);
      if (!mounted) return;
      switch (result) {
        case AccountDeleted():
          context.go('/onboarding');
        case DeletionBlocked(:final balances):
          setState(() => _serverBlocking = balances);
      }
    } on AccountActionError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(currentUserEmailProvider) ?? '';
    final rooms = ref.watch(roomSummariesProvider) ?? const <RoomSummary>[];

    // Local courtesy check; the account-delete function is the real gate.
    final owing = rooms.where((r) => r.myNetPaise < 0).toList();
    final owed = rooms.where((r) => r.myNetPaise > 0).toList();
    final serverOwing =
        _serverBlocking?.where((b) => b.netBalancePaise < 0).toList() ??
        const [];
    final blocked =
        owing.isNotEmpty ||
        serverOwing.isNotEmpty ||
        (owed.isNotEmpty && !_forfeit);
    final typedOk =
        email.isNotEmpty &&
        _confirm.text.trim().toLowerCase() == email.toLowerCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Delete account', style: AppTextStyles.titleSmall),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            if (owing.isNotEmpty || serverOwing.isNotEmpty) ...[
              Text('Settle these first', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your room-mates are counting on these. Clear them and come back.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final r in owing)
                _BalanceRow(
                  name: r.room.name,
                  label: 'You owe ${formatPaise(-r.myNetPaise)}',
                  color: AppColors.rust,
                  onSettle: () => context.go('/rooms/${r.room.id}'),
                ),
              for (final b in serverOwing.where(
                (b) => owing.every((r) => r.room.id != b.roomId),
              ))
                _BalanceRow(
                  name: b.roomName,
                  label: 'You owe ${formatPaise(-b.netBalancePaise)}',
                  color: AppColors.rust,
                  onSettle: () => context.go('/rooms/${b.roomId}'),
                ),
              const SizedBox(height: AppSpacing.xxl),
            ],
            if (owed.isNotEmpty) ...[
              Text('People still owe you', style: AppTextStyles.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              for (final r in owed)
                _BalanceRow(
                  name: r.room.name,
                  label: 'Owed ${formatPaise(r.myNetPaise)}',
                  color: AppColors.marigold,
                  onSettle: () => context.go('/rooms/${r.room.id}'),
                ),
              CheckboxListTile(
                value: _forfeit,
                onChanged: (v) => setState(() => _forfeit = v ?? false),
                activeColor: AppColors.rust,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'Write it off — I\'m okay not getting this back',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            Text('What happens', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.md),
            const _Explainer(
              icon: Icons.delete_outline,
              title: 'Gone right away',
              body:
                  'Your profile, personal spends, personal pots, and notification settings.',
            ),
            const _Explainer(
              icon: Icons.people_outline,
              title: 'Kept as "Deleted user"',
              body:
                  'Shared expenses and settle-ups stay so your room-mates\' balances don\'t break. Your name is replaced — nothing else about you remains.',
            ),
            const SizedBox(height: AppSpacing.xxl),
            DarkField(
              controller: _confirm,
              label: 'Type your email to confirm',
              hint: email,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.rust),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            PillButton(
              label: 'Delete my account',
              color: AppColors.rust,
              foreground: AppColors.onBtn,
              loading: _deleting,
              onPressed: blocked || !typedOk ? null : () => _delete(email),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.name,
    required this.label,
    required this.color,
    required this.onSettle,
  });
  final String name;
  final String label;
  final Color color;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.cardBorder),
      boxShadow: AppColors.cardShadow,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppTextStyles.bodySemibold),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(color: color),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onSettle, child: const Text('Settle up first')),
      ],
    ),
  );
}

class _Explainer extends StatelessWidget {
  const _Explainer({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodySemibold),
              const SizedBox(height: 2),
              Text(body, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}
