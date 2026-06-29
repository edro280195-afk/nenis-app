import 'package:flutter/widgets.dart';

import '../../../shared/widgets/status_chip.dart';

/// Filtro del feed "Mis pedidos". Mapea directo al query param `filter`
/// que acepta el backend (`all` | `open` | `closed`).
enum OrdersFilter { all, open, closed }

extension OrdersFilterX on OrdersFilter {
  String get queryValue {
    switch (this) {
      case OrdersFilter.all:
        return 'all';
      case OrdersFilter.open:
        return 'open';
      case OrdersFilter.closed:
        return 'closed';
    }
  }

  String get label {
    switch (this) {
      case OrdersFilter.all:
        return 'Todos';
      case OrdersFilter.open:
        return 'En curso';
      case OrdersFilter.closed:
        return 'Cerrados';
    }
  }

  static OrdersFilter fromQuery(String? value) {
    switch (value) {
      case 'open':
        return OrdersFilter.open;
      case 'closed':
        return OrdersFilter.closed;
      default:
        return OrdersFilter.all;
    }
  }
}

/// Mapea el `status` que llega del backend (string del enum OrderStatus de .NET)
/// a las 3 variantes visuales que pinta `StatusChip`. Igual convención que
/// usa `_chipStatus` en `home_screen.dart`: cualquier estado en tránsito cae
/// en `route`; entregado es `delivered`; el resto (pendiente/cancelado/
/// pospuesto/no entregado) se ve como `pending` mientras no haya variantes
/// dedicadas.
OrderStatus orderChipFromBackend(String status) {
  switch (status) {
    case 'Delivered':
      return OrderStatus.delivered;
    case 'InRoute':
    case 'Shipped':
    case 'Confirmed':
      return OrderStatus.route;
    default:
      return OrderStatus.pending;
  }
}

class BuyerOrder {
  const BuyerOrder({
    required this.orderId,
    required this.businessId,
    required this.businessName,
    required this.brandPrimaryColor,
    required this.status,
    required this.itemsCount,
    required this.total,
    required this.createdAt,
    this.logoUrl,
    this.accessToken,
    this.scheduledDeliveryDate,
  });

  final int orderId;
  final int businessId;
  final String businessName;
  final String brandPrimaryColor;
  final String status;
  final int itemsCount;
  final double total;
  final DateTime createdAt;
  final String? logoUrl;
  final String? accessToken;
  final DateTime? scheduledDeliveryDate;

  String get initial => businessName.isNotEmpty
      ? businessName.characters.first.toUpperCase()
      : '?';

  OrderStatus get chipStatus => orderChipFromBackend(status);

  factory BuyerOrder.fromJson(Map<String, dynamic> j) => BuyerOrder(
        orderId: (j['orderId'] as num).toInt(),
        businessId: (j['businessId'] as num).toInt(),
        businessName: (j['businessName'] ?? '') as String,
        brandPrimaryColor: (j['brandPrimaryColor'] ?? '#FB6F9C') as String,
        logoUrl: j['logoUrl'] as String?,
        status: (j['status'] ?? 'Pending') as String,
        itemsCount: (j['itemsCount'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toDouble() ?? 0,
        accessToken: j['accessToken'] as String?,
        createdAt: DateTime.tryParse((j['createdAt'] ?? '') as String) ??
            DateTime.now(),
        scheduledDeliveryDate: j['scheduledDeliveryDate'] != null
            ? DateTime.tryParse(j['scheduledDeliveryDate'] as String)
            : null,
      );
}

class BuyerOrdersPage {
  const BuyerOrdersPage({
    required this.orders,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.filter,
    this.businessId,
  });

  final List<BuyerOrder> orders;
  final int total;
  final int page;
  final int pageSize;
  final String filter;
  final int? businessId;

  int get totalPages => pageSize == 0 ? 0 : (total / pageSize).ceil();
  bool get hasNext => page < totalPages;
  bool get hasPrev => page > 1;
  bool get isEmpty => orders.isEmpty;

  factory BuyerOrdersPage.fromJson(Map<String, dynamic> j) => BuyerOrdersPage(
        orders: ((j['orders'] as List?) ?? const [])
            .map((e) => BuyerOrder.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (j['total'] as num?)?.toInt() ?? 0,
        page: (j['page'] as num?)?.toInt() ?? 1,
        pageSize: (j['pageSize'] as num?)?.toInt() ?? 20,
        filter: (j['filter'] ?? 'all') as String,
        businessId: (j['businessId'] as num?)?.toInt(),
      );
}
