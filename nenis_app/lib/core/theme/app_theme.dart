import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_text_styles.dart';
import 'brand_theme.dart';

class AppTheme {
  AppTheme._();

  /// Contraste WCAG entre dos colores (1 a 21).
  static double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Oscurece [color] solo lo necesario para que alcance [minRatio] de
  /// contraste sobre [background], conservando su tono. Los textos de botones
  /// usaban el color primario de la tienda tal cual: el rosa claro de marca da
  /// ~2.6:1 sobre el fondo, muy por debajo del mínimo AA (4.5:1) del producto.
  static Color readableOn(
    Color color,
    Color background, {
    double minRatio = 4.5,
  }) {
    var hsl = HSLColor.fromColor(color);
    var result = color;
    while (contrastRatio(result, background) < minRatio &&
        hsl.lightness > 0.04) {
      hsl = hsl.withLightness(hsl.lightness - 0.02);
      result = hsl.toColor();
    }
    return result;
  }

  static ThemeData light({BrandTheme brand = BrandTheme.neni}) {
    // Contra el más oscuro de los fondos de pantalla (crema) es el caso duro.
    final actionText = readableOn(brand.primary, AppColors.surfaceCream);

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
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: actionText),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(foregroundColor: actionText),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
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
