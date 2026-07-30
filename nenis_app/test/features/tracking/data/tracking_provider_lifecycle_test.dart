import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/tracking/data/tracking_controller.dart';
import 'package:nenis_app/features/tracking/data/tracking_repository.dart';

void main() {
  test('los providers de tiempo real usan autoDispose', () {
    expect(trackingTokenProvider.isAutoDispose, isTrue);
    expect(trackingControllerProvider.isAutoDispose, isTrue);
    expect(orderChatProvider.isAutoDispose, isTrue);
    expect(trackingHubProvider.isAutoDispose, isTrue);
  });

  test('el hub se conserva hasta que sale el último consumidor', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final trackingSubscription = container.listen(
      trackingHubProvider,
      (_, _) {},
      fireImmediately: true,
    );
    final chatSubscription = container.listen(
      trackingHubProvider,
      (_, _) {},
      fireImmediately: true,
    );
    final client = trackingSubscription.read();

    trackingSubscription.close();
    await container.pump();
    expect(client.isDisposed, isFalse);

    chatSubscription.close();
    await container.pump();
    expect(client.isDisposed, isTrue);
  });

  test('cerrar el cliente del hub más de una vez es seguro', () async {
    final client = TrackingHubClient();

    await client.dispose();
    await client.dispose();

    expect(client.isDisposed, isTrue);
  });
}
