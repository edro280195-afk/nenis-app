import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/clients/data/seller_clients_models.dart';

void main() {
  group('SellerClientProfile', () {
    test('parses API payload and derives delivery flags', () {
      final client = SellerClientProfile.fromJson({
        'id': 12,
        'name': 'Maria Lopez',
        'phone': '8671234567',
        'address': 'Colonia Centro 123',
        'tag': 'Vip',
        'ordersCount': 8,
        'totalSpent': 2450.5,
        'type': 'Frecuente',
        'deliveryInstructions': 'Porton negro',
        'latitude': 27.48,
        'longitude': -99.5,
        'aliases': ['Mary', 'Maria FB'],
      });

      expect(client.id, 12);
      expect(client.tag, SellerClientTag.vip);
      expect(client.isFrequent, isTrue);
      expect(client.hasPhone, isTrue);
      expect(client.hasAddress, isTrue);
      expect(client.hasCoordinates, isTrue);
      expect(client.needsLocation, isFalse);
      expect(client.aliases, contains('Mary'));
    });

    test('marks address without coordinates as pending location', () {
      final client = SellerClientProfile.fromJson({
        'id': 20,
        'name': 'Ana',
        'tag': 'None',
        'ordersCount': 0,
        'totalSpent': 0,
        'type': 'Nueva',
        'address': 'Calle 1',
      });

      expect(client.isFrequent, isFalse);
      expect(client.needsAddress, isFalse);
      expect(client.needsLocation, isTrue);
    });
  });

  group('SellerClientLoyaltySummary', () {
    test('computes tier progress and next tier labels', () {
      final summary = SellerClientLoyaltySummary.fromJson({
        'clientId': 4,
        'clientName': 'Laura',
        'currentPoints': 75,
        'lifetimePoints': 120,
        'tier': 'Clienta Rose Gold',
        'tierKey': 'rosegold',
      });

      expect(summary.tierProgress, 0.1);
      expect(summary.nextTierLabel, '180 pts para Diamante');
    });
  });
}
