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
}
