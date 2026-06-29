/// Estados visibles del pedido en la pantalla de rastreo. Incluye el
/// `InTransit` sintético que el backend puede mandar cuando el repartidor
/// viene en camino a la clienta.
enum TrackingStatus {
  pending,
  confirmed,
  shipped,
  inRoute,
  inTransit,
  delivered,
  notDelivered,
  canceled,
  postponed,
  unknown,
}

TrackingStatus trackingStatusFromString(String? value) {
  switch (value) {
    case 'Pending':
      return TrackingStatus.pending;
    case 'Confirmed':
      return TrackingStatus.confirmed;
    case 'Shipped':
      return TrackingStatus.shipped;
    case 'InRoute':
      return TrackingStatus.inRoute;
    case 'InTransit':
      return TrackingStatus.inTransit;
    case 'Delivered':
      return TrackingStatus.delivered;
    case 'NotDelivered':
      return TrackingStatus.notDelivered;
    case 'Canceled':
      return TrackingStatus.canceled;
    case 'Postponed':
      return TrackingStatus.postponed;
    default:
      return TrackingStatus.unknown;
  }
}

extension TrackingStatusDisplay on TrackingStatus {
  String get title {
    switch (this) {
      case TrackingStatus.pending:
        return 'Pedido confirmado';
      case TrackingStatus.confirmed:
        return 'Preparando tu pedido';
      case TrackingStatus.shipped:
        return 'Tu pedido salió';
      case TrackingStatus.inRoute:
        return 'Va en camino contigo';
      case TrackingStatus.inTransit:
        return 'Tu repartidor está cerca';
      case TrackingStatus.delivered:
        return '¡Entregado!';
      case TrackingStatus.notDelivered:
        return 'No se pudo entregar';
      case TrackingStatus.canceled:
        return 'Pedido cancelado';
      case TrackingStatus.postponed:
        return 'Entrega pospuesta';
      case TrackingStatus.unknown:
        return 'Tu pedido';
    }
  }

  String get subtitle {
    switch (this) {
      case TrackingStatus.pending:
        return 'Lo estamos preparando con tu tienda';
      case TrackingStatus.confirmed:
        return 'Tu tienda está empacando con cariño';
      case TrackingStatus.shipped:
        return 'El chofer ya pasó por la tienda';
      case TrackingStatus.inRoute:
      case TrackingStatus.inTransit:
        return 'Tu pedido va en camino';
      case TrackingStatus.delivered:
        return 'Gracias por tu compra 💖';
      case TrackingStatus.notDelivered:
        return 'El chofer no pudo completar la entrega';
      case TrackingStatus.canceled:
        return 'Tu tienda canceló este pedido';
      case TrackingStatus.postponed:
        return 'Te avisaremos cuando se reprograme';
      case TrackingStatus.unknown:
        return 'Buscando tu pedido…';
    }
  }

  /// Etapa del timeline 1..4. `0` significa "no hay etapa aplicable".
  int get timelineStep {
    switch (this) {
      case TrackingStatus.pending:
        return 1;
      case TrackingStatus.confirmed:
        return 2;
      case TrackingStatus.shipped:
      case TrackingStatus.inRoute:
      case TrackingStatus.inTransit:
        return 3;
      case TrackingStatus.delivered:
        return 4;
      default:
        return 0;
    }
  }

  bool get isTerminal =>
      this == TrackingStatus.delivered ||
      this == TrackingStatus.notDelivered ||
      this == TrackingStatus.canceled;

  bool get hasLiveMap =>
      this == TrackingStatus.shipped ||
      this == TrackingStatus.inRoute ||
      this == TrackingStatus.inTransit;
}

/// Item del pedido.
class OrderItem {
  const OrderItem({
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

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        id: (j['id'] as num).toInt(),
        productName: (j['productName'] ?? '') as String,
        quantity: (j['quantity'] as num?)?.toInt() ?? 0,
        unitPrice: (j['unitPrice'] as num?)?.toDouble() ?? 0,
        lineTotal: (j['lineTotal'] as num?)?.toDouble() ?? 0,
      );
}

/// Ubicación del repartidor en el último GET y/o en la última `LocationUpdate`.
class DriverLocation {
  const DriverLocation({
    required this.latitude,
    required this.longitude,
    required this.lastUpdate,
  });

  final double latitude;
  final double longitude;
  final DateTime lastUpdate;

