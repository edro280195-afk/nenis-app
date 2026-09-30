import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Candado contra colores "a mano": el texto secundario y el rosa de marca salen de
/// `AppColors` (`ink2`, `ink3`, `neniDeep`), que cumplen contraste AA. Un literal
/// `Color(0xFF8A6F82)` / `0xFFB6A4B1` / `0xFFE84E83` copiado en una pantalla se queda con
/// el color viejo (3.7 / 1.9 / 3.0:1) aunque se corrija la paleta.
void main() {
  // Usos decorativos permitidos del rosa viejo: ilustraciones y degradados, no texto.
  const decorativePinkAllowed = {
    'lib/features/auth/widgets/auth_brand_scene.dart',
    'lib/features/tracking/widgets/rating_experience.dart',
    'lib/features/tracking/widgets/status_journey_card.dart',
    'lib/shared/widgets/glass_bottom_nav.dart',
  };

  test('nadie usa a mano el texto secundario viejo (#8A6F82)', () {
    expect(_filesWithLiteral('8A6F82', allowed: const {}), isEmpty);
  });

  test('el gris suave viejo (#B6A4B1) solo vive en AppColors.inkDisabled', () {
    expect(
      _filesWithLiteral(
        'B6A4B1',
        allowed: const {'lib/core/theme/app_colors.dart'},
      ),
      isEmpty,
    );
  });

  test('el rosa viejo (#E84E83) solo se usa a mano en ilustraciones', () {
    expect(
      _filesWithLiteral('E84E83', allowed: decorativePinkAllowed),
      isEmpty,
    );
  });
}

List<String> _filesWithLiteral(String hex, {required Set<String> allowed}) {
  final pattern = RegExp('0xFF$hex', caseSensitive: false);
  final files = <String>[];
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.split(Platform.pathSeparator).join('/');
    if (allowed.contains(path)) continue;
    if (pattern.hasMatch(entity.readAsStringSync())) files.add(path);
  }
  return files;
}
