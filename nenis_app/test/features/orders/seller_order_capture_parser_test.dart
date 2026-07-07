import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/orders/data/seller_order_capture_parser.dart';

void main() {
  group('parseQuickCapture', () {
    test('lee formato con comas y precio total', () {
      final draft = parseQuickCapture('Maria Lopez, 2 blusas rojas, 300');

      expect(draft, isNotNull);
      expect(draft!.clientName, 'Maria Lopez');
      expect(draft.productName, 'Blusas Rojas');
      expect(draft.quantity, 2);
      expect(draft.unitPrice, 150);
    });

    test('lee formato simple separado por espacios', () {
      final draft = parseQuickCapture('Ana bolsa negra 120');

      expect(draft, isNotNull);
      expect(draft!.clientName, 'Ana');
      expect(draft.productName, 'Bolsa Negra');
      expect(draft.quantity, 1);
      expect(draft.unitPrice, 120);
    });

    test('lee cantidad escrita con palabra en captura por producto', () {
      final draft = parseQuickProductCapture(
        clientName: 'Laura',
        productText: 'dos toallas 180',
      );

      expect(draft, isNotNull);
      expect(draft!.clientName, 'Laura');
      expect(draft.productName, 'Toallas');
      expect(draft.quantity, 2);
      expect(draft.unitPrice, 90);
    });

    test('rechaza texto sin precio', () {
      expect(parseQuickCapture('Ana bolsa negra'), isNull);
    });
  });
}
