import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/routes/data/seller_routes_models.dart';

void main() {
  test('SellerRoute lee driverLink desde el API', () {
    final route = SellerRoute.fromJson({
      'id': 12,
      'driverToken': 'abc123',
      'driverLink': 'https://app.nenis.test/repartidor/abc123',
      'status': 'Pending',
      'createdAt': '2026-07-08T10:00:00Z',
      'deliveries': <Map<String, dynamic>>[],
    });

    expect(route.driverLink, 'https://app.nenis.test/repartidor/abc123');
  });

  test('RouteCandidate agrupa por clientId aunque cambie el nombre', () {
    final order = RouteCandidate.fromOrderJson({
      'id': 10,
      'clientId': 77,
      'clientName': 'María',
      'total': 100,
    });
    final tanda = RouteCandidate.fromTandaJson({
      'tandaParticipantId': '5f764386-9173-43dd-8cf4-8e20c68efbef',
      'clientId': 77,
      'clientName': 'María López',
    });

    expect(order.clientGroupKey, 'client:77');
    expect(tanda.clientGroupKey, order.clientGroupKey);
  });

  test('RouteCandidate no mezcla clientas distintas con el mismo nombre', () {
    final first = RouteCandidate.fromOrderJson({
      'id': 10,
      'clientId': 77,
      'clientName': 'María',
      'clientPhone': '8681234567',
      'total': 100,
    });
    final second = RouteCandidate.fromOrderJson({
      'id': 11,
      'clientId': 88,
      'clientName': 'María',
      'clientPhone': '8681234567',
      'total': 200,
    });

    expect(first.clientGroupKey, isNot(second.clientGroupKey));
  });

  test('RoutePreviewStop genera el identificador que espera el API', () {
    final order = RoutePreviewStop.fromJson({
      'kind': 'Order',
      'orderId': 10,
      'sortOrder': 2,
      'clientName': 'Ana',
      'total': 100,
      'hasCoords': true,
    });
    final tanda = RoutePreviewStop.fromJson({
      'kind': 'Tanda',
      'tandaParticipantId': '5f764386-9173-43dd-8cf4-8e20c68efbef',
      'sortOrder': 1,
      'clientName': 'Luisa',
      'total': 0,
      'hasCoords': true,
    });

    expect(order.key, 'order:10');
    expect(tanda.key, 'tanda:5f764386-9173-43dd-8cf4-8e20c68efbef');
  });
}
