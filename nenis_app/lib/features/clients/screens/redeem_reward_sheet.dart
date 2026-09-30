import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/premium_toast.dart';
import '../../orders/data/seller_orders_models.dart';
import '../../orders/data/seller_orders_repository.dart';
import '../data/seller_clients_models.dart';
import '../data/seller_clients_repository.dart';

/// Abre la hoja para canjear un premio de lealtad de una clienta aplicándolo
/// como descuento a uno de sus pedidos abiertos. Devuelve `true` si se canjeó.
///
/// Cierra el ciclo puntos → premio dentro de la app: antes la vendedora veía el
/// saldo de la clienta pero solo podía canjear desde el panel web.
Future<bool> showRedeemRewardSheet(
  BuildContext context, {
  required int clientId,
  required String clientName,
  required int currentPoints,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Sobre la barra inferior: si no, tapaba el final de la lista de premios.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RedeemRewardSheet(
      clientId: clientId,
      clientName: clientName,
      currentPoints: currentPoints,
    ),
  );
  return result ?? false;
}

class _RedeemRewardSheet extends ConsumerStatefulWidget {
  const _RedeemRewardSheet({
    required this.clientId,
    required this.clientName,
    required this.currentPoints,
  });

  final int clientId;
  final String clientName;
  final int currentPoints;

  @override
  ConsumerState<_RedeemRewardSheet> createState() => _RedeemRewardSheetState();
}

class _RedeemRewardSheetState extends ConsumerState<_RedeemRewardSheet> {
  List<SellerOrder>? _orders;
  String? _ordersError;
  SellerOrder? _selected;
  bool _redeeming = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  /// El backend solo permite canjear en pedidos que aún no se entregan ni
  /// cancelan; los fusionados dentro de otro tampoco están vigentes.
  bool _canRedeemOn(SellerOrder o) =>
      o.status != SellerOrderStatus.delivered &&
      o.status != SellerOrderStatus.canceled &&
      !o.isMergedAway;

