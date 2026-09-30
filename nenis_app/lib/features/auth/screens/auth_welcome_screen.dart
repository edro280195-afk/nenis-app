import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/nenis_logo.dart';
import '../../../shared/widgets/pill_button.dart';
import '../widgets/auth_editorial_hero.dart';
import '../widgets/auth_motion.dart';

/// Entrada principal de autenticación. Presenta una sola decisión clara para
/// entrar con teléfono y otra para crear cuenta, sin repetir la misma acción
/// con dos textos distintos.
class AuthWelcomeScreen extends StatelessWidget {
  const AuthWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth >= 600
                  ? 32.0
                  : 20.0;
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  18,
                  horizontalPadding,
                  28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: AuthMotionColumn(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: NenisLogo(markSize: 54, wordmarkSize: 26),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Compra bonito.\nCompra local.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.display.copyWith(
                            fontSize: 31,
                            height: 1.08,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          'Descubre boutiques de Nuevo Laredo y consiente tu estilo mientras apoyas a mujeres que venden cerca de ti.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 14,
                            height: 1.45,
                            color: AppColors.ink2,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const AuthEditorialHero(
                          role: AuthHeroRole.neutral,
                          showCopy: false,
                        ),
                        const SizedBox(height: 22),
                        PillButton(
                          key: const Key('welcome-phone-login'),
                          label: 'Entrar con mi teléfono',
                          icon: Symbols.phone_iphone,
                          variant: PillButtonVariant.brand,
                          onPressed: () => context.go('/login-otp'),
                        ),
                        const SizedBox(height: 11),
                        OutlinedButton.icon(
                          key: const Key('welcome-create-account'),
                          onPressed: () => context.go('/register'),
                          icon: const Icon(Symbols.add, size: 21),
                          label: const Text('Crear mi cuenta'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            foregroundColor: AppColors.neniDeep,
                            backgroundColor: AppColors.surface.withValues(
                              alpha: 0.58,
                            ),
                            side: const BorderSide(
                              color: AppColors.neniDeep,
                              width: 1.4,
                            ),
                            shape: const StadiumBorder(),
                            textStyle: AppTextStyles.button.copyWith(
                              color: AppColors.neniDeep,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 13),
                        Center(
                          child: TextButton(
                            key: const Key('welcome-password-login'),
                            onPressed: () => context.go('/login-password'),
                            child: Text(
                              'También puedes entrar con contraseña',
                              style: AppTextStyles.subtitle.copyWith(
                                color: AppColors.ink2,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Al continuar aceptas los Términos y el Aviso de privacidad.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 11,
                            color: AppColors.ink3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
