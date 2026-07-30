import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'store_models.dart';

class StoreException implements Exception {
  StoreException(this.message);
  final String message;
  @override
  String toString() => message;
}

class StoreRepository {
  StoreRepository(this._dio);

  final Dio _dio;

  Future<BuyerStoreDetail> getStore(int businessId) async {
    try {
      final res = await _dio.get('/api/me/store/$businessId');
      return BuyerStoreDetail.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw StoreException('Esta tienda no está disponible.');
      }
      final data = e.response?.data;
      final message = (data is Map && data['message'] is String)
          ? data['message'] as String
          : 'No pudimos cargar la tienda.';
      throw StoreException(message);
    } catch (_) {
      throw StoreException('No pudimos cargar la tienda.');
    }
  }
}

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository(ref.read(dioProvider));
});

/// Id de la tienda actualmente cargada. La pantalla lo setea en
/// `initState` y el `StoreController` lo observa para saber qué cargar.
class StoreBusinessId extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int id) => state = id;
  void clear() => state = null;
}

final storeBusinessIdProvider =
    NotifierProvider<StoreBusinessId, int?>(StoreBusinessId.new);

/// Tab actualmente seleccionado en la pantalla de tienda. Es un
/// Notifier simple (no del controller) porque el cambio de tab NO
/// requiere refetch — solo rebuild del widget.
class StoreSelectedTab extends Notifier<StoreTab> {
  @override
  StoreTab build() => StoreTab.products;
  void set(StoreTab tab) => state = tab;
}

final storeSelectedTabProvider =
    NotifierProvider<StoreSelectedTab, StoreTab>(StoreSelectedTab.new);

/// Controller de la pantalla "Tienda de vendedora". Carga el detalle
/// de la tienda según el `storeBusinessIdProvider` y lo expone.
class StoreController extends AsyncNotifier<BuyerStoreDetail?> {
  @override
  Future<BuyerStoreDetail?> build() async {
    final id = ref.watch(storeBusinessIdProvider);
    if (id == null) return null;
    return ref.read(storeRepositoryProvider).getStore(id);
  }

  /// Actualiza el detalle ya cargado sin ir a la red (estado optimista de
  /// `FollowController`: seguir/dejar de seguir, contador de seguidoras).
  /// No hace nada si todavía no hay datos cargados.
  void applyLocalUpdate(
    BuyerStoreDetail Function(BuyerStoreDetail current) transform,
  ) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(transform(current));
  }
}

final storeControllerProvider =
    AsyncNotifierProvider<StoreController, BuyerStoreDetail?>(
  StoreController.new,
);
