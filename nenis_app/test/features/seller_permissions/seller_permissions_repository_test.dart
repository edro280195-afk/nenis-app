import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/seller_updates/data/seller_updates_repository.dart';
import 'package:nenis_app/features/seller_vip/data/seller_vip_repository.dart';

void main() {
  test('VIP traduce un 403 a una explicación de rol', () async {
    final repository = SellerVipRepository(_forbiddenDio());

    await expectLater(
      repository.getFollowers(),
      throwsA(
        isA<SellerVipException>().having(
          (error) => error.message,
          'message',
          contains('Tu rol no permite administrar el grupo VIP'),
        ),
      ),
    );
  });

  test('Novedades traduce un 403 a una explicación de rol', () async {
    final repository = SellerUpdatesRepository(_forbiddenDio());

    await expectLater(
      repository.getMyPosts(),
      throwsA(
        isA<SellerUpdatesException>().having(
          (error) => error.message,
          'message',
          contains('Tu rol no permite publicar novedades'),
        ),
      ),
    );
  });
}

Dio _forbiddenDio() {
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
              statusCode: 403,
              data: {'message': 'Forbidden'},
            ),
          ),
        );
      },
    ),
  );
  return dio;
}
