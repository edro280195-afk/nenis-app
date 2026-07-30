import 'package:flutter/material.dart';
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
  State<OrderTrackingExperience> createState() => _OrderTrackingExperienceState();
}

class _OrderTrackingExperienceState extends State<OrderTrackingExperience> {
  // Keys para calcular posiciones globales
  final GlobalKey _destinationKey = GlobalKey();
  final List<GlobalKey> _starKeys = List.generate(5, (_) => GlobalKey());
  final GlobalKey<DeliveryCelebrationState> _celebrationKey = GlobalKey<DeliveryCelebrationState>();

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
    if (widget.order.status == TrackingStatus.delivered && !oldWidget.order.status.isTerminal && !_hasCelebrated) {
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

                          // Artículos del pedido
                          _InfoCard(
                            title: 'Detalle del pedido',
                            icon: Icons.shopping_bag_outlined,
                            content: Column(
                              children: [
                                ...order.items.map((item) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFDF4F7),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${item.quantity}x',
                                              style: const TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.neniDeep,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              item.productName,
                                              style: const TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 13,
                                                color: Color(0xFF3A2233),
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '\$${item.lineTotal.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontFamily: 'Outfit',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF3A2233),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                const Divider(color: Color(0xFFECDFE6), height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total del pedido',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF8A6F82),
                                      ),
                                    ),
                                    Text(
                                      '\$${order.total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.neniDeep,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

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
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF5EEF2),
            width: 1,
          ),
        ),
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
