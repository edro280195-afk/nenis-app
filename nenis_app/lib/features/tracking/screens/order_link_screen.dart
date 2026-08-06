import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/deeplinks/deep_link_service.dart';
import '../../../core/deeplinks/pending_claim_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/pill_button.dart';
import '../../claim/data/claim_models.dart';
import '../../claim/data/claim_repository.dart';
import 'tracking_screen.dart';

/// Pantalla de destino cuando la clienta llega por el enlace del pedido
/// (deep link `/o/{token}` o `/pedido/{token}`). Reutiliza [TrackingScreen]
/// para mostrar el pedido + rastreo y solicita confirmación previa antes de
/// reclamar el pedido para la cuenta autenticada.
class OrderLinkScreen extends ConsumerStatefulWidget {
  const OrderLinkScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<OrderLinkScreen> createState() => _OrderLinkScreenState();
}

class _OrderLinkScreenState extends ConsumerState<OrderLinkScreen> {
  bool _hasPrompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndPromptClaim());
  }

  Future<void> _checkAndPromptClaim() async {
    // Ya aterrizamos en el pedido: soltar el pendiente para que el router no
    // vuelva a forzar esta ruta cuando la clienta navegue a otro lado.
    ref.read(pendingDeepLinkProvider.notifier).clear();

    final session = ref.read(authControllerProvider).asData?.value;
    // Sin sesión no se puede reclamar (el endpoint exige JWT). El pedido se
    // sigue viendo por el token público; el reclamo ocurrirá tras registrarse.
    if (session == null) return;

    if (_hasPrompted) return;
    _hasPrompted = true;

    // Pequeño retardo para dar tiempo a que la pantalla de rastreo empiece a renderizarse.
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    _showSoftClaimBottomSheet();
  }

  void _showSoftClaimBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceCream,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Symbols.inventory_2,
                  size: 28,
                  color: AppColors.neniDeep,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '¿Este pedido es tuyo? 🌸',
                style: AppTextStyles.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Vincúlalo a tu cuenta para guardarlo en "Mis pedidos", acumular puntos y recibir notificaciones de tu entrega.',
                style: AppTextStyles.subtitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              PillButton(
                label: 'Sí, vincular a mi cuenta 💖',
                variant: PillButtonVariant.brand,
                onPressed: () {
                  Navigator.pop(ctx);
                  _doClaim();
                },
              ),
              const SizedBox(height: 10),
              PillButton(
                label: 'Ver como visitante',
                variant: PillButtonVariant.ghost,
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(pendingClaimStoreProvider).clear();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _doClaim() async {
    final messenger = ScaffoldMessenger.of(context);
    final result =
        await ref.read(claimRepositoryProvider).claimByOrderToken(widget.token);
    if (!mounted) return;

    if (result.status == ClaimByTokenStatus.linked) {
      await ref.read(pendingClaimStoreProvider).clear();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('¡Pedido vinculado exitosamente a tu cuenta! ✨'),
          backgroundColor: AppColors.neniDeep,
        ),
      );
    } else if (result.status == ClaimByTokenStatus.forbidden) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'No se pudo vincular este pedido.'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    } else if (result.isTerminal) {
      await ref.read(pendingClaimStoreProvider).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    // orderId vacío: el deep link sólo trae el token; la UI muestra "Tu pedido".
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/home');
        }
      },
      child: TrackingScreen(orderId: '', accessToken: widget.token),
    );
  }
}
