import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import '../../../core/auth/auth_controller.dart';
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

  /// Historial de notificaciones. Con [audience] el backend devuelve solo las de ese
  /// destinatario; además se descarta cualquier fila que venga marcada para el otro
  /// (red de seguridad si el backend no filtrara). Las filas sin destinatario (backend
  /// anterior) se conservan.
  Future<List<BuyerNotification>> getMyNotifications({
    NotificationAudience? audience,
  }) async {
    try {
      final res = await _dio.get(
        '/api/me/notifications',
        queryParameters: _audienceQuery(audience),
      );
      final list = (res.data as List?) ?? const [];
      return list
          .map((e) => BuyerNotification.fromJson(e as Map<String, dynamic>))
          .where(
            (n) =>
                audience == null ||
                n.audience == null ||
                n.audience == audience,
          )
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
        'No pudimos marcar la notificación como leída.',
      );
    } catch (_) {
      throw NotificationsException(
        'No pudimos marcar la notificación como leída.',
      );
    }
  }

  Future<int> markAllAsRead({NotificationAudience? audience}) async {
    try {
      final res = await _dio.post(
        '/api/me/notifications/read-all',
        queryParameters: _audienceQuery(audience),
      );
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

  Future<int> getUnreadCount({NotificationAudience? audience}) async {
    try {
      final res = await _dio.get(
        '/api/me/notifications/unread-count',
        queryParameters: _audienceQuery(audience),
      );
      return (res.data as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Map<String, dynamic>? _audienceQuery(NotificationAudience? audience) =>
      audience == null ? null : {'audience': audience.apiValue};
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository(ref.read(dioProvider));
});

/// Destinatario de la campanita según el papel con el que entró la persona: con
/// negocio (dueña/administradora) ve los avisos de su tienda; sin negocio, los de
/// clienta. Las dos listas nunca se mezclan, aunque la cuenta tenga ambos papeles.
final notificationAudienceProvider = Provider<NotificationAudience>((ref) {
  final session = ref.watch(authControllerProvider).asData?.value;
  return session != null && session.hasMembership
      ? NotificationAudience.seller
      : NotificationAudience.buyer;
});

/// Feed de notificaciones del papel actual. Se hidrata una vez al
/// entrar a la pantalla y se rehidrata con pull-to-refresh o vía
/// `ref.invalidate` cuando se marcan como leídas.
final notificationsFeedProvider =
    FutureProvider.autoDispose<List<BuyerNotification>>((ref) {
      final audience = ref.watch(notificationAudienceProvider);
      return ref
          .read(notificationsRepositoryProvider)
          .getMyNotifications(audience: audience);
    });

/// Contador de no leídas del papel actual (lo usa el badge del icono 🔔 en el Home).
final unreadNotificationsCountProvider = FutureProvider.autoDispose<int>((ref) {
  final audience = ref.watch(notificationAudienceProvider);
  return ref
      .read(notificationsRepositoryProvider)
      .getUnreadCount(audience: audience);
});
