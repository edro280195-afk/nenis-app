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

  group('SellerTanda.canDrawTurns', () {
    test('permite sortear cuando hay participantes sin actividad', () {
      final tanda = _tandaWithParticipant();

      expect(tanda.hasStartedOperations, isFalse);
      expect(tanda.canDrawTurns, isTrue);
    });

    test('bloquea el sorteo cuando existe un pago', () {
      final tanda = _tandaWithParticipant(
        payment: {
          'id': 'payment-1',
          'participantId': 'participant-1',
          'weekNumber': 1,
          'amountPaid': 250,
          'penaltyPaid': 0,
          'paymentDate': DateTime.now().toIso8601String(),
          'isVerified': true,
        },
      );

      expect(tanda.hasStartedOperations, isTrue);
      expect(tanda.canDrawTurns, isFalse);
    });

    test('bloquea el sorteo cuando la entrega está confirmada', () {
      final tanda = _tandaWithParticipant(isDelivered: true);

      expect(tanda.hasStartedOperations, isTrue);
      expect(tanda.canDrawTurns, isFalse);
    });

    test('bloquea el sorteo cuando Rutas registró la fecha de entrega', () {
      final tanda = _tandaWithParticipant(deliveryDate: DateTime.now());

      expect(tanda.hasStartedOperations, isTrue);
      expect(tanda.canDrawTurns, isFalse);
    });
  });
}

SellerTanda _tandaWithParticipant({
  Map<String, dynamic>? payment,
  bool isDelivered = false,
  DateTime? deliveryDate,
}) {
  return SellerTanda.fromJson({
    'id': 'tanda-1',
    'productId': 'product-1',
    'name': 'Plan semanal',
    'totalWeeks': 10,
    'weeklyAmount': 250,
    'penaltyAmount': 50,
    'status': 'Active',
    'participants': [
      {
        'id': 'participant-1',
        'tandaId': 'tanda-1',
        'customerId': 1,
        'customerName': 'Ana',
        'assignedTurn': 1,
        'isDelivered': isDelivered,
        'deliveryDate': deliveryDate?.toIso8601String(),
        'status': 'Active',
        'payments': [if (payment != null) payment],
      },
    ],
  });
}
