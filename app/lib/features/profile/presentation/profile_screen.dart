import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/money.dart';
import '../../../data/local/database.dart';
import '../../../data/local/local_streams.dart';
import '../../../data/remote/session.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/motion.dart';
import '../../../shared/widgets/sheets.dart';
import '../../auth/application/auth_provider.dart';
import '../../rooms/application/room_providers.dart';
import 'widgets/edit_field_sheets.dart';

/// Profile (UI_UX_SPEC.md §4): pushed from Home's avatar, hides the tab bar.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final me = ref.watch(currentUserIdProvider) ?? '';
    final rooms = ref.watch(roomSummariesProvider)?.length ?? 0;
    final name = profile?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xxxl,
          ),
          children: [
            Center(
              child: Column(
                children: [
                  SplitsaAvatar(
                    name: name.isEmpty ? '?' : name,
                    tone: toneFor(me),
                    size: 84,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(name, style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  if (profile != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        'Member since ${profile.createdAt.year} · potli fam 🎒',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            Text('ACCOUNT', style: AppTextStyles.labelCaps),
            const SizedBox(height: AppSpacing.sm),
            _SettingsRow(
              icon: Icons.person_outline,
              tone: AppColors.textSecondary,
              title: 'Name',
              value: name,
              onTap: () => EditNameSheet.show(context, name),
            ),
            _SettingsRow(
              icon: Icons.account_balance_outlined,
              tone: AppColors.marigold,
              title: 'Linked UPI ID',
              value: profile?.upiId ?? 'Add one',
              onTap: () => EditUpiSheet.show(context, profile?.upiId),
            ),
            _SettingsRow(
              icon: Icons.account_balance_wallet_outlined,
              tone: AppColors.jade,
              title: 'Monthly budget',
              value: profile?.monthlyBudgetPaise == null
                  ? 'Not set'
                  : formatPaise(profile!.monthlyBudgetPaise!),
              onTap: () => EditBudgetSheet.show(context),
            ),
            _SettingsRow(
              icon: AppColors.isNight
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
              tone: AppColors.lilacInk,
              title: 'Appearance',
              value: appearanceLabel(ref.watch(appearanceSettingProvider)),
              onTap: () => _pickAppearance(context, ref),
            ),
            _SettingsRow(
              icon: Icons.notifications_none,
              tone: AppColors.textSecondary,
              title: 'Notifications',
              onTap: () => NotificationPrefsSheet.show(context),
            ),
            _SettingsRow(
              icon: Icons.groups_outlined,
              tone: AppColors.textSecondary,
              title: 'Rooms I\'m in',
              value: '$rooms',
              onTap: () => context.go('/rooms'),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text('MORE', style: AppTextStyles.labelCaps),
            const SizedBox(height: AppSpacing.sm),
            _SettingsRow(
              icon: Icons.download_outlined,
              tone: AppColors.textSecondary,
              title: 'Export my data',
              onTap: () => _exportData(context, ref),
            ),
            _SettingsRow(
              icon: Icons.lock_outline,
              tone: AppColors.textSecondary,
              title: 'Privacy',
              onTap: () => showToast(
                context,
                'Only your room-mates see your name & UPI ID. Personal spends stay yours.',
              ),
            ),
            _SettingsRow(
              icon: Icons.logout,
              tone: AppColors.rust,
              title: 'Log out',
              titleColor: AppColors.rust,
              showChevron: false,
              onTap: () async {
                await ref.read(authNotifierProvider.notifier).signOut();
                if (context.mounted) context.go('/onboarding');
              },
            ),
            const SizedBox(height: AppSpacing.xxxl),
            // Destructive — visually separated from routine settings.
            _SettingsRow(
              icon: Icons.delete_outline,
              tone: AppColors.rust,
              title: 'Delete account',
              titleColor: AppColors.rust,
              onTap: () => context.push('/profile/delete'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAppearance(BuildContext context, WidgetRef ref) {
    final current = ref.read(appearanceSettingProvider);
    return showAppSheet(
      context,
      (ctx) => DarkSheet(
        title: 'Appearance',
        child: Column(
          children: [
            for (final (mode, icon, hint) in [
              (
                ThemeMode.system,
                Icons.brightness_auto_outlined,
                'Day by day, night by night',
              ),
              (
                ThemeMode.light,
                Icons.light_mode_outlined,
                'Warm mist and white cards',
              ),
              (
                ThemeMode.dark,
                Icons.dark_mode_outlined,
                'Soft charcoal, easy on the eyes',
              ),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: PressSpring(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ref.read(appearanceSettingProvider.notifier).set(mode);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: AppColors.cardDecoration(radius: 20).copyWith(
                      border: Border.all(
                        color: mode == current
                            ? AppColors.jade
                            : AppColors.cardBorder,
                        width: mode == current ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, color: AppColors.textPrimary),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appearanceLabel(mode),
                                style: AppTextStyles.bodySemibold,
                              ),
                              Text(hint, style: AppTextStyles.bodySmall),
                            ],
                          ),
                        ),
                        if (mode == current)
                          Icon(Icons.check_circle, color: AppColors.jade),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// "Export my data" (SECURITY.md §2 Privacy): copies everything this
  /// device holds about the user as JSON. No PII leaves the device unasked.
  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final db = ref.read(appDatabaseProvider);
    final me = ref.read(currentUserIdProvider);
    if (me == null) return;
    final profile = await db.profileDao.getProfile(me);
    final personal = await (db.select(
      db.personalExpensesTable,
    )..where((t) => t.userId.equals(me))).get();
    final splits = await (db.select(
      db.expenseSplitsTable,
    )..where((t) => t.userId.equals(me))).get();
    final paid = await (db.select(
      db.expensesTable,
    )..where((t) => t.paidBy.equals(me))).get();
    final contributions = await (db.select(
      db.potContributionsTable,
    )..where((t) => t.userId.equals(me))).get();

    final export = {
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'profile': profile?.toJson(),
      'personal_expenses': [for (final r in personal) r.toJson()],
      'expenses_paid': [for (final r in paid) r.toJson()],
      'my_shares': [for (final r in splits) r.toJson()],
      'pot_contributions': [for (final r in contributions) r.toJson()],
    };
    await Clipboard.setData(
      ClipboardData(text: const JsonEncoder.withIndent('  ').convert(export)),
    );
    if (context.mounted) {
      showToast(
        context,
        'Your data is copied as JSON — paste it anywhere to keep it',
      );
    }
  }
}

class _SettingsRow extends StatefulWidget {
  const _SettingsRow({
    required this.icon,
    required this.tone,
    required this.title,
    required this.onTap,
    this.value,
    this.titleColor,
    this.showChevron = true,
  });
  final IconData icon;
  final Color tone;
  final String title;
  final String? value;
  final Color? titleColor;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  State<_SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<_SettingsRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.textPrimary.withValues(alpha: 0.04)
              : Colors.transparent,
          border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: widget.tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, size: 17, color: widget.tone),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                widget.title,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: widget.titleColor,
                ),
              ),
            ),
            if (widget.value != null)
              Flexible(
                child: Text(
                  widget.value!,
                  style: AppTextStyles.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (widget.showChevron)
              Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
