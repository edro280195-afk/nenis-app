import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';
import '../data/subscription_repository.dart';

/// Muro de bloqueo cuando la prueba/plan de la tienda venció. Reemplaza el
/// contenido normal del shell (ver `AppShell`) — solo Owner/Admin lo ven.
class SubscriptionPaywallScreen extends ConsumerWidget {
  const SubscriptionPaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(subscriptionStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.neniDeep, AppColors.neni],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Symbols.workspace_premium,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Tu prueba terminó',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h1,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    status.when(
                      data: (s) => s.subscriptionStatus == 'PastDue'
                          ? 'Tuvimos un problema para cobrar tu tarjeta. Actualiza tu pago para seguir usando tu tienda.'
                          : 'Elige un plan para seguir usando las herramientas de tu tienda.',
                      loading: () => 'Elige un plan para seguir usando tu tienda.',
                      error: (_, _) => 'Elige un plan para seguir usando tu tienda.',
                    ),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle,
                  ),
                  const SizedBox(height: 28),
                  PillButton(
                    label: 'Ver planes',
                    icon: Symbols.arrow_forward,
                    variant: PillButtonVariant.brand,
                    onPressed: () => context.push('/seller/plan'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
