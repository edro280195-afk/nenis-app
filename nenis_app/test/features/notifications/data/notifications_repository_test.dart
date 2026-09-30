import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/notifications/data/notifications_models.dart';
import 'package:nenis_app/features/notifications/data/notifications_repository.dart';

void main() {
  group('NotificationsRepository — destinatario (vendedora vs clienta)', () {
    test('pide al backend solo las notificaciones del papel actual', () async {
      final sent = <RequestOptions>[];
      final repository = NotificationsRepository(
        _recordingDio(sent, (options) {
          return switch (options.path) {
            '/api/me/notifications/unread-count' => 3,
            '/api/me/notifications/read-all' => {'updated': 2},
            _ => <Map<String, Object?>>[],
          };
        }),
      );

      await repository.getMyNotifications(
        audience: NotificationAudience.seller,
      );
      await repository.getUnreadCount(audience: NotificationAudience.buyer);
      await repository.markAllAsRead(audience: NotificationAudience.seller);

      expect(sent[0].path, '/api/me/notifications');
      expect(sent[0].queryParameters, {'audience': 'seller'});
      expect(sent[1].path, '/api/me/notifications/unread-count');
      expect(sent[1].queryParameters, {'audience': 'buyer'});
      expect(sent[2].path, '/api/me/notifications/read-all');
      expect(sent[2].queryParameters, {'audience': 'seller'});
    });

    test('sin destinatario no manda el parámetro (compatibilidad)', () async {
      final sent = <RequestOptions>[];
      final repository = NotificationsRepository(
        _recordingDio(sent, (options) => <Map<String, Object?>>[]),
      );

      await repository.getMyNotifications();

      expect(sent.single.queryParameters, isEmpty);
    });

    test('descarta cualquier fila marcada para el otro papel', () async {
      final repository = NotificationsRepository(
        _recordingDio(<RequestOptions>[], (options) {
          return [
            _row('tienda', audience: 'seller'),
            _row('compra', audience: 'buyer'),
            _row('sin-dato'), // backend anterior: sin destinatario
          ];
        }),
      );

      final seller = await repository.getMyNotifications(
        audience: NotificationAudience.seller,
      );
      final buyer = await repository.getMyNotifications(
        audience: NotificationAudience.buyer,
      );
      final all = await repository.getMyNotifications();

      expect(seller.map((n) => n.id), ['tienda', 'sin-dato']);
      expect(buyer.map((n) => n.id), ['compra', 'sin-dato']);
      expect(all, hasLength(3));
    });

    test('lee el destinatario y los íconos de los avisos de tienda', () async {
      final repository = NotificationsRepository(
        _recordingDio(<RequestOptions>[], (options) {
          return [
            _row('a', audience: 'seller', tag: 'saldos-sin-cobrar'),
            _row('b', audience: 'buyer', tag: 'delivered'),
          ];
        }),
      );

      final list = await repository.getMyNotifications();

      expect(list[0].audience, NotificationAudience.seller);
      expect(list[1].audience, NotificationAudience.buyer);
      expect(list[0].icon, isNot(list[1].icon));
    });
  });

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

/// Dio que guarda cada petición en [sent] y responde con lo que devuelva [answer].
Dio _recordingDio(
  List<RequestOptions> sent,
  Object Function(RequestOptions options) answer,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        sent.add(options);
        handler.resolve(
          Response<Object>(
            requestOptions: options,
            statusCode: 200,
            data: answer(options),
          ),
        );
      },
    ),
  );
  return dio;
}

Map<String, Object?> _row(
  String id, {
  String? audience,
  String tag = 'general',
}) => {
  'id': id,
  'businessId': 1,
  'businessName': 'Regi Bazar',
  'brandPrimaryColor': '#FF0072',
  'title': 'Título $id',
  'message': 'Mensaje $id',
  'tag': tag,
  'createdAt': '2026-09-30T12:00:00Z',
  'audience': ?audience,
};