  factory DriverLocation.fromJson(Map<String, dynamic> j) => DriverLocation(
        latitude: (j['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (j['longitude'] as num?)?.toDouble() ?? 0,
        lastUpdate: DateTime.tryParse((j['lastUpdate'] ?? '') as String) ??
            DateTime.now(),
      );
}

/// Vista pública del pedido devuelta por `GET /api/pedido/{accessToken}`.
class OrderTracking {
  const OrderTracking({
    required this.clientId,
    required this.clientName,
    required this.items,
    required this.subtotal,
    required this.shippingCost,
    required this.total,
    required this.status,
    required this.isCurrentDelivery,
    required this.amountPaid,
    required this.balanceDue,
    required this.clientPoints,
    this.clientAddress,
    this.scheduledDeliveryDate,
    this.driverLocation,
    this.deliveriesAhead,
    this.totalDeliveries,
    this.queuePosition,
    this.failureReason,
    this.deliveredAt,
  });

  final int clientId;
  final String clientName;
  final List<OrderItem> items;
  final double subtotal;
  final double shippingCost;
  final double total;
  final TrackingStatus status;
  final bool isCurrentDelivery;
  final double amountPaid;
  final double balanceDue;
  final int clientPoints;
  final String? clientAddress;
  final DateTime? scheduledDeliveryDate;
  final DriverLocation? driverLocation;
  final int? deliveriesAhead;
  final int? totalDeliveries;
  final int? queuePosition;
  final String? failureReason;
  final DateTime? deliveredAt;

  String get driverHint {
    final ahead = deliveriesAhead ?? 0;
    if (ahead == 0) return 'Tu repartidor va hacia ti';
    if (ahead == 1) return 'A 1 parada de ti';
    return 'A $ahead paradas de ti';
  }

  String get etaLabel {
    if (status == TrackingStatus.delivered) {
      return '¡Listo!';
    }
    if (status == TrackingStatus.notDelivered) {
      return 'No se pudo entregar';
    }
    if (deliveriesAhead == null) {
      return 'Asignando repartidor…';
    }
    if (isCurrentDelivery) {
      return 'Llegando ahora';
    }
    return 'Llega pronto';
  }

  factory OrderTracking.fromJson(Map<String, dynamic> j) => OrderTracking(
        clientId: (j['clientId'] as num?)?.toInt() ?? 0,
        clientName: (j['clientName'] ?? 'Cliente') as String,
        items: ((j['items'] as List?) ?? const [])
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        subtotal: (j['subtotal'] as num?)?.toDouble() ?? 0,
        shippingCost: (j['shippingCost'] as num?)?.toDouble() ?? 0,
        total: (j['total'] as num?)?.toDouble() ?? 0,
        status: trackingStatusFromString(j['status'] as String?),
        isCurrentDelivery: (j['isCurrentDelivery'] as bool?) ?? false,
        amountPaid: (j['amountPaid'] as num?)?.toDouble() ?? 0,
        balanceDue: (j['balanceDue'] as num?)?.toDouble() ?? 0,
        clientPoints: (j['clientPoints'] as num?)?.toInt() ?? 0,
        clientAddress: j['clientAddress'] as String?,
        scheduledDeliveryDate: j['scheduledDeliveryDate'] != null
            ? DateTime.tryParse(j['scheduledDeliveryDate'] as String)
            : null,
        driverLocation: j['driverLocation'] != null
            ? DriverLocation.fromJson(
                j['driverLocation'] as Map<String, dynamic>)
            : null,
        deliveriesAhead: (j['deliveriesAhead'] as num?)?.toInt(),
        totalDeliveries: (j['totalDeliveries'] as num?)?.toInt(),
        queuePosition: (j['queuePosition'] as num?)?.toInt(),
        failureReason: j['failureReason'] as String?,
        deliveredAt: j['deliveredAt'] != null
            ? DateTime.tryParse(j['deliveredAt'] as String)
            : null,
      );

  OrderTracking copyWith({
    DriverLocation? driverLocation,
    TrackingStatus? status,
    int? deliveriesAhead,
    int? queuePosition,
    bool? isCurrentDelivery,
  }) =>
      OrderTracking(
        clientId: clientId,
        clientName: clientName,
        items: items,
        subtotal: subtotal,
        shippingCost: shippingCost,
        total: total,
        status: status ?? this.status,
        isCurrentDelivery: isCurrentDelivery ?? this.isCurrentDelivery,
        amountPaid: amountPaid,
        balanceDue: balanceDue,
        clientPoints: clientPoints,
        clientAddress: clientAddress,
        scheduledDeliveryDate: scheduledDeliveryDate,
        driverLocation: driverLocation ?? this.driverLocation,
        deliveriesAhead: deliveriesAhead ?? this.deliveriesAhead,
        totalDeliveries: totalDeliveries,
        queuePosition: queuePosition ?? this.queuePosition,
        failureReason: failureReason,
        deliveredAt: deliveredAt,
      );
}

/// Etapa del timeline que se renderiza en la bottom sheet.
class TimelineStep {
  const TimelineStep({
    required this.index,
    required this.label,
    required this.subtitle,
    required this.state,
  });

  final int index;
  final String label;
  final String subtitle;
  final TimelineStepState state;
}

enum TimelineStepState { done, active, todo }
