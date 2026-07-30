class BuyerStore {
  const BuyerStore({
    required this.businessId,
    required this.name,
    required this.brandPrimaryColor,
    required this.points,
    required this.isLive,
    this.slug,
    this.logoUrl,
  });

  final int businessId;
  final String name;
  final String brandPrimaryColor;
  final int points;
  final bool isLive;
  final String? slug;
  final String? logoUrl;

  factory BuyerStore.fromJson(Map<String, dynamic> j) => BuyerStore(
        businessId: (j['businessId'] as num).toInt(),
        name: (j['name'] ?? '') as String,
        brandPrimaryColor: (j['brandPrimaryColor'] ?? '#FB6F9C') as String,
        points: (j['points'] as num?)?.toInt() ?? 0,
        isLive: (j['isLive'] as bool?) ?? false,
        slug: j['slug'] as String?,
        logoUrl: j['logoUrl'] as String?,
      );

  String get initial =>
      name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
}

class BuyerActiveOrder {
  const BuyerActiveOrder({
    required this.orderId,
    required this.businessId,
    required this.businessName,
    required this.brandPrimaryColor,
    required this.status,
    required this.total,
    this.accessToken,
    this.scheduledDeliveryDate,
  });

  final int orderId;
  final int businessId;
  final String businessName;
  final String brandPrimaryColor;
  final String status;
  final double total;
  final String? accessToken;
  final DateTime? scheduledDeliveryDate;

  factory BuyerActiveOrder.fromJson(Map<String, dynamic> j) => BuyerActiveOrder(
        orderId: (j['orderId'] as num).toInt(),
        businessId: (j['businessId'] as num).toInt(),
        businessName: (j['businessName'] ?? '') as String,
        brandPrimaryColor: (j['brandPrimaryColor'] ?? '#FB6F9C') as String,
        status: (j['status'] ?? 'Pending') as String,
        total: (j['total'] as num?)?.toDouble() ?? 0,
        accessToken: j['accessToken'] as String?,
        scheduledDeliveryDate: j['scheduledDeliveryDate'] != null
            ? DateTime.tryParse(j['scheduledDeliveryDate'] as String)
            : null,
      );
}

class BuyerRecentOrder {
  const BuyerRecentOrder({
    required this.orderId,
    required this.businessId,
    required this.businessName,
    required this.brandPrimaryColor,
    required this.status,
    required this.itemsCount,
    required this.total,
    required this.createdAt,
    this.accessToken,
  });

  final int orderId;
  final int businessId;
  final String businessName;
  final String brandPrimaryColor;
  final String status;
  final int itemsCount;
  final double total;
  final DateTime createdAt;
  final String? accessToken;

  factory BuyerRecentOrder.fromJson(Map<String, dynamic> j) => BuyerRecentOrder(
        orderId: (j['orderId'] as num).toInt(),
        businessId: (j['businessId'] as num).toInt(),
        businessName: (j['businessName'] ?? '') as String,
        brandPrimaryColor: (j['brandPrimaryColor'] ?? '#FB6F9C') as String,
        status: (j['status'] ?? 'Pending') as String,
        itemsCount: (j['itemsCount'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.tryParse((j['createdAt'] ?? '') as String) ??
            DateTime.now(),
        accessToken: j['accessToken'] as String?,
      );

  String get initial => businessName.isNotEmpty
      ? businessName.substring(0, 1).toUpperCase()
      : '?';
}

class BuyerHome {
  const BuyerHome({
    required this.displayName,
    required this.totalPoints,
    required this.stores,
    required this.recentOrders,
    required this.liveCount,
    this.activeOrder,
  });

  final String displayName;
  final int totalPoints;
  final List<BuyerStore> stores;
  final List<BuyerRecentOrder> recentOrders;
  final int liveCount;
  final BuyerActiveOrder? activeOrder;

  bool get isEmpty =>
      stores.isEmpty && recentOrders.isEmpty && activeOrder == null;

  factory BuyerHome.fromJson(Map<String, dynamic> j) => BuyerHome(
        displayName: (j['displayName'] ?? '') as String,
        totalPoints: (j['totalPoints'] as num?)?.toInt() ?? 0,
        activeOrder: j['activeOrder'] != null
            ? BuyerActiveOrder.fromJson(j['activeOrder'] as Map<String, dynamic>)
            : null,
        stores: ((j['stores'] as List?) ?? const [])
            .map((e) => BuyerStore.fromJson(e as Map<String, dynamic>))
            .toList(),
        recentOrders: ((j['recentOrders'] as List?) ?? const [])
            .map((e) => BuyerRecentOrder.fromJson(e as Map<String, dynamic>))
            .toList(),
        liveCount: (j['liveCount'] as num?)?.toInt() ?? 0,
      );
}
