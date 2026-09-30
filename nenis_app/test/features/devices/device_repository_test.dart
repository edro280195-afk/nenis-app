import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/devices/data/device_repository.dart';

void main() {
  group('DeviceRepository.unregisterDevice', () {
    test('presenta el JWT de la sesión que sale cuando se lo dan', () async {
      final sent = <RequestOptions>[];
      final repository = DeviceRepository(_recordingDio(sent));

      await repository.unregisterDevice('fcm-token', accessToken: 'jwt-de-ana');

      expect(sent.single.method, 'DELETE');
      expect(sent.single.path, '/api/me/devices/fcm-token');
      expect(sent.single.headers['Authorization'], 'Bearer jwt-de-ana');
    });

    test(
      'sin credencial no inventa una (el backend acepta la baja anónima)',
      () async {
        final sent = <RequestOptions>[];
        final repository = DeviceRepository(_recordingDio(sent));

        await repository.unregisterDevice('fcm-token');

        expect(sent.single.headers.containsKey('Authorization'), isFalse);
      },
    );

    test(
      'un fallo de red no lanza (no debe trabar el cierre de sesión)',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            ),
          ),
        );

        await DeviceRepository(dio).unregisterDevice('fcm-token');
      },
    );
  });
}

Dio _recordingDio(List<RequestOptions> sent) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        sent.add(options);
        handler.resolve(
          Response<void>(requestOptions: options, statusCode: 204),
        );
      },
    ),
  );
  return dio;
}
