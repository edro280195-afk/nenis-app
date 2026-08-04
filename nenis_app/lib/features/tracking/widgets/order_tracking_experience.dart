import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../data/tracking_models.dart';
import 'status_journey_card.dart';
import 'delivery_celebration.dart';
import 'rating_experience.dart';
import 'order_tools_section.dart';

/// Orquestador principal de la experiencia de seguimiento de pedidos (Nenis V3).
///
/// Este widget maneja:
/// 1. La conmutación entre los modos de visualización (por ahora `statusJourney` de manera predeterminada).
/// 2. La detección de la transición a `delivered` para lanzar la celebración.
/// 3. La presentación del modal de calificación interactivo.
class OrderTrackingExperience extends StatefulWidget {
  const OrderTrackingExperience({
    super.key,
    required this.order,
    required this.accessToken,
    required this.onRefresh,
    required this.onRatingSubmitted,
  });

  final OrderTracking order;
  final String accessToken;
  final Future<void> Function() onRefresh;
  final ValueChanged<OrderRating> onRatingSubmitted;

  @override
  State<OrderTrackingExperience> createState() =>
      _OrderTrackingExperienceState();
}

class _OrderTrackingExperienceState extends State<OrderTrackingExperience> {
  // Keys para calcular posiciones globales
  final GlobalKey _destinationKey = GlobalKey();
  final List<GlobalKey> _starKeys = List.generate(5, (_) => GlobalKey());
  final GlobalKey<DeliveryCelebrationState> _celebrationKey =
      GlobalKey<DeliveryCelebrationState>();

  // Control del flujo de celebración y calificación
  bool _hasCelebrated = false;
  bool _showRatingSheet = false;

  @override
  void initState() {
    super.initState();
    // Si ya está entregado cuando entramos a la pantalla, no repetimos la animación de celebración inicial.
    // Opcionalmente podemos forzarla si queremos deleitar, pero para practicidad marcamos según el rating previo.
    if (widget.order.status == TrackingStatus.delivered) {
      _hasCelebrated = true;
      if (widget.order.rating == null) {
        _showRatingSheet = true;
      }
    }
  }

  @override
  void didUpdateWidget(OrderTrackingExperience oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si el estado cambia a delivered y no hemos celebrado, disparamos la secuencia.
    if (widget.order.status == TrackingStatus.delivered &&
        !oldWidget.order.status.isTerminal &&
        !_hasCelebrated) {
      _triggerCelebration();
    }
  }

