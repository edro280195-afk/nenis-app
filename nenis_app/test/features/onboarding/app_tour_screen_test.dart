import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nenis_app/core/theme/app_theme.dart';
import 'package:nenis_app/features/onboarding/screens/app_tour_screen.dart';
import 'package:nenis_app/features/subscription/data/subscription_models.dart';
import 'package:nenis_app/features/subscription/data/subscription_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
  });

  testWidgets('explica prueba, bloqueo y paquetes a la vendedora', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionStatusProvider.overrideWith(
            (ref) async => SubscriptionAccountState(
              effectivePlan: 'Pro',
              planTier: 'Pro',
              subscriptionStatus: 'Trialing',
              isLocked: false,
              daysLeft: 14,
              pastDueGraceDays: 3,
              trialEndsAt: DateTime(2026, 8, 17),
            ),
          ),
          subscriptionPricingProvider.overrideWith(
            (ref) async => const SubscriptionPricing(
              currency: 'MXN',
              plans: [
                PlanPrice(
                  planTier: 'Entrada',
                  monthly: 129,
                  quarterly: 348,
                  annual: 1238,
                  quarterlyDiscountPct: 10,
                  annualDiscountPct: 20,
                  currency: 'MXN',
                ),
                PlanPrice(
                  planTier: 'Pro',
                  monthly: 250,
                  quarterly: 675,
                  annual: 2400,
                  quarterlyDiscountPct: 10,
                  annualDiscountPct: 20,
                  currency: 'MXN',
                ),
                PlanPrice(
                  planTier: 'Elite',
                  monthly: 460,
                  quarterly: 1242,
                  annual: 4416,
                  quarterlyDiscountPct: 10,
                  annualDiscountPct: 20,
                  currency: 'MXN',
                ),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AppTourScreen(role: AppTourRole.seller, replay: true),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Tu prueba Pro ya comenzó'), findsOneWidget);
    expect(find.textContaining('sin tarjeta y sin cobro hoy'), findsOneWidget);
    expect(find.textContaining('se bloquea'), findsOneWidget);
    expect(find.textContaining('\$129 MXN/mes'), findsOneWidget);
    expect(find.textContaining('\$250 MXN/mes'), findsOneWidget);
    expect(find.textContaining('\$460 MXN/mes'), findsOneWidget);
  });

  testWidgets('explica a la clienta por qué verifica su teléfono', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const ProviderScope(
          child: AppTourScreen(role: AppTourRole.client, replay: true),
        ),
      ),
    );

    expect(find.text('Tu número protege tus compras'), findsOneWidget);
    expect(find.textContaining('confirmamos por WhatsApp'), findsOneWidget);
    expect(find.textContaining('sólo tú reclames'), findsOneWidget);
  });
}
