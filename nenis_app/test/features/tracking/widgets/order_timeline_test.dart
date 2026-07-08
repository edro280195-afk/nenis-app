import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/tracking/data/tracking_models.dart';
import 'package:nenis_app/features/tracking/widgets/status_journey_card.dart';

void main() {
  testWidgets('OrderTimeline muestra estado cancelado como paso final', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OrderTimeline(status: TrackingStatus.canceled)),
      ),
    );

    expect(find.text('Cancelado'), findsOneWidget);
    expect(find.text('Entregado'), findsNothing);
  });

  testWidgets('OrderTimeline muestra estado no entregado como paso final', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OrderTimeline(status: TrackingStatus.notDelivered),
        ),
      ),
    );

    expect(find.text('No entregado'), findsOneWidget);
    expect(find.text('Entregado'), findsNothing);
  });

  testWidgets('OrderTimeline muestra pospuesto en la etapa de preparacion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OrderTimeline(status: TrackingStatus.postponed)),
      ),
    );

    expect(find.text('Pospuesto'), findsOneWidget);
  });
}
