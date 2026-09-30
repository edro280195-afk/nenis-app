import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/nenis_logo.dart';
import '../../../shared/widgets/pill_button.dart';
import '../widgets/auth_editorial_hero.dart';
import '../widgets/auth_motion.dart';

/// Entrada de autenticación. Una acción principal para quien ya tiene cuenta
/// y, debajo, dos caminos de igual peso para quien llega por primera vez:
/// clienta y vendedora. Antes la vendedora tenía que adivinar que debía tocar
/// "Crear mi cuenta" y elegir su rol después.
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
                  : 22.0;
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  16,
                  horizontalPadding,
                  24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: AuthMotionColumn(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: NenisLogo(markSize: 46, wordmarkSize: 23),
                        ),
                        const SizedBox(height: 18),
                        Semantics(
                          header: true,
                          child: Text(
                            'Compra bonito.\nCompra local.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.display.copyWith(
                              fontSize: 30,
                              height: 1.1,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Boutiques de Nuevo Laredo y mujeres que venden '
                          'cerca de ti, en un solo lugar.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 14,
                            height: 1.45,
                            color: AppColors.textAa,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const AuthEditorialHero(
                          role: AuthHeroRole.neutral,
                          compact: true,
                          showCopy: false,
                        ),
                        const SizedBox(height: 20),
                        PillButton(
                          key: const Key('welcome-phone-login'),
                          label: 'Entrar con mi teléfono',
                          icon: Symbols.phone_iphone,
                          variant: PillButtonVariant.brand,
                          onPressed: () => context.go('/login-otp'),
                        ),
                        const SizedBox(height: 22),
                        const _FirstTimeDivider(),
                        const SizedBox(height: 12),
                        // IntrinsicHeight: sin él, `stretch` dentro del área
                        // desplazable recibe alto infinito y la pantalla no
                        // se dibuja.
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _RoleTile(
                                  key: const Key('welcome-create-client'),
                                  icon: Symbols.shopping_bag,
                                  title: 'Soy clienta',
                                  subtitle: 'Descubre y compra',
                                  accent: AppColors.neniDeep,
                                  onTap: () => context.go('/register'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _RoleTile(
                                  key: const Key('welcome-create-seller'),
                                  icon: Symbols.storefront,
                                  title: 'Vendo en Neni\'s',
                                  subtitle: 'Haz crecer tu tienda',
                                  accent: AppColors.lavender,
                                  onTap: () =>
                                      context.go('/register?role=seller'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: TextButton(
                            key: const Key('welcome-password-login'),
                            onPressed: () => context.go('/login-password'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            child: Text(
                              'Entrar con contraseña',
                              style: AppTextStyles.subtitle.copyWith(
                                color: AppColors.textAa,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          'Al continuar aceptas los Términos y el Aviso de '
                          'privacidad.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 11,
                            color: AppColors.textAa,
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

class _FirstTimeDivider extends StatelessWidget {
  const _FirstTimeDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.line, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '¿Primera vez en Neni\'s?',
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textAa,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.line, height: 1)),
      ],
    );
  }
}

/// Camino de creación de cuenta. El rol se distingue por icono y texto, no solo
/// por color (requisito de accesibilidad del producto).
class _RoleTile extends StatelessWidget {
  const _RoleTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle. Crear cuenta',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.78),
        borderRadius: AppRadii.softRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.softRadius,
          child: Container(
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            decoration: BoxDecoration(
              borderRadius: AppRadii.softRadius,
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: accent),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 12,
                    color: AppColors.textAa,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
