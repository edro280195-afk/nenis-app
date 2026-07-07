import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/glass_bottom_nav.dart';
import '../../../shared/widgets/pill_button.dart';
import '../../../shared/widgets/segmented.dart';
import '../data/seller_tandas_models.dart';
import '../data/seller_tandas_repository.dart';

class SellerTandasScreen extends ConsumerStatefulWidget {
  const SellerTandasScreen({super.key});

  @override
  ConsumerState<SellerTandasScreen> createState() => _SellerTandasScreenState();
}

class _SellerTandasScreenState extends ConsumerState<SellerTandasScreen> {
  SellerTandaFilter _filter = SellerTandaFilter.active;

  Future<void> _reload() {
    return ref.read(sellerTandasControllerProvider.notifier).reload();
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String success,
  }) async {
    try {
      await action();
      if (!mounted) return;
      _toast(success);
    } catch (error) {
      if (!mounted) return;
      _toast(error.toString());
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _createTanda(SellerTandasWorkspace workspace) async {
    if (workspace.products.isEmpty || workspace.clients.isEmpty) {
      _toast(
        'Necesitas productos de tanda y clientas cargadas desde el API para crear.',
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateTandaSheet(
        products: workspace.products,
        clients: workspace.clients,
        onSubmit: (request) async {
          await ref
              .read(sellerTandasControllerProvider.notifier)
              .createTanda(request);
          if (context.mounted) Navigator.pop(context);
          if (mounted) _toast('Tanda creada con datos del API.');
        },
      ),
    );
  }

  Future<void> _copyPublicLink(SellerTanda tanda) async {
    final token = tanda.accessToken?.trim();
    if (token == null || token.isEmpty) {
      _toast('Esta tanda no trae enlace público desde el API.');
      return;
    }
    final url = '${AppConfig.apiBaseUrl}/api/public-tanda/$token';
    await Clipboard.setData(ClipboardData(text: url));
    _toast('Enlace público copiado.');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sellerTandasControllerProvider);

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
                  _Header(onRefresh: _reload),
                  Expanded(
                    child: async.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: AppColors.neni),
                      ),
                      error: (error, _) => _ErrorState(
                        message: error.toString(),
                        onRetry: _reload,
                      ),
                      data: (workspace) => RefreshIndicator(
                        color: AppColors.neniDeep,
                        onRefresh: _reload,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 720;
                            return ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                8,
                                22,
                                130,
                              ),
                              children: [
                                _KpiGrid(dashboard: workspace.dashboard),
                                const SizedBox(height: 14),
                                SegmentedControl(
                                  items: SellerTandaFilter.values
                                      .map(
                                        (filter) =>
                                            SegmentedItem(label: filter.label),
                                      )
                                      .toList(),
                                  selectedIndex: SellerTandaFilter.values
                                      .indexOf(_filter),
                                  onChanged: (index) => setState(
                                    () => _filter =
                                        SellerTandaFilter.values[index],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (wide)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: _TandasColumn(
                                          workspace: workspace,
                                          filter: _filter,
                                          onSelect: (id) => ref
                                              .read(
                                                sellerTandasControllerProvider
                                                    .notifier,
                                              )
                                              .selectTanda(id),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 6,
                                        child: _DetailPanel(
                                          workspace: workspace,
                                          onCopyLink: _copyPublicLink,
                                          onPay: _payParticipant,
                                          onUndoPay: _deletePayment,
                                          onDeliver: _confirmDelivery,
                                          onProcessPenalties: _processPenalties,
                                        ),
                                      ),
                                    ],
                                  )
                                else ...[
                                  _TandasColumn(
                                    workspace: workspace,
                                    filter: _filter,
                                    onSelect: (id) => ref
                                        .read(
                                          sellerTandasControllerProvider
                                              .notifier,
                                        )
                                        .selectTanda(id),
                                  ),
                                  const SizedBox(height: 16),
                                  _DetailPanel(
                                    workspace: workspace,
                                    onCopyLink: _copyPublicLink,
                                    onPay: _payParticipant,
                                    onUndoPay: _deletePayment,
                                    onDeliver: _confirmDelivery,
                                    onProcessPenalties: _processPenalties,
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              async.maybeWhen(
                data: (workspace) => Positioned(
                  right: 22,
                  bottom: 104,
                  child: _CreateFab(onTap: () => _createTanda(workspace)),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GlassBottomNav(
                  items: buildSellerNavItems(),
                  currentRoute: '/tandas',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _payParticipant(
    SellerTanda tanda,
    SellerTandaParticipant participant,
  ) async {
    final ok = await _confirm(
      'Registrar pago',
      'Se marcará como pagada la semana ${tanda.actionableWeek} de ${participant.displayName}.',
    );
    if (!ok) return;
    await _run(
      () => ref
          .read(sellerTandasControllerProvider.notifier)
          .registerPayment(tanda: tanda, participant: participant),
      success: 'Pago registrado.',
    );
  }

  Future<void> _deletePayment(
    SellerTanda tanda,
    SellerTandaParticipant participant,
  ) async {
    final ok = await _confirm(
      'Quitar pago',
      'Se quitará el pago registrado de esta semana.',
    );
    if (!ok) return;
    await _run(
      () => ref
          .read(sellerTandasControllerProvider.notifier)
          .deleteCurrentPayment(tanda: tanda, participant: participant),
      success: 'Pago eliminado.',
    );
  }

  Future<void> _confirmDelivery(
    SellerTanda tanda,
    SellerTandaParticipant participant,
  ) async {
    final ok = await _confirm(
      'Confirmar entrega',
      'Se marcará como entregado el turno de ${participant.displayName}.',
    );
    if (!ok) return;
    await _run(
      () => ref
          .read(sellerTandasControllerProvider.notifier)
          .confirmDelivery(tanda: tanda, participant: participant),
      success: 'Entrega confirmada.',
    );
  }

  Future<void> _processPenalties(SellerTanda tanda) async {
    final ok = await _confirm(
      'Procesar atrasos',
      'El API revisará la semana actual y marcará atrasos donde falte pago.',
    );
    if (!ok) return;
    await _run(
      () => ref
          .read(sellerTandasControllerProvider.notifier)
          .processPenalties(tanda),
      success: 'Atrasos procesados.',
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 18, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.h1.copyWith(fontSize: 27),
                    children: [
                      const TextSpan(text: 'Tandas '),
                      TextSpan(
                        text: 'activas',
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
                  'Cobros, turnos y entregas conectados a sellgeneral-api.',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Actualizar',
            onPressed: () => onRefresh(),
            icon: const Icon(Symbols.sync, size: 22),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.dashboard});

  final SellerTandasDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 540 ? 4 : 2;
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: columns == 4 ? 1.55 : 2.25,
          ),
          children: [
            _KpiTile(
              label: 'Activas',
              value: dashboard.active.toString(),
              icon: Symbols.groups,
              color: AppColors.neniDeep,
            ),
            _KpiTile(
              label: 'Cobrar',
              value: dashboard.due.toString(),
              icon: Symbols.payments,
              color: AppColors.lavender,
            ),
            _KpiTile(
              label: 'Atrasos',
              value: dashboard.late.toString(),
              icon: Symbols.gavel,
              color: AppColors.statusPendingFg,
            ),
            _KpiTile(
              label: 'Entregar',
              value: dashboard.deliveries.toString(),
              icon: Symbols.inventory_2,
              color: AppColors.statusRouteFg,
            ),
          ],
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.small,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink3,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h1.copyWith(fontSize: 19),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TandasColumn extends StatelessWidget {
  const _TandasColumn({
    required this.workspace,
    required this.filter,
    required this.onSelect,
  });

  final SellerTandasWorkspace workspace;
  final SellerTandaFilter filter;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final tandas = workspace.filtered(filter);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _summaryLabel(tandas.length),
          style: AppTextStyles.subtitle.copyWith(
            fontSize: 11.5,
            color: AppColors.ink3,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        if (tandas.isEmpty)
          _EmptyState(
            icon: Symbols.groups,
            title: 'Sin tandas en esta vista',
            body:
                'Cuando el API tenga registros para este filtro aparecerán aquí.',
          )
        else
          ...tandas.map(
            (tanda) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TandaCard(
                tanda: tanda,
                selected: tanda.id == workspace.selectedId,
                onTap: () => onSelect(tanda.id),
              ),
            ),
          ),
      ],
    );
  }

  String _summaryLabel(int count) {
    final suffix = count == 1 ? 'tanda' : 'tandas';
    return 'Mostrando $count $suffix';
  }
}

class _TandaCard extends StatelessWidget {
  const _TandaCard({
    required this.tanda,
    required this.selected,
    required this.onTap,
  });

  final SellerTanda tanda;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final currentWeek = tanda.currentWeek;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.softRadius,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.softRadius,
            border: Border.all(
              color: selected
                  ? AppColors.neniDeep.withValues(alpha: 0.34)
                  : AppColors.line,
              width: selected ? 1.4 : 1,
            ),
            boxShadow: AppShadows.small,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(label: tanda.displayName),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tanda.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tanda.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(tanda: tanda),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetaPill(
                      icon: Symbols.calendar_today,
                      label: 'Semana',
                      value: currentWeek == 0
                          ? 'Por iniciar'
                          : '$currentWeek de ${tanda.totalWeeks}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetaPill(
                      icon: Symbols.payments,
                      label: 'Cuota',
                      value: '${tandaMoney(tanda.weeklyAmount)} sem.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: tanda.weekProgress,
                  backgroundColor: const Color(0xFFF8D9E4),
                  valueColor: const AlwaysStoppedAnimation(AppColors.neniDeep),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SmallChip(
                    icon: Symbols.groups,
                    label: '${tanda.participants.length} participantes',
                    fg: AppColors.lavender,
                    bg: const Color(0xFFF1E9FF),
                  ),
                  if (tanda.dueParticipants.isNotEmpty)
                    _SmallChip(
                      icon: Symbols.payments,
                      label: '${tanda.dueParticipants.length} por cobrar',
                      fg: AppColors.neniDeep,
                      bg: const Color(0xFFFFE1EC),
                    ),
                  if (tanda.lateParticipants.isNotEmpty)
                    _SmallChip(
                      icon: Symbols.warning,
                      label: '${tanda.lateParticipants.length} atrasos',
                      fg: AppColors.statusPendingFg,
                      bg: AppColors.statusPendingBg,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.workspace,
    required this.onCopyLink,
    required this.onPay,
    required this.onUndoPay,
    required this.onDeliver,
    required this.onProcessPenalties,
  });

  final SellerTandasWorkspace workspace;
  final ValueChanged<SellerTanda> onCopyLink;
  final Future<void> Function(SellerTanda, SellerTandaParticipant) onPay;
  final Future<void> Function(SellerTanda, SellerTandaParticipant) onUndoPay;
  final Future<void> Function(SellerTanda, SellerTandaParticipant) onDeliver;
  final Future<void> Function(SellerTanda) onProcessPenalties;

  @override
  Widget build(BuildContext context) {
    final tanda = workspace.selectedTanda;
    if (workspace.detailLoading) {
      return const _LoadingPanel();
    }
    if (tanda == null) {
      return const _EmptyState(
        icon: Symbols.fact_check,
        title: 'Sin tanda seleccionada',
        body: 'Carga o crea una tanda para ver su gestión semanal.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tanda.displayName,
                      style: AppTextStyles.h1.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tanda.productName,
                      style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copiar enlace público',
                onPressed: () => onCopyLink(tanda),
                icon: const Icon(Symbols.link, size: 21),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailStats(tanda: tanda),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Symbols.gavel,
                  label: 'Procesar atrasos',
                  onTap: tanda.actionableWeek == 0
                      ? null
                      : () => onProcessPenalties(tanda),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Symbols.inventory_2,
                  label: tanda.deliveryParticipants.isEmpty
                      ? 'Sin entrega'
                      : 'Entrega pendiente',
                  onTap: null,
                  muted: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Participantes', style: AppTextStyles.h2.copyWith(fontSize: 15)),
          const SizedBox(height: 10),
          if (tanda.sortedParticipants.isEmpty)
            const _EmptyState(
              icon: Symbols.person_add,
              title: 'Sin participantes',
              body: 'El detalle del API no trajo lugares asignados.',
            )
          else
            ...tanda.sortedParticipants.map(
              (participant) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ParticipantRow(
                  tanda: tanda,
                  participant: participant,
                  onPay: () => onPay(tanda, participant),
                  onUndoPay: () => onUndoPay(tanda, participant),
                  onDeliver: () => onDeliver(tanda, participant),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailStats extends StatelessWidget {
  const _DetailStats({required this.tanda});

  final SellerTanda tanda;

  @override
  Widget build(BuildContext context) {
    final week = tanda.currentWeek;
    final percent = (tanda.paymentProgress * 100).round();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniStat(
                label: 'Semana',
                value: week == 0
                    ? '0 / ${tanda.totalWeeks}'
                    : '$week / ${tanda.totalWeeks}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniStat(label: 'Pagos', value: '$percent%'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniStat(
                label: 'Multa',
                value: tandaMoney(tanda.penaltyAmount),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: tanda.paymentProgress,
            backgroundColor: const Color(0xFFF1E9FF),
            valueColor: const AlwaysStoppedAnimation(AppColors.lavender),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.tanda,
    required this.participant,
    required this.onPay,
    required this.onUndoPay,
    required this.onDeliver,
  });

  final SellerTanda tanda;
  final SellerTandaParticipant participant;
  final VoidCallback onPay;
  final VoidCallback onUndoPay;
  final VoidCallback onDeliver;

  @override
  Widget build(BuildContext context) {
    final week = tanda.actionableWeek;
    final paid = week > 0 && participant.hasPaidWeek(week);
    final receives = week > 0 && participant.assignedTurn == week;
    final canDeliver = receives && !participant.isDelivered;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: participant.isLate
                      ? AppColors.statusPendingBg
                      : const Color(0xFFFFE1EC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  participant.assignedTurn.toString(),
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: participant.isLate
                        ? AppColors.statusPendingFg
                        : AppColors.neniDeep,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      participant.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (participant.variant?.trim().isNotEmpty ?? false)
                          participant.variant!.trim(),
                        '${tandaMoney(participant.amountFor(tanda))} semanal',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subtitle.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _PaymentChip(paid: paid, late: participant.isLate),
            ],
          ),
          const SizedBox(height: 10),
          _WeekStrip(tanda: tanda, participant: participant),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              if (receives)
                _SmallChip(
                  icon: Symbols.redeem,
                  label: participant.isDelivered ? 'Entregado' : 'Recibe ahora',
                  fg: participant.isDelivered
                      ? AppColors.statusDeliveredFg
                      : AppColors.statusRouteFg,
                  bg: participant.isDelivered
                      ? AppColors.statusDeliveredBg
                      : AppColors.statusRouteBg,
                )
              else
                _SmallChip(
                  icon: Symbols.flag,
                  label: 'Turno ${participant.assignedTurn}',
                  fg: AppColors.ink2,
                  bg: AppColors.lineSoft,
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniIconButton(
                    tooltip: 'Registrar pago',
                    icon: Symbols.payments,
                    color: AppColors.statusDeliveredFg,
                    onTap: week == 0 || paid ? null : onPay,
                  ),
                  const SizedBox(width: 7),
                  _MiniIconButton(
                    tooltip: 'Quitar pago',
                    icon: Symbols.undo,
                    color: AppColors.neniDeep,
                    onTap: paid ? onUndoPay : null,
                  ),
                  const SizedBox(width: 7),
                  _MiniIconButton(
                    tooltip: 'Confirmar entrega',
                    icon: Symbols.inventory_2,
                    color: AppColors.statusRouteFg,
                    onTap: canDeliver ? onDeliver : null,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.tanda, required this.participant});

  final SellerTanda tanda;
  final SellerTandaParticipant participant;

  @override
  Widget build(BuildContext context) {
    final current = tanda.actionableWeek;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tanda.totalWeeks, (index) {
          final week = index + 1;
          final paid = participant.hasPaidWeek(week);
          final now = week == current;
          final bg = paid
              ? AppColors.statusDeliveredBg
              : now
              ? const Color(0xFFFFE1EC)
              : AppColors.surface;
          final fg = paid
              ? AppColors.statusDeliveredFg
              : now
              ? AppColors.neniDeep
              : AppColors.ink3;
          return Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(
              week.toString(),
              style: AppTextStyles.body.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CreateTandaSheet extends ConsumerStatefulWidget {
  const _CreateTandaSheet({
    required this.products,
    required this.clients,
    required this.onSubmit,
  });

  final List<SellerTandaProduct> products;
  final List<SellerTandaClient> clients;
  final Future<void> Function(CreateTandaRequest request) onSubmit;

  @override
  ConsumerState<_CreateTandaSheet> createState() => _CreateTandaSheetState();
}

class _CreateTandaSheetState extends ConsumerState<_CreateTandaSheet> {
  final _nameCtrl = TextEditingController();
  final _weeksCtrl = TextEditingController(text: '10');
  final _amountCtrl = TextEditingController();
  final _penaltyCtrl = TextEditingController(text: '0');
  final _formKey = GlobalKey<FormState>();

  String? _productId;
  DateTime _startDate = DateTime.now();
  List<int?> _clientIds = List<int?>.filled(10, null);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.products.isNotEmpty) {
      final first = widget.products.first;
      _productId = first.id;
      if (first.basePrice > 0) {
        _amountCtrl.text = first.basePrice.toStringAsFixed(0);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weeksCtrl.dispose();
    _amountCtrl.dispose();
    _penaltyCtrl.dispose();
    super.dispose();
  }

  void _syncWeeks(String value) {
    final total = (int.tryParse(value) ?? 1).clamp(1, 52).toInt();
    setState(() {
      _clientIds = List<int?>.generate(
        total,
        (index) => index < _clientIds.length ? _clientIds[index] : null,
      );
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_productId == null) {
      _toast('Selecciona un producto real del API.');
      return;
    }
    if (_clientIds.any((id) => id == null)) {
      _toast('Asigna una clienta en cada lugar.');
      return;
    }

    setState(() => _saving = true);
    try {
      final request = CreateTandaRequest(
        productId: _productId!,
        name: _nameCtrl.text.trim(),
        totalWeeks: int.parse(_weeksCtrl.text.trim()),
        weeklyAmount: double.parse(_amountCtrl.text.trim()),
        penaltyAmount: double.tryParse(_penaltyCtrl.text.trim()) ?? 0,
        startDate: _startDate,
        participants: [
          for (var i = 0; i < _clientIds.length; i++)
            CreateTandaParticipantDraft(
              customerId: _clientIds[i]!,
              assignedTurn: i + 1,
            ),
        ],
      );
      await widget.onSubmit(request);
    } catch (error) {
      if (mounted) _toast(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Nueva tanda',
                    style: AppTextStyles.h1.copyWith(fontSize: 21),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Symbols.close, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _TextFormField(
              controller: _nameCtrl,
              label: 'Nombre',
              hint: 'Ej. Tanda de julio',
              validator: (value) =>
                  value.trim().isEmpty ? 'Escribe un nombre.' : null,
            ),
            const SizedBox(height: 12),
            _SheetLabel(
              label: 'Producto',
              child: DropdownButtonFormField<String>(
                initialValue: _productId,
                isExpanded: true,
                decoration: _inputDecoration(),
                items: widget.products
                    .map(
                      (product) => DropdownMenuItem(
                        value: product.id,
                        child: Text(product.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  final product = widget.products.firstWhere(
                    (item) => item.id == value,
                  );
                  setState(() {
                    _productId = value;
                    if (_amountCtrl.text.trim().isEmpty &&
                        product.basePrice > 0) {
                      _amountCtrl.text = product.basePrice.toStringAsFixed(0);
                    }
                  });
                },
                validator: (value) =>
                    value == null ? 'Selecciona producto.' : null,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TextFormField(
                    controller: _weeksCtrl,
                    label: 'Lugares',
                    keyboardType: TextInputType.number,
                    onChanged: _syncWeeks,
                    validator: (value) {
                      final n = int.tryParse(value.trim());
                      if (n == null || n < 1 || n > 52) {
                        return 'Usa 1 a 52.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TextFormField(
                    controller: _amountCtrl,
                    label: 'Abono',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final n = double.tryParse(value.trim());
                      if (n == null || n <= 0) return 'Monto inválido.';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TextFormField(
                    controller: _penaltyCtrl,
                    label: 'Multa',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final n = double.tryParse(value.trim());
                      if (n == null || n < 0) return 'Monto inválido.';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SheetLabel(
                    label: 'Inicio',
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: AppRadii.fieldRadius,
                      child: InputDecorator(
                        decoration: _inputDecoration(),
                        child: Text(
                          DateFormat('dd MMM yyyy', 'es_MX').format(_startDate),
                          style: AppTextStyles.body.copyWith(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Asignación de lugares',
              style: AppTextStyles.h2.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 8),
            ...List.generate(_clientIds.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SlotSelector(
                  turn: index + 1,
                  value: _clientIds[index],
                  clients: widget.clients,
                  onChanged: (value) =>
                      setState(() => _clientIds[index] = value),
                ),
              );
            }),
            const SizedBox(height: 8),
            PillButton(
              label: _saving ? 'Creando...' : 'Crear tanda',
              icon: Symbols.save,
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotSelector extends StatelessWidget {
  const _SlotSelector({
    required this.turn,
    required this.value,
    required this.clients,
    required this.onChanged,
  });

  final int turn;
  final int? value;
  final List<SellerTandaClient> clients;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE1EC),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              turn.toString(),
              style: AppTextStyles.body.copyWith(
                color: AppColors.neniDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: value,
              isExpanded: true,
              decoration: _inputDecoration(dense: true),
              hint: const Text('Selecciona clienta'),
              items: clients
                  .map(
                    (client) => DropdownMenuItem(
                      value: client.id,
                      child: Text(
                        client.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextFormField extends StatelessWidget {
  const _TextFormField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String value)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return _SheetLabel(
      label: label,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: AppTextStyles.body.copyWith(fontSize: 13),
        decoration: _inputDecoration(hint: hint),
        validator: (value) => validator?.call(value ?? ''),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.subtitle.copyWith(
            fontSize: 12,
            color: AppColors.ink2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

InputDecoration _inputDecoration({String? hint, bool dense = false}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: AppTextStyles.fieldPlaceholder.copyWith(fontSize: 13),
    filled: true,
    fillColor: AppColors.surface,
    isDense: dense,
    contentPadding: EdgeInsets.symmetric(
      horizontal: 14,
      vertical: dense ? 10 : 14,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadii.fieldRadius,
      borderSide: const BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadii.fieldRadius,
      borderSide: const BorderSide(color: AppColors.neniDeep, width: 1.2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: AppRadii.fieldRadius,
      borderSide: const BorderSide(color: AppColors.liveRed),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: AppRadii.fieldRadius,
      borderSide: const BorderSide(color: AppColors.liveRed, width: 1.2),
    ),
  );
}

class _CreateFab extends StatelessWidget {
  const _CreateFab({required this.onTap});

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
              Text('Nueva', style: AppTextStyles.button.copyWith(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final initial = label.trim().isEmpty ? '?' : label.trim()[0].toUpperCase();
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.neni, AppColors.neniDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.avatarRadius,
        boxShadow: AppShadows.brandPrimary(AppColors.neniDeep),
      ),
      child: Text(
        initial,
        style: AppTextStyles.body.copyWith(
          fontSize: 15,
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.tanda});

  final SellerTanda tanda;

  @override
  Widget build(BuildContext context) {
    final active = tanda.isActive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFFFE1EC) : AppColors.lineSoft,
        borderRadius: AppRadii.pillRadius,
      ),
      child: Text(
        active ? 'Activa' : 'Finalizada',
        style: AppTextStyles.chip.copyWith(
          fontSize: 10,
          color: active ? AppColors.neniDeep : AppColors.ink2,
        ),
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({required this.paid, required this.late});

  final bool paid;
  final bool late;

  @override
  Widget build(BuildContext context) {
    final label = paid
        ? 'Pagado'
        : late
        ? 'Atraso'
        : 'Cobrar';
    final fg = paid
        ? AppColors.statusDeliveredFg
        : late
        ? AppColors.statusPendingFg
        : AppColors.neniDeep;
    final bg = paid
        ? AppColors.statusDeliveredBg
        : late
        ? AppColors.statusPendingBg
        : const Color(0xFFFFE1EC);
    return _SmallChip(icon: Symbols.payments, label: label, fg: fg, bg: bg);
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
  });

  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadii.pillRadius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.chip.copyWith(fontSize: 10, color: fg),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF3F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.neniDeep),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 9,
                    height: 1.1,
                    color: AppColors.ink3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = muted ? AppColors.ink2 : AppColors.neniDeep;
    return Opacity(
      opacity: enabled || muted ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            height: 42,
            decoration: BoxDecoration(
              color: muted ? const Color(0xFFFBF3F6) : const Color(0xFFFFE1EC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.buttonSmall.copyWith(
                      fontSize: 12,
                      color: fg,
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

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.16)),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        boxShadow: AppShadows.small,
      ),
      child: const CircularProgressIndicator(color: AppColors.neni),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 80, 22, 130),
      children: [
        _EmptyState(
          icon: Symbols.error,
          title: 'No pudimos cargar tandas',
          body: message,
        ),
        const SizedBox(height: 16),
        PillButton(
          label: 'Reintentar',
          icon: Symbols.refresh,
          onPressed: () => onRetry(),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: AppRadii.softRadius,
        border: Border.all(color: AppColors.neniDeep.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: AppColors.neniDeep),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.h2.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
