import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/subscription_repository.dart';

/// Checkout de Mercado Pago dentro de un WebView, apuntando a la página de
/// pago YA construida en el panel Angular (`/admin/subscription/checkout`).
/// No existe SDK oficial de MP para tokenizar tarjeta en Flutter — reusar
/// el brick de Angular (ya probado) evita reconstruir esa lógica nativa.
/// La vendedora inicia sesión de nuevo dentro del WebView (cero cambios en
/// Angular/backend); al cerrar, se refresca el estado de suscripción.
class MpCheckoutWebViewScreen extends ConsumerStatefulWidget {
  const MpCheckoutWebViewScreen({
    super.key,
    required this.planTier,
    required this.periodicity,
  });

  final String planTier;
  final String periodicity;

  @override
  ConsumerState<MpCheckoutWebViewScreen> createState() =>
      _MpCheckoutWebViewScreenState();
}

class _MpCheckoutWebViewScreenState
    extends ConsumerState<MpCheckoutWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final uri = Uri.parse('${AppConfig.webAdminBaseUrl}/admin/subscription/checkout').replace(
      queryParameters: {
        'plan': widget.planTier,
        'periodicity': widget.periodicity,
      },
    );
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(uri);
  }

  Future<void> _close() async {
    // Al volver, refresca el plan — no hace falta detectar "éxito" dentro
    // del WebView, GET /me trae el estado real.
    invalidateSubscriptionStateFromWidget(ref);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.surfaceCream,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Symbols.close, color: AppColors.ink),
            onPressed: _close,
          ),
          title: Text('Pagar suscripción', style: AppTextStyles.h2.copyWith(fontSize: 16)),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.neniDeep),
              ),
          ],
        ),
      ),
    );
  }
}
