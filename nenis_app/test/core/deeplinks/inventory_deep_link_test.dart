import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/core/deeplinks/deep_link_service.dart';

void main() {
  test('extrae una tarjeta NFC desde el enlace web', () {
    final link = extractInventoryTag(
      Uri.parse('https://app.nenisapp.com/caja/42/token-nfc-seguro'),
    );

    expect(link, isNotNull);
    expect(link!.businessId, 42);
    expect(link.token, 'token-nfc-seguro');
  });

  test('extrae una tarjeta NFC desde el scheme de la aplicación', () {
    final link = extractInventoryTag(
      Uri.parse('nenis://caja/42/token-nfc-seguro'),
    );

    expect(link, isNotNull);
    expect(link!.businessId, 42);
    expect(link.token, 'token-nfc-seguro');
  });

  test('rechaza enlaces de caja incompletos', () {
    expect(
      extractInventoryTag(Uri.parse('https://app.nenisapp.com/caja/42')),
      isNull,
    );
  });
}
