import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/nenis_logo.dart';

enum AuthHeroRole { client, seller, neutral }

/// Escena editorial compartida por las pantallas de autenticación.
///
/// La imagen vive como asset de la app para que bienvenida, login, registro y
/// confirmación compartan el mismo lenguaje visual. Los textos y el acento se
/// animan por separado cuando cambia el tipo de cuenta.
class AuthEditorialHero extends StatelessWidget {
  const AuthEditorialHero({
    super.key,
    this.role = AuthHeroRole.neutral,
    this.compact = false,
    this.showCopy = true,
    this.eyebrow,
    this.title,
    this.subtitle,
  });

  final AuthHeroRole role;
  final bool compact;
  final bool showCopy;
  final String? eyebrow;
  final String? title;
  final String? subtitle;

  bool get isSeller => role == AuthHeroRole.seller;

  Color get accent => isSeller ? AppColors.lavender : AppColors.neniDeep;

  String get resolvedEyebrow =>
      eyebrow ??
      switch (role) {
        AuthHeroRole.client => 'PARA TI',
        AuthHeroRole.seller => 'PARA TU TIENDA',
        AuthHeroRole.neutral => 'NENI\'S',
      };

  String get resolvedTitle =>
      title ??
      switch (role) {
        AuthHeroRole.client => 'Compra bonito.\nCompra local.',
        AuthHeroRole.seller => 'Haz crecer\nlo que vendes.',
        AuthHeroRole.neutral => 'Todo lo bonito\nempieza aquí.',
      };

  String get resolvedSubtitle =>
      subtitle ??
      switch (role) {
        AuthHeroRole.client =>
          'Tu espacio para descubrir, pedir y volver a tus favoritas.',
        AuthHeroRole.seller =>
          'Administra tus pedidos y conecta con clientas de tu ciudad.',
        AuthHeroRole.neutral =>
          'Una comunidad local para comprar y vender con intención.',
      };

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final radius = compact ? 24.0 : 30.0;

    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduceMotion ? 1 : 0.975, end: 1),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox(
            height: compact ? 174 : 328,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Image(
                  image: AssetImage('assets/branding/nenis-auth-bg.png'),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  semanticLabel: 'Escena editorial de moda y compras locales',
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.ink.withValues(alpha: 0.06),
                        AppColors.ink.withValues(alpha: 0.08),
                        AppColors.ink.withValues(alpha: compact ? 0.82 : 0.88),
                      ],
                      stops: const [0, 0.45, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: compact ? 12 : 16,
                  left: compact ? 12 : 16,
                  child: _HeroBadge(
                    icon: isSeller ? Symbols.storefront : Symbols.shopping_bag,
                    label: resolvedEyebrow,
                    accent: accent,
                  ),
                ),
                Positioned(
                  top: compact ? 12 : 16,
                  right: compact ? 12 : 16,
                  child: Container(
                    width: compact ? 36 : 42,
                    height: compact ? 36 : 42,
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.small,
                    ),
                    child: const NenisMark(size: 28),
                  ),
                ),
                if (showCopy)
                  Positioned(
                    left: compact ? 16 : 22,
                    right: compact ? 16 : 22,
                    bottom: compact ? 14 : 20,
                    child: AnimatedSwitcher(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: Alignment.bottomLeft,
                        children: [...previousChildren, ?currentChild],
                      ),
                      child: Column(
                        key: ValueKey('$role-$resolvedTitle'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resolvedEyebrow,
                            style: AppTextStyles.eyebrow(AppColors.surface)
                                .copyWith(
                                  fontSize: compact ? 9.5 : 10.5,
                                  letterSpacing: 1.7,
                                ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            resolvedTitle,
                            style: AppTextStyles.display.copyWith(
                              color: AppColors.surface,
                              fontSize: compact ? 22 : 31,
                              height: 1.04,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            resolvedSubtitle,
                            maxLines: compact ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.subtitle.copyWith(
                              color: AppColors.surface.withValues(alpha: 0.9),
                              fontSize: compact ? 11.5 : 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
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

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: AppRadii.pillRadius,
        boxShadow: AppShadows.small,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: accent, fill: 1),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.chip.copyWith(
                color: AppColors.ink,
                fontSize: 10.5,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
