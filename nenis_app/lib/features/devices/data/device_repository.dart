import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';

/// Diagnóstico que devuelve el backend al mandar la notificación de prueba
/// (`POST /api/me/devices/test-push`).
class DevicePushTest {
  const DevicePushTest({
    required this.firebaseConfigured,
    required this.tokensRegistered,
    required this.sent,
    required this.failed,
    this.projectId,
    this.errors = const [],
  });

  final bool firebaseConfigured;
  final String? projectId;
  final int tokensRegistered;
  final int sent;
  final int failed;
  final List<String> errors;

  factory DevicePushTest.fromJson(Map<String, dynamic> json) {
    int n(dynamic v) => v is num ? v.toInt() : 0;
    return DevicePushTest(
      firebaseConfigured: json['firebaseConfigured'] == true,
      projectId: json['projectId'] as String?,
      tokensRegistered: n(json['tokensRegistered']),
      sent: n(json['sent']),
      failed: n(json['failed']),
      errors: ((json['errors'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

/// Registro del token FCM del dispositivo contra el backend. Nunca lanza:
/// el registro de push es "best effort" y no debe tumbar el login/logout, pero
/// sí informa si funcionó para poder diagnosticarlo.
class DeviceRepository {
  DeviceRepository(this._dio);

  final Dio _dio;

  /// Devuelve `true` si el backend guardó el token.
  Future<bool> registerDevice(String token, {required String platform}) async {
    try {
      await _dio.post(
        '/api/me/devices',
        data: {'token': token, 'platform': platform},
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Push] registerDevice falló: $e');
      return false;
    }
  }

  Future<void> unregisterDevice(String token) async {
    try {
      await _dio.delete('/api/me/devices/$token');
    } catch (e) {
      if (kDebugMode) debugPrint('[Push] unregisterDevice falló: $e');
    }
  }

  /// Pide al backend una notificación de prueba a los dispositivos de la
  /// cuenta. Devuelve `null` si la petición misma falló.
  Future<DevicePushTest?> sendTestPush() async {
    try {
      final res = await _dio.post('/api/me/devices/test-push');
      return DevicePushTest.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) debugPrint('[Push] test-push falló: $e');
      return null;
    }
  }
}

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepository(ref.read(dioProvider));
});
