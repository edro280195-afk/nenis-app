import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/core/auth/firebase_phone_auth_service.dart';

void main() {
  test('traduce errores del SDK a mensajes seguros en español', () {
    expect(
      FirebasePhoneAuthService.friendlyMessage(
        FirebaseAuthException(code: 'invalid-verification-code'),
      ),
      contains('código'),
    );
    expect(
      FirebasePhoneAuthService.friendlyMessage(
        FirebaseAuthException(code: 'too-many-requests'),
      ),
      contains('varios intentos'),
    );
  });

  test('un servicio sin Firebase no se anuncia como disponible', () {
    expect(FirebasePhoneAuthService(null).isAvailable, isFalse);
  });
}
