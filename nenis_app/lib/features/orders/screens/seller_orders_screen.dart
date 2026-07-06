import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/glass_bottom_nav.dart';
import '../../../shared/widgets/segmented.dart';
import '../data/seller_orders_data.dart';
import '../widgets/seller_status_chip.dart';

class SellerOrdersScreen extends ConsumerStatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  ConsumerState<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends ConsumerState<SellerOrdersScreen> {
  int _filter = 0;
  String _search = '';
  final _searchCtrl = TextEditingController();

  static const _filters = ['Todos', 'Pendientes', 'En ruta', 'Entregados'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesFilter(SellerOrder o) {
    switch (_filter) {
      case 1:
        return o.status == SellerOrderStatus.pending ||
            o.status == SellerOrderStatus.confirmed;
      case 2:
        return o.status == SellerOrderStatus.route;
      case 3:
        return o.status == SellerOrderStatus.delivered;
      default:
        return true;
    }
  }

  bool _matchesSearch(SellerOrder o) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (o.clientName.toLowerCase().contains(q)) return true;
    if (o.id.contains(q)) return true;
    return o.items.any((i) => i.name.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(sellerOrdersProvider);
    final visible =
        orders.where(_matchesFilter).where(_matchesSearch).toList();
    final byCollect = orders
        .where((o) => !o.isPaid)
        .fold<double>(0, (s, o) => s + o.balanceDue);

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: AppTextStyles.h1.copyWith(fontSize: 27),
                            children: [
                              const TextSpan(text: 'Pedidos '),
                              TextSpan(
                                text: 'recibidos',
                                style: AppTextStyles.h1.copyWith(
                                  fontSize: 27,
                                  color: AppColors.neniDeep,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Gestiona entregas y cobros de tu negocio.',
                          style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                    child: _SearchField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                    child: SegmentedControl(
                      items: _filters
                          .map((l) => SegmentedItem(label: l))
                          .toList(),
                      selectedIndex: _filter,
                      onChanged: (i) => setState(() => _filter = i),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mostrando ${visible.length} de ${orders.length} pedidos',
                          style: AppTextStyles.subtitle
                              .copyWith(fontSize: 11.5, color: AppColors.ink3),
                        ),
                        if (byCollect > 0)
                          Text(
                            '${money(byCollect)} por cobrar 💕',
                            style: AppTextStyles.body.copyWith(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.neniDeep,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: visible.isEmpty
                        ? const _EmptyOrders()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(22, 0, 22, 120),
                            itemCount: visible.length,
                            itemBuilder: (context, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _OrderCard(order: visible[i]),
                            ),
                          ),
                  ),
                ],
              ),
              Positioned(
                right: 22,
                bottom: 104,
                child: _NewOrderFab(
                  onTap: () => context.push('/orders/new'),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GlassBottomNav(
                  items: buildSellerNavItems(),
                  currentRoute: '/orders',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.small,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTextStyles.body.copyWith(fontSize: 13.5),
        decoration: InputDecoration(
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: const Icon(Symbols.search, size: 20, color: AppColors.ink3),
          hintText: 'Buscar clienta, artículo o #folio…',
          hintStyle: AppTextStyles.fieldPlaceholder.copyWith(fontSize: 13.5),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _NewOrderFab extends StatelessWidget {
  const _NewOrderFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.pillRadius,
        child: Ink(
          height: 52,
          padding: const EdgeInsets.fromLTRB(16, 0, 20, 0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.neni, AppColors.neniDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadii.pillRadius,
            boxShadow: AppShadows.brandPrimary(AppColors.neniDeep),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.add, size: 24, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Nuevo',
                style: AppTextStyles.button.copyWith(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});
  final SellerOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = order;
    final itemsText =
        '${o.itemsCount} ${o.itemsCount == 1 ? 'artículo' : 'artículos'} · '
        '${o.items.map((e) => e.name).join(', ')}';

    return GestureDetector(
      onTap: () => context.push('/orders/detail/${o.id}'),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0x57FB6F9C), Color(0x80FFFFFF), Color(0x4D9B7BE0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: AppShadows.card,
        ),
        padding: const EdgeInsets.all(1.4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(23.6),
              ),
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Avatar(initial: o.initial, status: o.status),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    o.clientName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.body.copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (o.isFrequent) ...[
                                  const SizedBox(width: 6),
                                  const _MiniTag(
                                    label: 'Frecuente',
                                    fg: Color(0xFF7C5AC9),
                                    bg: Color(0xFFF1E9FF),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Pedido #${o.id}',
                              style: AppTextStyles.subtitle.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SellerStatusChip(status: o.status),
                    ],
                  ),
                  const SizedBox(height: 11),
                  _MetaLine(icon: Symbols.shopping_bag, text: itemsText),
                  const SizedBox(height: 5),
                  _MetaLine(
                    icon: o.deliveryType == SellerDeliveryType.pickup
                        ? Symbols.storefront
                        : Symbols.location_on,
                    text: o.address,
                  ),
                  const SizedBox(height: 13),
                  _FinancialPanel(order: o),
                  const SizedBox(height: 13),
                  _OrderActions(order: o),
                ],
              ),
            ),
            Positioned(
              top: -9,
              right: -9,
              child: _TrashButton(
                onTap: () => _confirmDelete(context, ref, o),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmDelete(
    BuildContext context, WidgetRef ref, SellerOrder o) async {
  await showDialog<void>(
    context: context,
    barrierColor: const Color(0x523A2233),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F4),
                borderRadius: BorderRadius.circular(22),
              ),
              alignment: Alignment.center,
              child: const Icon(Symbols.delete,
                  size: 34, color: Color(0xFFE11D5B)),
            ),
            const SizedBox(height: 16),
            Text('¿Eliminar este pedido?',
                textAlign: TextAlign.center,
                style: AppTextStyles.h2.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                children: [
                  const TextSpan(text: 'Se quitará el pedido '),
                  TextSpan(
                      text: '#${o.id}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.ink)),
                  const TextSpan(text: ' de '),
                  TextSpan(
                      text: o.clientName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.ink)),
                  const TextSpan(
                      text: '. Esta acción no se puede deshacer.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _DialogButton(
                    label: 'Cancelar',
                    bg: const Color(0xFFF3EEF1),
                    fg: AppColors.ink2,
                    onTap: () => Navigator.of(ctx).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DialogButton(
                    label: 'Eliminar',
                    gradient: const [Color(0xFFFB6F8E), Color(0xFFE11D5B)],
                    fg: Colors.white,
                    onTap: () {
                      ref
                          .read(sellerOrdersProvider.notifier)
                          .removeOrder(o.id);
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.ink,
                          content: Text('Pedido #${o.id} eliminado',
                              style: AppTextStyles.body
                                  .copyWith(color: Colors.white)),
                        ));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.fg,
    required this.onTap,
    this.bg,
    this.gradient,
  });
  final String label;
  final Color fg;
  final VoidCallback onTap;
  final Color? bg;
  final List<Color>? gradient;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            color: bg,
            gradient: gradient != null
                ? LinearGradient(colors: gradient!)
                : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: gradient != null
                ? const [
                    BoxShadow(
                      color: Color(0x66E11D5B),
                      offset: Offset(0, 10),
                      blurRadius: 20,
                      spreadRadius: -8,
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(label,
                style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w700, color: fg)),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.status});
  final String initial;
  final SellerOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = switch (status) {
      SellerOrderStatus.route => const [Color(0xFFB79BF0), Color(0xFF9B7BE0)],
      SellerOrderStatus.delivered => const [Color(0xFF7FB0F2), Color(0xFF4E82D6)],
      _ => const [AppColors.neni, AppColors.neniDeep],
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.5),
            offset: const Offset(0, 8),
            blurRadius: 16,
            spreadRadius: -8,
          )
        ],
      ),
      alignment: Alignment.center,
      child: Text(initial,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label, required this.fg, required this.bg});
  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
            color: fg,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.neni),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.subtitle
                .copyWith(fontSize: 11.5, color: AppColors.ink2),
          ),
        ),
      ],
    );
  }
}

