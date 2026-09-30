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
