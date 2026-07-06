import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Estatus de un pedido en el frente de la vendedora.
enum SellerOrderStatus { pending, confirmed, route, delivered }

/// Tipo de entrega del pedido.
enum SellerDeliveryType { delivery, pickup }

/// Formatea un monto en pesos mexicanos sin decimales: `$1,250`.
String money(num value) =>
    '\$${NumberFormat('#,##0', 'es_MX').format(value)}';

@immutable
class SellerOrderItem {
  const SellerOrderItem({
    required this.id,
    required this.name,
    required this.qty,
    required this.unitPrice,
  });

  final String id;
  final String name;
  final int qty;
  final double unitPrice;

  double get lineTotal => qty * unitPrice;

  SellerOrderItem copyWith({String? name, int? qty, double? unitPrice}) =>
      SellerOrderItem(
        id: id,
        name: name ?? this.name,
        qty: qty ?? this.qty,
        unitPrice: unitPrice ?? this.unitPrice,
      );
}

@immutable
class SellerPayment {
  const SellerPayment({
    required this.id,
    required this.amount,
    required this.method,
    required this.date,
  });

  final String id;
  final double amount;
  final String method; // Efectivo | Transferencia | Tarjeta
  final DateTime date;
}

@immutable
class SellerOrder {
  const SellerOrder({
    required this.id,
    required this.clientName,
    this.clientPhone = '',
    this.isFrequent = false,
    this.status = SellerOrderStatus.pending,
    this.deliveryType = SellerDeliveryType.delivery,
    this.address = '',
    required this.createdAt,
    this.scheduledDate,
    this.shippingCost = 0,
    this.items = const [],
    this.payments = const [],
  });

  final String id; // folio, ej. "10049"
  final String clientName;
  final String clientPhone;
  final bool isFrequent;
  final SellerOrderStatus status;
  final SellerDeliveryType deliveryType;
  final String address;
  final DateTime createdAt;
  final DateTime? scheduledDate;
  final double shippingCost;
  final List<SellerOrderItem> items;
  final List<SellerPayment> payments;

  double get subtotal => items.fold(0, (s, i) => s + i.lineTotal);
  double get total => subtotal + shippingCost;
  double get amountPaid => payments.fold(0, (s, p) => s + p.amount);
  double get balanceDue {
    final due = total - amountPaid;
    return due < 0 ? 0 : due;
  }

  int get itemsCount => items.fold(0, (s, i) => s + i.qty);
  double get paymentPercent {
    if (total <= 0) return 0;
    final p = amountPaid / total * 100;
    return p > 100 ? 100 : p;
  }

  bool get isPaid => total > 0 && balanceDue <= 0;
  String get initial =>
      clientName.trim().isEmpty ? '?' : clientName.trim()[0].toUpperCase();

  SellerOrder copyWith({
    String? clientName,
    String? clientPhone,
    bool? isFrequent,
    SellerOrderStatus? status,
    SellerDeliveryType? deliveryType,
    String? address,
    DateTime? scheduledDate,
    double? shippingCost,
    List<SellerOrderItem>? items,
    List<SellerPayment>? payments,
  }) =>
      SellerOrder(
        id: id,
        clientName: clientName ?? this.clientName,
        clientPhone: clientPhone ?? this.clientPhone,
        isFrequent: isFrequent ?? this.isFrequent,
        status: status ?? this.status,
        deliveryType: deliveryType ?? this.deliveryType,
        address: address ?? this.address,
        createdAt: createdAt,
        scheduledDate: scheduledDate ?? this.scheduledDate,
        shippingCost: shippingCost ?? this.shippingCost,
        items: items ?? this.items,
        payments: payments ?? this.payments,
      );
}

/// Estado en memoria de los pedidos de la vendedora (datos simulados).
/// Permite crear, eliminar y editar de forma reactiva mientras se integra
/// el backend real (.NET / sellgeneral-api).
class SellerOrdersNotifier extends Notifier<List<SellerOrder>> {
  int _folioSeq = 10050;
  int _idSeq = 0;

  @override
  List<SellerOrder> build() => _seed();

  String _newId(String prefix) => '$prefix-${_idSeq++}';

  /// Folio incremental para pedidos nuevos.
  String nextFolio() => '${_folioSeq++}';

  SellerOrderItem newItem(String name, int qty, double price) =>
      SellerOrderItem(id: _newId('it'), name: name, qty: qty, unitPrice: price);

  void addOrder(SellerOrder order) => state = [order, ...state];

  void removeOrder(String id) =>
      state = state.where((o) => o.id != id).toList();

  void _replace(SellerOrder order) =>
      state = [for (final o in state) if (o.id == order.id) order else o];

  SellerOrder? findById(String id) {
    for (final o in state) {
      if (o.id == id) return o;
    }
    return null;
  }

  void updateStatus(String id, SellerOrderStatus status) {
    final o = findById(id);
    if (o != null) _replace(o.copyWith(status: status));
  }

  void setDeliveryType(String id, SellerDeliveryType type) {
    final o = findById(id);
    if (o == null || o.deliveryType == type) return;
    final ship = type == SellerDeliveryType.pickup
        ? 0.0
        : (o.shippingCost == 0 ? 60.0 : o.shippingCost);
    _replace(o.copyWith(deliveryType: type, shippingCost: ship));
  }

