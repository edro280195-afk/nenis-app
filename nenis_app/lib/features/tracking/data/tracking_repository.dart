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
        'No pudimos cargar tu pedido. Revisa tu conexión e intenta de nuevo.',
      );
    }
  }

  Future<OrderRating> submitRating({
    required String accessToken,
    required int stars,
    List<String>? reasons,
    String? comment,
  }) async {
    try {
      final res = await _dio.post(
        '/api/pedido/$accessToken/rating',
        data: {'stars': stars, 'reasons': reasons, 'comment': comment},
      );
      return OrderRating.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 410) {
        throw TrackingException('Este enlace ha expirado.');
      }
      throw TrackingException(
        e.response?.data?['message'] ?? 'No se pudo enviar la calificación.',
      );
    } catch (_) {
      throw TrackingException('Error de conexión.');
    }
  }

  /// POST /api/pedido/{token}/confirm — la clienta confirma su pedido.
  Future<void> confirmOrder(String accessToken) async {
    try {
      await _dio.post('/api/pedido/$accessToken/confirm');
    } on DioException catch (e) {
      throw TrackingException(
        e.response?.data?['message'] ?? 'No se pudo confirmar el pedido.',
      );
    } catch (_) {
      throw TrackingException('Error de conexión.');
    }
  }

  /// PATCH /api/pedido/{token}/instructions — actualiza las instrucciones
  /// de entrega de la clienta.
  Future<void> updateInstructions(
    String accessToken,
    String instructions,
  ) async {
    try {
      await _dio.patch(
        '/api/pedido/$accessToken/instructions',
        data: {'instructions': instructions},
      );
    } on DioException catch (e) {
      throw TrackingException(
        e.response?.data?['message'] ??
            'No se pudieron guardar las instrucciones.',
      );
    } catch (_) {
      throw TrackingException('Error de conexión.');
    }
  }

  /// GET /api/pedido/{token}/chat — historial de mensajes clienta ↔ chofer.
  Future<List<ChatMessage>> getChat(String accessToken) async {
    try {
      final res = await _dio.get('/api/pedido/$accessToken/chat');
      final list = res.data as List? ?? const [];
      return list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // El chat es opcional: si falla, devolvemos vacío en lugar de romper.
      return const [];
    }
  }

  /// POST /api/pedido/{token}/chat — envía un mensaje de la clienta.
  Future<ChatMessage> sendChat(String accessToken, String text) async {
    final res = await _dio.post(
      '/api/pedido/$accessToken/chat',
      data: {'text': text},
    );
    return ChatMessage.fromJson(res.data as Map<String, dynamic>);
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
  bool _disposed = false;
  bool _eventsWired = false;
  Future<void>? _startInFlight;

  final StreamController<DriverLocation> _locationCtl =
      StreamController<DriverLocation>.broadcast();
  final StreamController<TrackingStatus> _statusCtl =
      StreamController<TrackingStatus>.broadcast();
  final StreamController<bool> _connectionCtl =
      StreamController<bool>.broadcast();
  final StreamController<ChatMessage> _chatCtl =
      StreamController<ChatMessage>.broadcast();

  Stream<DriverLocation> get locationStream => _locationCtl.stream;
  Stream<TrackingStatus> get statusStream => _statusCtl.stream;
  Stream<bool> get connectionStream => _connectionCtl.stream;
  Stream<ChatMessage> get chatStream => _chatCtl.stream;

  void _wireEvents() {
    if (_eventsWired) return;
    _eventsWired = true;

    _connection.on('LocationUpdate', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args.first;
      if (raw is Map) {
        final lat = (raw['latitude'] as num?)?.toDouble();
        final lng = (raw['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          _emitLocation(
            DriverLocation(
              latitude: lat,
              longitude: lng,
              lastUpdate: DateTime.now(),
            ),
          );
        }
      }
    });

    // El backend manda UN solo argumento objeto ({Status, Message} —
    // ver DriverController.cs, ej. líneas 199/245/316/613/704), no dos
    // posicionales. Con `args[1]` esto nunca disparaba: los cambios de
    // estado en vivo (Confirmed→Shipped→InRoute→Delivered) no llegaban y
    // solo se veían al hacer pull-to-refresh manual.
    _connection.on('DeliveryUpdate', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args.first;
      if (raw is Map) {
        final status = raw['status'] ?? raw['Status'];
        if (status is String) {
          _emitStatus(trackingStatusFromString(status));
        }
      } else if (raw is String) {
        _emitStatus(trackingStatusFromString(raw));
      }
    });

    // Chat chofer/admin → clienta: el repartidor envía por
    // POST /api/driver/{token}/deliver/{id}/chat y el backend emite
    // `ReceiveClientChatMessage` al grupo Order_ (donde está la clienta).
    _connection.on('ReceiveClientChatMessage', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args.first;
      if (raw is Map<String, dynamic>) {
        _emitChat(ChatMessage.fromJson(raw));
      } else if (raw is Map) {
        _emitChat(ChatMessage.fromJson(Map<String, dynamic>.from(raw)));
      }
    });

    _connection.onclose(({error}) {
      _emitConnection(false);
    });

    _connection.onreconnecting(({error}) {
      _emitConnection(false);
    });

    _connection.onreconnected(({connectionId}) {
      if (_disposed) return;
      _emitConnection(true);
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
    if (_disposed) return;
    if (_connection.state == signalr.HubConnectionState.Connected) return;

    final pending = _startInFlight;
    if (pending != null) {
      await pending;
      return;
    }

    _wireEvents();
    final startFuture = _connection.start() ?? Future<void>.value();
    _startInFlight = startFuture;
    try {
      await startFuture;
      if (_disposed) {
        await _stopConnection();
        return;
      }
      _emitConnection(true);
    } catch (_) {
      _emitConnection(false);
      rethrow;
    } finally {
      if (identical(_startInFlight, startFuture)) {
        _startInFlight = null;
      }
    }
  }

  Future<bool> joinOrder(String accessToken) async {
    if (_disposed || accessToken.isEmpty) return false;

    if (_lastAccessToken != null &&
        _lastAccessToken != accessToken &&
        _connection.state != signalr.HubConnectionState.Disconnected) {
      await _stopConnection();
    }
    _lastAccessToken = accessToken;
    if (_connection.state != signalr.HubConnectionState.Connected) {
      await start();
    }
    if (_disposed ||
        _connection.state != signalr.HubConnectionState.Connected) {
      return false;
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
    if (_disposed) return;
    await _stopConnection();
    _joined = false;
    _emitConnection(false);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _joined = false;
    _lastAccessToken = null;
    await _stopConnection();
    await _locationCtl.close();
    await _statusCtl.close();
    await _connectionCtl.close();
    await _chatCtl.close();
  }

  bool get isJoined => _joined;
  bool get isDisposed => _disposed;

  Future<void> _stopConnection() async {
    if (_connection.state == signalr.HubConnectionState.Disconnected) return;
    try {
      await _connection.stop();
    } catch (_) {}
  }

  void _emitLocation(DriverLocation location) {
    if (!_disposed && !_locationCtl.isClosed) {
      _locationCtl.add(location);
    }
  }

  void _emitStatus(TrackingStatus status) {
    if (!_disposed && !_statusCtl.isClosed) {
      _statusCtl.add(status);
    }
  }

  void _emitConnection(bool connected) {
    if (!_disposed && !_connectionCtl.isClosed) {
      _connectionCtl.add(connected);
    }
  }

  void _emitChat(ChatMessage message) {
    if (!_disposed && !_chatCtl.isClosed) {
      _chatCtl.add(message);
    }
  }

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

final trackingHubProvider = Provider.autoDispose<TrackingHubClient>((ref) {
  final client = TrackingHubClient();
  ref.onDispose(client.dispose);
  return client;
});
