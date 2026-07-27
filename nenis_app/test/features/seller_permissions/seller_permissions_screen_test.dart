import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/core/auth/session.dart';
import 'package:nenis_app/core/storage/session_storage.dart';
import 'package:nenis_app/core/theme/app_theme.dart';
import 'package:nenis_app/features/account/data/seller_settings_models.dart';
import 'package:nenis_app/features/account/data/seller_settings_repository.dart';
import 'package:nenis_app/features/account/screens/seller_account_screen.dart';
import 'package:nenis_app/features/seller_updates/screens/seller_updates_screen.dart';
import 'package:nenis_app/features/seller_vip/screens/seller_vip_screen.dart';

void main() {
  testWidgets('Grupo VIP explica el permiso faltante a un Driver', (
    tester,
  ) async {
    await tester.pumpWidget(_subject(const SellerVipScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('seller-permission-denied')), findsOneWidget);
    expect(find.text('Solo dueña o administradoras'), findsOneWidget);
    expect(find.textContaining('elegir seguidoras VIP'), findsOneWidget);
  });

  testWidgets('Novedades explica el permiso faltante a un Driver', (
    tester,
  ) async {
    await tester.pumpWidget(_subject(const SellerUpdatesScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('seller-permission-denied')), findsOneWidget);
    expect(find.text('Solo dueña o administradoras'), findsOneWidget);
    expect(find.textContaining('publicar novedades'), findsOneWidget);
  });

  testWidgets('Mi negocio deshabilita VIP y Novedades para un Driver', (
    tester,
  ) async {
    await tester.pumpWidget(
      _subject(const SellerAccountScreen(), includeSettings: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin permiso'), findsOneWidget);
    expect(
      find.text('Solo disponible para dueña y administradoras.'),
      findsOneWidget,
    );

    final updatesTile = tester.widget<InkWell>(
      find
          .ancestor(
            of: find.text('Novedades y vivo'),
            matching: find.byType(InkWell),
          )
          .first,
    );
    expect(updatesTile.onTap, isNull);

    await tester.scrollUntilVisible(find.text('Grupo VIP'), 250);
    expect(find.text('Sin permiso'), findsNWidgets(2));
    expect(
      find.text('Solo disponible para dueña y administradoras.'),
      findsNWidgets(2),
    );
    final vipTile = tester.widget<InkWell>(
      find
          .ancestor(of: find.text('Grupo VIP'), matching: find.byType(InkWell))
          .first,
    );
    expect(vipTile.onTap, isNull);
  });
}

Widget _subject(Widget child, {bool includeSettings = false}) {
  return ProviderScope(
    overrides: [
      sessionStorageProvider.overrideWithValue(
        _FakeSessionStorage(_driverSession),
      ),
      if (includeSettings)
        sellerBusinessSettingsProvider.overrideWith(
          (ref) async => _businessSettings,
        ),
      if (includeSettings)
        sellerPaymentSettingsProvider.overrideWith(
          (ref) async => const MercadoPagoSettings(
            hasAccessToken: false,
            isConfigured: false,
          ),
        ),
      if (includeSettings)
        sellerPayoutAccountsProvider.overrideWith((ref) async => const []),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );
}

final _driverSession = Session(
  token: 'token',
  accountId: 1,
  displayName: 'Chofer',
  role: 'Driver',
  expiresAt: DateTime.now().add(const Duration(days: 1)),
  memberships: const [
    Membership(businessId: 10, businessName: 'Tienda', role: 'Driver'),
  ],
  activeBusinessId: 10,
);

const _businessSettings = SellerBusinessSettings(
  id: 10,
  name: 'Tienda',
  slug: 'tienda',
  brand: SellerBrandSettings(primaryColor: '#FB6F9C'),
  subscription: SellerSubscriptionSettings(
    effectivePlan: 'Pro',
    subscriptionStatus: 'Active',
    isLocked: false,
    daysLeft: 30,
  ),
  features: [],
);

class _FakeSessionStorage extends SessionStorage {
  _FakeSessionStorage(this.session) : super(const FlutterSecureStorage());

  final Session session;

  @override
  Future<Session?> read() async => session;

  @override
  Future<void> write(Session session) async {}

  @override
  Future<void> clear() async {}
}
