import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart' as signalr;

import '../../../core/config/app_config.dart';
import '../../../core/storage/session_storage.dart';
import 'live_models.dart';

/// Convierte `AppConfig.apiBaseUrl` (http://host:puerto) a la URL del hub
/// de SignalR (ws://host:puerto/hubs/live).
String liveHubUrl() {
  final base = AppConfig.apiBaseUrl;
  final wsBase = base.replaceFirst(RegExp(r'^http(s)?://'), r'ws$1://');
  return '$wsBase/hubs/live';
}

/// Cliente de SignalR del "vivo" en tiempo real. A diferencia de
/// `TrackingHubClient` (anónimo, por token de recurso), este hub sí
/// requiere el JWT de la sesión — tanto la vendedora (JoinAdminLive /
/// AnnounceProduct) como la clienta (JoinLive) se autorizan por su cuenta.
class LiveHubClient {
  LiveHubClient({
    required Future<String?> Function() tokenProvider,
    signalr.HubConnection? connection,
  }) : _connection = connection ?? _buildConnection(tokenProvider);

  final signalr.HubConnection _connection;
  bool _wired = false;

  final StreamController<LiveProductAnnouncement> _announcedCtl =
      StreamController<LiveProductAnnouncement>.broadcast();
  final StreamController<bool> _connectionCtl =
      StreamController<bool>.broadcast();

  Stream<LiveProductAnnouncement> get productAnnouncedStream =>
      _announcedCtl.stream;
  Stream<bool> get connectionStream => _connectionCtl.stream;

  void _wireEvents() {
    if (_wired) return;
    _wired = true;

    _connection.on('ProductAnnounced', (args) {
      if (args == null || args.isEmpty) return;
      final raw = args.first;
      if (raw is Map) {
        _announcedCtl.add(
          LiveProductAnnouncement.fromJson(Map<String, dynamic>.from(raw)),
        );
      }
    });

    _connection.onclose(({error}) => _connectionCtl.add(false));
    _connection.onreconnecting(({error}) => _connectionCtl.add(false));
    _connection.onreconnected(({connectionId}) => _connectionCtl.add(true));
  }

  Future<void> start() async {
    if (_connection.state == signalr.HubConnectionState.Connected) return;
    _wireEvents();
    try {
      await _connection.start();
      _connectionCtl.add(true);
    } catch (_) {
      _connectionCtl.add(false);
      rethrow;
    }
  }

  /// Vendedora: se une al grupo del vivo de su propia tienda.
  Future<bool> joinAdminLive() async {
    if (_connection.state != signalr.HubConnectionState.Connected) {
      await start();
    }
    try {
      final ok = await _connection.invoke('JoinAdminLive');
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// Vendedora: anuncia un producto de su catálogo como "lo muestro ahora".
  Future<bool> announceProduct(int productId) async {
    if (_connection.state != signalr.HubConnectionState.Connected) {
      await start();
    }
    try {
      final ok = await _connection.invoke('AnnounceProduct', args: [productId]);
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// Clienta: se une al grupo del vivo de una tienda donde ya tiene
  /// Client o ya la sigue.
  Future<bool> joinLive(int businessId) async {
    if (_connection.state != signalr.HubConnectionState.Connected) {
      await start();
    }
    try {
      final ok = await _connection.invoke('JoinLive', args: [businessId]);
      return ok == true;
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
    await _announcedCtl.close();
    await _connectionCtl.close();
  }

  static signalr.HubConnection _buildConnection(
    Future<String?> Function() tokenProvider,
  ) {
    return signalr.HubConnectionBuilder()
        .withUrl(
          liveHubUrl(),
          options: signalr.HttpConnectionOptions(
            accessTokenFactory: () async => (await tokenProvider()) ?? '',
          ),
        )
        .withAutomaticReconnect(
          retryDelays: const [0, 2000, 5000, 10000, 30000],
        )
        .build();
  }
}

/// Un cliente por sesión de pantalla (vendedora anunciando o clienta viendo
/// el live) — `autoDispose` cierra la conexión al salir de la pantalla.
final liveHubProvider = Provider.autoDispose<LiveHubClient>((ref) {
  final storage = ref.read(sessionStorageProvider);
  final client = LiveHubClient(
    tokenProvider: () async => (await storage.read())?.token,
  );
  ref.onDispose(() => client.dispose());
  return client;
});
