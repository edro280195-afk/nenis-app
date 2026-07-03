import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/core/auth/auth_repository.dart';

void main() {
  group('OtpRequestResult', () {
    test('lee el estado real informado por el API', () {
      final result = OtpRequestResult.fromJson({
        'devMode': false,
        'providerConfigured': true,
      });

      expect(result.devMode, isFalse);
      expect(result.providerConfigured, isTrue);
    });

    test('usa valores seguros cuando el API omite campos opcionales', () {
      final result = OtpRequestResult.fromJson({});

      expect(result.devMode, isFalse);
      expect(result.providerConfigured, isFalse);
    });
  });
}
