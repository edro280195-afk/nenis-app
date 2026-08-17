import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/dio_provider.dart';
import '../legal/legal_config.dart';
import 'session.dart';

/// Error de autenticación con un mensaje listo para mostrar a la usuaria.
class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum PasswordResetFailure {
  invalidCode,
  invalidCodeFormat,
  other;

  bool get requiresCodeEntry =>
      this == PasswordResetFailure.invalidCode ||
      this == PasswordResetFailure.invalidCodeFormat;
}

/// Fallo al confirmar un restablecimiento, clasificado con el campo `error`
/// estable del backend. La UI no debe inferir el tipo desde el texto traducido.
class PasswordResetException extends AuthException {
  PasswordResetException(super.message, {required this.failure});

  final PasswordResetFailure failure;
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

enum AccountType {
  client('client'),
  seller('seller');

  const AccountType(this.apiValue);

  final String apiValue;
}

/// Datos opcionales que acompañan el primer canje de un ID token de Firebase.
/// El teléfono y la identidad siempre los obtiene la API desde Firebase; no
/// se aceptan desde este objeto.
class FirebaseLoginProfile {
  const FirebaseLoginProfile({
    required this.accountType,
    this.firstName,
    this.lastName,
    this.email,
    this.password,
    this.businessName,
    this.city,
    required this.acceptedLegal,
    this.legalVersion = LegalConfig.currentVersion,
  });

  final AccountType accountType;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? password;
  final String? businessName;
  final String? city;
  final bool acceptedLegal;
  final String legalVersion;

  Map<String, dynamic> toJson(String idToken) {
    return {
      'idToken': idToken,
      'accountType': accountType.apiValue,
      'acceptedLegal': acceptedLegal,
      'legalVersion': legalVersion,
      if (firstName?.trim().isNotEmpty == true) 'firstName': firstName!.trim(),
      if (lastName?.trim().isNotEmpty == true) 'lastName': lastName!.trim(),
      if (email?.trim().isNotEmpty == true) 'email': email!.trim(),
      if (password?.isNotEmpty == true) 'password': password,
      if (businessName?.trim().isNotEmpty == true)
        'businessName': businessName!.trim(),
      if (city?.trim().isNotEmpty == true) 'city': city!.trim(),
    };
  }
}

/// Resultado de pedir/enviar un código de verificación.
class OtpRequestResult {
  const OtpRequestResult({
    required this.devMode,
    required this.providerConfigured,
    required this.message,
  });

  final bool devMode;
  final bool providerConfigured;
  final String message;

  factory OtpRequestResult.fromJson(Map<String, dynamic> json) {
    final rawMessage = json['message'];
    final message =
        rawMessage is String &&
            rawMessage.trim().isNotEmpty &&
            rawMessage.trim().length <= 240
        ? rawMessage.trim()
        : 'Código enviado por WhatsApp.';
    return OtpRequestResult(
      devMode: json['devMode'] as bool? ?? false,
      providerConfigured: json['providerConfigured'] as bool? ?? false,
      message: message,
    );
  }
}

class PasswordResetResult {
  const PasswordResetResult(this.message);

  final String message;
}

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<AccountOnboarding> completeOnboarding(String role) async {
    try {
      final response = await _dio.put(
        '/api/onboarding/complete',
        data: {'role': role},
      );
      return AccountOnboarding.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw AuthException(
        _message(e, 'No pudimos guardar el recorrido. Intenta de nuevo.'),
      );
    }
  }

