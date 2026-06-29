import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/pill_button.dart';
import '../data/tracking_controller.dart';
import '../data/tracking_models.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({
    super.key,
    required this.orderId,
    this.accessToken,
  });

  final String orderId;
  final String? accessToken;

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  @override
  void initState() {
    super.initState();
    // Setea el token en el provider para que el controller se construya.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trackingTokenProvider.notifier).set(widget.accessToken ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.accessToken ?? '';
    final feed = ref.watch(trackingControllerProvider);

    if (token.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: _NoToken(onBack: () => context.go('/orders')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: feed.when(
        loading: () => const _LoadingTracking(),
        error: (e, _) => _TrackingError(
          message: e.toString(),
          onBack: () {
            ref.invalidate(trackingControllerProvider);
            context.go('/orders');
          },
        ),
        data: (order) {
          if (order == null) {
            return const _LoadingTracking();
          }
          return _TrackingView(
            order: order,
            orderId: widget.orderId,
            accessToken: token,
          );
        },
      ),
    );
  }
}

class _LoadingTracking extends StatelessWidget {
  const _LoadingTracking();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.neni),
    );
  }
}

class _NoToken extends StatelessWidget {
  const _NoToken({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    return _TrackingError(
      message: 'Este enlace ya no es válido.',
      onBack: onBack,
    );
  }
}

class _TrackingError extends StatelessWidget {
  const _TrackingError({required this.message, required this.onBack});
  final String message;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Symbols.link_off, size: 46, color: AppColors.ink3),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center, style: AppTextStyles.h2),
          const SizedBox(height: 22),
          PillButton(
            label: 'Volver a mis pedidos',
            icon: Symbols.receipt_long,
            onPressed: onBack,
          ),
        ],
      ),
    );
  }
}

class _TrackingView extends ConsumerWidget {
  const _TrackingView({
    required this.order,
    required this.orderId,
    required this.accessToken,
  });
  final OrderTracking order;
  final String orderId;
  final String accessToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              SizedBox(
                height: 320,
                child: _MapPlaceholder(
                  status: order.status,
                  hasDriver: order.driverLocation != null ||
                      order.deliveriesAhead != null,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _MapTopBar(orderId: orderId, status: order.status),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.68,
          minChildSize: 0.48,
          maxChildSize: 0.93,
          builder: (context, scrollController) {
            return _TrackingSheet(
              order: order,
              scrollController: scrollController,
              onRefresh: () async {
                ref.invalidate(trackingControllerProvider);
              },
            );
          },
        ),
      ],
    );
  }
}

class _MapTopBar extends StatelessWidget {
  const _MapTopBar({required this.orderId, required this.status});
  final String orderId;
  final TrackingStatus status;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: Row(
          children: [
            _RoundIconButton(
              icon: Symbols.arrow_back,
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/orders'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: AppShadows.small,
                ),
                child: Row(
                  children: [
                    const Icon(Symbols.receipt_long,
                        size: 16, color: AppColors.ink),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Pedido #$orderId',
                              style: AppTextStyles.body.copyWith(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                          Text('Rastreo en vivo',
                              style: AppTextStyles.subtitle
                                  .copyWith(fontSize: 11)),
                        ],
                      ),
                    ),
                    _StatusDot(status: status),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final TrackingStatus status;
  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case TrackingStatus.delivered:
        color = AppColors.statusDeliveredFg;
        break;
      case TrackingStatus.shipped:
      case TrackingStatus.inRoute:
      case TrackingStatus.inTransit:
        color = AppColors.statusRouteFg;
        break;
      case TrackingStatus.notDelivered:
      case TrackingStatus.canceled:
        color = AppColors.neniDeep;
        break;
      default:
        color = AppColors.statusPendingFg;
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: AppColors.ink),
        ),
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.status, required this.hasDriver});
  final TrackingStatus status;
  final bool hasDriver;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFFE7EDE6)),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _StreetsPainter(hasDriver: hasDriver)),
          ),
          if (hasDriver &&
              (status == TrackingStatus.shipped ||
                  status == TrackingStatus.inRoute ||
                  status == TrackingStatus.inTransit))
            const _StorePin(left: 60, top: 70),
          if (hasDriver &&
              (status == TrackingStatus.shipped ||
                  status == TrackingStatus.inRoute ||
                  status == TrackingStatus.inTransit)) ...[
            const _DriverPin(left: 180, top: 160),
            const _HomePin(right: 60, bottom: 60),
          ] else if (status == TrackingStatus.delivered)
            const Center(
              child: _CenterMessage(
                icon: Symbols.celebration,
                iconColor: AppColors.statusDeliveredFg,
                iconBg: Color(0xFFD9F3E6),
                title: '¡Entregado!',
                subtitle: 'Tu pedido llegó con éxito',
              ),
            )
          else if (status == TrackingStatus.notDelivered)
            const Center(
              child: _CenterMessage(
                icon: Symbols.error,
                iconColor: AppColors.neniDeep,
                iconBg: Color(0xFFFFE1EC),
                title: 'No se pudo entregar',
                subtitle: 'Tu tienda fue notificada',
              ),
            )
          else if (status == TrackingStatus.canceled)
            const Center(
              child: _CenterMessage(
                icon: Symbols.block,
                iconColor: AppColors.ink2,
                iconBg: Color(0xFFEFE5EE),
                title: 'Pedido cancelado',
                subtitle: 'Lo sentimos, esta vez no se completó',
              ),
            )
          else
            const Center(
              child: _CenterMessage(
                icon: Symbols.inventory_2,
                iconColor: AppColors.statusPendingFg,
                iconBg: Color(0xFFFCECD2),
                title: 'En preparación',
                subtitle: 'Te avisaremos cuando salga a entrega',
              ),
            ),
        ],
      ),
    );
  }
}

