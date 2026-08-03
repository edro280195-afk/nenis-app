import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/orders/data/seller_orders_models.dart';

void main() {
  group('SellerOrder', () {
    test('parsea estados especiales y datos de reprogramacion', () {
      final order = SellerOrder.fromJson({
        'id': 15,
        'clientName': 'Ana',
        'status': 'Postponed',
        'orderType': 'Delivery',
        'total': 450,
        'subtotal': 390,
        'shippingCost': 60,
        'amountPaid': 0,
        'balanceDue': 450,
        'itemsCount': 1,
        'createdAt': '2026-07-08T10:00:00Z',
        'type': 'Nueva',
        'postponedAt': '2026-07-10T16:00:00Z',
        'postponedNote': 'Clienta pidio cambiar la fecha',
      });

      expect(order.status, SellerOrderStatus.postponed);
      expect(order.postponedAt, isNotNull);
      expect(order.postponedNote, 'Clienta pidio cambiar la fecha');
    });

    test('mapea todos los status soportados por el backend', () {
      expect(SellerOrderStatus.fromApi('Pending'), SellerOrderStatus.pending);
      expect(
        SellerOrderStatus.fromApi('Confirmed'),
        SellerOrderStatus.confirmed,
      );
      expect(SellerOrderStatus.fromApi('Shipped'), SellerOrderStatus.shipped);
      expect(SellerOrderStatus.fromApi('InRoute'), SellerOrderStatus.inRoute);
      expect(
        SellerOrderStatus.fromApi('Delivered'),
        SellerOrderStatus.delivered,
      );
      expect(
        SellerOrderStatus.fromApi('NotDelivered'),
        SellerOrderStatus.notDelivered,
      );
      expect(SellerOrderStatus.fromApi('Canceled'), SellerOrderStatus.canceled);
      expect(
        SellerOrderStatus.fromApi('Postponed'),
        SellerOrderStatus.postponed,
      );
    });
  });

  group('SellerOrder fusion', () {
    test('marca un pedido fusionado y expone hacia donde se fue', () {
      final order = SellerOrder.fromJson({
        'id': 7,
        'clientName': 'Hija',
        'status': 'Canceled',
        'orderType': 'Delivery',
        'total': 0,
        'subtotal': 0,
        'shippingCost': 60,
        'amountPaid': 0,
        'balanceDue': 0,
        'itemsCount': 0,
        'createdAt': '2026-07-08T10:00:00Z',
        'type': 'Nueva',
        'mergedIntoOrderId': 9,
        'mergedAt': '2026-07-09T10:00:00Z',
      });

      expect(order.isMergedAway, isTrue);
      expect(order.mergedIntoOrderId, 9);
      expect(order.mergedAt, isNotNull);
    });

    test('un pedido normal (nunca fusionado) no está marcado como fusionado', () {
      final order = SellerOrder.fromJson({
        'id': 9,
        'clientName': 'Mamá',
        'status': 'Pending',
        'orderType': 'Delivery',
        'total': 500,
        'subtotal': 440,
        'shippingCost': 60,
        'amountPaid': 0,
        'balanceDue': 500,
        'itemsCount': 2,
        'createdAt': '2026-07-08T10:00:00Z',
        'type': 'Nueva',
      });

      expect(order.isMergedAway, isFalse);
      expect(order.mergedIntoOrderId, isNull);
    });

    test('un artículo movido al fusionar trae la clienta original', () {
      final item = SellerOrderItem.fromJson({
        'id': 1,
        'productName': 'Falda',
        'quantity': 1,
        'unitPrice': 150,
        'lineTotal': 150,
        'originalClientName': 'Hija',
      });

      expect(item.originalClientName, 'Hija');
    });

    test('un artículo que nunca cambió de clienta no trae etiqueta', () {
      final item = SellerOrderItem.fromJson({
        'id': 2,
        'productName': 'Blusa',
        'quantity': 1,
        'unitPrice': 200,
        'lineTotal': 200,
      });

      expect(item.originalClientName, isNull);
    });
  });

  group('OrderCaptureSettings', () {
    test('lee el costo de envio configurado por el backend', () {
      final settings = OrderCaptureSettings.fromJson({
        'defaultShippingCost': 85,
      });

      expect(settings.defaultShippingCost, 85);
    });
  });
}
