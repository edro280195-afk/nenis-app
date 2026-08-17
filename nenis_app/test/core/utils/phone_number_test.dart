import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/core/utils/phone_number.dart';

void main() {
  test('convierte un teléfono mexicano nacional a E.164', () {
    expect(PhoneNumberNormalizer.toE164('868 145 22 90'), '+528681452290');
  });

  test('conserva un teléfono mexicano que ya trae código de país', () {
    expect(PhoneNumberNormalizer.toE164('+52 868 145 22 90'), '+528681452290');
  });

  test('rechaza teléfonos que no pueden ser E.164', () {
    expect(PhoneNumberNormalizer.toE164('12345'), isNull);
    expect(PhoneNumberNormalizer.isValidE164('+528681452290'), isTrue);
    expect(PhoneNumberNormalizer.isValidE164('+521234'), isFalse);
  });
}
