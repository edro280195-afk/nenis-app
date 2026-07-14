import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/color_hex.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/store_avatar.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/slow_load_hint.dart';
import '../../../shared/widgets/interactive_bounce.dart';
import '../../notifications/data/notifications_repository.dart';
import '../data/home_models.dart';
import '../data/home_repository.dart';

import '../../../core/auth/auth_controller.dart';
import 'seller_home_screen.dart';

OrderStatus _chipStatus(String status) {
  switch (status) {
    case 'Delivered':
      return OrderStatus.delivered;
    case 'InRoute':
    case 'Shipped':
      return OrderStatus.route;
    default:
      return OrderStatus.pending;
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).value;
    final isSeller = session != null && session.hasMembership;
    return isSeller ? const SellerHomeScreen() : const BuyerHomeScreen();
  }
}

class BuyerHomeScreen extends ConsumerWidget {
  const BuyerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeFeedProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: feed.when(
            loading: () => const _BuyerHomeSkeleton(),
            error: (e, _) =>
                _HomeError(onRetry: () => ref.invalidate(homeFeedProvider)),
            data: (home) => RefreshIndicator(
              color: AppColors.neniDeep,
              onRefresh: () async => ref.invalidate(homeFeedProvider),
              child: _HomeContent(home: home),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.home});
  final BuyerHome home;

