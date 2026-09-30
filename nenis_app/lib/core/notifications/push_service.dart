import 'dart:async';

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

/// El backend manda los push de FCM con `ChannelId = "regibazar_channel"`. Si
/// ese canal no existe en el teléfono, Android degrada la notificación al canal
/// genérico "Varios" (sin aviso emergente). Se crea con la misma importancia.
const _backendChannel = AndroidNotificationChannel(
  'regibazar_channel',
  'Avisos de tus tiendas',
  description: 'Avisos de pedidos, entregas y novedades.',
  importance: Importance.high,
);

/// Resultado de registrar el token FCM de este dispositivo en el backend.
enum PushRegistration {
  /// El backend guardó el token.
  registered,

  /// La usuaria negó el permiso de notificaciones.
  permissionDenied,

  /// Firebase no entregó un token (sin Google Play, sin red o sin configurar).
  noToken,

  /// Hubo token pero el backend no lo guardó.
  failed,
}

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
  StreamSubscription<String>? _tokenRefreshSub;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_androidChannel);
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_backendChannel);

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

      // `getInitialMessage` puede colgarse si Firebase no está configurado
      // nativamente; timeout corto para no trabar el arranque.
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
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
  /// el backend. Se llama cada vez que hay una sesión (login o arranque con
  /// sesión guardada). Devuelve qué pasó para poder diagnosticarlo; en debug
  /// además lo imprime, porque antes todos los fallos eran silenciosos.
  Future<PushRegistration> registerCurrentToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        if (kDebugMode) debugPrint('[Push] permiso de notificaciones denegado');
        return PushRegistration.permissionDenied;
      }

      final token = await _readFcmToken(messaging);
      if (token == null || token.isEmpty) {
        if (kDebugMode) debugPrint('[Push] Firebase no entregó token FCM');
        return PushRegistration.noToken;
      }

      final ok = await _ref
          .read(deviceRepositoryProvider)
          .registerDevice(token, platform: _platform);
      if (kDebugMode) {
        final tail = token.substring(token.length - 6);
        debugPrint(
          '[Push] token …$tail (${token.length} car.) registrado: $ok',
        );
      }

      // Una sola suscripción a la rotación del token, sin importar cuántas
      // veces se llame (antes se acumulaba una por cada login).
      _tokenRefreshSub ??= messaging.onTokenRefresh.listen((refreshed) {
        _ref
            .read(deviceRepositoryProvider)
            .registerDevice(refreshed, platform: _platform);
      });
      return ok ? PushRegistration.registered : PushRegistration.failed;
    } catch (e) {
      if (kDebugMode) debugPrint('[Push] registro falló: $e');
      return PushRegistration.noToken;
    }
  }

  /// Registra el token de este dispositivo y le pide al backend una
  /// notificación de prueba. Sirve para validar de punta a punta el token FCM.
  Future<PushTestOutcome> runSelfTest() async {
    final registration = await registerCurrentToken();
    if (registration == PushRegistration.permissionDenied) {
      return const PushTestOutcome(
        ok: false,
        message:
            'Las notificaciones están desactivadas. Actívalas para Neni\'s App '
            'en los Ajustes del teléfono y vuelve a intentarlo.',
      );
    }
    if (registration == PushRegistration.noToken) {
      return const PushTestOutcome(
        ok: false,
        message:
            'Este teléfono no pudo obtener su identificador de notificaciones. '
            'Revisa tu conexión y que tenga Google Play Services.',
      );
    }
    if (registration == PushRegistration.failed) {
      return const PushTestOutcome(
        ok: false,
        message:
            'No pudimos registrar este teléfono en el servidor. Inténtalo de '
            'nuevo en un momento.',
      );
    }

    final result = await _ref.read(deviceRepositoryProvider).sendTestPush();
    if (result == null) {
      return const PushTestOutcome(
        ok: false,
        message: 'No pudimos contactar al servidor. Inténtalo de nuevo.',
      );
    }
    if (!result.firebaseConfigured) {
      return const PushTestOutcome(
        ok: false,
        message:
            'El servidor todavía no puede enviar notificaciones. Avísale al '
            'equipo de Neni\'s App.',
      );
    }
    if (result.tokensRegistered == 0) {
      return const PushTestOutcome(
        ok: false,
        message:
            'El servidor no tiene registrado este teléfono. Cierra sesión y '
            'vuelve a entrar.',
      );
    }
    if (result.sent > 0) {
      return const PushTestOutcome(
        ok: true,
        message:
            'Listo: te enviamos una notificación de prueba. Debería llegar en '
            'unos segundos.',
      );
    }
    final reason = result.errors.isEmpty ? '' : ' (${result.errors.first})';
    return PushTestOutcome(
      ok: false,
      message:
          'El servidor no logró entregar la notificación$reason. Avísale al '
          'equipo de Neni\'s App.',
    );
  }

  /// Quita el token del dispositivo (logout), para no seguir empujando push
  /// a una cuenta que ya cerró sesión en este dispositivo.
  Future<void> unregisterCurrentToken() async {
    try {
      final token = await _readFcmToken(FirebaseMessaging.instance);
      if (token == null) return;
      await _ref.read(deviceRepositoryProvider).unregisterDevice(token);
    } catch (_) {
      // Sin Firebase configurado, no hay nada que des-registrar.
    }
  }

  /// Obtiene el token FCM con un timeout duro. `FirebaseMessaging.getToken()`
  /// no tiene timeout propio y puede colgarse indefinidamente si Firebase no
  /// está configurado nativamente, si no hay red, o si la app acaba de abrir.
  /// Eso bloqueaba el `logout()` (la usuaria no salía) y el `init()`. Con 10s
  /// de margen es suficiente para un dispositivo sano; si no responde, se
  /// devuelve `null` y el flujo (login/logout) sigue sin trabarse.
  Future<String?> _readFcmToken(FirebaseMessaging messaging) {
    return messaging.getToken().timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
  }

  String get _platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
}

/// Resultado legible de [PushService.runSelfTest].
class PushTestOutcome {
  const PushTestOutcome({required this.ok, required this.message});
  final bool ok;
  final String message;
}

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));
