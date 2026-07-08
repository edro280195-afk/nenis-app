import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/segmented.dart';
import '../../../shared/widgets/skeleton.dart';
import '../data/seller_orders_models.dart';
import '../data/seller_orders_repository.dart';
import '../widgets/seller_status_chip.dart';

class SellerOrdersScreen extends ConsumerStatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  ConsumerState<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends ConsumerState<SellerOrdersScreen> {
  int _filter = 0;
  final _searchCtrl = TextEditingController();
  final _advancingOrderIds = <int>{};
  Timer? _debounce;

  static const _labels = ['Todos', 'Pendientes', 'En ruta', 'Entregados'];
  static const _statuses = ['', 'Pending', 'InRoute', 'Delivered'];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(sellerOrdersControllerProvider.notifier).setSearch(value);
    });
  }

  Future<void> _advanceOrderStatus(
    SellerOrder order,
    SellerOrderStatus next,
  ) async {
    if (_advancingOrderIds.contains(order.id)) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _advancingOrderIds.add(order.id));
    try {
      await ref
          .read(sellerOrdersRepositoryProvider)
          .updateStatus(order.id, next);
      ref.invalidate(sellerOrdersControllerProvider);
      ref.invalidate(sellerDashboardProvider);
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(_snack(e.toString(), color: const Color(0xFFE11D5B)));
    } finally {
      if (mounted) {
        setState(() => _advancingOrderIds.remove(order.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sellerOrdersControllerProvider);

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
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                    child: _SearchField(
                      controller: _searchCtrl,
                      onChanged: _onSearch,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                    child: SegmentedControl(
                      items: _labels
                          .map((l) => SegmentedItem(label: l))
                          .toList(),
                      selectedIndex: _filter,
                      onChanged: (i) {
                        setState(() => _filter = i);
                        ref
                            .read(sellerOrdersControllerProvider.notifier)
                            .setStatus(_statuses[i]);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
                    child: Text(
                      async.maybeWhen(
                        data: (p) =>
                            'Mostrando ${p.items.length} de ${p.totalCount} pedidos',
                        orElse: () => 'Cargando pedidos…',
                      ),
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 11.5,
                        color: AppColors.ink3,
                      ),
                    ),
                  ),
                  Expanded(
                    child: async.when(
                      loading: () => const _SellerOrdersLoading(),
                      error: (e, _) => _ErrorState(
                        message: e.toString(),
                        onRetry: () => ref
                            .read(sellerOrdersControllerProvider.notifier)
                            .reload(),
                      ),
                      data: (page) => RefreshIndicator(
                        color: AppColors.neniDeep,
                        onRefresh: () => ref
                            .read(sellerOrdersControllerProvider.notifier)
                            .reload(),
                        child: page.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 60),
                                  _EmptyOrders(),
                                ],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  22,
                                  0,
                                  22,
                                  120,
                                ),
                                itemCount: page.items.length + 1,
                                itemBuilder: (context, i) {
                                  if (i == page.items.length) {
                                    return _Pager(page: page);
                                  }
                                  final order = page.items[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _OrderCard(
                                      order: order,
                                      advancing: _advancingOrderIds.contains(
                                        order.id,
                                      ),
                                      onAdvanceStatus: _advanceOrderStatus,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 22,
                bottom: 16,
                child: _NewOrderFab(onTap: () => context.push('/orders/new')),
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
          prefixIcon: const Icon(
            Symbols.search,
            size: 20,
            color: AppColors.ink3,
          ),
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
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: 52,
          padding: const EdgeInsets.fromLTRB(16, 0, 20, 0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.neni, AppColors.neniDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: AppShadows.brandPrimary(AppColors.neniDeep),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.add, size: 24, color: Colors.white),
              const SizedBox(width: 8),
              Text('Nuevo', style: AppTextStyles.button.copyWith(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({
    required this.order,
    required this.advancing,
    required this.onAdvanceStatus,
  });
  final SellerOrder order;
  final bool advancing;
  final Future<void> Function(SellerOrder order, SellerOrderStatus next)
  onAdvanceStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = order;
    final names = o.items.map((e) => e.productName).where((n) => n.isNotEmpty);
    final itemsText = names.isEmpty
        ? '${o.itemsCount} ${o.itemsCount == 1 ? 'artículo' : 'artículos'}'
        : '${o.itemsCount} ${o.itemsCount == 1 ? 'artículo' : 'artículos'} · ${names.join(', ')}';

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
                                    o.clientName.isEmpty
                                        ? 'Sin nombre'
                                        : o.clientName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.body.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
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
                                color: AppColors.ink3,
                              ),
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
                  if ((o.clientAddress ?? '').isNotEmpty) ...[
                    const SizedBox(height: 5),
                    _MetaLine(
                      icon: o.orderType == SellerDeliveryType.pickup
                          ? Symbols.storefront
                          : Symbols.location_on,
                      text: o.clientAddress!,
                    ),
                  ],
                  const SizedBox(height: 13),
                  _FinancialPanel(order: o),
                  const SizedBox(height: 13),
                  _OrderActions(
                    order: o,
                    advancing: advancing,
                    onAdvanceStatus: onAdvanceStatus,
                  ),
                ],
              ),
            ),
            Positioned(
              top: -9,
              right: -9,
              child: _TrashButton(onTap: () => _confirmDelete(context, ref, o)),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  SellerOrder o,
) async {
  final messenger = ScaffoldMessenger.of(context);
  await showDialog<void>(
    context: context,
    barrierColor: const Color(0x523A2233),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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
              child: const Icon(
                Symbols.delete,
                size: 34,
                color: Color(0xFFE11D5B),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¿Eliminar este pedido?',
              textAlign: TextAlign.center,
              style: AppTextStyles.h2.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                children: [
                  const TextSpan(text: 'Se quitará el pedido '),
                  TextSpan(
                    text: '#${o.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const TextSpan(text: ' de '),
                  TextSpan(
                    text: o.clientName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const TextSpan(text: '. Esta acción no se puede deshacer.'),
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
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      try {
                        await ref
                            .read(sellerOrdersRepositoryProvider)
                            .deleteOrder(o.id);
                        ref.invalidate(sellerOrdersControllerProvider);
                        ref.invalidate(sellerDashboardProvider);
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(_snack('Pedido #${o.id} eliminado'));
                      } catch (e) {
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            _snack(
                              e.toString(),
                              color: const Color(0xFFE11D5B),
                            ),
                          );
                      }
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

SnackBar _snack(String msg, {Color? color}) => SnackBar(
  behavior: SnackBarBehavior.floating,
  backgroundColor: color ?? AppColors.ink,
  content: Text(msg, style: AppTextStyles.body.copyWith(color: Colors.white)),
);

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
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
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
      SellerOrderStatus.inRoute ||
      SellerOrderStatus.shipped => const [Color(0xFFB79BF0), Color(0xFF9B7BE0)],
      SellerOrderStatus.delivered => const [
        Color(0xFF7FB0F2),
        Color(0xFF4E82D6),
      ],
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
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
      ),
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
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
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 11.5,
              color: AppColors.ink2,
            ),
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
                        color: AppColors.ink3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      money(o.total),
                      style: AppTextStyles.h1.copyWith(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: AppColors.neniDeep,
                        letterSpacing: 0,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              if (o.isPaid)
                const _StatusPill(
                  label: '✅ Pagado',
                  fg: Color(0xFF1F9A6A),
                  bg: Color(0xFFD9F3E6),
                )
              else if (o.amountPaid > 0)
                _StatusPill(
                  label: 'Resta ${money(o.balanceDue)}',
                  fg: const Color(0xFFE11D5B),
                  bg: const Color(0xFFFFE4E9),
                )
              else
                _StatusPill(
                  label: 'Por cobrar',
                  fg: const Color(0xFFE11D5B),
                  bg: const Color(0xFFFFE4E9),
                ),
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w700),
      ),
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

class _OrderActions extends StatelessWidget {
  const _OrderActions({
    required this.order,
    required this.advancing,
    required this.onAdvanceStatus,
  });
  final SellerOrder order;
  final bool advancing;
  final Future<void> Function(SellerOrder order, SellerOrderStatus next)
  onAdvanceStatus;

  @override
  Widget build(BuildContext context) {
    final o = order;

    final (
      SellerOrderStatus? next,
      String? label,
      IconData icon,
    ) = switch (o.status) {
      SellerOrderStatus.pending => (
        SellerOrderStatus.confirmed,
        'Confirmar',
        Symbols.favorite,
      ),
      SellerOrderStatus.confirmed => (
        SellerOrderStatus.inRoute,
        'Poner en ruta',
        Symbols.local_shipping,
      ),
      SellerOrderStatus.inRoute => (
        SellerOrderStatus.delivered,
        'Marcar entregado',
        Symbols.check_circle,
      ),
      _ => (null, null, Symbols.check_circle),
    };

    Future<void> advance() async {
      if (next == null || advancing) return;
      await onAdvanceStatus(o, next);
    }

    return Column(
      children: [
        _PrimaryButton(
          label: 'Gestionar pedido',
          onTap: () => context.push('/orders/detail/${o.id}'),
        ),
        if (label != null) ...[
          const SizedBox(height: 9),
          _SoftButton(
            label: advancing ? 'Actualizando...' : label,
            icon: advancing ? Symbols.hourglass_top : icon,
            onTap: advancing ? null : advance,
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
              Text(label, style: AppTextStyles.button.copyWith(fontSize: 13.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftButton extends StatelessWidget {
  const _SoftButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          height: 42,
          decoration: BoxDecoration(
            color: disabled ? const Color(0xFFF7F3F6) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0x2EE84E83)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: disabled ? AppColors.ink3 : AppColors.neniDeep,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: disabled ? AppColors.ink3 : AppColors.neniDeep,
                ),
              ),
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
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(Symbols.delete, size: 17, color: AppColors.neni),
        ),
      ),
    );
  }
}

class _Pager extends ConsumerWidget {
  const _Pager({required this.page});
  final SellerOrdersPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (page.totalPages <= 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Center(
          child: Text(
            '${page.totalCount} pedidos',
            style: AppTextStyles.subtitle.copyWith(fontSize: 12),
          ),
        ),
      );
    }
    final notifier = ref.read(sellerOrdersControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PagerBtn(
            icon: Symbols.chevron_left,
            label: 'Anterior',
            onTap: page.hasPrev ? notifier.prevPage : null,
          ),
          const SizedBox(width: 12),
          Text(
            'Página ${page.currentPage} de ${page.totalPages}',
            style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
          ),
          const SizedBox(width: 12),
          _PagerBtn(
            icon: Symbols.chevron_right,
            label: 'Siguiente',
            trailing: true,
            onTap: page.hasNext ? notifier.nextPage : null,
          ),
        ],
      ),
    );
  }
}

class _PagerBtn extends StatelessWidget {
  const _PagerBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final fg = disabled ? AppColors.ink3 : AppColors.ink;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            boxShadow: AppShadows.small,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!trailing) Icon(icon, size: 16, color: fg),
              if (!trailing) const SizedBox(width: 4),
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              if (trailing) const SizedBox(width: 4),
              if (trailing) Icon(icon, size: 16, color: fg),
            ],
          ),
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
              child: const Icon(
                Symbols.receipt_long,
                color: AppColors.neniDeep,
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Sin pedidos aquí',
              textAlign: TextAlign.center,
              style: AppTextStyles.h2.copyWith(fontSize: 18),
            ),
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.cloud_off, size: 46, color: AppColors.ink3),
            const SizedBox(height: 14),
            Text(
              'No pudimos cargar los pedidos',
              textAlign: TextAlign.center,
              style: AppTextStyles.h2.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
            ),
            const SizedBox(height: 18),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onRetry,
                borderRadius: BorderRadius.circular(999),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.neni, AppColors.neniDeep],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: AppShadows.brandSmall(AppColors.neniDeep),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Symbols.refresh,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Reintentar',
                        style: AppTextStyles.button.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellerOrdersLoading extends StatelessWidget {
  const _SellerOrdersLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: Skeleton(height: 120, borderRadius: 20),
      ),
    );
  }
}
