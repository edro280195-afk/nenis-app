import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';

/// Registro del token FCM del dispositivo contra el backend. Nunca lanza:
/// el registro de push es "best effort" y no debe tumbar el login/logout.
class DeviceRepository {
  DeviceRepository(this._dio);

  final Dio _dio;

  Future<void> registerDevice(String token, {required String platform}) async {
    try {
      await _dio.post(
        '/api/me/devices',
        data: {'token': token, 'platform': platform},
      );
    } catch (_) {
      // Silencioso a propósito.
    }
  }

  Future<void> unregisterDevice(String token) async {
    try {
      await _dio.delete('/api/me/devices/$token');
    } catch (_) {
      // Silencioso a propósito.
    }
  }
}

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepository(ref.read(dioProvider));
});