  /// Alta de la compradora: nombre, apellido, correo, teléfono y contraseña.
  /// El backend envía un código por WhatsApp que se confirma en [confirmPhone].
  Future<OtpRequestResult> registerPhone({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
    required AccountType accountType,
    required bool acceptedLegal,
    String legalVersion = LegalConfig.currentVersion,
    String? businessName,
    String? city,
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
          'accountType': accountType.apiValue,
          'acceptedLegal': acceptedLegal,
          'legalVersion': legalVersion,
          if (businessName?.trim().isNotEmpty == true)
            'businessName': businessName!.trim(),
          if (city?.trim().isNotEmpty == true) 'city': city!.trim(),
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
  Future<Session> confirmPhone(
    String phone,
    String code, {
    AccountType? accountType,
    String? businessName,
    String? city,
    bool acceptedLegal = false,
    String legalVersion = LegalConfig.currentVersion,
  }) async {
    try {
      final res = await _dio.post(
        '/api/auth/phone/confirm',
        data: {
          'phone': phone,
          'code': code,
          'acceptedLegal': acceptedLegal,
          'legalVersion': legalVersion,
          if (accountType != null) 'accountType': accountType.apiValue,
          if (businessName?.trim().isNotEmpty == true)
            'businessName': businessName!.trim(),
          if (city?.trim().isNotEmpty == true) 'city': city!.trim(),
        },
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

  /// Passwordless paso 1: pide el código de WhatsApp para entrar o registrarse
  /// por teléfono, sin contraseña.
  Future<OtpRequestResult> requestPhoneOtp(String phone) async {
    try {
      final res = await _dio.post(
        '/api/auth/phone/request-otp',
        data: {'phone': phone},
      );
      return OtpRequestResult.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(
        _message(e, 'No pudimos enviar el código. Intenta de nuevo.'),
      );
    }
  }

  /// Passwordless paso 2: valida el código y devuelve la sesión (con refresh
  /// token). Si el teléfono no existía, crea la cuenta usando el nombre si
  /// viene. No usa contraseña.
  Future<Session> verifyPhoneOtp(
    String phone,
    String code, {
    String? firstName,
    String? lastName,
    required bool acceptedLegal,
    String legalVersion = LegalConfig.currentVersion,
    AccountType? accountType,
    String? businessName,
    String? city,
  }) async {
    try {
      final res = await _dio.post(
        '/api/auth/phone/verify',
        data: {
          'phone': phone,
          'code': code,
          'acceptedLegal': acceptedLegal,
          'legalVersion': legalVersion,
          if (accountType != null) 'accountType': accountType.apiValue,
          if (businessName?.trim().isNotEmpty == true)
            'businessName': businessName!.trim(),
          if (city?.trim().isNotEmpty == true) 'city': city!.trim(),
          if (firstName?.trim().isNotEmpty == true)
            'firstName': firstName!.trim(),
          if (lastName?.trim().isNotEmpty == true) 'lastName': lastName!.trim(),
        },
      );
      return Session.fromLoginJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(
        _message(e, 'Código incorrecto. Revísalo e intenta de nuevo.'),
      );
    }
  }

  /// Canjea el ID token emitido por Firebase por la sesión JWT propia de
  /// Nenis. El backend resuelve la cuenta por Firebase UID y teléfono.
  Future<Session> firebaseLogin({
    required String idToken,
    required FirebaseLoginProfile profile,
  }) async {
    try {
      final response = await _dio.post(
        '/api/auth/firebase',
        data: profile.toJson(idToken),
      );
      return Session.fromLoginJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(
        _message(e, 'No pudimos validar tu sesión. Inténtalo de nuevo.'),
      );
    }
  }

  /// Renueva la sesión con el refresh token (lo rota). Lanza si es
  /// inválido/expirado para que la app pida entrar de nuevo.
  ///
  /// El backend (Render Free) puede estar dormido y tardar hasta ~60s en
  /// despertar al primer hit. Como el refresh es un POST con rotación
  /// one-time-use, NO se puede reintentar a ciegas: si el primer POST llegó
  /// al backend pero la respuesta se perdió, reintentarlo con el mismo token
  /// (ya revocado) dispara la detección de robo y revoca TODOS los tokens de
  /// la cuenta. Por eso le damos un `receiveTimeout` amplio en lugar de retry.
  Future<Session> refresh(String refreshToken) async {
    final res = await _dio.post(
      '/api/auth/refresh',
      data: {'refreshToken': refreshToken},
      options: Options(receiveTimeout: const Duration(seconds: 60)),
    );
    return Session.fromLoginJson(res.data as Map<String, dynamic>);
  }

  /// Revoca el refresh token en el backend (best-effort al cerrar sesión).
  Future<void> revokeRefreshToken(String refreshToken) async {
    try {
      await _dio.post('/api/auth/logout', data: {'refreshToken': refreshToken});
    } catch (_) {
      // Silencioso: el cierre de sesión local no debe fallar por esto.
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

  /// Solicita un código para restablecer la contraseña sin revelar si el
  /// teléfono corresponde a una cuenta.
  Future<OtpRequestResult> requestPasswordReset(String phone) async {
    try {
      final response = await _dio.post(
        '/api/auth/password/reset/request',
        data: {'phone': phone},
      );
      return OtpRequestResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(
        _message(
          e,
          'No pudimos enviar el código. Revisa el número e intenta de nuevo.',
        ),
      );
    }
  }

  /// Confirma el código de WhatsApp y reemplaza la contraseña.
  Future<PasswordResetResult> confirmPasswordReset({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        '/api/auth/password/reset/confirm',
        data: {'phone': phone, 'code': code, 'newPassword': newPassword},
      );
      final data = _responseMap(response.data);
      return PasswordResetResult(
        data?['message'] as String? ??
            'Contraseña actualizada. Ya puedes iniciar sesión.',
      );
    } on DioException catch (e) {
      final data = _responseMap(e.response?.data);
      throw PasswordResetException(
        _message(e, 'No pudimos actualizar la contraseña. Revisa el código.'),
        failure: switch (data?['error']) {
          'invalid_code' => PasswordResetFailure.invalidCode,
          'invalid_code_format' => PasswordResetFailure.invalidCodeFormat,
          _ => PasswordResetFailure.other,
        },
      );
    }
  }

  /// Acceso de vendedora con correo y contraseña.
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
    if (e.response?.statusCode == 429) {
      return 'Hiciste varios intentos. Espera un minuto y vuelve a intentarlo.';
    }
    if (e.response?.statusCode == 405 &&
        e.requestOptions.path == '/api/auth/firebase') {
      return 'La autenticación por SMS está en actualización. Inténtalo en unos minutos.';
    }
    if ((e.response?.statusCode ?? 0) >= 500) {
      return 'El servicio no está disponible por el momento. Inténtalo más tarde.';
    }

    final data = _responseMap(e.response?.data);
    final apiMessage = data?['message'];
    if (apiMessage is String) {
      final normalized = apiMessage.trim();
      if (normalized.isNotEmpty && normalized.length <= 240) {
        return normalized;
      }
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'La conexión tardó demasiado. Inténtalo nuevamente.';
      case DioExceptionType.connectionError:
        return 'No pudimos conectar con el servidor. Revisa tu internet.';
      case DioExceptionType.cancel:
        return 'La operación se canceló. Puedes intentarlo de nuevo.';
      case DioExceptionType.badCertificate:
        return 'No pudimos establecer una conexión segura.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    return fallback;
  }

  Map<String, dynamic>? _responseMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(dioProvider));
});
