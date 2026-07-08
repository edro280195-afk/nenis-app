import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tracking_models.dart';
import 'tracking_repository.dart';

/// Token de acceso del pedido actualmente rastreado. La pantalla lo
/// setea al entrar y el `TrackingController` lo observa para saber qué
/// pedido cargar.
class TrackingToken extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
  void clear() => state = '';
}

final trackingTokenProvider =
    NotifierProvider<TrackingToken, String>(TrackingToken.new);

/// Controller de la pantalla de rastreo. Combina el GET inicial al
/// endpoint público con las suscripciones de SignalR para mantener el
/// estado (status del pedido + ubicación del chofer) en vivo.
class TrackingController extends AsyncNotifier<OrderTracking?> {
  StreamSubscription<DriverLocation>? _locationSub;
  StreamSubscription<TrackingStatus>? _statusSub;
  StreamSubscription<bool>? _connSub;

  @override
  Future<OrderTracking?> build() async {
    final accessToken = ref.watch(trackingTokenProvider);
    if (accessToken.isEmpty) {
      return null;
    }

    final repo = ref.read(trackingRepositoryProvider);
    final hub = ref.read(trackingHubProvider);
    final order = await repo.getOrderByToken(accessToken);

    _locationSub?.cancel();
    _statusSub?.cancel();
    _connSub?.cancel();

    _locationSub = hub.locationStream.listen((loc) {
      final current = state.asData?.value;
      if (current == null) return;
      state = AsyncData(current.copyWith(driverLocation: loc));
    });

    _statusSub = hub.statusStream.listen((status) {
      final current = state.asData?.value;
      if (current == null) return;
      state = AsyncData(current.copyWith(status: status));
    });

    _connSub = hub.connectionStream.listen((_) {
      // Reservado: futuro chip de "conectado / reconectando".
    });

    // Inicia el hub y se une al grupo. Si falla, igual tenemos el GET.
    Future<void>(() async {
      try {
        await hub.start();
        await hub.joinOrder(accessToken);
      } catch (_) {
        // La UI ya muestra el estado del GET; no hacemos nada aquí.
      }
    });

    ref.onDispose(() {
      _locationSub?.cancel();
      _statusSub?.cancel();
      _connSub?.cancel();
      hub.stop();
    });

    return order;
  }

  void updateRating(OrderRating rating) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(rating: rating));
  }

  /// Re-carga el pedido (token público) y actualiza el estado. Lo usan las
  /// acciones de la clienta (confirmar, instrucciones) para reflejar el cambio.
  Future<void> reload() async {
    final accessToken = ref.read(trackingTokenProvider);
    if (accessToken.isEmpty) return;
    state = const AsyncLoading<OrderTracking?>();
    try {
      final order =
          await ref.read(trackingRepositoryProvider).getOrderByToken(accessToken);
      state = AsyncData<OrderTracking?>(order);
    } catch (e, st) {
      state = AsyncError<OrderTracking?>(e, st);
    }
  }

  /// Confirma el pedido (visible si está Pending/Postponed).
  Future<void> confirmOrder() async {
    final accessToken = ref.read(trackingTokenProvider);
    if (accessToken.isEmpty) return;
    await ref.read(trackingRepositoryProvider).confirmOrder(accessToken);
    await reload();
  }

  /// Guarda las instrucciones de entrega editadas por la clienta.
  Future<void> saveInstructions(String instructions) async {
    final accessToken = ref.read(trackingTokenProvider);
    if (accessToken.isEmpty) return;
    await ref.read(trackingRepositoryProvider)
        .updateInstructions(accessToken, instructions);
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData(current.copyWith(deliveryInstructions: instructions));
    }
  }
}

final trackingControllerProvider =
    AsyncNotifierProvider<TrackingController, OrderTracking?>(
  TrackingController.new,
);

/// Estado del chat clienta ↔ chofer/admin. Carga el histórico al arrancar,
/// mezcla los mensajes en vivo que llegan por SignalR
/// (`ReceiveClientChatMessage`) y expone `send` para enviar.
class OrderChatNotifier extends Notifier<List<ChatMessage>> {
  StreamSubscription<ChatMessage>? _chatSub;
  String? _token;

  @override
  List<ChatMessage> build() {
    final token = ref.watch(trackingTokenProvider);
    if (token.isEmpty) return const [];
    _token = token;

    // Histórico (no bloquea el build; se actualiza al resolver).
    Future(() async {
      try {
        final msgs = await ref.read(trackingRepositoryProvider).getChat(token);
        if (msgs.isNotEmpty) state = msgs;
      } catch (_) {}
    });

    // Mensajes en vivo del chofer/admin.
    final hub = ref.read(trackingHubProvider);
    _chatSub = hub.chatStream.listen((msg) {
      if (state.any((m) => m.id == msg.id)) return;
      state = [...state, msg];
    });

    ref.onDispose(() => _chatSub?.cancel());
    return const [];
  }

  Future<void> send(String text) async {
    final token = _token;
    final body = text.trim();
    if (token == null || body.isEmpty) return;
    try {
      final msg = await ref.read(trackingRepositoryProvider).sendChat(token, body);
      if (state.any((m) => m.id == msg.id)) return;
      state = [...state, msg];
    } catch (_) {
      // El envío falló: la UI puede mostrar un error leve. No rompemos el chat.
    }
  }
}

final orderChatProvider =
    NotifierProvider<OrderChatNotifier, List<ChatMessage>>(
  OrderChatNotifier.new,
);
