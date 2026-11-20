/// Shared sheet chrome + small building blocks used across features.
/// Everything here paints from the active Day/Night palette.
library;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'motion.dart';

/// Opens a bottom sheet that springs up with a small rubber-band overshoot.
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.isNight
        ? const Color(0x99000000)
        : const Color(0x5917171A),
    sheetAnimationStyle: const AnimationStyle(
      curve: Motion.spring,
      duration: Duration(milliseconds: 520),
      reverseDuration: Duration(milliseconds: 260),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: builder(ctx),
    ),
  );
}

/// The standard sheet: soft background, rounded top, drag handle.
/// (Name kept from v1 — it now follows Day/Night.)
class DarkSheet extends StatelessWidget {
  const DarkSheet({super.key, required this.child, this.title});
  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: SheetHandle()),
              const SizedBox(height: AppSpacing.xl),
              if (title != null) ...[
                Text(title!, style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.lg),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 5,
    decoration: BoxDecoration(
      color: AppColors.textPrimary.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(100),
    ),
  );
}

/// The one solid pill in a group (UI_UX_SPEC.md §1). Ink in Day, cream in
/// Night by default; springs to 96% on press.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.foreground,
    this.loading = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? foreground;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.btn;
    final fg = foreground ?? AppColors.onBtn;
    final enabled = onPressed != null && !loading;
    return PressSpring(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: Motion.quick,
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          color: enabled || loading ? bg : bg.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(100),
        ),
        alignment: Alignment.center,
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: AppTextStyles.button.copyWith(
                      color: enabled || loading
                          ? fg
                          : fg.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Outlined secondary pill — pairs with [PillButton], never two solids.
class OutlinePillButton extends StatelessWidget {
  const OutlinePillButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => PressSpring(
    onTap: onPressed,
    child: Container(
      height: 54,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTextStyles.button.copyWith(color: AppColors.textPrimary),
      ),
    ),
  );
}

/// Soft text field: white card in Day, lifted charcoal in Night.
class DarkField extends StatelessWidget {
  const DarkField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.errorText,
    this.autofocus = false,
    this.prefixText,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
  });
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final String? errorText;
  final bool autofocus;
  final String? prefixText;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1.5]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: c, width: w),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          style: AppTextStyles.bodyLarge,
          cursorColor: AppColors.jade,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            errorText: errorText,
            hintStyle: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textTertiary,
            ),
            filled: true,
            fillColor: AppColors.card,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            enabledBorder: border(Colors.transparent),
            focusedBorder: border(AppColors.jade),
            errorBorder: border(AppColors.rust),
            focusedErrorBorder: border(AppColors.rust),
          ),
        ),
      ],
    );
  }
}

/// Friendly empty state — a gently floating icon, never a blank screen.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: AppColors.cardDecoration(radius: 28),
      child: Column(
        children: [
          Floating(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.jadeTint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: AppColors.jade),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTextStyles.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.lg),
            PillButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// Small "syncing" clock shown on rows written offline and not yet pushed.
class PendingMark extends StatelessWidget {
  const PendingMark({super.key});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Saved on this phone — syncs when you\'re online',
    child: Icon(Icons.schedule, size: 13, color: AppColors.textTertiary),
  );
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
