import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import 'glass_bottom_nav.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child, required this.currentRoute});

  final Widget child;
  final String currentRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).asData?.value;
    final items = session != null && session.hasMembership
        ? buildSellerNavItems(includeRoutes: session.canAccessRoutes)
        : buildDefaultNavItems();

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: child,
      bottomNavigationBar: GlassBottomNav(
        items: items,
        currentRoute: currentRoute,
      ),
    );
  }
}