  void _triggerCelebration() {
    _hasCelebrated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _celebrationKey.currentState?.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Stack(
      children: [
        // ── Celebración (Confeti y Flor Overlay) ──
        DeliveryCelebration(
          key: _celebrationKey,
          destinationKey: _destinationKey,
          starKeys: _starKeys,
          onCelebrationEnd: () {
            // Cuando la flor termina de florecer, abrimos el rating sheet
            if (order.rating == null) {
              setState(() => _showRatingSheet = true);
            }
          },
          child: Positioned.fill(
            child: Column(
              children: [
                // Top header con branding de la tienda
                _TopBrandingHeader(order: order),

                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.neniDeep,
                    onRefresh: widget.onRefresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Tarjeta de progresión de entrega
                          StatusJourneyCard(
                            order: order,
                            destinationKey: _destinationKey,
                          ),
                          const SizedBox(height: 20),

                          // Timeline horizontal de 4 pasos
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A3A2233),
                                  offset: Offset(0, 4),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: OrderTimeline(status: order.status),
                          ),
                          const SizedBox(height: 20),

                          // Dirección de entrega
                          if (order.clientAddress != null) ...[
                            _InfoCard(
                              title: 'Dirección de entrega',
                              icon: Icons.location_on_outlined,
                              content: Text(
                                order.clientAddress!,
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13.5,
                                  color: Color(0xFF3A2233),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          OrderDetailOverviewCard(order: order),

                          // ── Herramientas de la clienta (Fase E) ──
                          // Confirmar, instrucciones, repartidor (chat/llamada),
                          // RegiPuntos, pago (tarjeta en revisión) y evidencia.
                          const SizedBox(height: 20),
                          OrderToolsSection(
                            order: order,
                            accessToken: widget.accessToken,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Scrim y Dialog de Calificación
        if (_showRatingSheet)
          Positioned.fill(
            child: RatingExperience(
              accessToken: widget.accessToken,
              existingRating: order.rating,
              starKeys: _starKeys,
              onDismiss: () {
                _celebrationKey.currentState?.removeFlower();
                setState(() => _showRatingSheet = false);
              },
              onSubmitted: (newRating) {
                _celebrationKey.currentState?.removeFlower();
                setState(() => _showRatingSheet = false);
                widget.onRatingSubmitted(newRating);
              },
            ),
          ),
      ],
    );
  }
}

class _TopBrandingHeader extends StatelessWidget {
  const _TopBrandingHeader({required this.order});
  final OrderTracking order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF5EEF2), width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.adaptive.arrow_back,
                color: const Color(0xFF3A2233),
              ),
              onPressed: () {
                Navigator.of(context).maybePop();
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    order.businessName ?? 'Seguimiento del pedido',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF3A2233),
                    ),
                  ),
                  const Text(
                    'Nenis App',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neniDeep,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _OrderDetailTab { summary, products, payment }

class OrderDetailOverviewCard extends StatefulWidget {
  const OrderDetailOverviewCard({super.key, required this.order});

  final OrderTracking order;

  @override
  State<OrderDetailOverviewCard> createState() =>
      _OrderDetailOverviewCardState();
}

class _OrderDetailOverviewCardState extends State<OrderDetailOverviewCard> {
  _OrderDetailTab _tab = _OrderDetailTab.summary;

  static final NumberFormat _money = NumberFormat.currency(
    locale: 'es_MX',
    symbol: r'$',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final hasPendingBalance = order.balanceDue > 0.01;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF5EEF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A3A2233),
            offset: Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.neniDeep,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderId == null
                          ? 'Detalle del pedido'
                          : 'Pedido #${order.orderId}',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3A2233),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${order.totalPieces} piezas · ${_orderTypeLabel(order.orderType)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8A6F82),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(status: order.status),
            ],
          ),
          const SizedBox(height: 16),
          _OrderDetailTabs(
            selected: _tab,
            onChanged: (tab) => setState(() => _tab = tab),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(
              key: ValueKey(_tab),
              child: switch (_tab) {
                _OrderDetailTab.summary => _SummaryTab(
                  order: order,
                  money: _money,
                  hasPendingBalance: hasPendingBalance,
                ),
                _OrderDetailTab.products => _ProductsTab(
                  order: order,
                  money: _money,
                ),
                _OrderDetailTab.payment => _TicketTotals(
                  order: order,
                  money: _money,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }

  String _orderTypeLabel(String? value) {
    switch (value) {
      case 'PickUp':
        return 'recoger en tienda';
      case 'POS_Tienda':
        return 'compra en tienda';
      case 'Delivery':
      default:
        return 'entrega a domicilio';
    }
  }
}

class _OrderDetailTabs extends StatelessWidget {
  const _OrderDetailTabs({required this.selected, required this.onChanged});

  final _OrderDetailTab selected;
  final ValueChanged<_OrderDetailTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF4F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'Resumen',
            icon: Icons.dashboard_outlined,
            selected: selected == _OrderDetailTab.summary,
            onTap: () => onChanged(_OrderDetailTab.summary),
          ),
          _TabButton(
            label: 'Productos',
            icon: Icons.receipt_long_outlined,
            selected: selected == _OrderDetailTab.products,
            onTap: () => onChanged(_OrderDetailTab.products),
          ),
          _TabButton(
            label: 'Cobro',
            icon: Icons.payments_outlined,
            selected: selected == _OrderDetailTab.payment,
            onTap: () => onChanged(_OrderDetailTab.payment),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x0F3A2233),
                        offset: Offset(0, 3),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: selected
                        ? AppColors.neniDeep
                        : const Color(0xFF8A6F82),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? AppColors.neniDeep
                          : const Color(0xFF8A6F82),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({
    required this.order,
    required this.money,
    required this.hasPendingBalance,
  });

  final OrderTracking order;
  final NumberFormat money;
  final bool hasPendingBalance;

  @override
  Widget build(BuildContext context) {
    final previewItems = order.items.take(2).toList(growable: false);
    final hiddenItems = order.items.length - previewItems.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _AmountTile(
                label: 'Total',
                value: money.format(order.total),
                background: const Color(0xFFFFF5F9),
                valueColor: AppColors.neniDeep,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AmountTile(
                label: hasPendingBalance ? 'Saldo' : 'Pagado',
                value: money.format(order.balanceDue),
                background: hasPendingBalance
                    ? const Color(0xFFFFE8EF)
                    : AppColors.statusDeliveredBg,
                valueColor: hasPendingBalance
                    ? AppColors.neniDeep
                    : AppColors.statusDeliveredFg,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (previewItems.isEmpty)
          const _EmptyItemsMessage()
        else
          Column(
            children: [
              for (final item in previewItems)
                _CompactOrderItem(
                  key: ValueKey(item.id),
                  item: item,
                  money: money,
                ),
              if (hiddenItems > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+$hiddenItems artículo${hiddenItems == 1 ? '' : 's'} más en Productos',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A6F82),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _ProductsTab extends StatelessWidget {
  const _ProductsTab({required this.order, required this.money});

  final OrderTracking order;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    if (order.items.isEmpty) return const _EmptyItemsMessage();

    if (order.items.length <= 4) {
      return Column(
        children: [
          for (final item in order.items)
            _CompactOrderItem(key: ValueKey(item.id), item: item, money: money),
        ],
      );
    }

    return SizedBox(
      height: 312,
      child: Scrollbar(
        thumbVisibility: true,
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: order.items.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 14, color: Color(0xFFF5EEF2)),
          itemBuilder: (context, index) => _CompactOrderItem(
            key: ValueKey(order.items[index].id),
            item: order.items[index],
            money: money,
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final TrackingStatus status;

  @override
  Widget build(BuildContext context) {
    final isDelivered = status == TrackingStatus.delivered;
    final isNegative =
        status == TrackingStatus.notDelivered ||
        status == TrackingStatus.canceled;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDelivered
            ? AppColors.statusDeliveredBg
            : isNegative
            ? const Color(0xFFFFE8EF)
            : const Color(0xFFFFF0F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label(status),
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: isDelivered
              ? AppColors.statusDeliveredFg
              : isNegative
              ? AppColors.neniDeep
              : AppColors.statusPendingFg,
        ),
      ),
    );
  }

  String _label(TrackingStatus status) => switch (status) {
    TrackingStatus.pending => 'Pendiente',
    TrackingStatus.confirmed => 'Confirmado',
    TrackingStatus.shipped => 'Empacado',
    TrackingStatus.inRoute || TrackingStatus.inTransit => 'En ruta',
    TrackingStatus.delivered => 'Entregado',
    TrackingStatus.notDelivered => 'No entregado',
    TrackingStatus.canceled => 'Cancelado',
    TrackingStatus.postponed => 'Pospuesto',
    TrackingStatus.unknown => 'En proceso',
  };
}

class _AmountTile extends StatelessWidget {
  const _AmountTile({
    required this.label,
    required this.value,
    required this.background,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color background;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A6F82),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactOrderItem extends StatelessWidget {
  const _CompactOrderItem({super.key, required this.item, required this.money});

  final OrderItem item;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 34),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF4F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${item.quantity}x',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColors.neniDeep,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.productName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3A2233),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            money.format(item.lineTotal),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF3A2233),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyItemsMessage extends StatelessWidget {
  const _EmptyItemsMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF4F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'No hay productos registrados en este pedido.',
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8A6F82),
        ),
      ),
    );
  }
}

class _TicketTotals extends StatelessWidget {
  const _TicketTotals({required this.order, required this.money});

  final OrderTracking order;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF5EEF2)),
      ),
      child: Column(
        children: [
          _TicketTotalRow(
            label: 'Subtotal',
            value: money.format(order.subtotal),
          ),
          if (order.shippingCost > 0)
            _TicketTotalRow(
              label: 'Envío',
              value: money.format(order.shippingCost),
            ),
          if (order.amountPaid > 0)
            _TicketTotalRow(
              label: 'Pagado',
              value: money.format(order.amountPaid),
              valueColor: AppColors.statusDeliveredFg,
            ),
          const Divider(height: 22, color: Color(0xFFECDFE6)),
          _TicketTotalRow(
            label: 'Total',
            value: money.format(order.total),
            bold: true,
          ),
          if (order.balanceDue > 0.01)
            _TicketTotalRow(
              label: 'Saldo pendiente',
              value: money.format(order.balanceDue),
              valueColor: AppColors.neniDeep,
              bold: true,
            ),
        ],
      ),
    );
  }
}

class _TicketTotalRow extends StatelessWidget {
  const _TicketTotalRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              color: bold ? const Color(0xFF3A2233) : const Color(0xFF8A6F82),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: bold ? 16 : 13,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              color: valueColor ?? const Color(0xFF3A2233),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.icon,
    required this.content,
  });

  final String title;
  final IconData icon;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A3A2233),
            offset: Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF8A6F82)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8A6F82),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }
}