  String get _firstName {
    final name = home.displayName.trim();
    if (name.isEmpty || name == 'Clienta') return 'Hermosa';
    return name.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
          child: Row(
            children: [
              UserAvatar(label: _firstName.characters.first.toUpperCase()),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hola de nuevo',
                      style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                    ),
                    Text(
                      _firstName,
                      style: AppTextStyles.h2.copyWith(fontSize: 18),
                    ),
                  ],
                ),
              ),
              const _NotificationsIconButton(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22),
          child: SearchField(),
        ),
        const SizedBox(height: 18),
        if (home.activeOrder != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
            child: Text(
              'Tu pedido en camino',
              style: AppTextStyles.eyebrow(AppColors.neniDeep),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _ActiveOrderHero(order: home.activeOrder!),
          ),
          const SizedBox(height: 16),
        ],
        if (home.isEmpty) _ClaimBanner(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              Expanded(
                child: _BentoTile(
                  icon: Symbols.stars,
                  iconColor: AppColors.gold,
                  iconBg: const Color(0xFFFFF2D4),
                  value: '${home.totalPoints}',
                  caption: 'Puntos acumulados',
                  tint: const Color(0xFFFFF7E6),
                  onTap: () => context.go('/points'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _BentoTile(
                  icon: Symbols.sensors,
                  iconColor: AppColors.lavender,
                  iconBg: const Color(0xFFECE0FF),
                  value: '${home.liveCount}',
                  caption: 'Lives en vivo',
                  tint: const Color(0xFFF1E9FF),
                  onTap: () => context.go('/live'),
                ),
              ),
            ],
          ),
        ),
        if (home.isEmpty) const _EmptyHome(),
        if (home.stores.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionHeader(title: 'Mis tiendas'),
          const SizedBox(height: 12),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: home.stores.length,
              separatorBuilder: (_, _) => const SizedBox(width: 13),
              itemBuilder: (context, i) => _StoreCard(store: home.stores[i]),
            ),
          ),
        ],
        if (home.recentOrders.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionHeader(title: 'Pedidos recientes'),
          const SizedBox(height: 12),
          ...home.recentOrders.map(
            (o) => Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 11),
              child: _RecentOrderRow(order: o),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActiveOrderHero extends StatelessWidget {
  const _ActiveOrderHero({required this.order});
  final BuyerActiveOrder order;

  int get _progress {
    switch (order.status) {
      case 'Delivered':
        return 3;
      case 'InRoute':
      case 'Shipped':
      case 'Confirmed':
        return 2;
      default:
        return 1;
    }
  }

  String get _title {
    switch (order.status) {
      case 'InRoute':
        return 'Va en camino contigo';
      case 'Shipped':
        return 'Tu pedido salió';
      case 'Confirmed':
        return 'Preparando tu pedido';
      default:
        return 'Pedido confirmado';
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = colorFromHex(order.brandPrimaryColor);
    return GestureDetector(
      onTap: () => context.go(
        '/tracking/${order.orderId}?token=${order.accessToken ?? ''}',
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: AppRadii.cardRadius,
          gradient: LinearGradient(
            colors: [lighten(brand, 0.08), brand],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: AppShadows.brandPrimary(brand),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StoreAvatar(
                  label: order.businessName.isNotEmpty
                      ? order.businessName.characters.first.toUpperCase()
                      : '?',
                  size: 34,
                  radius: 11,
                  fontSize: 15,
                  gradientStart: Colors.white.withValues(alpha: 0.25),
                  gradientEnd: Colors.white.withValues(alpha: 0.18),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.businessName,
                        style: AppTextStyles.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Pedido #${order.orderId}',
                        style: AppTextStyles.subtitle.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(status: _chipStatus(order.status), onWhite: true),
              ],
            ),
            const SizedBox(height: 16),
            Text(_title, style: AppTextStyles.h1.copyWith(color: Colors.white)),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  Icon(
                    i == 0
                        ? Symbols.inventory_2
                        : i == 1
                        ? Symbols.local_shipping
                        : Symbols.home,
                    size: 18,
                    color: Colors.white.withValues(
                      alpha: i < _progress ? 1 : 0.55,
                    ),
                  ),
                  if (i < 2)
                    Expanded(
                      child: Container(
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: i < _progress - 1 ? 0.95 : 0.3,
                          ),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BentoTile extends StatelessWidget {
  const _BentoTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.caption,
    required this.tint,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String caption;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InteractiveBounce(
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [tint, AppColors.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadii.softRadius,
          boxShadow: AppShadows.small,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: iconColor, size: 23, fill: 1),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: AppTextStyles.display.copyWith(
                fontSize: 26,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              caption,
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store});
  final BuyerStore store;

  @override
  Widget build(BuildContext context) {
    final brand = colorFromHex(store.brandPrimaryColor);
    return InteractiveBounce(
      onPressed: () => context.go('/store/${store.businessId}'),
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                StoreAvatar(
                  label: store.initial,
                  size: 72,
                  radius: 24,
                  fontSize: 24,
                  gradientStart: lighten(brand, 0.08),
                  gradientEnd: brand,
                ),
                if (store.isLive)
                  Positioned(
                    bottom: -4,
                    left: 12,
                    right: 12,
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.liveRed,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                      child: Text(
                        'LIVE',
                        style: AppTextStyles.chip.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              store.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${store.points} pts',
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 11,
                color: AppColors.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentOrderRow extends StatelessWidget {
  const _RecentOrderRow({required this.order});
  final BuyerRecentOrder order;

  @override
  Widget build(BuildContext context) {
    final brand = colorFromHex(order.brandPrimaryColor);
    final items = order.itemsCount == 1
        ? '1 artículo'
        : '${order.itemsCount} artículos';
    return GestureDetector(
      onTap: () => context.go(
        '/tracking/${order.orderId}?token=${order.accessToken ?? ''}',
      ),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.softRadius,
          boxShadow: AppShadows.small,
        ),
        child: Row(
          children: [
            StoreAvatar(
              label: order.initial,
              size: 50,
              radius: 15,
              gradientStart: lighten(brand, 0.08),
              gradientEnd: brand,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pedido #${order.orderId}',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${order.businessName} · $items',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(status: _chipStatus(order.status)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Text(title, style: AppTextStyles.h2.copyWith(fontSize: 17)),
    );
  }
}

class _ClaimBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
      child: GestureDetector(
        onTap: () => context.go('/claim'),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.cardRadius,
            boxShadow: AppShadows.small,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE1EC),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Symbols.favorite,
                  color: AppColors.neniDeep,
                  size: 24,
                  fill: 1,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reclama tu historial',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Conecta tus compras con tus tiendas y junta puntos.',
                      style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                    ),
                  ],
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

/// Estado vacío del inicio para una compradora nueva (sin pedidos ni tiendas).
class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.cardRadius,
          boxShadow: AppShadows.small,
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2D4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Symbols.shopping_bag,
                size: 32,
                color: AppColors.gold,
                fill: 1,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Aún no hay nada por aquí',
              textAlign: TextAlign.center,
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando compres en un live o reclames tu historial, tus pedidos, puntos y tiendas aparecerán aquí.',
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Symbols.cloud_off, size: 46, color: AppColors.ink3),
          const SizedBox(height: 14),
          Text(
            'No pudimos cargar tu inicio',
            textAlign: TextAlign.center,
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 8),
          Text(
            'Revisa tu conexión e intenta de nuevo.',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 22),
          PillButton(
            label: 'Reintentar',
            icon: Symbols.refresh,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Icono de notificaciones con dot rojo cuando hay no leídas.
class _NotificationsIconButton extends ConsumerWidget {
  const _NotificationsIconButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCount = ref.watch(unreadNotificationsCountProvider);
    final count = asyncCount.asData?.value ?? 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PillIconButton(
          icon: Symbols.notifications,
          onPressed: () => context.push('/notifications').then((_) {
            // Al volver, refrescar el conteo.
            ref.invalidate(unreadNotificationsCountProvider);
          }),
        ),
        if (count > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.liveRed,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.surface, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BuyerHomeSkeleton extends StatelessWidget {
  const _BuyerHomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _skeletonList(),
        const SlowLoadHint(),
      ],
    );
  }

  Widget _skeletonList() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
          child: Row(
            children: [
              const Skeleton.circle(size: 40),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton.text(width: 80, height: 12),
                    SizedBox(height: 6),
                    Skeleton.text(width: 120, height: 16),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: const Skeleton.circle(size: 24),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22),
          child: Skeleton(height: 48, borderRadius: 14),
        ),
        const SizedBox(height: 18),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              Expanded(
                child: Skeleton(height: 94, borderRadius: 20),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Skeleton(height: 94, borderRadius: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22),
          child: Skeleton.text(width: 100, height: 16),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 13),
            itemBuilder: (_, __) => const Skeleton(width: 104, height: 116, borderRadius: 20),
          ),
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22),
          child: Skeleton.text(width: 140, height: 16),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.fromLTRB(22, 0, 22, 11),
            child: Skeleton(height: 72, borderRadius: 18),
          ),
        ),
      ],
    );
  }
}

