import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'orders_models.dart';

class OrdersException implements Exception {
  OrdersException(this.message);
  final String message;
  @override
  String toString() => message;
}

class OrdersRepository {
  OrdersRepository(this._dio);

  final Dio _dio;

  Future<BuyerOrdersPage> getOrders({
    OrdersFilter filter = OrdersFilter.all,
    int? businessId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final res = await _dio.get(
        '/api/me/orders',
        queryParameters: {
          // ignore: use_null_aware_elements
          if (businessId != null) 'businessId': businessId,
          'filter': filter.queryValue,
          'page': page,
          'pageSize': pageSize,
        },
      );
      return BuyerOrdersPage.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = (data is Map && data['message'] is String)
          ? data['message'] as String
          : 'No pudimos cargar tus pedidos.';
      throw OrdersException(message);
    } catch (_) {
      throw OrdersException('No pudimos cargar tus pedidos.');
    }
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.read(dioProvider));
});

/// Estado del query actual del feed de pedidos.
class OrdersQuery {
  const OrdersQuery({
    this.filter = OrdersFilter.all,
    this.businessId,
    this.page = 1,
  });

  final OrdersFilter filter;
  final int? businessId;
  final int page;

  OrdersQuery copyWith({
    OrdersFilter? filter,
    int? businessId,
    bool clearBusinessId = false,
    int? page,
  }) =>
      OrdersQuery(
        filter: filter ?? this.filter,
        businessId: clearBusinessId ? null : (businessId ?? this.businessId),
        page: page ?? this.page,
      );
}

/// Controller de la pantalla "Mis pedidos". Mantiene la query actual
/// (filtro + página) y se vuelve a pedir cuando cambia.
class OrdersController extends AsyncNotifier<BuyerOrdersPage> {
  OrdersQuery _query = const OrdersQuery();

  OrdersQuery get query => _query;

  @override
  Future<BuyerOrdersPage> build() async {
    final repo = ref.read(ordersRepositoryProvider);
    return repo.getOrders(
      filter: _query.filter,
      businessId: _query.businessId,
      page: _query.page,
    );
  }

  /// Cambia el filtro y resetea a la primera página.
  void setFilter(OrdersFilter filter) {
    if (_query.filter == filter && _query.page == 1) return;
    _query = _query.copyWith(filter: filter, page: 1);
    ref.invalidateSelf();
  }

  /// Avanza a la siguiente página si la hay.
  void nextPage() {
    final current = state.asData?.value;
    if (current == null || !current.hasNext) return;
    _query = _query.copyWith(page: _query.page + 1);
    ref.invalidateSelf();
  }

  /// Retrocede a la página anterior si la hay.
  void prevPage() {
    final current = state.asData?.value;
    if (current == null || !current.hasPrev) return;
    _query = _query.copyWith(page: _query.page - 1);
    ref.invalidateSelf();
  }

  /// Filtra por una sola tienda y resetea a la primera página.
  void setBusiness(int? businessId) {
    _query = _query.copyWith(
      businessId: businessId,
      clearBusinessId: businessId == null,
      page: 1,
    );
    ref.invalidateSelf();
  }
}

final ordersControllerProvider =
    AsyncNotifierProvider.autoDispose<OrdersController, BuyerOrdersPage>(
  OrdersController.new,
);
