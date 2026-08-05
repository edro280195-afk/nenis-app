import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/brand_theme.dart';
import '../../features/account/data/seller_settings_repository.dart';
import '../../features/subscription/screens/subscription_paywall_screen.dart';
import 'glass_bottom_nav.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child, required this.currentRoute});

  final Widget child;
  final String currentRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).asData?.value;
    final isSeller = session != null && session.hasMembership;
    final items = isSeller
        ? buildSellerNavItems(includeRoutes: session.canAccessRoutes)
        : buildDefaultNavItems();
    final overflowItems = isSeller
        ? buildSellerOverflowItems(includeRoutes: session.canAccessRoutes)
        : buildDefaultOverflowItems();

    // Muro de bloqueo: solo Owner/Admin lo ven. Driver/Scaner siguen
    // trabajando aunque la tienda este vencida, igual que en el panel web.
    final showPaywall =
        isSeller &&
        session.hasActiveBusinessRole(const {'Owner', 'Admin'}) &&
        (ref
                .watch(sellerBusinessSettingsProvider)
                .value
                ?.subscription
                .isLocked ??
            false);

    final content = showPaywall ? const SubscriptionPaywallScreen() : child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 720;
        return Scaffold(
          backgroundColor: AppColors.surfaceCream,
          body: useRail && !showPaywall
              ? Row(
                  children: [
                    _AdaptiveNavRail(
                      items: items,
                      overflowItems: overflowItems,
                      currentRoute: currentRoute,
                    ),
                    const VerticalDivider(width: 1, color: AppColors.line),
                    Expanded(child: content),
                  ],
                )
              : content,
          bottomNavigationBar: showPaywall || useRail
              ? null
              : GlassBottomNav(
                  items: items,
                  currentRoute: currentRoute,
                  onChanged: (route) {
                    final item = items.firstWhere(
                      (item) => item.route == route,
                    );
                    if (isMoreNavItem(item)) {
                      _showMoreSheet(
                        context,
                        overflowItems,
                        currentRoute,
                        isSeller: isSeller,
                      );
                    }
                  },
                ),
        );
      },
    );
  }
}

void _showMoreSheet(
  BuildContext context,
  List<NavItem> items,
  String currentRoute, {
  bool isSeller = true,
}) {
  if (items.isEmpty) return;
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _MoreNavSheet(
      items: items,
      currentRoute: currentRoute,
      isSeller: isSeller,
    ),
  );
}

class _MoreNavSheet extends StatelessWidget {
  const _MoreNavSheet({
    required this.items,
    required this.currentRoute,
    required this.isSeller,
  });

  final List<NavItem> items;
  final String currentRoute;
  final bool isSeller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCream,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.lineSoft.withValues(alpha: 0.8),
                borderRadius: AppRadii.pillRadius,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isSeller ? 'Más Espacios' : 'Más Experiencias',
                          style: AppTextStyles.h1.copyWith(
                            fontSize: 20,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isSeller
                                ? const Color(0xFFFFE1EC)
                                : const Color(0xFFEFE8FC),
                            borderRadius: AppRadii.pillRadius,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSeller
                                    ? Symbols.verified
                                    : Symbols.shopping_bag,
                                size: 13,
                                color: isSeller
                                    ? AppColors.neniDeep
                                    : AppColors.lavender,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isSeller ? 'Vendedora' : 'Clienta',
                                style: AppTextStyles.chip.copyWith(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSeller
                                      ? AppColors.neniDeep
                                      : AppColors.lavender,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSeller
                          ? 'Accesos directos a tus módulos principales'
                          : 'Participa en tandas y gana premios en sorteos',
                      style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const Icon(
                    Symbols.close,
                    size: 20,
                    color: AppColors.ink2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in items) ...[
                    _MoreNavModuleCard(
                      item: item,
                      active: isNavItemActive(currentRoute, item),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.go(item.route);
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Symbols.touch_app,
                  size: 15,
                  color: AppColors.neni,
                ),
                const SizedBox(width: 6),
                Text(
                  'Toca cualquier módulo para navegar al área de trabajo',
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 11,
                    color: AppColors.ink2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreNavModuleCard extends StatelessWidget {
  const _MoreNavModuleCard({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = item.gradientColors ??
        const [Color(0xFF9B7BE0), Color(0xFF7C3AED)];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(
              color: active ? AppColors.neni : AppColors.line,
              width: active ? 1.5 : 1,
            ),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(item.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.label,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (item.badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.first.withValues(alpha: 0.12),
                              borderRadius: AppRadii.pillRadius,
                            ),
                            child: Text(
                              item.badge!,
                              style: AppTextStyles.chip.copyWith(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: colors.last,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.subtitle.copyWith(
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Symbols.chevron_right,
                size: 20,
                color: AppColors.ink3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdaptiveNavRail extends StatelessWidget {
  const _AdaptiveNavRail({
    required this.items,
    required this.overflowItems,
    required this.currentRoute,
  });

  final List<NavItem> items;
  final List<NavItem> overflowItems;
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final allItems = [
      ...items.where((item) => !isMoreNavItem(item)),
      ...overflowItems,
    ];
    final selected = allItems.indexWhere(
      (item) => isNavItemActive(currentRoute, item),
    );

    return SafeArea(
      right: false,
      child: NavigationRail(
        minWidth: 86,
        groupAlignment: -0.72,
        backgroundColor: AppColors.surface.withValues(alpha: 0.88),
        selectedIndex: selected < 0 ? 0 : selected,
        onDestinationSelected: (index) => context.go(allItems[index].route),
        labelType: NavigationRailLabelType.all,
        indicatorColor: const Color(0xFFFFE1EC),
        selectedIconTheme: IconThemeData(color: context.brand.primaryDeep),
        unselectedIconTheme: const IconThemeData(color: AppColors.ink3),
        selectedLabelTextStyle: AppTextStyles.nav.copyWith(
          color: context.brand.primaryDeep,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: AppTextStyles.nav.copyWith(
          color: AppColors.ink3,
        ),
        destinations: [
          for (final item in allItems)
            NavigationRailDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.icon, fill: 1),
              label: Text(item.label),
            ),
        ],
      ),
    );
  }
}
