import 'package:flutter/widgets.dart';

/// Pago visto por la compradora. Es la unión de `OrderPayment` con info
/// mínima del Order y la tienda para que la app pueda agrupar y mostrar
/// sin N+1 requests.
class BuyerPayment {
  const BuyerPayment({
    required this.paymentId,
    required this.orderId,
    required this.businessId,
    required this.businessName,
    required this.brandPrimaryColor,
    required this.amount,
    required this.method,
    required this.date,
    required this.registeredBy,
    required this.orderStatus,
    required this.orderTotal,
    this.logoUrl,
    this.notes,
  });

  final int paymentId;
  final int orderId;
  final int businessId;
  final String businessName;
  final String brandPrimaryColor;
  final String? logoUrl;
  final double amount;
  final String method;
  final DateTime date;
  final String registeredBy;
  final String? notes;
  final String orderStatus;
  final double orderTotal;

  String get initial => businessName.isNotEmpty
      ? businessName.characters.first.toUpperCase()
      : '?';

  factory BuyerPayment.fromJson(Map<String, dynamic> j) => BuyerPayment(
        paymentId: (j['paymentId'] as num).toInt(),
        orderId: (j['orderId'] as num).toInt(),
        businessId: (j['businessId'] as num).toInt(),
        businessName: (j['businessName'] ?? '') as String,
        brandPrimaryColor: (j['brandPrimaryColor'] ?? '#FB6F9C') as String,
        logoUrl: j['logoUrl'] as String?,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        method: (j['method'] ?? 'Efectivo') as String,
        date:
            DateTime.tryParse((j['date'] ?? '') as String) ?? DateTime.now(),
        registeredBy: (j['registeredBy'] ?? 'Admin') as String,
        notes: j['notes'] as String?,
        orderStatus: (j['orderStatus'] ?? 'Pending') as String,
        orderTotal: (j['orderTotal'] as num?)?.toDouble() ?? 0,
      );
}
