import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/nenis_logo.dart';
import '../../../shared/widgets/pill_button.dart';

/// Pantalla de bienvenida que se muestra al comprador nuevo después del
/// splash. Hoy no aparece en el flujo normal (el router redirige
/// directamente a /login), pero la ruta /welcome existe y se usa como
/// punto de entrada manual o para un futuro onboarding paso a paso.
class AuthWelcomeScreen extends StatelessWidget {
  const AuthWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const NenisLogo(
                  markSize: 64,
                  wordmarkSize: 24,
                  subtitle: 'Compradora',
                ),
                const Spacer(),
                Text(
                  'Bienvenida',
                  style: AppTextStyles.h1.copyWith(fontSize: 32, height: 1.1),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tus compras de los lives, tus pedidos y tus tiendas favoritas, en un solo lugar.',
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 14,
                    color: AppColors.ink2,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                PillButton(
                  label: 'Empezar',
                  icon: Icons.arrow_forward,
                  variant: PillButtonVariant.brand,
                  onPressed: () => context.go('/login'),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Al continuar aceptas los términos y el aviso de privacidad.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 11,
                      color: AppColors.ink3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
