import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';
import '../../../shared/widgets/premium_toast.dart';
import '../../../shared/widgets/segmented.dart';
import '../data/subscription_models.dart';
import '../data/subscription_repository.dart';

const _periodicities = ['monthly', 'quarterly', 'annual'];

class MyPlanScreen extends ConsumerStatefulWidget {
  const MyPlanScreen({super.key});

  @override
  ConsumerState<MyPlanScreen> createState() => _MyPlanScreenState();
}

class _MyPlanScreenState extends ConsumerState<MyPlanScreen> {
  int _periodIndex = 0;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(subscriptionStatusProvider);
    final pricing = ref.watch(subscriptionPricingProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => invalidateSubscriptionStateFromWidget(ref),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
              children: [
                Row(
                  children: [
                    Material(
                      color: AppColors.surface,
                      shape: const CircleBorder(),
                      elevation: 2,
                      shadowColor: Colors.black26,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () =>
                            context.canPop() ? context.pop() : context.go('/account'),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(Icons.adaptive.arrow_back, size: 20, color: AppColors.ink),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('Mi plan', style: AppTextStyles.h1.copyWith(fontSize: 24)),
                  ],
                ),
                const SizedBox(height: 18),
                status.when(
                  loading: () => const _StatusSkeleton(),
                  error: (_, _) => _ErrorCard(onRetry: () => ref.invalidate(subscriptionStatusProvider)),
                  data: (s) => _StatusBanner(status: s),
                ),
                const SizedBox(height: 22),
                Text('Elige tu periodicidad', style: AppTextStyles.h2.copyWith(fontSize: 16)),
                const SizedBox(height: 10),
                SegmentedControl(
                  items: const [
                    SegmentedItem(label: 'Mensual'),
                    SegmentedItem(label: 'Trimestral'),
                    SegmentedItem(label: 'Anual'),
                  ],
                  selectedIndex: _periodIndex,
                  onChanged: _busy ? (_) {} : (i) => setState(() => _periodIndex = i),
                ),
                const SizedBox(height: 18),
                pricing.when(
                  loading: () => const _PlansSkeleton(),
                  error: (_, _) => _ErrorCard(onRetry: () => ref.invalidate(subscriptionPricingProvider)),
                  data: (p) => status.maybeWhen(
                    data: (s) => Column(
                      children: [
                        for (final plan in p.plans) ...[
                          _PlanCard(
                            plan: plan,
                            periodicity: _periodicities[_periodIndex],
                            currentPlanTier: s.planTier,
                            isCurrent: plan.planTier == s.planTier,
                            hasActivePreapproval: s.hasActivePreapproval,
                            busy: _busy,
                            onChoose: () => _choosePlan(plan),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ),
                status.maybeWhen(
                  data: (s) => s.hasActivePreapproval
                      ? _ManageSubscriptionSection(busy: _busy, onCancel: _cancel)
                      : const SizedBox.shrink(),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _choosePlan(PlanPrice plan) async {
    final s = ref.read(subscriptionStatusProvider).value;
    if (s == null || _busy) return;
    final periodicity = _periodicities[_periodIndex];

    if (!s.hasActivePreapproval) {
      // Sin preapproval activo (prueba o vencida): pasa por el checkout de
      // tarjeta en el panel web.
      context.push('/seller/plan/checkout?plan=${plan.planTier}&periodicity=$periodicity');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(subscriptionRepositoryProvider).updatePlan(
            planTier: plan.planTier,
            periodicity: periodicity,
          );
      invalidateSubscriptionStateFromWidget(ref);
      if (mounted) {
        context.showPremiumToast('Tu plan se actualizó.', type: PremiumToastType.success);
      }
    } on SubscriptionException catch (e) {
      if (mounted) context.showPremiumToast(e.message, type: PremiumToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('¿Cancelar tu suscripción?'),
        content: const Text(
          'Sigue activa hasta el fin de tu periodo actual; después tu tienda se bloquea hasta que elijas un plan de nuevo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No, conservarla')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar', style: TextStyle(color: AppColors.liveRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(subscriptionRepositoryProvider).cancel();
      invalidateSubscriptionStateFromWidget(ref);
      if (mounted) {
        context.showPremiumToast('Tu suscripción se canceló.', type: PremiumToastType.info);
      }
    } on SubscriptionException catch (e) {
      if (mounted) context.showPremiumToast(e.message, type: PremiumToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final SubscriptionAccountState status;

  @override
  Widget build(BuildContext context) {
    final (title, body, color) = _content();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadii.softRadius,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Symbols.info, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700, fontSize: 14.5)),
                const SizedBox(height: 3),
                Text(body, style: AppTextStyles.subtitle.copyWith(fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (String, String, Color) _content() {
    switch (status.subscriptionStatus) {
      case 'Trialing':
        return (
          'Prueba Pro · te quedan ${status.daysLeft} días',
          'Sin tarjeta todavía. Elige un plan cuando quieras seguir.',
          AppColors.gold,
        );
      case 'PastDue':
        return (
          'Tuvimos un problema con tu cobro',
          'Actualiza tu tarjeta antes de que se bloquee tu tienda (${status.pastDueGraceDays} días de gracia).',
          AppColors.liveRed,
        );
      case 'Active':
        final next = status.currentPeriodEndsAt != null
            ? DateFormat('d MMM y', 'es_MX').format(status.currentPeriodEndsAt!)
            : '—';
        final pending = status.pendingPlanTier != null
            ? ' · cambia a ${status.pendingPlanTier} el ${status.pendingPlanEffectiveAt != null ? DateFormat('d MMM', 'es_MX').format(status.pendingPlanEffectiveAt!) : next}'
            : '';
        return ('Plan ${status.planTier} activo', 'Próximo cobro: $next$pending', AppColors.statusDeliveredFg);
      default:
        return (
          'Tu plan está bloqueado',
          'Elige un plan para seguir usando tu tienda.',
          AppColors.liveRed,
        );
    }
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.periodicity,
    required this.currentPlanTier,
    required this.isCurrent,
    required this.hasActivePreapproval,
    required this.busy,
    required this.onChoose,
  });

  final PlanPrice plan;
  final String periodicity;
  final String currentPlanTier;
  final bool isCurrent;
  final bool hasActivePreapproval;
  final bool busy;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final amount = plan.amountFor(periodicity);
    final discount = periodicity == 'quarterly'
        ? plan.quarterlyDiscountPct
        : periodicity == 'annual'
            ? plan.annualDiscountPct
            : 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        boxShadow: AppShadows.small,
        border: Border.all(
          color: isCurrent ? AppColors.neniDeep : AppColors.lineSoft,
          width: isCurrent ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(plan.planTier, style: AppTextStyles.h2.copyWith(fontSize: 18)),
              if (plan.planTier == 'Pro') ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.gold, borderRadius: AppRadii.pillRadius),
                  child: const Text('Lo que más eligen',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('\$${amount.toStringAsFixed(0)}',
                  style: AppTextStyles.h1.copyWith(fontSize: 26)),
              const SizedBox(width: 4),
              Text('${plan.currency} / ${_periodLabel(periodicity)}',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12)),
              if (discount > 0) ...[
                const SizedBox(width: 8),
                Text('-$discount%',
                    style: AppTextStyles.chip.copyWith(color: AppColors.statusDeliveredFg, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
          const SizedBox(height: 14),
          ..._featuresFor(plan.planTier).map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Symbols.check_circle, size: 16, color: AppColors.statusDeliveredFg),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f, style: AppTextStyles.body.copyWith(fontSize: 12.5))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          PillButton(
            label: isCurrent
                ? 'Tu plan actual'
                : hasActivePreapproval
                    ? 'Cambiar a ${plan.planTier}'
                    : 'Elegir ${plan.planTier}',
            icon: isCurrent ? Symbols.check : Symbols.arrow_forward,
            variant: isCurrent ? PillButtonVariant.ghost : PillButtonVariant.brand,
            onPressed: isCurrent || busy ? null : onChoose,
          ),
        ],
      ),
    );
  }

  String _periodLabel(String p) => switch (p) {
        'quarterly' => 'trimestre',
        'annual' => 'año',
        _ => 'mes',
      };

  List<String> _featuresFor(String tier) => switch (tier) {
        'Pro' => const [
            'Todo lo de Entrada',
            'Avisos de en vivo y GPS en tiempo real',
            'Finanzas, tandas y sorteos',
            'Punto de venta (POS)',
          ],
        'Elite' => const [
            'Todo lo de Pro',
            'C.A.M.I., tu asistente con IA',
            'Optimización de rutas con tráfico',
            'Exportes y soporte prioritario',
          ],
        _ => const [
            'Captura manual de pedidos',
            'Directorio de clientas',
            'Link público de rastreo',
            '1 repartidor',
          ],
      };
}

class _ManageSubscriptionSection extends StatelessWidget {
  const _ManageSubscriptionSection({required this.busy, required this.onCancel});
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Administrar suscripción', style: AppTextStyles.h2.copyWith(fontSize: 15)),
          const SizedBox(height: 10),
          PillButton(
            label: 'Cancelar suscripción',
            icon: Symbols.cancel,
            variant: PillButtonVariant.ghost,
            onPressed: busy ? null : onCancel,
          ),
        ],
      ),
    );
  }
}

class _StatusSkeleton extends StatelessWidget {
  const _StatusSkeleton();
  @override
  Widget build(BuildContext context) => Container(
        height: 68,
        decoration: BoxDecoration(color: AppColors.segTrack, borderRadius: AppRadii.softRadius),
      );
}

class _PlansSkeleton extends StatelessWidget {
  const _PlansSkeleton();
  @override
  Widget build(BuildContext context) => Column(
        children: List.generate(
          3,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 220,
            decoration: BoxDecoration(color: AppColors.segTrack, borderRadius: AppRadii.cardRadius),
          ),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadii.softRadius, boxShadow: AppShadows.small),
        child: Row(
          children: [
            const Icon(Symbols.cloud_off, color: AppColors.ink3),
            const SizedBox(width: 10),
            const Expanded(child: Text('No pudimos cargar esto.')),
            TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      );
}
