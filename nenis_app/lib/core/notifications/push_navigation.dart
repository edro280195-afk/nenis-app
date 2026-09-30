import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../router/app_router.dart';
import 'push_payload.dart';

/// Abre el destino de un push (`PushPayload`, ver `PushNotificationService` en el
/// backend) — pero solo si el aviso es para la sesión que está abierta.
///
/// - Sin sesión no se puede comprobar de quién es el aviso: no se navega.
/// - Un aviso de tienda no se abre en una sesión que no es dueña/administradora de ese
///   negocio, y un aviso de una cuenta concreta no se abre en la de otra persona.
/// - Un aviso de tienda de OTRO de sus negocios cambia primero el negocio activo, para
///   que la pantalla a la que lleva muestre los datos de ese negocio.
/// - Solo se navega si es una ruta interna (empieza con `/`), igual que
///   `notifications_screen.dart`.
void handlePushNavigation(Ref ref, PushPayload payload) {
  final session = ref.read(authControllerProvider).asData?.value;
  if (session == null || !payload.isFor(session)) return;

  final businessId = payload.businessId;
  if (payload.audience == PushAudience.seller &&
      businessId != null &&
      session.activeBusinessId != businessId) {
    ref.read(authControllerProvider.notifier).setActiveBusiness(businessId);
  }

  if (!payload.hasInternalUrl) return;
  ref.read(routerProvider).go(payload.url!);
}
