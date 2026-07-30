import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
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

    // Muro de bloqueo: solo Owner/Admin lo ven (Driver/Scaner siguen
    // trabajando aunque la tienda esté vencida, igual que en el panel web).
    final showPaywall = isSeller &&
        session.hasActiveBusinessRole(const {'Owner', 'Admin'}) &&
        (ref.watch(sellerBusinessSettingsProvider).value?.subscription.isLocked ??
            false);

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: showPaywall ? const SubscriptionPaywallScreen() : child,
      bottomNavigationBar: showPaywall
          ? null
          : GlassBottomNav(items: items, currentRoute: currentRoute),
    );
  }
}
