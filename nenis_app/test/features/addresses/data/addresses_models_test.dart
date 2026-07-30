import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/addresses/data/addresses_models.dart';

void main() {
  group('validateAddressCoordinatesInput', () {
    test('acepta coordenadas vacias o dentro de rango', () {
      expect(validateAddressCoordinatesInput('', ''), isNull);
      expect(validateAddressCoordinatesInput('27.4861', '-99.5069'), isNull);
    });

    test('rechaza latitud y longitud fuera de rango', () {
      expect(
        validateAddressCoordinatesInput('999', '-99.5069'),
        'La latitud debe estar entre -90 y 90.',
      );
      expect(
        validateAddressCoordinatesInput('27.4861', '-999'),
        'La longitud debe estar entre -180 y 180.',
      );
    });

    test('rechaza capturar solo una coordenada', () {
      expect(
        validateAddressCoordinatesInput('27.4861', ''),
        'Captura latitud y longitud, o deja ambas vacias.',
      );
    });
  });
}
