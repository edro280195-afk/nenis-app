import 'package:intl/intl.dart';

double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();
double? _dn(dynamic v) => v == null ? null : (v as num).toDouble();
int _i(dynamic v) => v == null ? 0 : (v as num).toInt();
int? _in(dynamic v) => v == null ? null : (v as num).toInt();

String routeMoney(num value) =>
    '\$${NumberFormat('#,##0', 'es_MX').format(value)}';

enum SellerRouteStatus {
  pending,
  active,
  completed,
  canceled;

  static SellerRouteStatus fromApi(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'active':
        return SellerRouteStatus.active;
      case 'completed':
        return SellerRouteStatus.completed;
      case 'canceled':
        return SellerRouteStatus.canceled;
      default:
        return SellerRouteStatus.pending;
    }
  }

  String get label => switch (this) {
    SellerRouteStatus.pending => 'Pendiente',
    SellerRouteStatus.active => 'En reparto',
    SellerRouteStatus.completed => 'Completada',
    SellerRouteStatus.canceled => 'Cancelada',
  };
}

enum SellerDeliveryStatus {
  pending,
  delivered,
  notDelivered,
  inTransit;

  static SellerDeliveryStatus fromApi(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'delivered':
        return SellerDeliveryStatus.delivered;
      case 'notdelivered':
        return SellerDeliveryStatus.notDelivered;
      case 'intransit':
        return SellerDeliveryStatus.inTransit;
      default:
        return SellerDeliveryStatus.pending;
    }
  }

  String get label => switch (this) {
    SellerDeliveryStatus.pending => 'Pendiente',
    SellerDeliveryStatus.delivered => 'Entregado',
    SellerDeliveryStatus.notDelivered => 'No entregado',
    SellerDeliveryStatus.inTransit => 'En camino',
  };
}

class SellerRouteDelivery {
  const SellerRouteDelivery({
    required this.deliveryId,
    required this.sortOrder,
    required this.clientName,
    required this.status,
    required this.total,
    required this.amountPaid,
    required this.balanceDue,
    required this.kind,
    this.orderId,
    this.clientAddress,
    this.alternativeAddress,
    this.latitude,
    this.longitude,
    this.deliveredAt,
    this.failureReason,
    this.clientPhone,
    this.paymentMethod,
    this.deliveryInstructions,
    this.tandaParticipantId,
    this.tandaName,
    this.tandaProductName,
    this.tandaWeek,
    this.tandaTotalWeeks,
    this.tandaVariant,
  });

  final int deliveryId;
  final int? orderId;
  final int sortOrder;
  final String clientName;
  final String? clientAddress;
  final String? alternativeAddress;
  final double? latitude;
  final double? longitude;
  final SellerDeliveryStatus status;
  final double total;
  final double amountPaid;
  final double balanceDue;
  final DateTime? deliveredAt;
  final String? failureReason;
  final String? clientPhone;
  final String? paymentMethod;
  final String? deliveryInstructions;
  final String kind;
  final String? tandaParticipantId;
  final String? tandaName;
  final String? tandaProductName;
  final int? tandaWeek;
  final int? tandaTotalWeeks;
  final String? tandaVariant;

  String? get effectiveAddress =>
      (alternativeAddress?.trim().isNotEmpty ?? false)
      ? alternativeAddress
      : clientAddress;
  bool get hasCoordinates => latitude != null && longitude != null;
  bool get isTanda => kind.toLowerCase() == 'tanda';
  bool get isDelivered => status == SellerDeliveryStatus.delivered;
  bool get isClosed =>
      status == SellerDeliveryStatus.delivered ||
      status == SellerDeliveryStatus.notDelivered;

  factory SellerRouteDelivery.fromJson(Map<String, dynamic> j) {
    return SellerRouteDelivery(
      deliveryId: _i(j['deliveryId'] ?? j['id']),
      orderId: _in(j['orderId']),
      sortOrder: _i(j['sortOrder']),
      clientName: (j['clientName'] ?? 'Clienta') as String,
      clientAddress: j['clientAddress'] as String?,
      alternativeAddress: j['alternativeAddress'] as String?,
      latitude: _dn(j['latitude']),
      longitude: _dn(j['longitude']),
      status: SellerDeliveryStatus.fromApi(j['status'] as String?),
      total: _d(j['total']),
      amountPaid: _d(j['amountPaid']),
      balanceDue: _d(j['balanceDue']),
      deliveredAt: j['deliveredAt'] == null
          ? null
          : DateTime.tryParse(j['deliveredAt'] as String)?.toLocal(),
      failureReason: j['failureReason'] as String?,
      clientPhone: j['clientPhone'] as String?,
      paymentMethod: j['paymentMethod'] as String?,
      deliveryInstructions: j['deliveryInstructions'] as String?,
      kind: (j['kind'] ?? 'Order') as String,
      tandaParticipantId: j['tandaParticipantId']?.toString(),
      tandaName: j['tandaName'] as String?,
      tandaProductName: j['tandaProductName'] as String?,
      tandaWeek: _in(j['tandaWeek']),
      tandaTotalWeeks: _in(j['tandaTotalWeeks']),
      tandaVariant: j['tandaVariant'] as String?,
    );
  }
}

