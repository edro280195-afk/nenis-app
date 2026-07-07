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
}

final trackingControllerProvider =
    AsyncNotifierProvider<TrackingController, OrderTracking?>(
  TrackingController.new,
);
