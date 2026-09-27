import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/application/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            const Text('Account', style: AppTextStyles.labelCaps),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              title: const Text('Name', style: AppTextStyles.bodyLarge),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              contentPadding: EdgeInsets.zero,
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              title: const Text('UPI ID', style: AppTextStyles.bodyLarge),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              contentPadding: EdgeInsets.zero,
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              title: const Text('Notifications', style: AppTextStyles.bodyLarge),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              contentPadding: EdgeInsets.zero,
              onTap: () {},
            ),
            
            const SizedBox(height: AppSpacing.xxxl),
            const Text('More', style: AppTextStyles.labelCaps),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              title: const Text('Sign out', style: AppTextStyles.bodyLarge),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                ref.read(authNotifierProvider.notifier).signOut();
                context.go('/onboarding');
              },
            ),
            const Divider(),
            ListTile(
              title: Text('Delete account', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.rust)),
              contentPadding: EdgeInsets.zero,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}
