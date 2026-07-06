import 'package:dio/dio.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/dio_provider.dart';
import 'session.dart';

/// Error de autenticación con un mensaje listo para mostrar a la usuaria.
class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// La cuenta existe y la contraseña es correcta, pero el teléfono no se ha
/// confirmado por WhatsApp. La UI debe mandar a la pantalla de confirmación.
class PhoneNotVerifiedException implements Exception {
  PhoneNotVerifiedException(this.phone, this.message);
  final String phone;
  final String message;
  @override
  String toString() => message;
}

/// La usuaria canceló el diálogo de Facebook. No es un error grave: la UI no
/// debe mostrar un mensaje de fallo.
class FacebookCancelledException implements Exception {}

/// El backend necesita el teléfono para completar el alta con Facebook (cuenta
/// nueva). La UI debe pedirlo y reintentar con [AuthController.completeFacebookWithPhone].
class FacebookNeedsPhoneException implements Exception {
  FacebookNeedsPhoneException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Resultado de pedir/enviar un código de verificación.
class OtpRequestResult {
  const OtpRequestResult({
    required this.devMode,
    required this.providerConfigured,
  });

  final bool devMode;
  final bool providerConfigured;

  factory OtpRequestResult.fromJson(Map<String, dynamic> json) {
    return OtpRequestResult(
      devMode: json['devMode'] as bool? ?? false,
      providerConfigured: json['providerConfigured'] as bool? ?? false,
    );
  }
}

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  /// Alta de la compradora: nombre, apellido, correo, teléfono y contraseña.
  /// El backend envía un código por WhatsApp que se confirma en [confirmPhone].
  Future<OtpRequestResult> registerPhone({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post(
        '/api/auth/phone/register',
        data: {
          'firstName': firstName,
          'lastName': lastName,
          'phone': phone,
          'email': email,
          'password': password,
        },
      );
      return OtpRequestResult.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(
        _message(e, 'No pudimos crear tu cuenta. Intenta de nuevo.'),
      );
    }
  }

  /// Confirma el teléfono con el código de WhatsApp y devuelve la sesión.
  Future<Session> confirmPhone(String phone, String code) async {
    try {
      final res = await _dio.post(
        '/api/auth/phone/confirm',
        data: {'phone': phone, 'code': code},
      );
      return Session.fromLoginJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(
        _message(e, 'Código incorrecto. Revísalo e intenta de nuevo.'),
      );
    }
  }

  /// Acceso de la compradora ya registrada: teléfono + contraseña.
  Future<Session> loginPhone(String phone, String password) async {
    try {
      final res = await _dio.post(
        '/api/auth/phone/login',
        data: {'phone': phone, 'password': password},
      );
      return Session.fromLoginJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 403 &&
          data is Map &&
          data['needsPhoneVerification'] == true) {
        throw PhoneNotVerifiedException(
          (data['phone'] as String?)?.trim().isNotEmpty == true
              ? data['phone'] as String
              : phone,
          _message(e, 'Confirma tu teléfono con el código de WhatsApp.'),
        );
      }
      throw AuthException(_message(e, 'Teléfono o contraseña incorrectos.'));
    }
  }

  /// Reenvía el código de verificación por WhatsApp.
  Future<OtpRequestResult> resendCode(String phone) async {
    try {
      final response = await _dio.post(
        '/api/auth/phone/request-otp',
        data: {'phone': phone},
      );
      return OtpRequestResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(
        _message(e, 'No pudimos enviar el código. Intenta de nuevo.'),
      );
    }
  }

  /// Acceso de equipo (correo + contraseña, cuentas legacy).
  Future<Session> loginEmail(String email, String password) async {
    try {
      final res = await _dio.post(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );
      return Session.fromLoginJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(_message(e, 'Correo o contraseña incorrectos.'));
    }
  }

  // ── Facebook Login ──

  /// Abre el diálogo nativo de Facebook y devuelve el access token.
  /// Lanza [FacebookCancelledException] si la usuaria cancela y [AuthException]
  /// si el proveedor falla.
  Future<String> facebookAccessToken() async {
    late final LoginResult result;
    try {
      result = await FacebookAuth.instance.login(
        permissions: const ['email', 'public_profile'],
      );
    } catch (_) {
      throw AuthException('No pudimos abrir Facebook. Intenta de nuevo.');
    }

    switch (result.status) {
      case LoginStatus.success:
        final token = result.accessToken?.tokenString;
        if (token == null || token.isEmpty) {
          throw AuthException('No pudimos obtener tu Facebook. Intenta de nuevo.');
        }
        return token;
      case LoginStatus.cancelled:
        throw FacebookCancelledException();
      case LoginStatus.failed:
      case LoginStatus.operationInProgress:
        throw AuthException(
          result.message?.trim().isNotEmpty == true
              ? result.message!
              : 'No pudimos entrar con Facebook. Intenta de nuevo.',
        );
    }
  }

  /// Intercambia el token de Facebook por una sesión en el backend. Lanza
  /// [FacebookNeedsPhoneException] si es una cuenta nueva que requiere teléfono.
  Future<Session> facebookLogin(String accessToken, {String? phone}) async {
    try {
      final res = await _dio.post(
        '/api/auth/facebook',
        data: {
          'accessToken': accessToken,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
      );
      return Session.fromLoginJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 409 &&
          data is Map &&
          data['needsPhone'] == true) {
        throw FacebookNeedsPhoneException(
          _message(e, 'Necesitamos tu teléfono para crear tu cuenta.'),
        );
      }
      throw AuthException(_message(e, 'No pudimos entrar con Facebook.'));
    }
  }

  /// Cierra la sesión del SDK de Facebook (best-effort).
  Future<void> facebookLogout() async {
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {
      // Silencioso: el logout de la app no debe fallar por esto.
    }
  }

  String _message(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return fallback;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(dioProvider));
});
