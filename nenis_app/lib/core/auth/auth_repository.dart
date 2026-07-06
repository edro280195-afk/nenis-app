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
  });

  final FacebookAccountType accountType;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String? businessName;
  final String? city;
  final String? existingPassword;

  Map<String, dynamic> toJson(FacebookAccessCredential credential) {
    return {
      'accessToken': credential.token,
      'tokenType': credential.type.apiValue,
      'accountType': accountType.apiValue,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
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
  Future<Session> confirmPhone(
    String phone,
    String code, {
    FacebookAccountType? accountType,
    String? businessName,
    String? city,
  }) async {
    try {
      final res = await _dio.post(
        '/api/auth/phone/confirm',
        data: {
          'phone': phone,
          'code': code,
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
      case LoginStatus.operationInProgress:
        throw AuthException(
          result.message?.trim().isNotEmpty == true
              ? result.message!
              : 'No pudimos entrar con Facebook. Intenta de nuevo.',
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
    final data = _responseMap(e.response?.data);
    if (data != null && data['message'] is String) {
      return data['message'] as String;
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
