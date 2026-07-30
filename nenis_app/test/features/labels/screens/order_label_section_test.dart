import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/labels/data/label_print_models.dart';
import 'package:nenis_app/features/labels/data/label_print_repository.dart';
import 'package:nenis_app/features/labels/screens/order_label_section.dart';
import 'package:nenis_app/features/subscription/data/subscription_models.dart';
import 'package:nenis_app/features/subscription/data/subscription_repository.dart';

void main() {
  testWidgets('cerrar el panel de bolsas no usa un controlador ya destruido', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderLabelPackagesProvider(
            1,
          ).overrideWith((ref) async => <OrderPackageLabel>[]),
          subscriptionStatusProvider.overrideWith(
            (ref) async => const SubscriptionAccountState(
              effectivePlan: 'Pro',
              planTier: 'Pro',
              subscriptionStatus: 'Active',
              isLocked: false,
              daysLeft: 0,
              pastDueGraceDays: 0,
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: OrderLabelSection(orderId: 1)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generar bolsas'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