class SellerRoute {
  const SellerRoute({
    required this.id,
    required this.driverToken,
    required this.driverLink,
    required this.status,
    required this.createdAt,
    required this.deliveries,
    this.startedAt,
  });

  final int id;
  final String driverToken;
  final String driverLink;
  final SellerRouteStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final List<SellerRouteDelivery> deliveries;

  String get name => 'Ruta #$id';
  int get totalStops => deliveries.length;
  int get deliveredStops => deliveries.where((d) => d.isDelivered).length;
  int get pendingStops => deliveries.where((d) => !d.isClosed).length;
  double get totalAmount =>
      deliveries.fold<double>(0, (sum, d) => sum + d.total);
  double get balanceDue =>
      deliveries.fold<double>(0, (sum, d) => sum + d.balanceDue);
  bool get hasMapPoints => deliveries.any((d) => d.hasCoordinates);
  bool get isOpen =>
      status == SellerRouteStatus.pending || status == SellerRouteStatus.active;

  factory SellerRoute.fromJson(Map<String, dynamic> j) {
    return SellerRoute(
      id: _i(j['id']),
      driverToken: (j['driverToken'] ?? '') as String,
      driverLink: (j['driverLink'] ?? '') as String,
      status: SellerRouteStatus.fromApi(j['status'] as String?),
      createdAt:
          DateTime.tryParse((j['createdAt'] ?? '') as String)?.toLocal() ??
          DateTime.now(),
      startedAt: j['startedAt'] == null
          ? null
          : DateTime.tryParse(j['startedAt'] as String)?.toLocal(),
      deliveries: ((j['deliveries'] as List?) ?? const [])
          .map((e) => SellerRouteDelivery.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RouteCandidate {
  const RouteCandidate({
    required this.key,
    required this.kind,
    required this.clientName,
    required this.total,
    this.orderId,
    this.tandaParticipantId,
    this.subtitle,
    this.address,
    this.phone,
    this.latitude,
    this.longitude,
    this.badge,
  });

  final String key;
  final String kind;
  final int? orderId;
  final String? tandaParticipantId;
  final String clientName;
  final String? subtitle;
  final String? address;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final double total;
  final String? badge;

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get isOrder => orderId != null;
  String get initial =>
      clientName.trim().isEmpty ? '?' : clientName.trim()[0].toUpperCase();

  factory RouteCandidate.fromOrderJson(Map<String, dynamic> j) {
    final orderId = _i(j['id']);
    final alternativeAddress = j['alternativeAddress'] as String?;
    final clientAddress = j['clientAddress'] as String?;
    return RouteCandidate(
      key: 'order:$orderId',
      kind: 'Pedido',
      orderId: orderId,
      clientName: (j['clientName'] ?? 'Clienta') as String,
      subtitle:
          '#$orderId · ${(j['itemsCount'] as num?)?.toInt() ?? 0} artículos',
      address: (alternativeAddress?.trim().isNotEmpty ?? false)
          ? alternativeAddress
          : clientAddress,
      phone: j['clientPhone'] as String?,
      latitude: _dn(j['clientLatitude']),
      longitude: _dn(j['clientLongitude']),
      total: _d(j['total']),
      badge: j['type'] as String?,
    );
  }

  factory RouteCandidate.fromTandaJson(Map<String, dynamic> j) {
    final participantId = (j['tandaParticipantId'] ?? '').toString();
    final week = _i(j['week']);
    final totalWeeks = _i(j['totalWeeks']);
    return RouteCandidate(
      key: 'tanda:$participantId',
      kind: 'Tanda',
      tandaParticipantId: participantId,
      clientName: (j['clientName'] ?? 'Clienta') as String,
      subtitle: '${j['tandaName'] ?? 'Tanda'} · Semana $week/$totalWeeks',
      address: j['clientAddress'] as String?,
      phone: j['clientPhone'] as String?,
      latitude: _dn(j['clientLatitude']),
      longitude: _dn(j['clientLongitude']),
      total: 0,
      badge: j['tandaProductName'] as String?,
    );
  }
}

class SkippedStop {
  const SkippedStop({
    required this.kind,
    required this.id,
    required this.name,
    required this.reason,
  });

  final String kind;
  final String id;
  final String name;
  final String reason;

  factory SkippedStop.fromJson(Map<String, dynamic> j) => SkippedStop(
    kind: (j['kind'] ?? '') as String,
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '') as String,
    reason: (j['reason'] ?? '') as String,
  );
}

class RoutePreviewStop {
  const RoutePreviewStop({
    required this.kind,
    required this.sortOrder,
    required this.clientName,
    required this.total,
    required this.hasCoords,
    this.orderId,
    this.tandaParticipantId,
    this.clientAddress,
    this.latitude,
    this.longitude,
    this.tandaName,
    this.tandaWeek,
  });

  final String kind;
  final int? orderId;
  final String? tandaParticipantId;
  final int sortOrder;
  final String clientName;
  final String? clientAddress;
  final double? latitude;
  final double? longitude;
  final double total;
  final bool hasCoords;
  final String? tandaName;
  final int? tandaWeek;

  bool get isTanda => kind.toLowerCase() == 'tanda';

  factory RoutePreviewStop.fromJson(Map<String, dynamic> j) => RoutePreviewStop(
    kind: (j['kind'] ?? 'Order') as String,
    orderId: _in(j['orderId']),
    tandaParticipantId: j['tandaParticipantId']?.toString(),
    sortOrder: _i(j['sortOrder']),
    clientName: (j['clientName'] ?? 'Clienta') as String,
    clientAddress: j['clientAddress'] as String?,
    latitude: _dn(j['latitude']),
    longitude: _dn(j['longitude']),
    total: _d(j['total']),
    hasCoords: (j['hasCoords'] as bool?) ?? false,
    tandaName: j['tandaName'] as String?,
    tandaWeek: _in(j['tandaWeek']),
  );
}

class RoutePreview {
  const RoutePreview({
    required this.stops,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.optimizerSource,
    required this.skipped,
    required this.stopsWithoutCoords,
    this.polylineEncoded,
    this.depotLatitude,
    this.depotLongitude,
  });

  final List<RoutePreviewStop> stops;
  final int totalDistanceMeters;
  final int totalDurationSeconds;
  final String optimizerSource;
  final List<SkippedStop> skipped;
  final int stopsWithoutCoords;
  final String? polylineEncoded;
  final double? depotLatitude;
  final double? depotLongitude;

  String get distanceLabel {
    if (totalDistanceMeters <= 0) return 'Sin distancia';
    if (totalDistanceMeters < 1000) return '$totalDistanceMeters m';
    return '${(totalDistanceMeters / 1000).toStringAsFixed(1)} km';
  }

  String get durationLabel {
    if (totalDurationSeconds <= 0) return 'Sin tiempo';
    final minutes = (totalDurationSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  factory RoutePreview.fromJson(Map<String, dynamic> j) => RoutePreview(
    stops: ((j['stops'] as List?) ?? const [])
        .map((e) => RoutePreviewStop.fromJson(e as Map<String, dynamic>))
        .toList(),
    totalDistanceMeters: _i(j['totalDistanceMeters']),
    totalDurationSeconds: _i(j['totalDurationSeconds']),
    optimizerSource: (j['optimizerSource'] ?? '') as String,
    skipped: ((j['skipped'] as List?) ?? const [])
        .map((e) => SkippedStop.fromJson(e as Map<String, dynamic>))
        .toList(),
    stopsWithoutCoords: _i(j['stopsWithoutCoords']),
    polylineEncoded: j['polylineEncoded'] as String?,
    depotLatitude: _dn(j['depotLatitude']),
    depotLongitude: _dn(j['depotLongitude']),
  );
}

class SellerRoutesWorkspace {
  const SellerRoutesWorkspace({required this.routes, required this.candidates});

  final List<SellerRoute> routes;
  final List<RouteCandidate> candidates;

  List<SellerRoute> get openRoutes =>
      routes.where((r) => r.isOpen).toList(growable: false);
  List<SellerRoute> get historyRoutes => routes
      .where((r) => r.status == SellerRouteStatus.completed)
      .toList(growable: false);
}
