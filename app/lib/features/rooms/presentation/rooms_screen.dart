import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';

class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rooms', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Text('Your rooms will appear here.', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 80),
          ],
        ),
      ),
    ),
  );
}
