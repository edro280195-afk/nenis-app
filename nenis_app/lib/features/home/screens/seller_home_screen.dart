import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../orders/data/seller_orders_models.dart';
import '../../orders/data/seller_orders_repository.dart';
import '../../orders/screens/seller_orders_screen.dart' show GradientText;
import '../../orders/widgets/seller_status_chip.dart';

class SellerHomeScreen extends ConsumerWidget {
  const SellerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).value;
    final async = ref.watch(sellerDashboardProvider);

    final firstName = (session?.displayName ?? '').trim().split(' ').first;
    String businessName = 'Mi tienda';
    if (session != null && session.memberships.isNotEmpty) {
      final active = session.activeBusinessId;
      final m = session.memberships.firstWhere(
        (x) => x.businessId == active,
        orElse: () => session.memberships.first,
      );
      if (m.businessName.trim().isNotEmpty) businessName = m.businessName;
    }
    final logoInitial = businessName.trim().isEmpty
        ? 'N'
        : businessName.trim()[0].toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              RefreshIndicator(
                color: AppColors.neniDeep,
                onRefresh: () async {
                  ref.invalidate(sellerDashboardProvider);
                  await ref.read(sellerDashboardProvider.future);
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _AppBar(
                        businessName: businessName,
                        logoInitial: logoInitial,
                        onBell: () => context.push('/notifications'),
                      ),
                    ),
                    async.when(
                      loading: () => const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.neni,
                          ),
                        ),
                      ),
                      error: (e, _) => SliverFillRemaining(
                        hasScrollBody: false,
                        child: _ErrorState(
                          message: e.toString(),
                          onRetry: () =>
                              ref.invalidate(sellerDashboardProvider),
                        ),
                      ),
                      data: (d) => SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _Greeting(
                              firstName: firstName,
                              hasActivePeriod: d.activePeriod != null,
                            ),
                            const SizedBox(height: 16),
                            if (d.activePeriod != null) ...[
                              _CorteCard(period: d.activePeriod!),
                              const SizedBox(height: 14),
                            ],
                            _KpiGrid(dashboard: d),
                            const SizedBox(height: 16),
                            _SalesChartCard(data: d.salesByMonth),
                            const SizedBox(height: 20),
                            _RecentActivity(orders: d.recentOrders),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 20,
                bottom: 16,
                child: _Fab(onTap: () => context.push('/orders/new')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({
    required this.businessName,
    required this.logoInitial,
    required this.onBell,
  });
  final String businessName;
  final String logoInitial;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.neni, AppColors.neniDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppShadows.brandSmall(AppColors.neniDeep),
                ),
                alignment: Alignment.center,
                child: Text(
                  logoInitial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    businessName,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'VENDEDORA',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                      color: AppColors.lavender,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Stack(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onBell,
                  borderRadius: BorderRadius.circular(13),
                  child: Ink(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: const Icon(
                      Symbols.notifications,
                      size: 20,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 9,
                right: 9,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.neni,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.firstName, required this.hasActivePeriod});
  final String firstName;
  final bool hasActivePeriod;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  firstName.isEmpty ? '¡Hola! 🌸' : '¡Hola $firstName! 🌸',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.h1.copyWith(fontSize: 23),
                    children: [
                      const TextSpan(text: 'Tu panel '),
                      TextSpan(
                        text: 'hoy',
                        style: AppTextStyles.h1.copyWith(
                          fontSize: 21,
                          color: AppColors.neniDeep,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (hasActivePeriod)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD9F3E6),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x381F9A6A)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1F9A6A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'CORTE ABIERTO',
                    style: TextStyle(
                      color: Color(0xFF1F9A6A),
                      fontWeight: FontWeight.w800,
                      fontSize: 8.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CorteCard extends StatelessWidget {
  const _CorteCard({required this.period});
  final SellerActivePeriod period;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF0F5), Color(0xFFF3EBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x21E84E83)),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    const Icon(
                      Symbols.calendar_today,
                      size: 18,
                      color: AppColors.neniDeep,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Corte: ${period.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'ACTIVO',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AppColors.ink2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _CorteStat(
                label: 'Ventas',
                value: money(period.totalSales),
                color: const Color(0xFF1F9A6A),
              ),
              const SizedBox(width: 9),
              _CorteStat(
                label: 'Invertido',
                value: money(period.totalInvested),
                color: const Color(0xFFFF2D55),
              ),
              const SizedBox(width: 9),
              _CorteStat(
                label: 'Utilidad',
                value: money(period.netProfit),
                color: AppColors.neniDeep,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CorteStat extends StatelessWidget {
  const _CorteStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: AppColors.ink3,
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.dashboard});
  final SellerDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final d = dashboard;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        _KpiCard(
          title: 'Ventas Hoy',
          value: money(d.revenueToday),
          badge: 'Hoy',
          icon: Symbols.payments,
          color: const Color(0xFF1F9A6A),
          bg: const Color(0xFFD9F3E6),
        ),
        _KpiCard(
          title: 'Pendientes',
          value: '${d.pendingOrders}',
          badge: 'pedidos',
          icon: Symbols.shopping_bag,
          color: AppColors.neniDeep,
          bg: const Color(0xFFFFE1EC),
        ),
        _KpiCard(
          title: 'Por Cobrar',
          value: money(d.pendingAmount),
          badge: 'Cobrar',
          icon: Symbols.account_balance_wallet,
          color: const Color(0xFFB5730A),
          bg: const Color(0xFFFCECD2),
        ),
        _KpiCard(
          title: 'Repartos',
          value: '${d.activeRoutes}',
          badge: 'activos',
          icon: Symbols.map,
          color: AppColors.lavender,
          bg: const Color(0xFFF1E9FF),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.badge,
    required this.icon,
    required this.color,
    required this.bg,
  });
  final String title;
  final String value;
  final String badge;
  final IconData icon;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 17, color: color),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: AppColors.ink3,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: AppTextStyles.h1.copyWith(
                    fontSize: 19,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalesChartCard extends StatelessWidget {
  const _SalesChartCard({required this.data});
  final List<MonthlySales> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Symbols.query_stats,
                size: 16,
                color: AppColors.neniDeep,
              ),
              const SizedBox(width: 6),
              Text(
                'VENTAS MENSUALES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.ink2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (data.length < 2)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'Aún no hay suficientes ventas para la gráfica',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                ),
              ),
            )
          else
            SizedBox(
              height: 150,
              width: double.infinity,
              child: CustomPaint(painter: _ChartPainter(data)),
            ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.data);
  final List<MonthlySales> data;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    const labelH = 18.0;
    final chartH = size.height - labelH;
    final maxSales = data
        .map((e) => e.sales)
        .fold<double>(0, (a, b) => b > a ? b : a);
    final maxV = maxSales <= 0 ? 1.0 : maxSales;

    final gridPaint = Paint()
      ..color = AppColors.neni.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = chartH * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = <Offset>[];
    final step = data.length == 1 ? size.width : size.width / (data.length - 1);
    for (var i = 0; i < data.length; i++) {
      final x = step * i;
      final y =
          chartH - (data[i].sales / maxV) * (chartH * 0.86) - chartH * 0.07;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cx = p0.dx + (p1.dx - p0.dx) / 2;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, chartH)
      ..lineTo(points.first.dx, chartH)
      ..close();
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, chartH),
        [
          AppColors.neni.withValues(alpha: 0.32),
          AppColors.neni.withValues(alpha: 0.0),
        ],
      );
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = AppColors.neniDeep
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    final dotOuter = Paint()..color = Colors.white;
    final dotInner = Paint()..color = AppColors.neniDeep;
    for (final p in points) {
      canvas.drawCircle(p, 4.5, dotOuter);
      canvas.drawCircle(p, 2.8, dotInner);
    }

    for (var i = 0; i < data.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: data[i].month,
          style: const TextStyle(
            color: AppColors.ink3,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      var dx = points[i].dx - tp.width / 2;
      dx = dx.clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(dx, chartH + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.data != data;
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.orders});
  final List<SellerOrder> orders;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            'ACTIVIDAD RECIENTE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.ink3,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (orders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 26),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(
              'Aún no hay actividad reciente',
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
            ),
          )
        else
          for (final o in orders.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _ActivityRow(order: o),
            ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.order});
  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final date = DateFormat("d MMM · HH:mm", 'es').format(o.createdAt);
    return GestureDetector(
      onTap: () => context.push('/orders/detail/${o.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
          boxShadow: AppShadows.small,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF0F5), Color(0xFFF3EBFF)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text('🛍️', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.clientName.isEmpty ? 'Sin nombre' : o.clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$date · ${o.itemsCount} art',
                    style: AppTextStyles.subtitle.copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GradientText(money(o.total), fontSize: 14),
                const SizedBox(height: 4),
                _MiniStatus(status: o.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatus extends StatelessWidget {
  const _MiniStatus({required this.status});
  final SellerOrderStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.fg,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.neni, AppColors.neniDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: AppShadows.brandPrimary(AppColors.neniDeep),
          ),
          child: const Icon(Symbols.add, size: 27, color: Colors.white),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 34),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Symbols.cloud_off, size: 46, color: AppColors.ink3),
          const SizedBox(height: 14),
          Text(
            'No pudimos cargar tu panel',
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
                    const Icon(Symbols.refresh, size: 18, color: Colors.white),
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
    );
  }
}
