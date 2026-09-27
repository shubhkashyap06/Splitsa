/// AppTheme — assembles all design tokens into a Flutter ThemeData.
///
/// The app always runs in dark mode (true black per spec).
/// ThemeData.light() is used only for the numeric-entry light-mode flip
/// sheets (Add Expense, Settle Up entry) — those override the ambient
/// theme locally, not globally.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_spacing.dart';

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      surface:    AppColors.background,
      onSurface:  AppColors.textPrimary,
      primary:    AppColors.marigold,
      onPrimary:  AppColors.black,
      secondary:  AppColors.jade,
      onSecondary: AppColors.textPrimary,
      error:      AppColors.rust,
      onError:    AppColors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        side: const BorderSide(color: AppColors.cardBorder, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF111113),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        borderSide: const BorderSide(color: AppColors.marigold, width: 1.5),
      ),
      hintStyle: AppTextStyles.bodyMedium,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    textTheme: const TextTheme(
      displayLarge:  AppTextStyles.titleLarge,
      displayMedium: AppTextStyles.titleMedium,
      titleMedium:   AppTextStyles.titleSmall,
      bodyLarge:     AppTextStyles.bodyLarge,
      bodyMedium:    AppTextStyles.bodyMedium,
      bodySmall:     AppTextStyles.bodySmall,
      labelSmall:    AppTextStyles.labelSmall,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.cardBorder,
      thickness: 1,
      space: 1,
    ),
  );

  /// Light theme — used ONLY for the numeric-entry flip sheets (Add Expense,
  /// Settle Up entry). Apply via Theme(data: AppTheme.lightEntry, child: ...).
  static ThemeData get lightEntry => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: const ColorScheme.light(
      surface:   Colors.white,
      onSurface: AppColors.black,
      primary:   AppColors.black,
      onPrimary: Colors.white,
    ),
  );
}
