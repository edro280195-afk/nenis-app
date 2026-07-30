import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/live/data/meta_live_probe_repository.dart';

void main() {
  test('envía el token solo en el cuerpo y convierte la respuesta', () async {
    const token = 'facebook-secret-token';
    Object? requestData;
    String? requestPath;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestPath = options.path;
          requestData = options.data;
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'profile': {'id': '100', 'name': 'Eduardo'},
                'grantedPermissions': ['public_profile'],
                'declinedPermissions': <String>[],
                'missingPermissions': ['publish_video'],
                'permissionsError': null,
                'pageDiscoveryError': null,
                'pagesTruncated': false,
                'sources': <Map<String, Object?>>[],
                'checkedAtUtc': '2026-07-27T12:00:00Z',
              },
            ),
          );
        },
      ),
    );
    final repository = MetaLiveProbeRepository(
      dio,
      accessTokenLoader: () async => token,
    );

    final result = await repository.probe();

    expect(requestPath, '/api/business/meta-live/probe');
    expect(requestPath, isNot(contains(token)));
    expect(requestData, {'accessToken': token});
    expect(result.profile.id, '100');
    expect(result.missingPermissions, ['publish_video']);
  });

  test('usa el mensaje seguro devuelto por la API', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 409,
                data: {
                  'message': 'Primero inicia sesión en Neni’s con Facebook.',
                },
              ),
            ),
          );
        },
      ),
    );
    final repository = MetaLiveProbeRepository(
      dio,
      accessTokenLoader: () async => 'token',
    );

    await expectLater(
      repository.probe(),
      throwsA(
        isA<MetaLiveProbeException>().having(
          (error) => error.message,
          'message',
          contains('inicia sesión'),
        ),
      ),
    );
  });
}