class _CenterMessage extends StatelessWidget {
  const _CenterMessage({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(22),
              boxShadow: AppShadows.small,
            ),
            child: Icon(icon, color: iconColor, size: 32),
          ),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: AppTextStyles.h2.copyWith(fontSize: 17)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle.copyWith(fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _StreetsPainter extends CustomPainter {
  _StreetsPainter({required this.hasDriver});
  final bool hasDriver;
  @override
  void paint(Canvas canvas, Size size) {
    final parkPaint = Paint()..color = const Color(0xFFD8ECD6);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.55, -20, 90, 70), parkPaint);
    canvas.drawRect(
        Rect.fromLTWH(-20, size.height * 0.55, 100, 90), parkPaint);

    final waterPaint = Paint()..color = const Color(0xFFD4E7F3);
    canvas.drawRect(
        Rect.fromLTWH(size.width - 70, 0, 70, 80), waterPaint);

    final streetPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round;
    final thinStreetPaint = Paint()
      ..color = const Color(0xFFE2EAE0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final minorPaint = Paint()
      ..color = const Color(0xFFEDF1EC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Calles principales (anchas)
    canvas.drawLine(Offset(0, size.height * 0.32),
        Offset(size.width, size.height * 0.32), streetPaint);
    canvas.drawLine(Offset(size.width * 0.45, 0),
        Offset(size.width * 0.45, size.height), streetPaint);

    // Calles secundarias
    canvas.drawLine(Offset(0, size.height * 0.7),
        Offset(size.width, size.height * 0.7), thinStreetPaint);
    canvas.drawLine(Offset(size.width * 0.18, 0),
        Offset(size.width * 0.18, size.height), thinStreetPaint);
    canvas.drawLine(Offset(size.width * 0.78, 0),
        Offset(size.width * 0.78, size.height), thinStreetPaint);

    // Pequeñas
    canvas.drawLine(Offset(0, size.height * 0.15),
        Offset(size.width, size.height * 0.15), minorPaint);
    canvas.drawLine(Offset(0, size.height * 0.5),
        Offset(size.width, size.height * 0.5), minorPaint);
    canvas.drawLine(Offset(size.width * 0.32, 0),
        Offset(size.width * 0.32, size.height), minorPaint);
    canvas.drawLine(Offset(size.width * 0.62, 0),
        Offset(size.width * 0.62, size.height), minorPaint);
    canvas.drawLine(Offset(size.width * 0.92, 0),
        Offset(size.width * 0.92, size.height), minorPaint);

    if (hasDriver) {
      // Ruta planeada (punteada) tienda → casa
      final routeStart = const Offset(60 + 22, 70 + 36);
      final routeEnd = Offset(size.width - 60 - 22, size.height - 60 - 36);
      final midControl = Offset(
        (routeStart.dx + routeEnd.dx) / 2,
        math.min(routeStart.dy, routeEnd.dy) - 30,
      );
      final path = Path()
        ..moveTo(routeStart.dx, routeStart.dy)
        ..quadraticBezierTo(midControl.dx, midControl.dy,
            routeEnd.dx, routeEnd.dy);

      final dashedPaint = Paint()
        ..color = const Color(0xFFFFB9D4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      _drawDashedPath(canvas, path, dashedPaint, 14);

      // Ruta recorrida (sólida) tienda → driver
      final driverCenter = const Offset(180 + 22, 160 + 22);
      final traveled = Path()
        ..moveTo(routeStart.dx, routeStart.dy)
        ..lineTo(driverCenter.dx, driverCenter.dy);
      final solidPaint = Paint()
        ..color = AppColors.neni
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(traveled, solidPaint);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, double dashGap) {
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = math.min(distance + dashGap / 2, metric.length);
        canvas.drawPath(
            metric.extractPath(distance, next), paint..style = PaintingStyle.stroke);
        distance = next + dashGap / 2;
      }
    }
  }

  @override
  bool shouldRepaint(_StreetsPainter oldDelegate) =>
      oldDelegate.hasDriver != hasDriver;
}

class _StorePin extends StatelessWidget {
  const _StorePin({required this.left, required this.top});
  final double left;
  final double top;
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF3D8B), Color(0xFFFF0072)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppShadows.small,
            ),
            child: const Icon(Symbols.storefront,
                color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }
}

