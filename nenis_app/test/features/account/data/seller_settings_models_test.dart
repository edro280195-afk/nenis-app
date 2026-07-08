import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/account/data/seller_settings_models.dart';
import 'package:nenis_app/features/account/data/seller_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SellerPreferenceSettings', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('serializa y restaura las preferencias locales', () {
      const settings = SellerPreferenceSettings(
        notifyNewOrders: false,
        notifyRouteChanges: false,
        autoCopyClientMessage: false,
        requirePaymentBeforeRoute: true,
        defaultDeliveryWindow: 'Sabados por la manana',
      );

      final restored = SellerPreferenceSettings.decode(settings.encode());

      expect(restored.notifyNewOrders, isFalse);
      expect(restored.notifyRouteChanges, isFalse);
      expect(restored.autoCopyClientMessage, isFalse);
      expect(restored.requirePaymentBeforeRoute, isTrue);
      expect(restored.defaultDeliveryWindow, 'Sabados por la manana');
    });

    test('regresa valores por defecto si el JSON guardado no sirve', () {
      final settings = SellerPreferenceSettings.decode('no es json');

      expect(settings.notifyNewOrders, isTrue);
      expect(settings.notifyRouteChanges, isTrue);
      expect(settings.autoCopyClientMessage, isTrue);
      expect(settings.requirePaymentBeforeRoute, isFalse);
      expect(settings.defaultDeliveryWindow, 'Domingos por la tarde');
    });

    test('carga preferencias guardadas al construir el provider', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'seller.preference.settings.v1': const SellerPreferenceSettings(
          notifyNewOrders: false,
          defaultDeliveryWindow: 'Entre semana',
        ).encode(),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final loaded = Completer<SellerPreferenceSettings>();
      container.listen<SellerPreferenceSettings>(
        sellerPreferenceSettingsProvider,
        (_, next) {
          if (!loaded.isCompleted &&
              next.notifyNewOrders == false &&
              next.defaultDeliveryWindow == 'Entre semana') {
            loaded.complete(next);
          }
        },
        fireImmediately: true,
      );

      final settings = await loaded.future.timeout(const Duration(seconds: 1));

      expect(settings.notifyNewOrders, isFalse);
      expect(settings.defaultDeliveryWindow, 'Entre semana');
    });

    test('guarda preferencias desde el provider', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      const settings = SellerPreferenceSettings(
        requirePaymentBeforeRoute: true,
        defaultDeliveryWindow: 'Viernes por la tarde',
      );

      await container
          .read(sellerPreferenceSettingsProvider.notifier)
          .set(settings);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('seller.preference.settings.v1');

      expect(raw, isNotNull);
      expect(
        SellerPreferenceSettings.decode(raw!).defaultDeliveryWindow,
        'Viernes por la tarde',
      );
      expect(
        SellerPreferenceSettings.decode(raw).requirePaymentBeforeRoute,
        isTrue,
      );
    });
  });

  group('MercadoPagoSettings', () {
    test('lee el estado de configuracion desde el API', () {
      final settings = MercadoPagoSettings.fromJson({
        'publicKey': 'APP_USR-public',
        'hasAccessToken': true,
        'isConfigured': true,
      });

      expect(settings.publicKey, 'APP_USR-public');
      expect(settings.hasAccessToken, isTrue);
      expect(settings.isConfigured, isTrue);
    });
  });
}
