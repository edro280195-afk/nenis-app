import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

/// Encapsula el flujo nativo de Firebase Phone Auth y nunca expone mensajes
/// técnicos del SDK directamente a la interfaz.
class FirebasePhoneAuthService {
  FirebasePhoneAuthService(this._auth);

  final FirebaseAuth? _auth;
  String? _verificationId;
  int? _resendToken;
  bool _requestInProgress = false;

  bool get isAvailable => _auth != null;

  Future<void> sendCode(
    String phoneNumber, {
    required void Function() onCodeSent,
    Future<void> Function(PhoneAuthCredential credential)?
    onVerificationCompleted,
    void Function(FirebaseAuthException error)? onVerificationFailed,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw AuthException(
        'La verificación por SMS no está disponible en este momento.',
      );
    }
    if (_requestInProgress) return;

    _requestInProgress = true;
    try {
      await auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (credential) {
          _requestInProgress = false;
          final callback = onVerificationCompleted;
          if (callback != null) unawaited(callback(credential));
        },
        verificationFailed: (error) {
          _requestInProgress = false;
          onVerificationFailed?.call(error);
        },
        codeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _requestInProgress = false;
          onCodeSent();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
          _requestInProgress = false;
        },
      );
    } on FirebaseAuthException catch (error) {
      _requestInProgress = false;
      throw AuthException(friendlyMessage(error));
    } catch (_) {
      _requestInProgress = false;
      throw AuthException(
        'No pudimos enviar el código. Revisa tu conexión e inténtalo de nuevo.',
      );
    }
  }

  Future<String> verifyCode(String smsCode) async {
    final verificationId = _verificationId;
    final auth = _auth;
    if (auth == null || verificationId == null || verificationId.isEmpty) {
      throw AuthException('Solicita un código nuevo antes de continuar.');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(smsCode)) {
      throw AuthException('Escribe el código de 6 dígitos.');
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return signInWithCredential(credential);
  }

  Future<String> signInWithCredential(PhoneAuthCredential credential) async {
    final auth = _auth;
    if (auth == null) {
      throw AuthException(
        'La verificación por SMS no está disponible en este momento.',
      );
    }

    try {
      final userCredential = await auth.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        throw AuthException('No pudimos validar tu número de teléfono.');
      }
      return idToken;
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthException(friendlyMessage(error));
    } catch (_) {
      throw AuthException('No pudimos validar tu número de teléfono.');
    }
  }

  Future<void> signOut() async {
    _verificationId = null;
    _resendToken = null;
    _requestInProgress = false;
    try {
      await _auth?.signOut();
    } catch (_) {
      // La sesión local ya se limpió; Firebase no debe bloquear el logout.
    }
  }

  static String friendlyMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-phone-number' => 'Escribe un número de teléfono válido.',
      'invalid-verification-code' =>
        'El código no es correcto. Revísalo e inténtalo de nuevo.',
      'session-expired' => 'El código expiró. Solicita uno nuevo.',
      'too-many-requests' || 'quota-exceeded' =>
        'Hiciste varios intentos. Espera un momento y vuelve a intentarlo.',
      'network-request-failed' =>
        'No pudimos conectar. Revisa tu internet e inténtalo de nuevo.',
      'operation-not-allowed' =>
        'La verificación por SMS no está habilitada todavía.',
      'captcha-check-failed' =>
        'No pudimos validar el dispositivo. Inténtalo nuevamente.',
      _ => 'No pudimos verificar tu teléfono. Inténtalo de nuevo.',
    };
  }
}

final firebasePhoneAuthServiceProvider = Provider<FirebasePhoneAuthService>((
  ref,
) {
  try {
    return FirebasePhoneAuthService(FirebaseAuth.instance);
  } catch (_) {
    return FirebasePhoneAuthService(null);
  }
});
