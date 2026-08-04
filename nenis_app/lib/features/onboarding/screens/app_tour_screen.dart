import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/nenis_logo.dart';
import '../../../shared/widgets/pill_button.dart';
import '../../subscription/data/subscription_models.dart';
import '../../subscription/data/subscription_repository.dart';

enum AppTourRole { client, seller }

class AppTourScreen extends ConsumerStatefulWidget {
  const AppTourScreen({super.key, required this.role, this.replay = false});

  final AppTourRole role;
  final bool replay;

  @override
  ConsumerState<AppTourScreen> createState() => _AppTourScreenState();
}

class _AppTourScreenState extends ConsumerState<AppTourScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _saving = false;

  bool get _isSeller => widget.role == AppTourRole.seller;
  int get _pageCount => _isSeller ? 5 : 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                child: Row(
                  children: [
                    if (widget.replay)
                      IconButton(
                        tooltip: 'Cerrar recorrido',
                        onPressed: _saving ? null : () => context.pop(),
                        icon: const Icon(Icons.close),
                      )
                    else
                      const NenisLogo(markSize: 34, wordmarkSize: 18),
                    const Spacer(),
                    TextButton(
                      onPressed: _saving ? null : _finish,
                      child: Text(widget.replay ? 'Cerrar' : 'Omitir'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pageCount,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
                    child: _isSeller
                        ? _buildSellerPage(index)
                        : _buildClientPage(index),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
                child: Column(
                  children: [
                    _PageIndicator(count: _pageCount, selected: _page),
                    const SizedBox(height: 16),
                    _saving
                        ? const SizedBox(
                            height: 56,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : PillButton(
                            key: const Key('tour-primary-action'),
                            label: _page == _pageCount - 1
                                ? (_isSeller
                                      ? 'Entrar a mi negocio'
                                      : 'Entrar a la app')
                                : 'Siguiente',
                            icon: _page == _pageCount - 1
                                ? Symbols.check
                                : Symbols.arrow_forward,
                            onPressed: _next,
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSellerPage(int index) {
    if (index == 0) {
      return _SellerTrialPage(
        status: ref.watch(subscriptionStatusProvider),
        pricing: ref.watch(subscriptionPricingProvider),
      );
    }
    return _TourPage(data: _sellerPages[index - 1]);
  }

  Widget _buildClientPage(int index) => _TourPage(data: _clientPages[index]);

  Future<void> _next() async {
    if (_page < _pageCount - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    if (_saving) return;
    if (widget.replay) {
      if (mounted) context.pop();
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .completeOnboarding(_isSeller ? 'seller' : 'client');
      if (!mounted) return;
      context.go(_isSeller ? '/home' : '/claim');
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SellerTrialPage extends StatelessWidget {
  const _SellerTrialPage({required this.status, required this.pricing});

  final AsyncValue<SubscriptionAccountState> status;
  final AsyncValue<SubscriptionPricing> pricing;

  @override
  Widget build(BuildContext context) {
    final hasActivePlan = status.value != null &&
        !status.value!.isLocked &&
        !status.value!.isTrialing;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TourIcon(icon: Symbols.workspace_premium),
          const SizedBox(height: 20),
          Text(
            status.maybeWhen(
              data: (value) {
                final active = !value.isLocked && !value.isTrialing;
                return value.isTrialing
                    ? 'Tu prueba Pro ya comenzó'
                    : (active
                          ? 'Tu plan ${value.effectivePlan} está activo'
                          : 'Tu tienda ya está creada');
              },
              orElse: () => 'Tu tienda ya está creada',
            ),
            textAlign: TextAlign.center,
            style: AppTextStyles.h1.copyWith(fontSize: 27),
          ),
          const SizedBox(height: 10),
          _SellerTrialStatus(status: status),
          // Solo mostramos el catálogo de planes a quien aún no tiene un plan
          // activo: a una vendedora con plan pagado, la lista de precios le
          // sugiere que falta elegir, cuando ya eligió.
          if (!hasActivePlan) ...[
            const SizedBox(height: 20),
            Text(
              'Planes disponibles',
              style: AppTextStyles.h2.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 10),
            pricing.when(
              loading: () => const LinearProgressIndicator(minHeight: 3),
              error: (_, _) => Text(
                'No pudimos cargar los precios. Podrás revisarlos en Mi plan.',
                style: AppTextStyles.subtitle,
              ),
              data: (catalog) => Column(
                children: [
                  for (final plan in catalog.plans) _CompactPlanRow(plan: plan),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SellerTrialStatus extends StatelessWidget {
  const _SellerTrialStatus({required this.status});

  final AsyncValue<SubscriptionAccountState> status;

  @override
  Widget build(BuildContext context) {
    return status.when(
      loading: () => Text(
        'Estamos preparando los datos de tu prueba.',
        textAlign: TextAlign.center,
        style: AppTextStyles.subtitle,
      ),
      error: (_, _) => Text(
        'Podrás consultar el estado exacto desde Mi plan.',
        textAlign: TextAlign.center,
        style: AppTextStyles.subtitle,
      ),
      data: (value) {
        if (value.isLocked) {
          return const _InfoBox(
            icon: Symbols.shield_lock,
            text:
                'Esta cuenta necesita contratar un plan antes de operar. Esto puede ocurrir cuando la prueba ya se usó o la identidad requiere revisión.',
            color: AppColors.statusPendingFg,
          );
        }
        if (!value.isTrialing) {
          return _InfoBox(
            icon: Symbols.verified,
            text:
                'Tu plan ${value.effectivePlan} está activo. Revisa cobros, periodicidad y opciones para cambiar desde Mi plan.',
            color: AppColors.statusDeliveredFg,
          );
        }
        final end = value.trialEndsAt == null
            ? 'al terminar los 14 días'
            : 'el ${DateFormat('d MMMM y', 'es_MX').format(value.trialEndsAt!.toLocal())}';
        return _InfoBox(
          icon: Symbols.calendar_month,
          text:
              'Tienes 14 días de Pro sin tarjeta y sin cobro hoy. Tu prueba termina $end; después la tienda se bloquea hasta que actives un plan.',
          color: AppColors.statusDeliveredFg,
        );
      },
    );
  }
}

class _CompactPlanRow extends StatelessWidget {
  const _CompactPlanRow({required this.plan});

  final PlanPrice plan;

  @override
  Widget build(BuildContext context) {
    final highlighted = plan.planTier == 'Pro';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFFFEAF2) : AppColors.surface,
        borderRadius: AppRadii.softRadius,
        border: Border.all(
          color: highlighted ? AppColors.neni : AppColors.line,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              plan.planTier,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '\$${plan.monthly.toStringAsFixed(0)} ${plan.currency}/mes',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w800,
              color: highlighted ? AppColors.neniDeep : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _TourPage extends StatelessWidget {
  const _TourPage({required this.data});

  final _TourPageData data;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          children: [
            _TourIcon(icon: data.icon),
            const SizedBox(height: 24),
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: AppTextStyles.h1.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 12),
            Text(
              data.body,
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 24),
            for (final item in data.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _InfoBox(
                  icon: item.icon,
                  text: item.text,
                  color: item.color,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TourIcon extends StatelessWidget {
  const _TourIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.line),
        ),
        child: Icon(icon, size: 46, color: AppColors.neniDeep, fill: 1),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadii.softRadius,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body.copyWith(fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.selected});

  final int count;
  final int selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: index == selected ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: index == selected ? AppColors.neniDeep : AppColors.line,
            borderRadius: AppRadii.pillRadius,
          ),
        ),
      ),
    );
  }
}

class _TourPageData {
  const _TourPageData({
    required this.icon,
    required this.title,
    required this.body,
    required this.items,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<_TourItem> items;
}

class _TourItem {
  const _TourItem(this.icon, this.text, this.color);

  final IconData icon;
  final String text;
  final Color color;
}

const _sellerPages = [
  _TourPageData(
    icon: Symbols.shopping_bag,
    title: 'Captura cada venta',
    body: 'Tus pedidos viven en un solo lugar desde que termina el en vivo.',
    items: [
      _TourItem(
        Symbols.add_circle,
        'Crea pedidos manuales o desde tus herramientas de venta.',
        AppColors.neniDeep,
      ),
      _TourItem(
        Symbols.sell,
        'Prepara bolsas, etiquetas e inventario sin perder el nombre de la clienta.',
        AppColors.statusRouteFg,
      ),
    ],
  ),
  _TourPageData(
    icon: Symbols.groups,
    title: 'Conoce a tus clientas',
    body:
        'El teléfono verificado une compras, puntos y seguimiento con la persona correcta.',
    items: [
      _TourItem(
        Symbols.badge,
        'Consulta historial, saldos y datos de entrega desde Clientas.',
        AppColors.neniDeep,
      ),
      _TourItem(
        Symbols.verified_user,
        'Evita perfiles duplicados usando el mismo teléfono en cada venta.',
        AppColors.statusDeliveredFg,
      ),
    ],
  ),
  _TourPageData(
    icon: Symbols.route,
    title: 'Organiza tus entregas',
    body: 'Arma rutas, asigna repartidores y mantén informada a cada clienta.',
    items: [
      _TourItem(
        Symbols.map,
        'Agrupa pedidos y revisa el orden de las paradas.',
        AppColors.statusRouteFg,
      ),
      _TourItem(
        Symbols.location_on,
        'La clienta puede seguir el avance desde su pedido.',
        AppColors.statusDeliveredFg,
      ),
    ],
  ),
  _TourPageData(
    icon: Symbols.storefront,
    title: 'Haz crecer tu tienda',
    body:
        'Publica novedades, anuncia tus en vivos y revisa tu plan desde Mi negocio.',
    items: [
      _TourItem(
        Symbols.campaign,
        'Avisa a tus seguidoras cuando tengas productos o transmisiones nuevas.',
        AppColors.liveRed,
      ),
      _TourItem(
        Symbols.workspace_premium,
        'En Mi plan ves días restantes, cobros y opciones para continuar.',
        AppColors.gold,
      ),
    ],
  ),
];

const _clientPages = [
  _TourPageData(
    icon: Symbols.verified_user,
    title: 'Tu número protege tus compras',
    body:
        'Lo confirmamos por WhatsApp para que sólo tú reclames pedidos, historial y puntos.',
    items: [
      _TourItem(
        Symbols.lock,
        'Tu teléfono no se muestra a otras clientas.',
        AppColors.statusDeliveredFg,
      ),
      _TourItem(
        Symbols.link,
        'Al abrir el enlace de un pedido, la app lo vincula contigo.',
        AppColors.statusRouteFg,
      ),
    ],
  ),
  _TourPageData(
    icon: Symbols.local_shipping,
    title: 'Sigue tus pedidos',
    body:
        'Consulta lo que compraste, cuánto falta por pagar y el avance de la entrega.',
    items: [
      _TourItem(
        Symbols.receipt_long,
        'Pedidos reúne tus compras de todas las tiendas.',
        AppColors.neniDeep,
      ),
      _TourItem(
        Symbols.location_on,
        'Cuando salga a ruta verás su progreso y mensajes.',
        AppColors.statusRouteFg,
      ),
    ],
  ),
  _TourPageData(
    icon: Symbols.stars,
    title: 'Tus tiendas y puntos',
    body:
        'Cada tienda conserva su propio saldo de puntos, premios y novedades.',
    items: [
      _TourItem(
        Symbols.storefront,
        'Sigue tus tiendas para enterarte de sus próximos en vivos.',
        AppColors.liveRed,
      ),
      _TourItem(
        Symbols.redeem,
        'Revisa premios disponibles antes de usar tus puntos.',
        AppColors.gold,
      ),
    ],
  ),
  _TourPageData(
    icon: Symbols.notifications_active,
    title: 'No pierdas una actualización',
    body:
        'Recibe avisos útiles de pedidos, entregas, mensajes y tiendas que sigues.',
    items: [
      _TourItem(
        Symbols.notifications,
        'Tú decides qué tiendas pueden avisarte.',
        AppColors.neniDeep,
      ),
      _TourItem(
        Symbols.account_circle,
        'Desde Mi cuenta administras direcciones, pagos y este tutorial.',
        AppColors.statusDeliveredFg,
      ),
    ],
  ),
];
