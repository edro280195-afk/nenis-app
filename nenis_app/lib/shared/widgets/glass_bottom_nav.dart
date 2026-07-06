import 'dart:ui';

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
  });

  final IconData icon;
  final String label;
  final String route;
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: ClipRRect(
        borderRadius: AppRadii.navRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: AppRadii.navRadius,
              border: Border.all(color: AppColors.glassBorder, width: 1),
              boxShadow: AppShadows.nav,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: items.map((item) {
                final isActive = currentRoute == item.route ||
                    currentRoute.startsWith('${item.route}/');
                final fg = isActive ? brand.primaryDeep : AppColors.ink3;
                return Expanded(
                  child: InkWell(
                    onTap: () {
                      onChanged?.call(item.route);
                      if (currentRoute != item.route) {
                        context.go(item.route);
                      }
                    },
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
                        Text(
                          item.label,
                          style: AppTextStyles.nav.copyWith(color: fg),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

List<NavItem> buildDefaultNavItems() => const [
      NavItem(icon: Symbols.home, label: 'Inicio', route: '/home'),
      NavItem(
        icon: Symbols.receipt_long,
        label: 'Pedidos',
        route: '/orders',
      ),
      NavItem(icon: Symbols.stars, label: 'Puntos', route: '/points'),
      NavItem(icon: Symbols.person, label: 'Cuenta', route: '/account'),
    ];

List<NavItem> buildSellerNavItems() => const [
      NavItem(icon: Symbols.home, label: 'Inicio', route: '/home'),
      NavItem(
        icon: Symbols.receipt_long,
        label: 'Pedidos',
        route: '/orders',
      ),
      NavItem(icon: Symbols.groups, label: 'Tandas', route: '/tandas'),
      NavItem(
        icon: Symbols.directions_car,
        label: 'Reparto',
        route: '/routes',
      ),
      NavItem(icon: Symbols.person, label: 'Cuenta', route: '/account'),
    ];
