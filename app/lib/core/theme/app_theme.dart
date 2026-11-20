/// AppTheme — assembles the design tokens into ThemeData for Day and Night.
///
/// Both themes are built from the same token names (see app_colors.dart);
/// [build] is called with the palette that's active for the current
/// appearance setting (System / Day / Night — see theme_mode_provider.dart).
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  /// Plus Jakarta Sans — rounded and friendly without being childish.
  /// Fetched once and cached by google_fonts; falls back to the system font
  /// when offline on first launch, so nothing ever blocks on the network.
  static String? get fontFamily => GoogleFonts.plusJakartaSans().fontFamily;

  static ThemeData build(SplitsaPalette p) {
    final night = p.brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: p.brightness,
      surface: p.background,
      onSurface: p.textPrimary,
      primary: p.btn,
      onPrimary: p.onBtn,
      secondary: p.jade,
      onSecondary: p.onBtn,
      error: p.rust,
      onError: p.onBtn,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: night ? Brightness.light : Brightness.dark,
          statusBarBrightness: night ? Brightness.dark : Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: p.jade, width: 1.5),
        ),
        hintStyle: TextStyle(color: p.textTertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.titleLarge,
        displayMedium: AppTextStyles.titleMedium,
        titleMedium: AppTextStyles.titleSmall,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelSmall: AppTextStyles.labelSmall,
      ).apply(fontFamily: fontFamily),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.btn,
        contentTextStyle: TextStyle(
          color: p.onBtn,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(p.card),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.jade : p.fog,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.rust : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(p.onBtn),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.jade),
      dividerTheme: DividerThemeData(
        color: p.cardBorder,
        thickness: 1,
        space: 1,
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
