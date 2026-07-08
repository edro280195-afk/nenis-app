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

  group('OrderCaptureSettings', () {
    test('lee el costo de envio configurado por el backend', () {
      final settings = OrderCaptureSettings.fromJson({
        'defaultShippingCost': 85,
      });

      expect(settings.defaultShippingCost, 85);
    });
  });
}
