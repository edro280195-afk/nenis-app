import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../data/tracking_models.dart';
import 'nenis_thread_widget.dart';

/// Hero card del modo `statusJourney`.
///
/// Muestra:
/// - Chip "live" con punto pulsante
/// - Eyebrow (nombre del negocio o repartidor)
/// - Título animado según el status
/// - Hilo Nenis con progreso
/// - Sección ETA + paradas
class StatusJourneyCard extends StatefulWidget {
  const StatusJourneyCard({
    super.key,
    required this.order,
    this.destinationKey,
  });

  final OrderTracking order;

  /// GlobalKey colocado sobre el pin de destino (para la flor de celebración).
  final GlobalKey? destinationKey;

  @override
  State<StatusJourneyCard> createState() => _StatusJourneyCardState();
}

class _StatusJourneyCardState extends State<StatusJourneyCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _titleCtrl;
  late Animation<double> _titleFade;
  TrackingStatus? _prevStatus;

  @override
  void initState() {
    super.initState();
    _titleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..value = 1.0;
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _titleCtrl, curve: Curves.easeOut),
    );
    _prevStatus = widget.order.status;
  }

  @override
  void didUpdateWidget(StatusJourneyCard old) {
    super.didUpdateWidget(old);
    if (old.order.status != widget.order.status) {
      _titleCtrl.reverse().then((_) {
        if (mounted) {
          setState(() => _prevStatus = widget.order.status);
          _titleCtrl.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final status = order.status;
    final isDelivered = status == TrackingStatus.delivered;
    final isInRoute = status == TrackingStatus.inRoute ||
        status == TrackingStatus.inTransit ||
        status == TrackingStatus.shipped;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDelivered
              ? [const Color(0xFFFDF0F5), const Color(0xFFFFFCFD)]
              : [const Color(0xFFFFF5F9), const Color(0xFFFFFCFD)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14E84E83),
            offset: Offset(0, 8),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Blobs ambientales decorativos
          _AmbientBlob(
            color: isDelivered
                ? const Color(0x18E95D92)
                : const Color(0x0FE95D92),
            size: 140,
            top: -30,
            right: -30,
          ),
          _AmbientBlob(
            color: const Color(0x0AF3B341),
            size: 90,
            bottom: 20,
            left: -20,
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Eyebrow ──
                _EyebrowRow(order: order, isInRoute: isInRoute),
                const SizedBox(height: 14),

                // ── Hilo Nenis ──
                NenisThreadWidget(
                  progress: status.threadProgress,
                  height: 110,
                  endKey: widget.destinationKey,
                ),
                const SizedBox(height: 14),

                // ── Título animado ──
                FadeTransition(
                  opacity: _titleFade,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (_prevStatus ?? status).title,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3A2233),
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (_prevStatus ?? status).subtitle,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          color: Color(0xFF8A6F82),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── ETA Section ──
                _EtaSection(order: order),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EyebrowRow extends StatelessWidget {
  const _EyebrowRow({required this.order, required this.isInRoute});
  final OrderTracking order;
  final bool isInRoute;

  @override
  Widget build(BuildContext context) {
    final eyebrow = isInRoute && order.courierName != null
        ? '${order.courierName} va en camino'
        : order.businessName ?? 'Nenis';

    return Row(
      children: [
        // Live dot pulsante
        _LiveDot(pulse: isInRoute),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            eyebrow,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE84E83),
              letterSpacing: 0.3,
            ),
          ),
        ),
        // Logo del negocio (si existe)
        if (order.businessLogoUrl != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                order.businessLogoUrl!,
                width: 28,
                height: 28,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.pulse});
  final bool pulse;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.pulse) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_LiveDot old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.pulse && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.lerp(
            const Color(0xFFE84E83),
            const Color(0xFFFB6F9C),
            _ctrl.value,
          ),
          boxShadow: widget.pulse
              ? [
                  BoxShadow(
                    color: const Color(0xFFE84E83)
                        .withValues(alpha: 0.4 * _ctrl.value),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _EtaSection extends StatelessWidget {
  const _EtaSection({required this.order});
  final OrderTracking order;

  @override
  Widget build(BuildContext context) {
    final isDelivered = order.status == TrackingStatus.delivered;
    final isNegative = order.status == TrackingStatus.notDelivered ||
        order.status == TrackingStatus.canceled;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDelivered
            ? AppColors.statusDeliveredBg
            : isNegative
                ? const Color(0xFFFFE8EF)
                : const Color(0xFFFFF0F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isDelivered
                ? Icons.celebration_rounded
                : isNegative
                    ? Icons.error_outline_rounded
                    : Icons.access_time_rounded,
            size: 18,
            color: isDelivered
                ? AppColors.statusDeliveredFg
                : isNegative
                    ? AppColors.neniDeep
                    : AppColors.statusPendingFg,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.etaLabel,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDelivered
                        ? AppColors.statusDeliveredFg
                        : isNegative
                            ? AppColors.neniDeep
                            : const Color(0xFF3A2233),
                  ),
                ),
                if (order.deliveriesAhead != null &&
                    !isDelivered &&
                    !isNegative)
                  Text(
                    order.driverHint,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11.5,
                      color: Color(0xFF8A6F82),
                    ),
                  ),
              ],
            ),
          ),
          if (order.deliveriesAhead != null &&
              order.deliveriesAhead! > 0 &&
              !isDelivered)
            _StopsBadge(count: order.deliveriesAhead!),
        ],
      ),
    );
  }
}

class _StopsBadge extends StatelessWidget {
  const _StopsBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.neni.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count parada${count != 1 ? 's' : ''}',
        style: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.neniDeep,
        ),
      ),
    );
  }
}

class _AmbientBlob extends StatelessWidget {
  const _AmbientBlob({
    required this.color,
    required this.size,
    this.top,
    this.bottom,
    this.left,
    this.right,
  });
  final Color color;
  final double size;
  final double? top, bottom, left, right;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Timeline horizontal de 4 pasos para el modo statusJourney.
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({super.key, required this.status});
  final TrackingStatus status;

  static const _steps = [
    (label: 'Confirmado', icon: Icons.check_circle_outline_rounded),
    (label: 'Empacando', icon: Icons.inventory_2_outlined),
    (label: 'En ruta', icon: Icons.local_shipping_outlined),
    (label: 'Entregado', icon: Icons.celebration_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final step = status.timelineStep;
    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final leftDone = (i ~/ 2) < step - 1;
          return Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: leftDone ? AppColors.neni : const Color(0xFFECDFE6),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          );
        }
        final idx = i ~/ 2;
        final isDone = idx < step - 1;
        final isActive = idx == step - 1;
        return _TimelineStep(
          label: _steps[idx].label,
          icon: _steps[idx].icon,
          isDone: isDone,
          isActive: isActive,
        );
      }),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.icon,
    required this.isDone,
    required this.isActive,
  });
  final String label;
  final IconData icon;
  final bool isDone;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final Color fg = isDone
        ? AppColors.neniDeep
        : isActive
            ? AppColors.neni
            : const Color(0xFFB6A4B1);

    final Color bg = isDone
        ? const Color(0xFFFFE8F0)
        : isActive
            ? const Color(0xFFFFF0F5)
            : const Color(0xFFF5EEF2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: isActive
                ? Border.all(color: AppColors.neni, width: 1.5)
                : null,
            boxShadow: isActive
                ? const [
                    BoxShadow(
                      color: Color(0x20E84E83),
                      offset: Offset(0, 3),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isDone ? Icons.check_rounded : icon,
            size: 17,
            color: fg,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: fg,
          ),
        ),
      ],
    );
  }
}
