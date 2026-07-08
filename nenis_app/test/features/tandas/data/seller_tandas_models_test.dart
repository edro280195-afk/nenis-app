import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/tandas/data/seller_tandas_models.dart';

void main() {
  group('SellerTanda.currentWeek', () {
    test('usa la semana enviada por el backend cuando viene en el JSON', () {
      final tanda = SellerTanda.fromJson({
        'id': 'tanda-1',
        'productId': 'product-1',
        'name': 'Plan semanal',
        'totalWeeks': 10,
        'weeklyAmount': 250,
        'penaltyAmount': 50,
        'startDate': DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String(),
        'status': 'Active',
        'currentWeek': 4,
        'participants': const [],
      });

      expect(tanda.currentWeek, 4);
      expect(tanda.actionableWeek, 4);
    });

    test('el fallback local avanza a semana 2 al cumplirse 7 dias', () {
      final startDate = DateTime.now().toUtc().subtract(
        const Duration(days: 7),
      );
      final tanda = SellerTanda(
        id: 'tanda-1',
        productId: 'product-1',
        name: 'Plan semanal',
        totalWeeks: 10,
        weeklyAmount: 250,
        penaltyAmount: 50,
        status: 'Active',
        participants: const [],
        startDate: startDate,
      );

      expect(tanda.currentWeek, 2);
    });
  });
}
