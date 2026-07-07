import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/deeplinks/deep_link_service.dart';
import '../../../core/deeplinks/pending_claim_store.dart';
import '../../claim/data/claim_repository.dart';
import 'tracking_screen.dart';

/// Pantalla de destino cuando la clienta llega por el enlace del pedido
/// (deep link `/o/{token}` o `/pedido/{token}`). Reutiliza [TrackingScreen]
/// para mostrar el pedido + rastreo y, en segundo plano, reclama el pedido para
/// la cuenta autenticada — la posesión del token es la prueba.
class OrderLinkScreen extends ConsumerStatefulWidget {
  const OrderLinkScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<OrderLinkScreen> createState() => _OrderLinkScreenState();
}

class _OrderLinkScreenState extends ConsumerState<OrderLinkScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePending());
  }

  Future<void> _consumePending() async {
    // Ya aterrizamos en el pedido: soltar el pendiente para que el router no
    // vuelva a forzar esta ruta cuando la clienta navegue a otro lado.
    ref.read(pendingDeepLinkProvider.notifier).clear();

    final session = ref.read(authControllerProvider).asData?.value;
    // Sin sesión no se puede reclamar (el endpoint exige JWT). El pedido se
    // sigue viendo por el token público; el reclamo ocurrirá tras registrarse.
    if (session == null) return;

    final result =
        await ref.read(claimRepositoryProvider).claimByOrderToken(widget.token);
    // Enlazado o fallo definitivo (4xx): descartar el token persistido para no
    // reintentar en el próximo arranque. Los errores de red se conservan.
    if (result.isTerminal) {
      await ref.read(pendingClaimStoreProvider).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    // orderId vacío: el deep link sólo trae el token; la UI muestra "Tu pedido".
    return TrackingScreen(orderId: '', accessToken: widget.token);
  }
}
