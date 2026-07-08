import 'package:dio/dio.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
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

enum FacebookAccountType {
  client('client'),
  seller('seller');

  const FacebookAccountType(this.apiValue);

  final String apiValue;
}

enum FacebookTokenType {
  classic('classic'),
  limited('limited');

  const FacebookTokenType(this.apiValue);

  final String apiValue;
}

class FacebookAccessCredential {
  const FacebookAccessCredential({required this.token, required this.type});

  final String token;
  final FacebookTokenType type;
}

/// Datos adicionales para completar una cuenta nueva o vincular una existente
/// con Facebook.
class FacebookProfileCompletion {
  const FacebookProfileCompletion({
    required this.accountType,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    this.businessName,
    this.city,
    this.existingPassword,
    required this.acceptedLegal,
    this.legalVersion = LegalConfig.currentVersion,
  });

  final FacebookAccountType accountType;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String? businessName;
  final String? city;
  final String? existingPassword;
  final bool acceptedLegal;
  final String legalVersion;

  Map<String, dynamic> toJson(FacebookAccessCredential credential) {
    return {
      'accessToken': credential.token,
      'tokenType': credential.type.apiValue,
      'accountType': accountType.apiValue,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'acceptedLegal': acceptedLegal,
      'legalVersion': legalVersion,
      if (businessName?.trim().isNotEmpty == true)
        'businessName': businessName!.trim(),
      if (city?.trim().isNotEmpty == true) 'city': city!.trim(),
      if (existingPassword?.isNotEmpty == true)
        'existingPassword': existingPassword,
    };
  }
}

/// El backend necesita completar datos antes de crear o vincular la cuenta.
class FacebookProfileRequiredException implements Exception {
  FacebookProfileRequiredException({
    required this.message,
    required this.accountType,
    required this.requiresExistingPassword,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.missingFields,
  });

  final String message;
  final FacebookAccountType accountType;
  final bool requiresExistingPassword;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final List<String> missingFields;

  factory FacebookProfileRequiredException.fromJson(
    Map<String, dynamic> json, {
    required FacebookAccountType fallbackAccountType,
  }) {
    final rawMissingFields = json['missingFields'];
    return FacebookProfileRequiredException(
      message: (json['message'] as String?)?.trim().isNotEmpty == true
          ? json['message'] as String
          : 'Completa tus datos para continuar con Facebook.',
      accountType: switch (json['accountType']) {
        'seller' => FacebookAccountType.seller,
        'client' => FacebookAccountType.client,
        _ => fallbackAccountType,
      },
      requiresExistingPassword:
          json['requiresExistingPassword'] as bool? ?? false,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      missingFields: rawMissingFields is List
          ? rawMissingFields.whereType<String>().toList(growable: false)
          : const [],
    );
  }

  @override
  String toString() => message;
}

/// El perfil ya se guardó, pero todavía falta confirmar el teléfono por
/// WhatsApp antes de entregar una sesión.
class FacebookPhoneVerificationRequiredException implements Exception {
  FacebookPhoneVerificationRequiredException({
    required this.message,
    required this.phone,
    required this.devMode,
    required this.providerConfigured,
  });

  final String message;
  final String phone;
  final bool devMode;
  final bool providerConfigured;

  @override
  String toString() => message;
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

  /// Alta de la compradora: nombre, apellido, correo, teléfono y contraseña.
  /// El backend envía un código por WhatsApp que se confirma en [confirmPhone].
  Future<OtpRequestResult> registerPhone({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
    required FacebookAccountType accountType,
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
    FacebookAccountType? accountType,
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
    FacebookAccountType? accountType,
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

  /// Renueva la sesión con el refresh token (lo rota). Lanza si es
  /// inválido/expirado para que la app pida entrar de nuevo.
  Future<Session> refresh(String refreshToken) async {
    final res = await _dio.post(
      '/api/auth/refresh',
      data: {'refreshToken': refreshToken},
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
      throw AuthException(
        _message(e, 'No pudimos actualizar la contraseña. Revisa el código.'),
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

  // ── Facebook Login ──

  /// Abre el diálogo nativo de Facebook y devuelve el access token.
  /// Lanza [FacebookCancelledException] si la usuaria cancela y [AuthException]
  /// si el proveedor falla.
  Future<FacebookAccessCredential> facebookAccessToken() async {
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
        final accessToken = result.accessToken;
        final token = accessToken?.tokenString;
        if (token == null || token.isEmpty) {
          throw AuthException(
            'No pudimos obtener tu Facebook. Intenta de nuevo.',
          );
        }
        return FacebookAccessCredential(
          token: token,
          type: accessToken!.type == AccessTokenType.limited
              ? FacebookTokenType.limited
              : FacebookTokenType.classic,
        );
      case LoginStatus.cancelled:
        throw FacebookCancelledException();
      case LoginStatus.failed:
        throw AuthException(
          'Facebook no pudo completar el acceso. Inténtalo otra vez.',
        );
      case LoginStatus.operationInProgress:
        throw AuthException(
          'Ya hay un acceso con Facebook en curso. Espera un momento.',
        );
    }
  }

  /// Intercambia el token de Facebook por una sesión en el backend. Si faltan
  /// datos, conserva el token en el controlador y solicita completar el perfil.
  Future<Session> facebookLogin(
    FacebookAccessCredential credential, {
    required FacebookAccountType accountType,
  }) async {
    try {
      final res = await _dio.post(
        '/api/auth/facebook',
        data: {
          'accessToken': credential.token,
          'tokenType': credential.type.apiValue,
          'accountType': accountType.apiValue,
        },
      );
      return Session.fromLoginJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = _responseMap(e.response?.data);
      if (e.response?.statusCode == 409 && data != null) {
        throw FacebookProfileRequiredException.fromJson(
          data,
          fallbackAccountType: accountType,
        );
      }
      throw AuthException(_message(e, 'No pudimos entrar con Facebook.'));
    }
  }

  /// Completa los datos requeridos por el backend. Puede devolver una sesión
  /// inmediata para una cuenta ya verificada, o dejar pendiente el OTP.
  Future<Session> completeFacebookProfile(
    FacebookAccessCredential credential,
    FacebookProfileCompletion profile,
  ) async {
    try {
      final response = await _dio.post(
        '/api/auth/facebook/complete',
        data: profile.toJson(credential),
      );
      final data = response.data as Map<String, dynamic>;
      if (response.statusCode == 202 ||
          data['needsPhoneVerification'] == true) {
        throw FacebookPhoneVerificationRequiredException(
          message:
              (data['message'] as String?) ??
              'Confirma tu teléfono con el código de WhatsApp.',
          phone: data['phone'] as String? ?? profile.phone,
          devMode: data['devMode'] as bool? ?? false,
          providerConfigured: data['providerConfigured'] as bool? ?? false,
        );
      }
      return Session.fromLoginJson(data);
    } on FacebookPhoneVerificationRequiredException {
      rethrow;
    } on DioException catch (e) {
      final data = _responseMap(e.response?.data);
      if (e.response?.statusCode == 409 && data != null) {
        throw FacebookProfileRequiredException.fromJson(
          data,
          fallbackAccountType: profile.accountType,
        );
      }
      throw AuthException(
        _message(e, 'No pudimos completar tu cuenta de Facebook.'),
      );
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
    if (e.response?.statusCode == 429) {
      return 'Hiciste varios intentos. Espera un minuto y vuelve a intentarlo.';
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
