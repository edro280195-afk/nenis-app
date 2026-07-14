import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/color_hex.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';
import '../../../shared/widgets/segmented.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/slow_load_hint.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/store_avatar.dart';
import '../data/orders_models.dart';
import '../data/orders_repository.dart';

import '../../../core/auth/auth_controller.dart';
import 'seller_orders_screen.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).value;
    final isSeller = session != null && session.hasMembership;
    return isSeller ? const SellerOrdersScreen() : const BuyerOrdersScreen();
  }
}

class BuyerOrdersScreen extends ConsumerWidget {
  const BuyerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(ordersControllerProvider);
    final filter = ref.watch(ordersControllerProvider.notifier).query.filter;

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const _OrdersHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
                child: SegmentedControl(
                  items: OrdersFilter.values
                      .map((f) => SegmentedItem(label: f.label))
                      .toList(),
                  selectedIndex: OrdersFilter.values.indexOf(filter),
                  onChanged: (i) => ref
                      .read(ordersControllerProvider.notifier)
                      .setFilter(OrdersFilter.values[i]),
                ),
              ),
              Expanded(
                child: feed.when(
                  loading: () => const _OrdersLoading(),
                  error: (e, _) => _OrdersError(
                    onRetry: () => ref.invalidate(ordersControllerProvider),
                  ),
                  data: (page) => _OrdersList(page: page),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrdersHeader extends StatelessWidget {
  const _OrdersHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mis pedidos',
                  style: AppTextStyles.h1.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tu historial con todas tus tiendas.',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersList extends ConsumerWidget {
  const _OrdersList({required this.page});
  final BuyerOrdersPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (page.isEmpty) {
      return RefreshIndicator(
        color: AppColors.neniDeep,
        onRefresh: () async => ref.invalidate(ordersControllerProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: const [SizedBox(height: 40), _OrdersEmpty()],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.neniDeep,
      onRefresh: () async => ref.invalidate(ordersControllerProvider),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        itemCount: page.orders.length + 1,
        itemBuilder: (context, i) {
          if (i == page.orders.length) {
            return _Pager(page: page);
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: _OrderRow(order: page.orders[i]),
          );
        },
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});
  final BuyerOrder order;

  @override
  Widget build(BuildContext context) {
    final brand = colorFromHex(order.brandPrimaryColor);
    final items = order.itemsCount == 1
        ? '1 artículo'
        : '${order.itemsCount} artículos';
    final dateLabel = _formatDate(order.createdAt);
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
                  const SizedBox(height: 1),
                  Text(
                    dateLabel,
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 11.5,
                      color: AppColors.ink3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(status: order.chipStatus),
          ],
        ),
      ),
    );
  }
}

class _Pager extends ConsumerWidget {
  const _Pager({required this.page});
  final BuyerOrdersPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (page.totalPages <= 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Center(
          child: Text(
            '${page.total} pedido${page.total == 1 ? '' : 's'}',
            style: AppTextStyles.subtitle.copyWith(fontSize: 12),
          ),
        ),
      );
    }

    final notifier = ref.read(ordersControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PagerButton(
            icon: Symbols.chevron_left,
            label: 'Anterior',
            onTap: page.hasPrev ? notifier.prevPage : null,
          ),
          const SizedBox(width: 12),
          Text(
            'Página ${page.page} de ${page.totalPages}',
            style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
          ),
          const SizedBox(width: 12),
          _PagerButton(
            icon: Symbols.chevron_right,
            label: 'Siguiente',
            onTap: page.hasNext ? notifier.nextPage : null,
            trailingIcon: true,
          ),
        ],
      ),
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingIcon = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool trailingIcon;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final fg = disabled ? AppColors.ink3 : AppColors.ink;
    final children = <Widget>[
      if (!trailingIcon) Icon(icon, size: 16, color: fg),
      if (!trailingIcon) const SizedBox(width: 4),
      Text(
        label,
        style: AppTextStyles.body.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
      if (trailingIcon) const SizedBox(width: 4),
      if (trailingIcon) Icon(icon, size: 16, color: fg),
    ];
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.pillRadius,
            boxShadow: AppShadows.small,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class _OrdersEmpty extends StatelessWidget {
  const _OrdersEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE1EC),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Symbols.receipt_long,
              color: AppColors.neniDeep,
              size: 40,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Aún no hay pedidos aquí',
            textAlign: TextAlign.center,
            style: AppTextStyles.h2.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Cuando hagas un pedido con alguna de tus tiendas aparecerá en este lugar.',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 22),
          PillButton(
            label: 'Explorar tiendas',
            icon: Symbols.storefront,
            variant: PillButtonVariant.brand,
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
    );
  }
}

class _OrdersError extends StatelessWidget {
  const _OrdersError({required this.onRetry});
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
            'No pudimos cargar tus pedidos',
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

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return DateFormat("d 'de' MMM, yyyy", 'es').format(local);
}

class _OrdersLoading extends StatelessWidget {
  const _OrdersLoading();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          itemBuilder: (_, __) => const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Skeleton(height: 110, borderRadius: 20),
          ),
        ),
        const SlowLoadHint(),
      ],
    );
  }
}
