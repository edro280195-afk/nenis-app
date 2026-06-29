import 'package:dio/dio.dart';
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

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  /// Pide el OTP. En el backend dev devuelve el modo DEV (código fijo).
  Future<void> requestOtp(String phone) async {
    try {
      await _dio.post('/api/auth/phone/request-otp', data: {'phone': phone});
    } on DioException catch (e) {
      throw AuthException(
          _message(e, 'No pudimos enviar el código. Intenta de nuevo.'));
    }
  }

  /// Verifica el OTP y devuelve la sesión (crea la Account si es nueva).
  Future<Session> verifyOtp(String phone, String code) async {
    try {
      final res = await _dio.post(
        '/api/auth/phone/verify',
        data: {'phone': phone, 'code': code},
      );
      return Session.fromLoginJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(
          _message(e, 'Código incorrecto. Revísalo e intenta de nuevo.'));
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
