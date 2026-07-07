import 'package:intl/intl.dart';

/// Formatea un monto en pesos mexicanos sin decimales: `$1,250`.
String money(num value) => '\$${NumberFormat('#,##0', 'es_MX').format(value)}';

double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();
int _i(dynamic v) => v == null ? 0 : (v as num).toInt();

/// Estatus de pedido tal como los define `OrderStatus` en el backend.
enum SellerOrderStatus {
  pending,
  confirmed,
  shipped,
  inRoute,
  delivered,
  notDelivered,
  canceled,
  postponed;

  static SellerOrderStatus fromApi(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'pending':
        return SellerOrderStatus.pending;
      case 'confirmed':
        return SellerOrderStatus.confirmed;
      case 'shipped':
        return SellerOrderStatus.shipped;
      case 'inroute':
        return SellerOrderStatus.inRoute;
      case 'delivered':
        return SellerOrderStatus.delivered;
      case 'notdelivered':
        return SellerOrderStatus.notDelivered;
      case 'canceled':
        return SellerOrderStatus.canceled;
      case 'postponed':
        return SellerOrderStatus.postponed;
      default:
        return SellerOrderStatus.pending;
    }
  }

  String get api => switch (this) {
    SellerOrderStatus.pending => 'Pending',
    SellerOrderStatus.confirmed => 'Confirmed',
    SellerOrderStatus.shipped => 'Shipped',
    SellerOrderStatus.inRoute => 'InRoute',
    SellerOrderStatus.delivered => 'Delivered',
    SellerOrderStatus.notDelivered => 'NotDelivered',
    SellerOrderStatus.canceled => 'Canceled',
    SellerOrderStatus.postponed => 'Postponed',
  };
}

/// Tipo de entrega (`OrderType` en el backend).
enum SellerDeliveryType {
  delivery,
  pickup,
  pos;

  static SellerDeliveryType fromApi(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'pickup':
        return SellerDeliveryType.pickup;
      case 'pos_tienda':
      case 'postienda':
        return SellerDeliveryType.pos;
      default:
        return SellerDeliveryType.delivery;
    }
  }

  String get api => switch (this) {
    SellerDeliveryType.delivery => 'Delivery',
    SellerDeliveryType.pickup => 'PickUp',
    SellerDeliveryType.pos => 'POS_Tienda',
  };
}

