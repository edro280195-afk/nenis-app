import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/brand_theme.dart';

class NavItem {
  const NavItem({
    required this.icon,
    required this.label,
    required this.route,
    this.subtitle,
    this.badge,
    this.gradientColors,
    this.alternativeRoutes = const [],
  });

  final IconData icon;
  final String label;
  final String route;
  final String? subtitle;
  final String? badge;
  final List<Color>? gradientColors;
  final List<String> alternativeRoutes;
}

bool isMoreNavItem(NavItem item) => item.icon == Symbols.more_horiz;

bool isNavItemActive(String currentRoute, NavItem item) {
  bool matches(String route) =>
      currentRoute == route || currentRoute.startsWith('$route/');

  return matches(item.route) || item.alternativeRoutes.any(matches);
}

class GlassBottomNav extends StatelessWidget {
  const GlassBottomNav({
    super.key,
    required this.items,
    required this.currentRoute,
    this.onChanged,
  });

  final List<NavItem> items;
  final String currentRoute;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.navRadius,
          border: Border.all(color: AppColors.line, width: 1),
          boxShadow: AppShadows.nav,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.map((item) {
            final isActive = isNavItemActive(currentRoute, item);
            final fg = isActive ? brand.primaryDeep : AppColors.ink3;
            return Expanded(
              child: InkWell(
                onTap: () {
                  onChanged?.call(item.route);
                  if (isMoreNavItem(item)) return;
                  if (currentRoute != item.route) {
                    context.go(item.route);
                  }
                },
                borderRadius: AppRadii.navRadius,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: isActive
                            ? const LinearGradient(
                                colors: [Color(0xFFFFE1EC), Color(0xFFFFD0E2)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                      ),
                      child: Icon(item.icon, size: 25, color: fg),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        style: AppTextStyles.nav.copyWith(color: fg),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

List<NavItem> buildDefaultNavItems() => const [
  NavItem(icon: Symbols.home, label: 'Inicio', route: '/home'),
  NavItem(icon: Symbols.receipt_long, label: 'Pedidos', route: '/orders'),
  NavItem(icon: Symbols.stars, label: 'Puntos', route: '/points'),
  NavItem(
    icon: Symbols.more_horiz,
    label: 'M\u00E1s',
    route: '/tandas',
    alternativeRoutes: ['/raffles'],
  ),
  NavItem(icon: Symbols.person, label: 'Cuenta', route: '/account'),
];

List<NavItem> buildDefaultOverflowItems() => const [
  NavItem(
    icon: Symbols.groups,
    label: 'Tandas de Ahorro',
    route: '/tandas',
    subtitle: 'Organiza o únete a tandas de ahorro con tus amigas.',
    badge: 'AHORRO',
    gradientColors: [Color(0xFF6366F1), Color(0xFF4338CA)],
  ),
  NavItem(
    icon: Symbols.celebration,
    label: 'Sorteos & Premios',
    route: '/raffles',
    subtitle: 'Participa con tus boletos acumulados y gana productos.',
    badge: 'BOLETOS',
    gradientColors: [Color(0xFFF3B341), Color(0xFFB45309)],
  ),
];

List<NavItem> buildSellerNavItems({bool includeRoutes = true}) => [
  const NavItem(icon: Symbols.home, label: 'Inicio', route: '/home'),
  const NavItem(icon: Symbols.receipt_long, label: 'Pedidos', route: '/orders'),
  const NavItem(icon: Symbols.group, label: 'Clientas', route: '/clients'),
  const NavItem(icon: Symbols.groups, label: 'Tandas', route: '/tandas'),
  NavItem(
    icon: Symbols.more_horiz,
    label: 'M\u00E1s',
    route: includeRoutes ? '/routes' : '/seller/inventory',
    alternativeRoutes: const [
      '/account',
      '/seller/labels',
      '/seller/inventory',
      '/seller/updates',
      '/seller/vip',
      '/seller/live',
    ],
  ),
];

List<NavItem> buildSellerOverflowItems({bool includeRoutes = true}) => [
  if (includeRoutes)
    const NavItem(
      icon: Symbols.directions_car,
      label: 'Reparto y Rutas',
      route: '/routes',
      subtitle: 'Organiza entregas, chóferes, mapa GPS y confirmación de paradas.',
      badge: 'RUTAS HOY',
      gradientColors: [Color(0xFF3B82F6), Color(0xFF2E6BD6)],
    ),
  const NavItem(
    icon: Symbols.inventory_2,
    label: 'Bodega y Stock',
    route: '/seller/inventory',
    subtitle: 'Control de cajas, escaneo de barras, bitácora y auditoría NFC.',
    badge: 'NFC & CAJAS',
    gradientColors: [Color(0xFFF3B341), Color(0xFFD97706)],
  ),
  const NavItem(
    icon: Symbols.print,
    label: 'Estudio de Etiquetas',
    route: '/seller/labels',
    subtitle: 'Diseña e imprime plantillas térmicas para paquetes y cajas.',
    badge: 'STICKERS',
    gradientColors: [Color(0xFFFB6F9C), Color(0xFFE84E83)],
  ),
  const NavItem(
    icon: Symbols.person,
    label: 'Mi Cuenta y Negocio',
    route: '/account',
    subtitle: 'Configura tu tienda, equipo de trabajo, cobros, plan y preferencias.',
    badge: 'AJUSTES',
    gradientColors: [Color(0xFF9B7BE0), Color(0xFF7C3AED)],
  ),
];
