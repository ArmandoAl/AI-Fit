import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Editorial fashion type — Cormorant Garamond (display) + Outfit (UI).
class AppTypography {
  AppTypography._();

  static String get displayFontFamily => 'Cormorant Garamond';
  static String get bodyFontFamily => 'Outfit';

  static TextTheme textTheme(ColorScheme colors) {
    final display = GoogleFonts.cormorantGaramondTextTheme();
    final body = GoogleFonts.outfitTextTheme();

    return TextTheme(
      displayLarge: display.displayLarge?.copyWith(
        fontSize: 48,
        fontWeight: FontWeight.w600,
        height: 52 / 48,
        letterSpacing: -0.6,
        color: colors.onSurface,
      ),
      headlineLarge: display.headlineLarge?.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        height: 42 / 36,
        letterSpacing: -0.3,
        color: colors.onSurface,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 34 / 28,
        color: colors.onSurface,
      ),
      headlineSmall: display.headlineSmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 28 / 22,
        color: colors.onSurface,
      ),
      titleLarge: body.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 26 / 18,
        letterSpacing: 0.1,
        color: colors.onSurface,
      ),
      titleMedium: body.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 24 / 16,
        color: colors.onSurface,
      ),
      titleSmall: body.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        letterSpacing: 0.1,
        color: colors.onSurface,
      ),
      bodyLarge: body.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 26 / 16,
        color: colors.onSurface,
      ),
      bodyMedium: body.bodyMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 24 / 15,
        color: colors.onSurface,
      ),
      bodySmall: body.bodySmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 20 / 13,
        color: AppColors.secondary,
      ),
      labelLarge: body.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 18 / 13,
        letterSpacing: 1.4,
        color: colors.onSurface,
      ),
      labelMedium: body.labelMedium?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 16 / 11,
        letterSpacing: 1.6,
        color: AppColors.tertiary,
      ),
      labelSmall: body.labelSmall?.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        height: 14 / 10,
        letterSpacing: 1.8,
        color: AppColors.tertiary,
      ),
    );
  }
}
