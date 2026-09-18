import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nenis_app/core/auth/session.dart';
import 'package:nenis_app/core/storage/session_storage.dart';
import 'package:nenis_app/core/theme/app_theme.dart';
import 'package:nenis_app/features/inventory/data/inventory_repository.dart';
import 'package:nenis_app/features/inventory/screens/inventory_screen.dart';
import 'package:nenis_app/features/subscription/data/subscription_models.dart';
import 'package:nenis_app/features/subscription/data/subscription_repository.dart';

void main() {
  testWidgets(
    'el botón atrás de bodega vuelve a inicio cuando no hay historial',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/seller/inventory',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const Scaffold(body: Text('Inicio')),
          ),
          GoRoute(
            path: '/seller/inventory',
            builder: (context, state) => const InventoryScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStorageProvider.overrideWithValue(_FakeSessionStorage()),
            inventoryBoxesProvider.overrideWith((ref) async => const []),
            subscriptionStatusProvider.overrideWith(
              (ref) async => const SubscriptionAccountState(
                effectivePlan: 'Pro',
                planTier: 'Pro',
                subscriptionStatus: 'Active',
                isLocked: false,
                daysLeft: 30,
                pastDueGraceDays: 0,
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mi bodega'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Inicio'), findsOneWidget);
    },
  );
}

class _FakeSessionStorage extends SessionStorage {
  _FakeSessionStorage() : super(const FlutterSecureStorage());

  @override
  Future<Session?> read() async => null;

  @override
  Future<void> write(Session session) async {}

  @override
  Future<void> clear() async {}
}
