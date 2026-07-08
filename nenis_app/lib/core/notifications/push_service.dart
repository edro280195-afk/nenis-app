import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/devices/data/device_repository.dart';
import 'push_navigation.dart';

const _androidChannel = AndroidNotificationChannel(
  'nenis_app_channel',
  "Notificaciones de Neni's App",
  description: 'Avisos de pedidos, en vivo y novedades de tus tiendas.',
  importance: Importance.high,
);

/// Handler de mensajes en background/terminado. Debe ser una función
/// top-level (corre en un isolate aparte). El sistema ya muestra la
/// notificación con el payload `notification` que manda el backend
/// (`PushNotificationService`); no hace falta procesar nada más aquí.
@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage message) async {}

/// Recepción de push nativo (FCM) para la app de la compradora/vendedora.
/// "Best effort" a propósito: si Firebase todavía no está configurado
/// nativamente (falta `google-services.json`/`GoogleService-Info.plist`),
/// ningún método de esta clase debe tumbar la app — solo deja de haber
/// push hasta que se complete esa configuración.
class PushService {
  PushService(this._ref)
      : _localNotifications = FlutterLocalNotificationsPlugin();

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _localNotifications;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);

      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (response) {
          handlePushNavigation(_ref, response.payload);
        },
      );

      FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => handlePushNavigation(_ref, message.data['url'] as String?),
      );

      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        handlePushNavigation(_ref, initialMessage.data['url'] as String?);
      }
    } catch (_) {
      // Firebase no configurado nativamente todavía — sin push por ahora.
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    try {
      await _localNotifications.show(
        id: message.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: message.data['url'] as String?,
      );
    } catch (_) {
      // No hay UI que mostrar si Firebase/local notifications no están listos.
    }
  }

  /// Pide permiso, obtiene el token FCM del dispositivo y lo registra contra
  /// el backend. Se llama tras cada login exitoso (`AuthController._apply`).
  Future<void> registerCurrentToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _ref.read(deviceRepositoryProvider).registerDevice(
              token,
              platform: _platform,
            );
      }

      messaging.onTokenRefresh.listen((refreshed) {
        _ref.read(deviceRepositoryProvider).registerDevice(
              refreshed,
              platform: _platform,
            );
      });
    } catch (_) {
      // Sin Firebase configurado, no hay token que registrar.
    }
  }

  /// Quita el token del dispositivo (logout), para no seguir empujando push
  /// a una cuenta que ya cerró sesión en este dispositivo.
  Future<void> unregisterCurrentToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _ref.read(deviceRepositoryProvider).unregisterDevice(token);
    } catch (_) {
      // Sin Firebase configurado, no hay nada que des-registrar.
    }
  }

  String get _platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
}

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));
