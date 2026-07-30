import 'package:dio/dio.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'meta_live_probe_models.dart';

class MetaLiveProbeException implements Exception {
  const MetaLiveProbeException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class MetaLiveProbeGateway {
  Future<MetaLiveProbeResult> probe();
}

typedef MetaLiveAccessTokenLoader = Future<String> Function();

class MetaLiveProbeRepository implements MetaLiveProbeGateway {
  MetaLiveProbeRepository(
    this._dio, {
    MetaLiveAccessTokenLoader? accessTokenLoader,
  }) : _accessTokenLoader = accessTokenLoader ?? _requestFacebookAccessToken;

  static const _permissions = [
    'public_profile',
    'publish_video',
    'pages_show_list',
    'pages_read_engagement',
    'pages_read_user_content',
  ];

  final Dio _dio;
  final MetaLiveAccessTokenLoader _accessTokenLoader;

  @override
  Future<MetaLiveProbeResult> probe() async {
    final accessToken = await _accessTokenLoader();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/business/meta-live/probe',
        data: {'accessToken': accessToken},
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 75),
        ),
      );
      final data = response.data;
      if (data == null) {
        throw const MetaLiveProbeException(
          'Facebook respondió sin datos. Intenta otra vez.',
        );
      }
      return MetaLiveProbeResult.fromJson(data);
    } on DioException catch (error) {
      throw MetaLiveProbeException(_messageFrom(error));
    }
  }

  static Future<String> _requestFacebookAccessToken() async {
    late final LoginResult result;
    try {
      result = await FacebookAuth.instance.login(
        permissions: _permissions,
        loginTracking: LoginTracking.enabled,
      );
    } catch (_) {
      throw const MetaLiveProbeException(
        'No pudimos abrir Facebook. Intenta de nuevo.',
      );
    }

    switch (result.status) {
      case LoginStatus.success:
        final accessToken = result.accessToken;
        if (accessToken == null || accessToken.tokenString.isEmpty) {
          throw const MetaLiveProbeException(
            'Facebook no entregó un acceso válido.',
          );
        }
        if (accessToken.type != AccessTokenType.classic) {
          throw const MetaLiveProbeException(
            'Facebook dio acceso limitado. Para leer Pages y comentarios '
            'necesitamos el acceso clásico de Facebook.',
          );
        }
        return accessToken.tokenString;
      case LoginStatus.cancelled:
        throw const MetaLiveProbeException(
          'Cancelaste la autorización de Facebook.',
        );
      case LoginStatus.failed:
        throw const MetaLiveProbeException(
          'Facebook no autorizó la conexión. Revisa la configuración de la app '
          'en Meta.',
        );
      case LoginStatus.operationInProgress:
        throw const MetaLiveProbeException(
          'Ya hay una autorización de Facebook en curso.',
        );
    }
  }

  static String _messageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }

    return switch (error.response?.statusCode) {
      429 => 'Hicimos demasiadas pruebas seguidas. Espera un minuto.',
      502 || 503 => 'Facebook no está disponible en este momento.',
      _ => 'No pudimos completar la prueba con Facebook.',
    };
  }
}

final metaLiveProbeRepositoryProvider = Provider<MetaLiveProbeGateway>((ref) {
  return MetaLiveProbeRepository(ref.read(dioProvider));
});
