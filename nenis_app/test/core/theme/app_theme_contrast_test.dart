import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/core/theme/app_colors.dart';
import 'package:nenis_app/core/theme/app_theme.dart';
import 'package:nenis_app/core/theme/brand_theme.dart';

void main() {
  test('el rosa de marca sin ajustar NO cumple AA sobre el fondo', () {
    expect(
      AppTheme.contrastRatio(BrandTheme.neni.primary, AppColors.surfaceCream),
      lessThan(4.5),
    );
  });

  test('readableOn alcanza AA conservando el tono', () {
    final original = BrandTheme.neni.primary;
    final fixed = AppTheme.readableOn(original, AppColors.surfaceCream);

    expect(
      AppTheme.contrastRatio(fixed, AppColors.surfaceCream),
      greaterThanOrEqualTo(4.5),
    );
    final hueDiff =
        (HSLColor.fromColor(fixed).hue - HSLColor.fromColor(original).hue)
            .abs();
    expect(hueDiff, lessThan(2));
  });

  test('un color que ya cumple no se modifica', () {
    const ink = AppColors.ink;
    expect(AppTheme.readableOn(ink, AppColors.surfaceCream), ink);
  });

  testWidgets('el tema aplica el color legible a los botones de texto', (
    tester,
  ) async {
    final theme = AppTheme.light();
    final color = theme.textButtonTheme.style!.foregroundColor!.resolve(
      <WidgetState>{},
    );
    expect(
      AppTheme.contrastRatio(color!, AppColors.surfaceCream),
      greaterThanOrEqualTo(4.5),
    );
  });

  group('paleta con contraste AA en TODOS los fondos de la app', () {
    // Los fondos donde de verdad aparece texto, incluido el caso más duro: el brillo
    // rosa del fondo (NeniBackground) y los chips rosados.
    final backgrounds = <String, Color>{
      'blanco': Colors.white,
      'surface': AppColors.surface,
      'crema': AppColors.surfaceCream,
      'pista del segmentado (5% de tinta sobre crema)': Color.alphaBlend(
        AppColors.segTrack,
        AppColors.surfaceCream,
      ),
      'brillo rosa del fondo': const Color(0xFFFFE1EE),
      'brillo durazno del fondo': const Color(0xFFFFE7D8),
      'chip rosa': const Color(0xFFFFE1EC),
      'chip dorado': const Color(0xFFFFF2D4),
    };
    final palette = <String, Color>{
      'ink2': AppColors.ink2,
      'ink3': AppColors.ink3,
      'neniDeep': AppColors.neniDeep,
      'textAa': AppColors.textAa,
      'linkAa': AppColors.linkAa,
    };

    for (final color in palette.entries) {
      test('${color.key} cumple 4.5:1 sobre cada fondo', () {
        for (final background in backgrounds.entries) {
          expect(
            AppTheme.contrastRatio(color.value, background.value),
            greaterThanOrEqualTo(4.5),
            reason: '${color.key} sobre ${background.key}',
          );
        }
      });
    }

    test('conservan el tono de la marca (solo se oscurecen)', () {
      // Tonos originales: ink2 #8A6F82, ink3 #B6A4B1, neniDeep #E84E83.
      const originals = {
        'ink2': Color(0xFF8A6F82),
        'ink3': Color(0xFFB6A4B1),
        'neniDeep': Color(0xFFE84E83),
      };
      for (final entry in originals.entries) {
        final now = palette[entry.key]!;
        final hueDiff =
            (HSLColor.fromColor(now).hue - HSLColor.fromColor(entry.value).hue)
                .abs();
        expect(hueDiff, lessThan(6), reason: entry.key);
        expect(
          HSLColor.fromColor(now).lightness,
          lessThan(HSLColor.fromColor(entry.value).lightness),
          reason: '${entry.key} debe ser más oscuro que antes',
        );
      }
    });

    test('se mantiene la jerarquía: ink > ink2 > ink3 en contraste', () {
      double onCream(Color c) =>
          AppTheme.contrastRatio(c, AppColors.surfaceCream);
      expect(onCream(AppColors.ink), greaterThan(onCream(AppColors.ink2)));
      expect(onCream(AppColors.ink2), greaterThan(onCream(AppColors.ink3)));
    });

    test(
      'inkDisabled es el gris suave de antes, solo para controles deshabilitados',
      () {
        expect(AppColors.inkDisabled, const Color(0xFFB6A4B1));
        expect(
          AppTheme.contrastRatio(AppColors.inkDisabled, AppColors.surfaceCream),
          lessThan(3),
        );
      },
    );
  });

  test('el aviso del código y los enlaces usan colores AA', () {
    for (final c in [AppColors.textAa, AppColors.linkAa]) {
      expect(
        AppTheme.contrastRatio(c, AppColors.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        AppTheme.contrastRatio(c, AppColors.surfaceCream),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}