class _DriverPin extends StatelessWidget {
  const _DriverPin({required this.left, required this.top});
  final double left;
  final double top;
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.neni.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.neni, width: 3),
            boxShadow: AppShadows.small,
          ),
          child: const Icon(Symbols.local_shipping,
              color: AppColors.neni, size: 20),
        ),
      ),
    );
  }
}

class _HomePin extends StatelessWidget {
  const _HomePin({required this.right, required this.bottom});
  final double right;
  final double bottom;
  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: right,
      bottom: bottom,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.ink,
          shape: BoxShape.circle,
          boxShadow: AppShadows.small,
        ),
        child: const Icon(Symbols.home, color: Colors.white, size: 22),
      ),
    );
  }
}

class _TrackingSheet extends StatelessWidget {
  const _TrackingSheet({
    required this.order,
    required this.scrollController,
    required this.onRefresh,
  });
  final OrderTracking order;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x401E0A12),
            offset: Offset(0, -14),
            blurRadius: 40,
            spreadRadius: -16,
          ),
        ],
      ),
      child: RefreshIndicator(
        color: AppColors.neniDeep,
        onRefresh: onRefresh,
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFECDFE6),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Header(order: order),
            const SizedBox(height: 18),
            if (order.driverLocation != null ||
                order.deliveriesAhead != null ||
                order.status == TrackingStatus.shipped ||
                order.status == TrackingStatus.inRoute ||
                order.status == TrackingStatus.inTransit)
              _DriverRow(order: order),
            if (order.driverLocation != null ||
                order.deliveriesAhead != null ||
                order.status == TrackingStatus.shipped ||
                order.status == TrackingStatus.inRoute ||
                order.status == TrackingStatus.inTransit)
              const SizedBox(height: 20),
            _Timeline(status: order.status),
            const SizedBox(height: 20),
            if (order.clientAddress != null) _AddressRow(order: order),
            if (order.clientAddress != null) const SizedBox(height: 18),
            _ItemsSection(items: order.items, total: order.total),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.order});
  final OrderTracking order;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.etaLabel,
                  style: AppTextStyles.h1.copyWith(fontSize: 21)),
              const SizedBox(height: 2),
              Text(order.status.subtitle,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12.5)),
            ],
          ),
        ),
        _StatusChip(status: order.status),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final TrackingStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, label, fg, bg) = _chip(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadii.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(label,
              style: AppTextStyles.chip
                  .copyWith(color: fg, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  (IconData, String, Color, Color) _chip(TrackingStatus s) {
    switch (s) {
      case TrackingStatus.pending:
      case TrackingStatus.confirmed:
        return (
          Symbols.schedule,
          'En preparación',
          AppColors.statusPendingFg,
          AppColors.statusPendingBg
        );
      case TrackingStatus.shipped:
      case TrackingStatus.inRoute:
      case TrackingStatus.inTransit:
        return (
          Symbols.local_shipping,
          'En ruta',
          AppColors.statusRouteFg,
          AppColors.statusRouteBg
        );
      case TrackingStatus.delivered:
        return (
          Symbols.check_circle,
          'Entregado',
          AppColors.statusDeliveredFg,
          AppColors.statusDeliveredBg
        );
      case TrackingStatus.notDelivered:
        return (
          Symbols.error,
          'No entregado',
          AppColors.neniDeep,
          const Color(0xFFFFE1EC)
        );
      case TrackingStatus.canceled:
        return (
          Symbols.block,
          'Cancelado',
          AppColors.ink2,
          const Color(0xFFEFE5EE)
        );
      case TrackingStatus.postponed:
        return (
          Symbols.schedule_send,
          'Pospuesto',
          AppColors.statusPendingFg,
          AppColors.statusPendingBg
        );
      case TrackingStatus.unknown:
        return (
          Symbols.help,
          'Buscando',
          AppColors.ink3,
          const Color(0xFFEFE5EE)
        );
    }
  }
}

class _DriverRow extends StatelessWidget {
  const _DriverRow({required this.order});
  final OrderTracking order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF3F6),
        borderRadius: AppRadii.softRadius,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFA98CF0), Color(0xFF8E6BE6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            alignment: Alignment.center,
            child: const Text('V',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                )),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vicente',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    )),
                const SizedBox(height: 1),
                Text(
                  'Tu repartidor · ${order.driverHint}',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          _ActionIconButton(icon: Symbols.chat_bubble),
          const SizedBox(width: 8),
          _ActionIconButton(icon: Symbols.call),
        ],
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.small,
      ),
      child: Icon(icon, size: 18, color: AppColors.neniDeep),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.status});
  final TrackingStatus status;

  @override
  Widget build(BuildContext context) {
    final current = status.timelineStep;
    final steps = <({String label, String subtitle, IconData icon})>[
      (
        label: 'Pedido confirmado',
        subtitle: 'Recibimos tu pedido',
        icon: Symbols.check
      ),
      (
        label: 'En preparación',
        subtitle: 'Tu tienda lo está empacando',
        icon: Symbols.inventory_2
      ),
      (
        label: 'En ruta',
        subtitle: 'Tu repartidor va hacia ti',
        icon: Symbols.local_shipping
      ),
      (
        label: 'Entregado',
        subtitle: '¡Listo! 💖',
        icon: Symbols.celebration
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _TimelineRow(
              index: i + 1,
              isFirst: i == 0,
              isLast: i == steps.length - 1,
              state: i + 1 < current
                  ? TimelineStepState.done
                  : i + 1 == current
                      ? TimelineStepState.active
                      : TimelineStepState.todo,
              label: steps[i].label,
              subtitle: steps[i].subtitle,
              icon: steps[i].icon,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.state,
    required this.label,
    required this.subtitle,
    required this.icon,
  });
  final int index;
  final bool isFirst;
  final bool isLast;
  final TimelineStepState state;
  final String label;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final dotColor = switch (state) {
      TimelineStepState.done => AppColors.statusDeliveredFg,
      TimelineStepState.active => AppColors.neni,
      TimelineStepState.todo => AppColors.surface,
    };
    final lineColor = switch (state) {
      TimelineStepState.done => AppColors.statusDeliveredFg,
      TimelineStepState.active => AppColors.neni.withValues(alpha: 0.4),
      TimelineStepState.todo => const Color(0xFFECD9E2),
    };
    final isActive = state == TimelineStepState.active;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Columna dot + línea
          SizedBox(
            width: 28,
            child: Column(
              children: [
                if (!isFirst)
                  Container(width: 2, height: 6, color: lineColor)
                else
                  const SizedBox(height: 6),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: state == TimelineStepState.todo
                        ? AppColors.surface
                        : dotColor,
                    shape: BoxShape.circle,
                    border: state == TimelineStepState.todo
                        ? Border.all(color: const Color(0xFFECD9E2), width: 2)
                        : null,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color:
                                  AppColors.neni.withValues(alpha: 0.35),
                              blurRadius: 12,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    state == TimelineStepState.done ? Symbols.check : icon,
                    size: state == TimelineStepState.todo ? 0 : 14,
                    color: state == TimelineStepState.todo
                        ? Colors.transparent
                        : (state == TimelineStepState.todo
                            ? AppColors.ink3
                            : Colors.white),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: lineColor),
                  )
                else
                  const SizedBox(height: 6),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isActive ? AppColors.neniDeep : AppColors.ink,
                      )),
                  const SizedBox(height: 1),
                  Text(subtitle,
                      style: AppTextStyles.subtitle
                          .copyWith(fontSize: 11.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.order});
  final OrderTracking order;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE1EC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Symbols.location_on,
                color: AppColors.neniDeep, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Entregar en',
                    style: AppTextStyles.subtitle.copyWith(
                        fontSize: 11.5, color: AppColors.ink3)),
                Text(order.clientAddress ?? '—',
                    style: AppTextStyles.body.copyWith(
                        fontSize: 13.5, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsSection extends StatelessWidget {
  const _ItemsSection({required this.items, required this.total});
  final List<OrderItem> items;
  final double total;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final money = NumberFormat.currency(
      locale: 'es_MX',
      symbol: r'$',
      decimalDigits: 0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text('Tu pedido',
              style: AppTextStyles.h2.copyWith(fontSize: 15)),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.softRadius,
            border: Border.all(color: AppColors.lineSoft),
          ),
          child: Column(
            children: [
              for (final it in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE1EC),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text('${it.quantity}×',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.neniDeep,
                            )),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(it.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body.copyWith(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500)),
                      ),
                      Text(money.format(it.lineTotal),
                          style: AppTextStyles.subtitle.copyWith(
                              fontSize: 13,
                              color: AppColors.ink2,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              const Divider(
                  height: 1, thickness: 1, color: AppColors.lineSoft),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Total',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          )),
                    ),
                    Text(money.format(total),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