class SellerOrderItem {
  const SellerOrderItem({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final int id;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  factory SellerOrderItem.fromJson(Map<String, dynamic> j) => SellerOrderItem(
    id: _i(j['id']),
    productName: (j['productName'] ?? '') as String,
    quantity: _i(j['quantity']),
    unitPrice: _d(j['unitPrice']),
    lineTotal: _d(j['lineTotal']),
  );
}

class SellerPayment {
  const SellerPayment({
    required this.id,
    required this.amount,
    required this.method,
    required this.date,
  });

  final int id;
  final double amount;
  final String method;
  final DateTime date;

  factory SellerPayment.fromJson(Map<String, dynamic> j) => SellerPayment(
    id: _i(j['id']),
    amount: _d(j['amount']),
    method: (j['method'] ?? '') as String,
    date:
        DateTime.tryParse((j['date'] ?? '') as String)?.toLocal() ??
        DateTime.now(),
  );
}

/// Pedido de vendedora mapeado de `OrderSummaryDto`.
class SellerOrder {
  const SellerOrder({
    required this.id,
    required this.clientName,
    required this.clientType,
    required this.status,
    required this.orderType,
    required this.total,
    required this.subtotal,
    required this.shippingCost,
    required this.amountPaid,
    required this.balanceDue,
    required this.itemsCount,
    required this.createdAt,
    this.clientPhone,
    this.clientAddress,
    this.alternativeAddress,
    this.deliveryInstructions,
    this.deliveryRouteId,
    this.clientLatitude,
    this.clientLongitude,
    this.scheduledDeliveryDate,
    this.expiresAt,
    this.clientFacebookProfileUrl,
    this.notifiedAt,
    this.clientPoints = 0,
    this.salesPeriodName,
    this.link,
    this.shareUrl,
    this.items = const [],
    this.payments = const [],
  });

  final int id;
  final String clientName;
  final String clientType; // "Nueva" | "Frecuente"
  final SellerOrderStatus status;
  final SellerDeliveryType orderType;
  final double total;
  final double subtotal;
  final double shippingCost;
  final double amountPaid;
  final double balanceDue;
  final int itemsCount;
  final DateTime createdAt;
  final String? clientPhone;
  final String? clientAddress;
  final String? alternativeAddress;
  final String? deliveryInstructions;
  final int? deliveryRouteId;
  final double? clientLatitude;
  final double? clientLongitude;
  final DateTime? scheduledDeliveryDate;
  final DateTime? expiresAt;
  final String? clientFacebookProfileUrl;
  final DateTime? notifiedAt;
  final int clientPoints;
  final String? salesPeriodName;
  final String? link;

  /// Enlace corto compartible (`{ShareLinkBaseUrl}/o/{token}`) que abre el muro
  /// de instalación o, si la app está instalada, directamente el pedido.
  final String? shareUrl;
  final List<SellerOrderItem> items;
  final List<SellerPayment> payments;

  bool get isFrequent => clientType.toLowerCase() == 'frecuente';
  bool get isPaid => total > 0 && balanceDue <= 0.01;
  double get paymentPercent {
    if (total <= 0) return 0;
    final p = amountPaid / total * 100;
    return p > 100 ? 100 : p;
  }

  String get initial =>
      clientName.trim().isEmpty ? '?' : clientName.trim()[0].toUpperCase();
  String? get effectiveAddress =>
      (alternativeAddress?.trim().isNotEmpty ?? false)
      ? alternativeAddress
      : clientAddress;
  bool get hasCoordinates => clientLatitude != null && clientLongitude != null;
  bool get isNotified => notifiedAt != null;

  factory SellerOrder.fromJson(Map<String, dynamic> j) => SellerOrder(
    id: _i(j['id']),
    clientName: (j['clientName'] ?? '') as String,
    clientType: (j['type'] ?? 'Nueva') as String,
    status: SellerOrderStatus.fromApi(j['status'] as String?),
    orderType: SellerDeliveryType.fromApi(j['orderType'] as String?),
    total: _d(j['total']),
    subtotal: _d(j['subtotal']),
    shippingCost: _d(j['shippingCost']),
    amountPaid: _d(j['amountPaid']),
    balanceDue: _d(j['balanceDue']),
    itemsCount: _i(j['itemsCount']),
    createdAt:
        DateTime.tryParse((j['createdAt'] ?? '') as String)?.toLocal() ??
        DateTime.now(),
    clientPhone: j['clientPhone'] as String?,
    clientAddress: j['clientAddress'] as String?,
    alternativeAddress: j['alternativeAddress'] as String?,
    deliveryInstructions: j['deliveryInstructions'] as String?,
    deliveryRouteId: (j['deliveryRouteId'] as num?)?.toInt(),
    clientLatitude: (j['clientLatitude'] as num?)?.toDouble(),
    clientLongitude: (j['clientLongitude'] as num?)?.toDouble(),
    scheduledDeliveryDate: j['scheduledDeliveryDate'] == null
        ? null
        : DateTime.tryParse(j['scheduledDeliveryDate'] as String)?.toLocal(),
    expiresAt: j['expiresAt'] == null
        ? null
        : DateTime.tryParse(j['expiresAt'] as String)?.toLocal(),
    clientFacebookProfileUrl: j['clientFacebookProfileUrl'] as String?,
    notifiedAt: j['notifiedAt'] == null
        ? null
        : DateTime.tryParse(j['notifiedAt'] as String)?.toLocal(),
    clientPoints: _i(j['clientPoints']),
    salesPeriodName: j['salesPeriodName'] as String?,
    link: j['link'] as String?,
    shareUrl: j['shareUrl'] as String?,
    items: ((j['items'] as List?) ?? const [])
        .map((e) => SellerOrderItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    payments: ((j['payments'] as List?) ?? const [])
        .map((e) => SellerPayment.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Página de `PagedResult<OrderSummaryDto>`.
class SellerOrdersPage {
  const SellerOrdersPage({
    required this.items,
    required this.totalCount,
    required this.currentPage,
    required this.pageSize,
  });

  final List<SellerOrder> items;
  final int totalCount;
  final int currentPage;
  final int pageSize;

  int get totalPages =>
      pageSize <= 0 ? 1 : (totalCount / pageSize).ceil().clamp(1, 9999);
  bool get hasNext => currentPage < totalPages;
  bool get hasPrev => currentPage > 1;
  bool get isEmpty => items.isEmpty;

  factory SellerOrdersPage.fromJson(Map<String, dynamic> j) => SellerOrdersPage(
    items: ((j['items'] as List?) ?? const [])
        .map((e) => SellerOrder.fromJson(e as Map<String, dynamic>))
        .toList(),
    totalCount: _i(j['totalCount']),
    currentPage: _i(j['currentPage']),
    pageSize: _i(j['pageSize']),
  );
}

/// Corte de venta activo dentro del dashboard.
class SellerActivePeriod {
  const SellerActivePeriod({
    required this.id,
    required this.name,
    required this.totalSales,
    required this.totalInvested,
    required this.netProfit,
    required this.collectedAmount,
  });

  final int id;
  final String name;
  final double totalSales;
  final double totalInvested;
  final double netProfit;
  final double collectedAmount;

  factory SellerActivePeriod.fromJson(Map<String, dynamic> j) =>
      SellerActivePeriod(
        id: _i(j['id']),
        name: (j['name'] ?? '') as String,
        totalSales: _d(j['totalSales']),
        totalInvested: _d(j['totalInvested']),
        netProfit: _d(j['netProfit']),
        collectedAmount: _d(j['collectedAmount']),
      );
}

class MonthlySales {
  const MonthlySales({required this.month, required this.sales});
  final String month;
  final double sales;

  factory MonthlySales.fromJson(Map<String, dynamic> j) =>
      MonthlySales(month: (j['month'] ?? '') as String, sales: _d(j['sales']));
}

/// Dashboard de vendedora mapeado de `DashboardDto`.
class SellerDashboard {
  const SellerDashboard({
    required this.totalOrders,
    required this.pendingOrders,
    required this.deliveredOrders,
    required this.activeRoutes,
    required this.revenueToday,
    required this.revenueMonth,
    required this.pendingAmount,
    required this.totalInvestment,
    required this.ordersDelivery,
    required this.ordersPickUp,
    required this.salesByMonth,
    required this.recentOrders,
    this.activePeriod,
  });

  final int totalOrders;
  final int pendingOrders;
  final int deliveredOrders;
  final int activeRoutes;
  final double revenueToday;
  final double revenueMonth;
  final double pendingAmount;
  final double totalInvestment;
  final int ordersDelivery;
  final int ordersPickUp;
  final List<MonthlySales> salesByMonth;
  final List<SellerOrder> recentOrders;
  final SellerActivePeriod? activePeriod;

  factory SellerDashboard.fromJson(Map<String, dynamic> j) => SellerDashboard(
    totalOrders: _i(j['totalOrders']),
    pendingOrders: _i(j['pendingOrders']),
    deliveredOrders: _i(j['deliveredOrders']),
    activeRoutes: _i(j['activeRoutes']),
    revenueToday: _d(j['revenueToday']),
    revenueMonth: _d(j['revenueMonth']),
    pendingAmount: _d(j['pendingAmount']),
    totalInvestment: _d(j['totalInvestment']),
    ordersDelivery: _i(j['ordersDelivery']),
    ordersPickUp: _i(j['ordersPickUp']),
    salesByMonth: ((j['salesByMonth'] as List?) ?? const [])
        .map((e) => MonthlySales.fromJson(e as Map<String, dynamic>))
        .toList(),
    recentOrders: ((j['recentOrders'] as List?) ?? const [])
        .map((e) => SellerOrder.fromJson(e as Map<String, dynamic>))
        .toList(),
    activePeriod: j['activePeriod'] == null
        ? null
        : SellerActivePeriod.fromJson(
            j['activePeriod'] as Map<String, dynamic>,
          ),
  );
}

class SellerClient {
  const SellerClient({
    required this.id,
    required this.name,
    required this.ordersCount,
    required this.totalSpent,
    required this.type,
    this.phone,
    this.address,
    this.deliveryInstructions,
    this.latitude,
    this.longitude,
    this.aliases = const [],
  });

  final int id;
  final String name;
  final int ordersCount;
  final double totalSpent;
  final String type;
  final String? phone;
  final String? address;
  final String? deliveryInstructions;
  final double? latitude;
  final double? longitude;
  final List<String> aliases;

  bool get isFrequent => ordersCount > 0 || type.toLowerCase() == 'frecuente';

  factory SellerClient.fromJson(Map<String, dynamic> j) => SellerClient(
    id: _i(j['id']),
    name: (j['name'] ?? '') as String,
    ordersCount: _i(j['ordersCount']),
    totalSpent: _d(j['totalSpent']),
    type: (j['type'] ?? 'Nueva') as String,
    phone: j['phone'] as String?,
    address: j['address'] as String?,
    deliveryInstructions: j['deliveryInstructions'] as String?,
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    aliases: ((j['aliases'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
  );
}

class CommonProduct {
  const CommonProduct({
    required this.name,
    required this.count,
    required this.typicalPrice,
  });

  final String name;
  final int count;
  final double typicalPrice;

  factory CommonProduct.fromJson(Map<String, dynamic> j) => CommonProduct(
    name: (j['name'] ?? '') as String,
    count: _i(j['count']),
    typicalPrice: _d(j['typicalPrice']),
  );
}

/// Artículo en construcción para crear un pedido nuevo (`ManualOrderItem`).
class DraftOrderItem {
  DraftOrderItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });
  String name;
  int quantity;
  double unitPrice;
  double get lineTotal => quantity * unitPrice;

  Map<String, dynamic> toJson() => {
    'productName': name,
    'quantity': quantity,
    'unitPrice': unitPrice,
  };
}
