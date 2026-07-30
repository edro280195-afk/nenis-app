import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'notifications_models.dart';

class NotificationsException implements Exception {
  NotificationsException(this.message);
  final String message;
  @override
  String toString() => message;
}

class NotificationsRepository {
  NotificationsRepository(this._dio);

  final Dio _dio;

  Future<List<BuyerNotification>> getMyNotifications() async {
    try {
      final res = await _dio.get('/api/me/notifications');
      final list = (res.data as List?) ?? const [];
      return list
          .map((e) => BuyerNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (_) {
      throw NotificationsException('No pudimos cargar tus notificaciones.');
    } catch (_) {
      throw NotificationsException('No pudimos cargar tus notificaciones.');
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _dio.post('/api/me/notifications/$id/read');
    } on DioException catch (_) {
      throw NotificationsException(
        'No pudimos marcar la notificacion como leida.',
      );
    } catch (_) {
      throw NotificationsException(
        'No pudimos marcar la notificacion como leida.',
      );
    }
  }

  Future<int> markAllAsRead() async {
    try {
      final res = await _dio.post('/api/me/notifications/read-all');
      return ((res.data as Map<String, dynamic>)['updated'] as num?)?.toInt() ??
          0;
    } on DioException catch (_) {
      throw NotificationsException(
        'No pudimos marcar las notificaciones como leidas.',
      );
    } catch (_) {
      throw NotificationsException(
        'No pudimos marcar las notificaciones como leidas.',
      );
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final res = await _dio.get('/api/me/notifications/unread-count');
      return (res.data as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository(ref.read(dioProvider));
});

/// Feed de notificaciones de la compradora. Se hidrata una vez al
/// entrar a la pantalla y se rehidrata con pull-to-refresh o vía
/// `ref.invalidate` cuando se marcan como leídas.
final notificationsFeedProvider =
    FutureProvider.autoDispose<List<BuyerNotification>>((ref) {
      return ref.read(notificationsRepositoryProvider).getMyNotifications();
    });

/// Contador de no leídas (lo usa el badge del icono 🔔 en el Home).
final unreadNotificationsCountProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.read(notificationsRepositoryProvider).getUnreadCount();
});