class _FinancialPanel extends StatelessWidget {
  const _FinancialPanel({required this.order});
  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF0F5), Color(0xFFF5EBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x24FB6F9C)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL (${o.itemsCount} ARTS)',
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.ink3),
                    ),
                    const SizedBox(height: 3),
                    GradientText(money(o.total), fontSize: 23),
                  ],
                ),
              ),
              if (o.isPaid)
                const _StatusPill(
                    label: '✅ Pagado',
                    fg: Color(0xFF1F9A6A),
                    bg: Color(0xFFD9F3E6))
              else
                _StatusPill(
                    label: 'Resta ${money(o.balanceDue)}',
                    fg: const Color(0xFFE11D5B),
                    bg: const Color(0xFFFFE4E9)),
            ],
          ),
          const SizedBox(height: 11),
          _ProgressBar(percent: o.paymentPercent, done: o.isPaid),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.fg, required this.bg});
  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.percent, required this.done});
  final double percent;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 7,
      decoration: BoxDecoration(
        color: const Color(0x29FB6F9C),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: (percent / 100).clamp(0, 1)),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => FractionallySizedBox(
            widthFactor: v == 0 ? 0.0001 : v,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: done
                      ? const [Color(0xFF4ADE9E), Color(0xFF1F9A6A)]
                      : const [AppColors.neni, AppColors.neniDeep],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderActions extends ConsumerWidget {
  const _OrderActions({required this.order});
  final SellerOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = order;
    final notifier = ref.read(sellerOrdersProvider.notifier);

    void nextStatus() {
      final next = switch (o.status) {
        SellerOrderStatus.pending => SellerOrderStatus.confirmed,
        SellerOrderStatus.confirmed => SellerOrderStatus.route,
        SellerOrderStatus.route => SellerOrderStatus.delivered,
        SellerOrderStatus.delivered => SellerOrderStatus.delivered,
      };
      notifier.updateStatus(o.id, next);
    }

    void whatsapp() {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF12A150),
          content: Text('Abriendo WhatsApp con ${o.clientName}…',
              style: AppTextStyles.body.copyWith(color: Colors.white)),
        ));
    }

    final (String? secondaryLabel, IconData secondaryIcon) =
        switch (o.status) {
      SellerOrderStatus.pending => ('Confirmar', Symbols.favorite),
      SellerOrderStatus.confirmed => ('A ruta', Symbols.local_shipping),
      SellerOrderStatus.route => ('Entregado', Symbols.check_circle),
      SellerOrderStatus.delivered => (null, Symbols.check_circle),
    };

    return Column(
      children: [
        _PrimaryButton(
          label: 'Gestionar pedido',
          onTap: () => context.push('/orders/detail/${o.id}'),
        ),
        if (secondaryLabel != null) ...[
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _SoftButton(
                  label: secondaryLabel,
                  icon: secondaryIcon,
                  onTap: nextStatus,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _WaButton(
                  label: o.status == SellerOrderStatus.route
                      ? 'En camino'
                      : 'WhatsApp',
                  onTap: whatsapp,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.neni, AppColors.neniDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: AppShadows.brandSmall(AppColors.neniDeep),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Symbols.bolt, size: 18, color: Colors.white),
              const SizedBox(width: 7),
              Text(label,
                  style: AppTextStyles.button.copyWith(fontSize: 13.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftButton extends StatelessWidget {
  const _SoftButton(
      {required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0x2EE84E83)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.neniDeep),
              const SizedBox(width: 6),
              Text(label,
                  style: AppTextStyles.body.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neniDeep)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaButton extends StatelessWidget {
  const _WaButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFE9F9EE),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0x2E1F9A6A)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Symbols.chat, size: 16, color: Color(0xFF12A150)),
              const SizedBox(width: 6),
              Text(label,
                  style: AppTextStyles.body.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF12A150))),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrashButton extends StatelessWidget {
  const _TrashButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x2EE84E83)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40D6336C),
                offset: Offset(0, 6),
                blurRadius: 14,
                spreadRadius: -6,
              )
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(Symbols.delete, size: 17, color: AppColors.neni),
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE1EC),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Symbols.receipt_long,
                  color: AppColors.neniDeep, size: 40),
            ),
            const SizedBox(height: 18),
            Text('Sin pedidos aquí',
                textAlign: TextAlign.center,
                style: AppTextStyles.h2.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Ajusta los filtros o crea un pedido nuevo con el botón rosa.',
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle.copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Texto con degradado rosa→lavanda (para los totales).
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, this.fontSize = 22});
  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [AppColors.neniDeep, Color(0xFFB15AD8)],
      ).createShader(bounds),
      child: Text(
        text,
        style: AppTextStyles.h1.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.5,
          height: 1,
        ),
      ),
    );
  }
}
