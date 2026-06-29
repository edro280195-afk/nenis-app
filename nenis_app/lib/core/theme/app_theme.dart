import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_text_styles.dart';
import 'brand_theme.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light({BrandTheme brand = BrandTheme.neni}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brand.primary,
      brightness: Brightness.light,
      primary: brand.primary,
      onPrimary: brand.onPrimary,
      secondary: AppColors.lavender,
      onSecondary: AppColors.surface,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      surfaceContainerHighest: AppColors.surfaceCream,
      error: AppColors.statusPendingFg,
      onError: AppColors.surface,
    );

    final textTheme = AppTextStyles.toTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surfaceCream,
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: AppColors.ink, size: 24),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 56),
          shape: const StadiumBorder(),
          textStyle: AppTextStyles.button,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: AppTextStyles.fieldPlaceholder,
        border: OutlineInputBorder(
          borderRadius: AppRadii.fieldRadius,
          borderSide: const BorderSide(color: AppColors.line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.fieldRadius,
          borderSide: const BorderSide(color: AppColors.line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.fieldRadius,
          borderSide: BorderSide(color: brand.primary, width: 1.5),
        ),
      ),
      extensions: [BrandColors(brand: brand)],
    );
  }
}
