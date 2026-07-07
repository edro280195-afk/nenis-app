import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'seller_orders_models.dart';

class SellerOrdersException implements Exception {
  SellerOrdersException(this.message);
  final String message;
  @override
  String toString() => message;
}

String _friendly(Object e, String fallback) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    if (data is String && data.trim().isNotEmpty) return data;
  }
  return fallback;
}

/// Repositorio de pedidos de vendedora contra `OrdersController` de
/// `sellgeneral-api`. El negocio activo lo inyecta el interceptor de Dio
/// (`X-Business-Id`).
class SellerOrdersRepository {
  SellerOrdersRepository(this._dio);
  final Dio _dio;

  Future<SellerOrdersPage> getPaged({
    int page = 1,
    int pageSize = 20,
    String search = '',
    String status = '',
    String type = '',
  }) async {
    try {
      final res = await _dio.get(
        '/api/orders/paged',
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          if (search.trim().isNotEmpty) 'search': search.trim(),
          if (status.isNotEmpty) 'status': status,
          if (type.isNotEmpty) 'type': type,
          'sortBy': 'date',
          'sortDir': 'desc',
        },
      );
      return SellerOrdersPage.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw SellerOrdersException(
        _friendly(e, 'No pudimos cargar los pedidos.'),
      );
    }
  }

  Future<SellerOrder> getOrder(int id) async {
    try {
      final res = await _dio.get('/api/orders/$id');
      return SellerOrder.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw SellerOrdersException(_friendly(e, 'No pudimos abrir el pedido.'));
    }
  }

  Future<SellerDashboard> getDashboard() async {
    try {
      final res = await _dio.get('/api/orders/dashboard');
      return SellerDashboard.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw SellerOrdersException(_friendly(e, 'No pudimos cargar tu panel.'));
    }
  }

  Future<SellerOrder> createManual({
    required String clientName,
    String? clientPhone,
    String? clientAddress,
    String? alternativeAddress,
    String? deliveryInstructions,
    DateTime? scheduledDeliveryDate,
    int? clientId,
    required String type,
    required SellerDeliveryType orderType,
    required List<DraftOrderItem> items,
  }) async {
    try {
      final res = await _dio.post(
        '/api/orders/manual',
        data: {
          'clientName': clientName,
          if (clientPhone != null && clientPhone.trim().isNotEmpty)
            'clientPhone': clientPhone.trim(),
          if (clientAddress != null && clientAddress.trim().isNotEmpty)
            'clientAddress': clientAddress.trim(),
          if (alternativeAddress != null &&
              alternativeAddress.trim().isNotEmpty)
            'alternativeAddress': alternativeAddress.trim(),
          if (deliveryInstructions != null &&
              deliveryInstructions.trim().isNotEmpty)
            'deliveryInstructions': deliveryInstructions.trim(),
          'scheduledDeliveryDate': ?scheduledDeliveryDate?.toIso8601String(),
          'clientId': ?clientId,
          'type': type,
          'orderType': orderType.api,
          'status': 'Pending',
          'items': items.map((i) => i.toJson()).toList(),
        },
      );
      return SellerOrder.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw SellerOrdersException(_friendly(e, 'No pudimos crear el pedido.'));
    }
  }

  Future<List<SellerClient>> getClients() async {
    try {
      final res = await _dio.get('/api/clients');
      return ((res.data as List?) ?? const [])
          .map((e) => SellerClient.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw SellerOrdersException(
        _friendly(e, 'No pudimos cargar las clientas.'),
      );
    }
  }

  Future<List<CommonProduct>> getCommonProducts() async {
    try {
      final res = await _dio.get('/api/orders/common-products');
      return ((res.data as List?) ?? const [])
          .map((e) => CommonProduct.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw SellerOrdersException(
        _friendly(e, 'No pudimos cargar productos frecuentes.'),
      );
    }
  }

  Future<void> deleteOrder(int id) async {
    try {
      await _dio.delete('/api/orders/$id');
    } catch (e) {
      throw SellerOrdersException(
        _friendly(e, 'No pudimos eliminar el pedido.'),
      );
    }
  }

  Future<SellerOrder> updateStatus(int id, SellerOrderStatus status) async {
    try {
      final res = await _dio.patch(
        '/api/orders/$id/status',
        data: {'status': status.api},
      );
      return SellerOrder.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw SellerOrdersException(
        _friendly(e, 'No pudimos cambiar el estatus.'),
      );
    }
  }

  Future<SellerOrder> setOrderType(int id, SellerDeliveryType type) async {
    try {
      final res = await _dio.patch(
        '/api/orders/$id/status',
        data: {'orderType': type.api},
      );
      return SellerOrder.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw SellerOrdersException(
        _friendly(e, 'No pudimos cambiar la entrega.'),
      );
    }
  }

  Future<SellerOrder> addItem(
    int orderId,
    String name,
    int qty,
    double price,
  ) async {
    try {
      final res = await _dio.post(
        '/api/orders/$orderId/items',
        data: {'productName': name, 'quantity': qty, 'unitPrice': price},
      );
      return SellerOrder.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw SellerOrdersException(
        _friendly(e, 'No pudimos agregar el artículo.'),
      );
    }
  }

  Future<SellerOrder> updateItem(
    int orderId,
    int itemId,
    String name,
    int qty,
    double price,
  ) async {
    try {
      final res = await _dio.put(
        '/api/orders/$orderId/items/$itemId',
        data: {'productName': name, 'quantity': qty, 'unitPrice': price},
      );
      return SellerOrder.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw SellerOrdersException(
        _friendly(e, 'No pudimos actualizar el artículo.'),
      );
    }
  }

  Future<SellerOrder> removeItem(int orderId, int itemId) async {
    try {
      final res = await _dio.delete('/api/orders/$orderId/items/$itemId');
      return SellerOrder.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw SellerOrdersException(
        _friendly(e, 'No pudimos quitar el artículo.'),
      );
    }
  }

  Future<void> addPayment(int orderId, double amount, String method) async {
    try {
      await _dio.post(
        '/api/orders/$orderId/payments',
        data: {'amount': amount, 'method': method},
      );
    } catch (e) {
      throw SellerOrdersException(
        _friendly(e, 'No pudimos registrar el cobro.'),
      );
    }
  }

  Future<SellerOrder> setNotified(int orderId, bool notified) async {
    try {
      final res = await _dio.patch(
        '/api/orders/$orderId/notified',
        data: {'notified': notified},
      );
      return SellerOrder.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw SellerOrdersException(
        _friendly(e, 'No pudimos marcar el enlace como enviado.'),
      );
    }
  }
}

final sellerOrdersRepositoryProvider = Provider<SellerOrdersRepository>((ref) {
  return SellerOrdersRepository(ref.read(dioProvider));
});

/// Dashboard de vendedora (`GET /api/orders/dashboard`).
final sellerDashboardProvider = FutureProvider.autoDispose<SellerDashboard>((
  ref,
) {
  return ref.read(sellerOrdersRepositoryProvider).getDashboard();
});

/// Detalle de un pedido (`GET /api/orders/{id}`).
final sellerOrderDetailProvider = FutureProvider.autoDispose
    .family<SellerOrder, int>((ref, id) {
      return ref.read(sellerOrdersRepositoryProvider).getOrder(id);
    });

/// Query actual de la lista de pedidos (filtro + búsqueda + página).
class SellerOrdersQuery {
  const SellerOrdersQuery({this.search = '', this.status = '', this.page = 1});
  final String search;
  final String status;
  final int page;

  SellerOrdersQuery copyWith({String? search, String? status, int? page}) =>
      SellerOrdersQuery(
        search: search ?? this.search,
        status: status ?? this.status,
        page: page ?? this.page,
      );
}

/// Controlador de la lista de pedidos de vendedora. Mantiene filtro/búsqueda
/// y página; refetch server-side al cambiar.
class SellerOrdersController extends AsyncNotifier<SellerOrdersPage> {
  SellerOrdersQuery _query = const SellerOrdersQuery();
  SellerOrdersQuery get query => _query;

  @override
  Future<SellerOrdersPage> build() {
    return ref
        .read(sellerOrdersRepositoryProvider)
        .getPaged(
          page: _query.page,
          search: _query.search,
          status: _query.status,
        );
  }

  void setStatus(String status) {
    if (_query.status == status && _query.page == 1) return;
    _query = _query.copyWith(status: status, page: 1);
    ref.invalidateSelf();
  }

  void setSearch(String search) {
    if (_query.search == search) return;
    _query = _query.copyWith(search: search, page: 1);
    ref.invalidateSelf();
  }

  void nextPage() {
    final current = state.asData?.value;
    if (current == null || !current.hasNext) return;
    _query = _query.copyWith(page: _query.page + 1);
    ref.invalidateSelf();
  }

  void prevPage() {
    final current = state.asData?.value;
    if (current == null || !current.hasPrev) return;
    _query = _query.copyWith(page: _query.page - 1);
    ref.invalidateSelf();
  }

  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }
}

final sellerOrdersControllerProvider =
    AsyncNotifierProvider<SellerOrdersController, SellerOrdersPage>(
      SellerOrdersController.new,
    );