  Future<void> _loadOrders() async {
    try {
      final all = await ref
          .read(sellerOrdersRepositoryProvider)
          .getOpenOrders(clientId: widget.clientId);
      if (!mounted) return;
      final open = all.where(_canRedeemOn).toList();
      setState(() {
        _orders = open;
        _ordersError = null;
        if (open.length == 1) _selected = open.first;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _ordersError = e.toString());
    }
  }

  /// Motivo por el que un premio no se puede aplicar ahora, o `null` si sí.
  /// Espeja las validaciones de `POST /api/loyalty/redeem`.
  String? _blockedReason(SellerLoyaltyReward reward) {
    if (reward.pointsCost > widget.currentPoints) {
      return 'Faltan ${reward.pointsCost - widget.currentPoints} pts';
    }
    final order = _selected;
    if (order == null) return 'Elige primero el pedido';
    final discount = reward.discountFor(shippingCost: order.shippingCost);
    if (discount > order.total) {
      return 'El pedido (${money(order.total)}) es menor al descuento '
          '(${money(discount)})';
    }
    return null;
  }

  String _effectLabel(SellerLoyaltyReward reward) {
    switch (reward.type) {
      case SellerRewardType.fixedDiscount:
        return 'Descuento de ${money(reward.value)}';
      case SellerRewardType.freeShipping:
        final order = _selected;
        return order == null
            ? 'Envío gratis'
            : 'Envío gratis (${money(order.shippingCost)})';
      case SellerRewardType.gift:
        return 'Regalo físico: se entrega con el pedido, no baja el total';
    }
  }

  Future<void> _confirmAndRedeem(SellerLoyaltyReward reward) async {
    final order = _selected;
    if (order == null || _redeeming) return;
    final discount = reward.discountFor(shippingCost: order.shippingCost);
    final left = widget.currentPoints - reward.pointsCost;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Canjear "${reward.name}"?'),
        content: Text(
          '${widget.clientName} usa ${reward.pointsCost} pts y le quedan $left.\n\n'
          'Se aplica al pedido #${order.displayNumber}: '
          '${reward.type == SellerRewardType.gift ? 'regalo físico (el total no cambia).' : 'baja ${money(discount)} y el pedido queda en ${money(order.total - discount)}.'}\n\n'
          'Esta acción no se puede deshacer desde la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sí, canjear'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _redeeming = true);
    try {
      await ref
          .read(sellerClientsRepositoryProvider)
          .redeemReward(
            clientId: widget.clientId,
            orderId: order.id,
            rewardId: reward.id,
          );
      if (!mounted) return;
      context.showPremiumToast(
        'Premio aplicado al pedido #${order.displayNumber}.',
        type: PremiumToastType.success,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _redeeming = false);
      context.showPremiumToast(e.toString(), type: PremiumToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rewards = ref.watch(sellerLoyaltyRewardsProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.lineSoft,
              borderRadius: AppRadii.pillRadius,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Canjear premio',
                        style: AppTextStyles.h1.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.clientName} · ${widget.currentPoints} pts',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: _redeeming
                      ? null
                      : () => Navigator.of(context).pop(false),
                  icon: const Icon(Symbols.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _StepTitle(number: 1, text: '¿En qué pedido se aplica?'),
                const SizedBox(height: 8),
                _buildOrders(),
                const SizedBox(height: 18),
                _StepTitle(number: 2, text: 'Elige el premio'),
                const SizedBox(height: 8),
                rewards.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => _Notice(
                    icon: Symbols.error,
                    text: e.toString(),
                    action: TextButton(
                      onPressed: () =>
                          ref.invalidate(sellerLoyaltyRewardsProvider),
                      child: const Text('Reintentar'),
                    ),
                  ),
                  data: (list) => list.isEmpty
                      ? const _Notice(
                          icon: Symbols.redeem,
                          text:
                              'Esta tienda aún no tiene premios activos. '
                              'Créalos en el panel web para poder canjear.',
                        )
                      : Column(
                          children: [
                            for (final reward in list) ...[
                              _RewardTile(
                                reward: reward,
                                effect: _effectLabel(reward),
                                blockedReason: _blockedReason(reward),
                                busy: _redeeming,
                                onTap: () => _confirmAndRedeem(reward),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrders() {
    if (_ordersError != null) {
      return _Notice(
        icon: Symbols.error,
        text: _ordersError!,
        action: TextButton(
          onPressed: () {
            setState(() => _ordersError = null);
            _loadOrders();
          },
          child: const Text('Reintentar'),
        ),
      );
    }
    final orders = _orders;
    if (orders == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (orders.isEmpty) {
      return const _Notice(
        icon: Symbols.receipt_long,
        text:
            'Esta clienta no tiene pedidos abiertos. El premio se aplica como '
            'descuento a un pedido: crea uno primero.',
      );
    }
    return Column(
      children: [
        for (final order in orders) ...[
          _OrderChoice(
            order: order,
            selected: _selected?.id == order.id,
            onTap: _redeeming ? null : () => setState(() => _selected = order),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: AppColors.neniDeep,
          child: Text(
            '$number',
            style: AppTextStyles.chip.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderChoice extends StatelessWidget {
  const _OrderChoice({
    required this.order,
    required this.selected,
    required this.onTap,
  });

  final SellerOrder order;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.softRadius,
      child: InkWell(
        borderRadius: AppRadii.softRadius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: AppRadii.softRadius,
            border: Border.all(
              color: selected ? AppColors.neniDeep : AppColors.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Symbols.radio_button_checked
                    : Symbols.radio_button_unchecked,
                color: selected ? AppColors.neniDeep : AppColors.ink3,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedido #${order.displayNumber}',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${order.itemsCount} '
                      '${order.itemsCount == 1 ? 'artículo' : 'artículos'} · '
                      'Envío ${money(order.shippingCost)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                money(order.total),
                style: AppTextStyles.h2.copyWith(fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.reward,
    required this.effect,
    required this.blockedReason,
    required this.busy,
    required this.onTap,
  });

  final SellerLoyaltyReward reward;
  final String effect;
  final String? blockedReason;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = blockedReason == null && !busy;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        child: InkWell(
          borderRadius: AppRadii.softRadius,
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: AppRadii.softRadius,
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Text(
                  (reward.icon ?? '').isEmpty ? '🎁' : reward.icon!,
                  style: const TextStyle(fontSize: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reward.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        effect,
                        style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                      ),
                      if (blockedReason != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            blockedReason!,
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: 11.5,
                              color: AppColors.liveRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E6),
                    borderRadius: AppRadii.pillRadius,
                  ),
                  child: Text(
                    '${reward.pointsCost} pts',
                    style: AppTextStyles.chip.copyWith(
                      color: const Color(0xFF8A5A0E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.ink3),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                ),
                ?action,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
