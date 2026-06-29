import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart' as signalr;

import '../../../core/api/dio_provider.dart';
import '../../../core/config/app_config.dart';
import 'tracking_models.dart';

class TrackingException implements Exception {
  TrackingException(this.message);
  final String message;
  @override
  String toString() => message;
}

class TrackingRepository {
  TrackingRepository(this._dio);

  final Dio _dio;

  Future<OrderTracking> getOrderByToken(String accessToken) async {
    try {
      final res = await _dio.get('/api/pedido/$accessToken');
      return OrderTracking.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw TrackingException('Este enlace ya no es válido.');
      }
      if (e.response?.statusCode == 410) {
        throw TrackingException('Este enlace ha expirado.');
      }
      throw TrackingException(
          'No pudimos cargar tu pedido. Revisa tu conexión e intenta de nuevo.');
    } catch (_) {
      throw TrackingException(
          'No pudimos cargar tu pedido. Revisa tu conexión e intenta de nuevo.');
    }
  }
}

final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  return TrackingRepository(ref.read(dioProvider));
});

/// Convierte `AppConfig.apiBaseUrl` (http://host:puerto) a la URL del hub
/// de SignalR (ws://host:puerto/hubs/delivery).
String trackingHubUrl() {
  final base = AppConfig.apiBaseUrl;
  final wsBase = base.replaceFirst(RegExp(r'^http(s)?://'), r'ws$1://');
  return '$wsBase/hubs/delivery';
}

/// Cliente de SignalR para la pantalla de rastreo. Se conecta al hub
/// `/hubs/delivery` y al hacer `joinOrder(accessToken)` se suscribe
/// automáticamente a los grupos de pedido y (si la tienda tiene
/// `LiveGpsTracking`) al grupo de tracking del chofer.
///
/// Devuelve streams reactivos que la UI consume para actualizar el mapa
/// y el estado en tiempo real.
class TrackingHubClient {
  TrackingHubClient({signalr.HubConnection? connection})
      : _connection = connection ?? _defaultConnection();

  final signalr.HubConnection _connection;
  bool _joined = false;

  final StreamController<DriverLocation> _locationCtl =
      StreamController<DriverLocation>.broadcast();
  final StreamController<TrackingStatus> _statusCtl =
      StreamController<TrackingStatus>.broadcast();
  final StreamController<bool> _connectionCtl =
      StreamController<bool>.broadcast();

  Stream<DriverLocation> get locationStream => _locationCtl.stream;
  Stream<TrackingStatus> get statusStream => _statusCtl.stream;
  Stream<bool> get connectionStream => _connectionCtl.stream;

  void _wireEvents() {
    _connection.on('LocationUpdate', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args.first;
      if (raw is Map) {
        final lat = (raw['latitude'] as num?)?.toDouble();
        final lng = (raw['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          _locationCtl.add(DriverLocation(
            latitude: lat,
            longitude: lng,
            lastUpdate: DateTime.now(),
          ));
        }
      }
    });

    _connection.on('DeliveryUpdate', (args) {
      if (args == null || args.length < 2) return;
      final raw = args[1];
      if (raw is String) {
        _statusCtl.add(trackingStatusFromString(raw));
      }
    });

    _connection.onclose(({error}) {
      _connectionCtl.add(false);
    });

    _connection.onreconnecting(({error}) {
      _connectionCtl.add(false);
    });

    _connection.onreconnected(({connectionId}) {
      _connectionCtl.add(true);
      // Re-join si el accessToken estaba activo.
      if (_lastAccessToken != null) {
        // No esperamos — la reconexión ya garantiza el grupo, pero si la
        // suscripción se perdió al reconnect, re-intentar silenciosamente.
        _connection
            .invoke('JoinOrder', args: [_lastAccessToken!])
            .catchError((_) => false);
      }
    });
  }

  String? _lastAccessToken;

  Future<void> start() async {
    if (_connection.state == signalr.HubConnectionState.Connected) return;
    try {
      _wireEvents();
      await _connection.start();
      _connectionCtl.add(true);
    } catch (_) {
      _connectionCtl.add(false);
      rethrow;
    }
  }

  Future<bool> joinOrder(String accessToken) async {
    if (accessToken.isEmpty) return false;
    _lastAccessToken = accessToken;
    if (_connection.state != signalr.HubConnectionState.Connected) {
      await start();
    }
    try {
      final ok = await _connection.invoke('JoinOrder', args: [accessToken]);
      _joined = ok == true;
      return _joined;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    if (_connection.state == signalr.HubConnectionState.Connected) {
      try {
        await _connection.stop();
      } catch (_) {}
    }
    _connectionCtl.add(false);
  }

  Future<void> dispose() async {
    await stop();
    await _locationCtl.close();
    await _statusCtl.close();
    await _connectionCtl.close();
  }

  bool get isJoined => _joined;

  static signalr.HubConnection _defaultConnection() {
    final url = trackingHubUrl();
    return signalr.HubConnectionBuilder()
        .withUrl(url)
        .withAutomaticReconnect(
          retryDelays: const [0, 2000, 5000, 10000, 30000],
        )
        .build();
  }
}

final trackingHubProvider = Provider<TrackingHubClient>((ref) {
  final client = TrackingHubClient();
  ref.onDispose(() => client.dispose());
  return client;
});
