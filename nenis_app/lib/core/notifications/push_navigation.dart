import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/app_router.dart';

/// Navega a la URL de deep link que trae el `data` de una notificación push
/// (`{type, businessId, url}`, ver `PushNotificationService.SendNotificationToFollowersAsync`
/// en el backend). Mismo criterio que `notifications_screen.dart`: solo se
/// navega si es una ruta interna (empieza con `/`).
void handlePushNavigation(Ref ref, String? url) {
  if (url == null || url.isEmpty || !url.startsWith('/')) return;
  ref.read(routerProvider).go(url);
}
