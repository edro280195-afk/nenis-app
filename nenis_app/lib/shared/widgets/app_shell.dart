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
                      _showMoreSheet(context, overflowItems, currentRoute);
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
  String currentRoute,
) {
  if (items.isEmpty) return;
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        _MoreNavSheet(items: items, currentRoute: currentRoute),
  );
}

class _MoreNavSheet extends StatelessWidget {
  const _MoreNavSheet({required this.items, required this.currentRoute});

  final List<NavItem> items;
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: AppRadii.pillRadius,
            ),
          ),
          for (final item in items)
            _MoreNavTile(
              item: item,
              active: isNavItemActive(currentRoute, item),
              onTap: () {
                Navigator.of(context).pop();
                context.go(item.route);
              },
            ),
        ],
      ),
    );
  }
}

class _MoreNavTile extends StatelessWidget {
  const _MoreNavTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? context.brand.primaryDeep : AppColors.ink;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.softRadius,
        child: Ink(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFFEAF2) : Colors.transparent,
            borderRadius: AppRadii.softRadius,
          ),
          child: Row(
            children: [
              Icon(item.icon, color: fg, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: AppTextStyles.body.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(Symbols.chevron_right, color: AppColors.ink3),
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
