import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/notifications/data/notifications_repository.dart';

void main() {
  group('NotificationsRepository', () {
    test('markAsRead reporta errores de red', () async {
      final repository = NotificationsRepository(_failingDio());

      await expectLater(
        repository.markAsRead('n-1'),
        throwsA(isA<NotificationsException>()),
      );
    });

    test('markAllAsRead reporta errores de red', () async {
      final repository = NotificationsRepository(_failingDio());

      await expectLater(
        repository.markAllAsRead(),
        throwsA(isA<NotificationsException>()),
      );
    });
  });
}

Dio _failingDio() {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: 'offline',
          ),
        );
      },
    ),
  );
  return dio;
}