  void changeItemQty(String orderId, String itemId, int qty) {
    if (qty < 1) return;
    final o = findById(orderId);
    if (o == null) return;
    _replace(o.copyWith(
      items: [
        for (final it in o.items)
          if (it.id == itemId) it.copyWith(qty: qty) else it,
      ],
    ));
  }

  void removeItem(String orderId, String itemId) {
    final o = findById(orderId);
    if (o == null) return;
    _replace(o.copyWith(
      items: o.items.where((it) => it.id != itemId).toList(),
    ));
  }

  void addItem(String orderId, String name, int qty, double price) {
    final o = findById(orderId);
    if (o == null) return;
    _replace(o.copyWith(items: [...o.items, newItem(name, qty, price)]));
  }

  void addPayment(String orderId, double amount, String method) {
    if (amount <= 0) return;
    final o = findById(orderId);
    if (o == null) return;
    final payment = SellerPayment(
      id: _newId('pay'),
      amount: amount,
      method: method,
      date: DateTime.now(),
    );
    _replace(o.copyWith(payments: [...o.payments, payment]));
  }

  List<SellerOrder> _seed() {
    final now = DateTime.now();
    return [
      SellerOrder(
        id: '10049',
        clientName: 'Karla Gómez',
        clientPhone: '55 1234 5678',
        isFrequent: true,
        status: SellerOrderStatus.pending,
        deliveryType: SellerDeliveryType.delivery,
        address: 'Av. de las Flores 128, Col. Jardines',
        createdAt: now.subtract(const Duration(hours: 2)),
        shippingCost: 60,
        items: const [
          SellerOrderItem(id: 's1a', name: 'Vestido Rosa Palo', qty: 1, unitPrice: 320),
          SellerOrderItem(id: 's1b', name: 'Top de Encaje', qty: 2, unitPrice: 135),
        ],
      ),
      SellerOrder(
        id: '10048',
        clientName: 'Lucía Fernández',
        clientPhone: '55 2233 4455',
        status: SellerOrderStatus.confirmed,
        deliveryType: SellerDeliveryType.delivery,
        address: 'Calle Luna 45, Col. Centro',
        createdAt: now.subtract(const Duration(hours: 6)),
        shippingCost: 60,
        items: const [
          SellerOrderItem(id: 's2a', name: 'Jean Azul Claro', qty: 1, unitPrice: 420),
        ],
      ),
      SellerOrder(
        id: '10047',
        clientName: 'Adriana Pérez',
        clientPhone: '55 8899 1122',
        isFrequent: true,
        status: SellerOrderStatus.pending,
        deliveryType: SellerDeliveryType.delivery,
        address: 'Priv. del Sol 12, Col. Las Palmas',
        createdAt: now.subtract(const Duration(hours: 9)),
        shippingCost: 60,
        items: const [
          SellerOrderItem(id: 's3a', name: 'Set Invierno', qty: 1, unitPrice: 1050),
          SellerOrderItem(id: 's3b', name: 'Bufanda Tejida', qty: 2, unitPrice: 70),
        ],
      ),
      SellerOrder(
        id: '10044',
        clientName: 'Valeria Martínez',
        clientPhone: '55 5566 7788',
        status: SellerOrderStatus.route,
        deliveryType: SellerDeliveryType.delivery,
        address: 'Blvd. Norte 900, Col. Moderna',
        createdAt: now.subtract(const Duration(days: 1)),
        scheduledDate: now,
        shippingCost: 60,
        items: const [
          SellerOrderItem(id: 's4a', name: 'Blusa Blanca', qty: 2, unitPrice: 230),
          SellerOrderItem(id: 's4b', name: 'Falda Midi', qty: 1, unitPrice: 400),
        ],
        payments: [
          SellerPayment(id: 'p4', amount: 620, method: 'Transferencia', date: now.subtract(const Duration(days: 1))),
        ],
      ),
      SellerOrder(
        id: '10043',
        clientName: 'Sofía Castro',
        clientPhone: '55 3344 9900',
        status: SellerOrderStatus.route,
        deliveryType: SellerDeliveryType.delivery,
        address: 'Calle Río 78, Col. Reforma',
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
        scheduledDate: now,
        shippingCost: 60,
        items: const [
          SellerOrderItem(id: 's5a', name: 'Cinturón de Cuero', qty: 1, unitPrice: 320),
        ],
      ),
      SellerOrder(
        id: '10041',
        clientName: 'Ana Lucía',
        clientPhone: '55 7788 5544',
        isFrequent: true,
        status: SellerOrderStatus.delivered,
        deliveryType: SellerDeliveryType.pickup,
        address: 'Recoge en tienda',
        createdAt: now.subtract(const Duration(days: 2)),
        items: const [
          SellerOrderItem(id: 's6a', name: 'Set de Sábanas King', qty: 1, unitPrice: 1200),
        ],
        payments: [
          SellerPayment(id: 'p6', amount: 1200, method: 'Efectivo', date: now.subtract(const Duration(days: 2))),
        ],
      ),
    ];
  }
}

final sellerOrdersProvider =
    NotifierProvider<SellerOrdersNotifier, List<SellerOrder>>(
  SellerOrdersNotifier.new,
);
