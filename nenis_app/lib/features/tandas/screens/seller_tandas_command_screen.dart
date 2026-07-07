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
import '../../../shared/widgets/pill_button.dart';
import '../../../shared/widgets/segmented.dart';
import '../data/seller_tandas_models.dart';
import '../data/seller_tandas_repository.dart';

class SellerTandasCommandScreen extends ConsumerStatefulWidget {
  const SellerTandasCommandScreen({super.key});

  @override
  ConsumerState<SellerTandasCommandScreen> createState() =>
      _SellerTandasCommandScreenState();
}

class _SellerTandasCommandScreenState
    extends ConsumerState<SellerTandasCommandScreen> {
  final _searchCtrl = TextEditingController();
  SellerTandaFilter _filter = SellerTandaFilter.active;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _copyPublicLink(SellerTanda tanda) async {
    final token = tanda.accessToken?.trim();
    if (token == null || token.isEmpty) {
      _toast('Esta tanda no tiene enlace publico disponible.');
      return;
    }
    final url = '${AppConfig.apiBaseUrl}/api/public-tanda/$token';
    await Clipboard.setData(ClipboardData(text: url));
    _toast('Enlace publico copiado.');
  }

  Future<void> _createTanda(SellerTandasWorkspace workspace) async {
    if (workspace.clients.isEmpty) {
      _toast('Primero necesitas clientas cargadas desde el API.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TandaBuilderSheet(
        products: workspace.products,
        clients: workspace.clients,
        onCreateProduct: (name, basePrice) => ref
            .read(sellerTandasRepositoryProvider)
            .createProduct(name: name, basePrice: basePrice),
        onSubmit: (request) async {
          await ref
              .read(sellerTandasControllerProvider.notifier)
              .createTanda(request);
          if (context.mounted) Navigator.pop(context);
          if (mounted) _toast('Tanda creada y lista para operar.');
        },
      ),
    );
  }

  Future<void> _editTanda(SellerTanda tanda) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditTandaSheet(
        tanda: tanda,
        onSubmit: (request) async {
          await ref
              .read(sellerTandasControllerProvider.notifier)
              .updateTanda(request);
          if (context.mounted) Navigator.pop(context);
          if (mounted) _toast('Tanda actualizada.');
        },
      ),
    );
  }

  Future<void> _addParticipant(
    SellerTandasWorkspace workspace,
    SellerTanda tanda,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddParticipantSheet(
        tanda: tanda,
        clients: workspace.clients,
        onSubmit: (request) async {
          await ref
              .read(sellerTandasControllerProvider.notifier)
              .addParticipant(request);
          if (context.mounted) Navigator.pop(context);
          if (mounted) _toast('Participante inscrita.');
        },
      ),
    );
  }

  Future<void> _editParticipant(
    SellerTanda tanda,
    SellerTandaParticipant participant,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ParticipantEditorSheet(
        tanda: tanda,
        participant: participant,
        onSave: (result) async {
          final controller = ref.read(sellerTandasControllerProvider.notifier);
          if (result.turn != participant.assignedTurn) {
            await controller.updateParticipantTurn(
              tanda: tanda,
              participant: participant,
              newTurn: result.turn,
            );
          }
          final currentVariant = participant.variant?.trim() ?? '';
          if (result.variant.trim() != currentVariant) {
            await controller.updateParticipantVariant(
              tanda: tanda,
              participant: participant,
              variant: result.variant.trim().isEmpty
                  ? null
                  : result.variant.trim(),
            );
          }
          if (context.mounted) Navigator.pop(context);
          if (mounted) _toast('Participante actualizada.');
        },
        onRemove: () async {
          final ok = await _confirm(
            'Retirar participante',
            'Se eliminara a ${participant.displayName} y sus pagos de esta tanda.',
          );
          if (!ok) return;
          await ref
              .read(sellerTandasControllerProvider.notifier)
              .removeParticipant(tanda: tanda, participant: participant);
          if (context.mounted) Navigator.pop(context);
          if (mounted) _toast('Participante retirada.');
        },
      ),
    );
  }

  Future<void> _reorderParticipants(SellerTanda tanda) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReorderParticipantsSheet(
        tanda: tanda,
        onSubmit: (orderedIds) async {
          await ref
              .read(sellerTandasControllerProvider.notifier)
              .reorderParticipants(tanda: tanda, participantIds: orderedIds);
          if (context.mounted) Navigator.pop(context);
          if (mounted) _toast('Nuevo orden guardado.');
        },
      ),
    );
  }

  Future<void> _payParticipant(
    SellerTanda tanda,
    SellerTandaParticipant participant,
  ) async {
    final ok = await _confirm(
      'Registrar pago',
      'Se marcara pagada la semana ${tanda.actionableWeek} de ${participant.displayName}.',
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
      'Se quitara el pago registrado de esta semana.',
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
      'Se marcara como entregado el turno de ${participant.displayName}.',
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
      'El API revisara la semana actual y marcara atrasos donde falte pago.',
    );
    if (!ok) return;
    await _run(
      () => ref
          .read(sellerTandasControllerProvider.notifier)
          .processPenalties(tanda),
      success: 'Atrasos procesados.',
    );
  }

  List<SellerTanda> _visibleTandas(SellerTandasWorkspace workspace) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = workspace.filtered(_filter);
    if (query.isEmpty) return filtered;
    return filtered.where((tanda) {
      return tanda.displayName.toLowerCase().contains(query) ||
          tanda.productName.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sellerTandasControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.neni),
            ),
            error: (error, _) =>
                _CommandError(message: error.toString(), onRetry: _reload),
            data: (workspace) => RefreshIndicator(
              color: AppColors.neniDeep,
              onRefresh: _reload,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final visibleTandas = _visibleTandas(workspace);
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                    children: [
                      _CommandHero(
                        workspace: workspace,
                        onRefresh: _reload,
                        onCreate: () => _createTanda(workspace),
                      ),
                      const SizedBox(height: 16),
                      _FocusBoard(
                        workspace: workspace,
                        onFilter: (filter) => setState(() => _filter = filter),
                      ),
                      const SizedBox(height: 16),
                      SegmentedControl(
                        items: SellerTandaFilter.values
                            .map((filter) => SegmentedItem(label: filter.label))
                            .toList(),
                        selectedIndex: SellerTandaFilter.values.indexOf(
                          _filter,
                        ),
                        onChanged: (index) => setState(
                          () => _filter = SellerTandaFilter.values[index],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SearchField(controller: _searchCtrl),
                      const SizedBox(height: 16),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 360,
                              child: _TandaRail(
                                tandas: visibleTandas,
                                selectedId: workspace.selectedId,
                                onSelect: (id) => ref
                                    .read(
                                      sellerTandasControllerProvider.notifier,
                                    )
                                    .selectTanda(id),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _DetailPanel(
                                workspace: workspace,
                                onCopyLink: _copyPublicLink,
                                onEditTanda: _editTanda,
                                onAddParticipant: (tanda) =>
                                    _addParticipant(workspace, tanda),
                                onReorder: _reorderParticipants,
                                onPay: _payParticipant,
                                onUndoPay: _deletePayment,
                                onDeliver: _confirmDelivery,
                                onProcessPenalties: _processPenalties,
                                onEditParticipant: _editParticipant,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _TandaRail(
                          tandas: visibleTandas,
                          selectedId: workspace.selectedId,
                          onSelect: (id) => ref
                              .read(sellerTandasControllerProvider.notifier)
                              .selectTanda(id),
                        ),
                        const SizedBox(height: 16),
                        _DetailPanel(
                          workspace: workspace,
                          onCopyLink: _copyPublicLink,
                          onEditTanda: _editTanda,
                          onAddParticipant: (tanda) =>
                              _addParticipant(workspace, tanda),
                          onReorder: _reorderParticipants,
                          onPay: _payParticipant,
                          onUndoPay: _deletePayment,
                          onDeliver: _confirmDelivery,
                          onProcessPenalties: _processPenalties,
                          onEditParticipant: _editParticipant,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommandHero extends StatelessWidget {
  const _CommandHero({
    required this.workspace,
    required this.onRefresh,
    required this.onCreate,
  });

  final SellerTandasWorkspace workspace;
  final Future<void> Function() onRefresh;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final active = workspace.tandas.where((tanda) => tanda.isActive).toList();
    final expected = active.fold<double>(
      0,
      (sum, tanda) => sum + tanda.expectedAmount,
    );
    final collected = active.fold<double>(
      0,
      (sum, tanda) => sum + tanda.collectedAmount,
    );
    final pendingWeek = active.fold<double>(
      0,
      (sum, tanda) => sum + tanda.currentWeekPending,
    );
    final progress = expected <= 0 ? 0.0 : (collected / expected).clamp(0, 1);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFCFD), Color(0xFFFFEAF2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.74)),
        boxShadow: AppShadows.card,
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
                      'Centro de tandas',
                      style: AppTextStyles.display.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cobros, turnos, atrasos y entregas en una sola mesa de control.',
                      style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              PillIconButton(
                icon: Symbols.sync,
                onPressed: () => onRefresh(),
                background: Colors.white,
                iconColor: AppColors.neniDeep,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: progress.toDouble(),
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation(AppColors.neniDeep),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final children = [
                _HeroMetric(
                  label: 'Activas',
                  value: active.length.toString(),
                  icon: Symbols.groups,
                  color: AppColors.neniDeep,
                ),
                _HeroMetric(
                  label: 'Cobrado',
                  value: tandaMoney(collected),
                  icon: Symbols.savings,
                  color: AppColors.statusDeliveredFg,
                ),
                _HeroMetric(
                  label: 'Pendiente semana',
                  value: tandaMoney(pendingWeek),
                  icon: Symbols.payments,
                  color: AppColors.statusPendingFg,
                ),
              ];
              if (compact) {
                return Column(
                  children: [
                    for (final child in children) ...[
                      child,
                      if (child != children.last) const SizedBox(height: 8),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (final child in children) ...[
                    Expanded(child: child),
                    if (child != children.last) const SizedBox(width: 8),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          PillButton(
            label: 'Nueva tanda',
            icon: Symbols.add,
            expand: false,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
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
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
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
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
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

class _FocusBoard extends StatelessWidget {
  const _FocusBoard({required this.workspace, required this.onFilter});

  final SellerTandasWorkspace workspace;
  final ValueChanged<SellerTandaFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final dashboard = workspace.dashboard;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final items = [
          _FocusItem(
            title: 'Cobrar hoy',
            value: dashboard.due.toString(),
            body: 'Pagos pendientes de la semana actual.',
            icon: Symbols.point_of_sale,
            color: AppColors.neniDeep,
            onTap: () => onFilter(SellerTandaFilter.due),
          ),
          _FocusItem(
            title: 'Atrasos',
            value: dashboard.late.toString(),
            body: 'Participantes con corte pendiente.',
            icon: Symbols.warning,
            color: AppColors.statusPendingFg,
            onTap: () => onFilter(SellerTandaFilter.late),
          ),
          _FocusItem(
            title: 'Entregas',
            value: dashboard.deliveries.toString(),
            body: 'Turnos listos para entregar producto.',
            icon: Symbols.inventory_2,
            color: AppColors.statusRouteFg,
            onTap: () => onFilter(SellerTandaFilter.active),
          ),
        ];
        if (compact) {
          return SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) =>
                  SizedBox(width: 250, child: items[index]),
            ),
          );
        }
        return Row(
          children: [
            for (final item in items) ...[
              Expanded(child: item),
              if (item != items.last) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }
}

class _FocusItem extends StatelessWidget {
  const _FocusItem({
    required this.title,
    required this.value,
    required this.body,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String value;
  final String body;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            border: Border.all(color: AppColors.line),
            boxShadow: AppShadows.small,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subtitle.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: AppTextStyles.h1.copyWith(fontSize: 22, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: AppTextStyles.body,
      decoration: _inputDecoration(
        hint: 'Buscar por tanda o producto',
        prefixIcon: const Icon(Symbols.search, size: 21),
      ),
    );
  }
}

class _TandaRail extends StatelessWidget {
  const _TandaRail({
    required this.tandas,
    required this.selectedId,
    required this.onSelect,
  });

  final List<SellerTanda> tandas;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (tandas.isEmpty) {
      return const _EmptyPanel(
        icon: Symbols.groups,
        title: 'No hay tandas aqui',
        body: 'Cambia el filtro o crea una tanda nueva para empezar.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${tandas.length} ${tandas.length == 1 ? 'tanda' : 'tandas'}',
          style: AppTextStyles.subtitle.copyWith(
            fontSize: 11.5,
            color: AppColors.ink3,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        for (final tanda in tandas) ...[
          _TandaCommandCard(
            tanda: tanda,
            selected: tanda.id == selectedId,
            onTap: () => onSelect(tanda.id),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _TandaCommandCard extends StatelessWidget {
  const _TandaCommandCard({
    required this.tanda,
    required this.selected,
    required this.onTap,
  });

  final SellerTanda tanda;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final delivery = tanda.currentDeliveryParticipant;
    final collectionProgress = tanda.currentWeekExpected <= 0
        ? 0.0
        : (tanda.currentWeekCollected / tanda.currentWeekExpected).clamp(0, 1);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.softRadius,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFF2F7) : AppColors.surface,
            borderRadius: AppRadii.softRadius,
            border: Border.all(
              color: selected
                  ? AppColors.neniDeep.withValues(alpha: 0.36)
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
                  _InitialBadge(label: tanda.displayName),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(tanda: tanda),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TinyMetric(
                      label: 'Semana',
                      value: tanda.actionableWeek == 0
                          ? 'Sin corte'
                          : '${tanda.actionableWeek}/${tanda.totalWeeks}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TinyMetric(
                      label: 'Cobrar',
                      value: tandaMoney(tanda.currentWeekPending),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: collectionProgress.toDouble(),
                  backgroundColor: AppColors.segTrack,
                  valueColor: const AlwaysStoppedAnimation(
                    AppColors.statusDeliveredFg,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _SoftChip(
                    icon: Symbols.groups,
                    label: '${tanda.participants.length} lugares',
                    color: AppColors.lavender,
                  ),
                  if (delivery != null)
                    _SoftChip(
                      icon: Symbols.inventory_2,
                      label: delivery.isDelivered
                          ? 'Entrega lista'
                          : 'Entrega: ${delivery.displayName}',
                      color: AppColors.statusRouteFg,
                    ),
                  if (tanda.lateParticipants.isNotEmpty)
                    _SoftChip(
                      icon: Symbols.warning,
                      label: '${tanda.lateParticipants.length} atrasos',
                      color: AppColors.statusPendingFg,
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
    required this.onEditTanda,
    required this.onAddParticipant,
    required this.onReorder,
    required this.onPay,
    required this.onUndoPay,
    required this.onDeliver,
    required this.onProcessPenalties,
    required this.onEditParticipant,
  });

  final SellerTandasWorkspace workspace;
  final ValueChanged<SellerTanda> onCopyLink;
  final ValueChanged<SellerTanda> onEditTanda;
  final ValueChanged<SellerTanda> onAddParticipant;
  final ValueChanged<SellerTanda> onReorder;
  final Future<void> Function(SellerTanda, SellerTandaParticipant) onPay;
  final Future<void> Function(SellerTanda, SellerTandaParticipant) onUndoPay;
  final Future<void> Function(SellerTanda, SellerTandaParticipant) onDeliver;
  final Future<void> Function(SellerTanda) onProcessPenalties;
  final Future<void> Function(SellerTanda, SellerTandaParticipant)
  onEditParticipant;

  @override
  Widget build(BuildContext context) {
    final tanda = workspace.selectedTanda;
    if (workspace.detailLoading) {
      return const _LoadingPanel();
    }
    if (tanda == null) {
      return const _EmptyPanel(
        icon: Symbols.fact_check,
        title: 'Sin tanda seleccionada',
        body: 'Selecciona una tanda para ver su operacion semanal.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailHeader(
            tanda: tanda,
            onCopyLink: () => onCopyLink(tanda),
            onEdit: () => onEditTanda(tanda),
            onAddParticipant: () => onAddParticipant(tanda),
            onReorder: () => onReorder(tanda),
          ),
          const SizedBox(height: 14),
          _TandaScoreboard(tanda: tanda),
          const SizedBox(height: 14),
          _WeekActionPanel(
            tanda: tanda,
            onPay: onPay,
            onUndoPay: onUndoPay,
            onDeliver: onDeliver,
            onProcessPenalties: onProcessPenalties,
          ),
          const SizedBox(height: 16),
          Text(
            'Participantes y pagos',
            style: AppTextStyles.h2.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 10),
          if (tanda.sortedParticipants.isEmpty)
            const _EmptyPanel(
              icon: Symbols.person_add,
              title: 'Sin participantes',
              body: 'Inscribir clientas habilita cobros, turnos y entregas.',
            )
          else
            for (final participant in tanda.sortedParticipants) ...[
              _ParticipantLedgerRow(
                tanda: tanda,
                participant: participant,
                onPay: () => onPay(tanda, participant),
                onUndoPay: () => onUndoPay(tanda, participant),
                onDeliver: () => onDeliver(tanda, participant),
                onEdit: () => onEditParticipant(tanda, participant),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.tanda,
    required this.onCopyLink,
    required this.onEdit,
    required this.onAddParticipant,
    required this.onReorder,
  });

  final SellerTanda tanda;
  final VoidCallback onCopyLink;
  final VoidCallback onEdit;
  final VoidCallback onAddParticipant;
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tanda.displayName,
                style: AppTextStyles.h1.copyWith(fontSize: 21),
              ),
              const SizedBox(height: 3),
              Text(
                tanda.productName,
                style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _SoftChip(
                    icon: Symbols.calendar_today,
                    label: 'Inicio ${tandaDate(tanda.startDate)}',
                    color: AppColors.ink2,
                  ),
                  _SoftChip(
                    icon: Symbols.payments,
                    label: '${tandaMoney(tanda.weeklyAmount)} semanal',
                    color: AppColors.neniDeep,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.end,
          children: [
            _RoundAction(
              tooltip: 'Copiar enlace',
              icon: Symbols.link,
              onTap: onCopyLink,
            ),
            _RoundAction(
              tooltip: 'Editar tanda',
              icon: Symbols.edit,
              onTap: onEdit,
            ),
            _RoundAction(
              tooltip: 'Inscribir clienta',
              icon: Symbols.person_add,
              onTap: onAddParticipant,
            ),
            _RoundAction(
              tooltip: 'Reordenar turnos',
              icon: Symbols.swap_vert,
              onTap: tanda.sortedParticipants.length < 2 ? null : onReorder,
            ),
          ],
        ),
      ],
    );
  }
}

class _TandaScoreboard extends StatelessWidget {
  const _TandaScoreboard({required this.tanda});

  final SellerTanda tanda;

  @override
  Widget build(BuildContext context) {
    final progress = tanda.expectedAmount <= 0
        ? 0.0
        : (tanda.collectedAmount / tanda.expectedAmount).clamp(0, 1);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ScoreItem(
                  label: 'Cobrado total',
                  value: tandaMoney(tanda.collectedAmount),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ScoreItem(
                  label: 'Meta tanda',
                  value: tandaMoney(tanda.expectedAmount),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ScoreItem(
                  label: 'Entregas',
                  value: '${tanda.deliveredCount}/${tanda.participants.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress.toDouble(),
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation(AppColors.lavender),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekActionPanel extends StatelessWidget {
  const _WeekActionPanel({
    required this.tanda,
    required this.onPay,
    required this.onUndoPay,
    required this.onDeliver,
    required this.onProcessPenalties,
  });

  final SellerTanda tanda;
  final Future<void> Function(SellerTanda, SellerTandaParticipant) onPay;
  final Future<void> Function(SellerTanda, SellerTandaParticipant) onUndoPay;
  final Future<void> Function(SellerTanda, SellerTandaParticipant) onDeliver;
  final Future<void> Function(SellerTanda) onProcessPenalties;

  @override
  Widget build(BuildContext context) {
    final week = tanda.actionableWeek;
    final delivery = tanda.currentDeliveryParticipant;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  week == 0
                      ? 'Semana fuera de rango'
                      : 'Semana $week de ${tanda.totalWeeks}',
                  style: AppTextStyles.h2.copyWith(fontSize: 15),
                ),
              ),
              _SoftChip(
                icon: Symbols.point_of_sale,
                label: '${tanda.dueParticipants.length} por cobrar',
                color: AppColors.neniDeep,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TinyMetric(
                  label: 'Cobrado semana',
                  value: tandaMoney(tanda.currentWeekCollected),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TinyMetric(
                  label: 'Pendiente',
                  value: tandaMoney(tanda.currentWeekPending),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tanda.dueParticipants.isEmpty)
            _InlineNotice(
              icon: Symbols.check_circle,
              title: 'Cobros al corriente',
              body:
                  'Esta semana ya aparece cubierta para todas las participantes.',
              color: AppColors.statusDeliveredFg,
            )
          else
            for (final participant in tanda.dueParticipants.take(4)) ...[
              _MiniDueRow(
                tanda: tanda,
                participant: participant,
                onPay: () => onPay(tanda, participant),
              ),
              const SizedBox(height: 8),
            ],
          if (tanda.dueParticipants.length > 4)
            Text(
              '+${tanda.dueParticipants.length - 4} participantes mas en la lista completa.',
              style: AppTextStyles.subtitle.copyWith(fontSize: 11),
            ),
          const SizedBox(height: 12),
          if (delivery != null)
            _DeliveryNow(
              tanda: tanda,
              participant: delivery,
              onDeliver: () => onDeliver(tanda, delivery),
            )
          else
            _InlineNotice(
              icon: Symbols.inventory_2,
              title: 'Sin entrega activa',
              body: 'No hay turno de entrega para la semana actual.',
              color: AppColors.statusRouteFg,
            ),
          if (tanda.lateParticipants.isNotEmpty) ...[
            const SizedBox(height: 12),
            _LateNotice(
              count: tanda.lateParticipants.length,
              onProcess: () => onProcessPenalties(tanda),
            ),
          ] else ...[
            const SizedBox(height: 12),
            _GhostAction(
              icon: Symbols.gavel,
              label: 'Procesar corte de atrasos',
              onTap: week == 0 ? null : () => onProcessPenalties(tanda),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniDueRow extends StatelessWidget {
  const _MiniDueRow({
    required this.tanda,
    required this.participant,
    required this.onPay,
  });

  final SellerTanda tanda;
  final SellerTandaParticipant participant;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TurnBubble(turn: participant.assignedTurn, late: participant.isLate),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            participant.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          tandaMoney(participant.amountFor(tanda)),
          style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
        ),
        const SizedBox(width: 8),
        _MiniPillAction(label: 'Pagar', icon: Symbols.payments, onTap: onPay),
      ],
    );
  }
}

class _DeliveryNow extends StatelessWidget {
  const _DeliveryNow({
    required this.tanda,
    required this.participant,
    required this.onDeliver,
  });

  final SellerTanda tanda;
  final SellerTandaParticipant participant;
  final VoidCallback onDeliver;

  @override
  Widget build(BuildContext context) {
    final delivered = participant.isDelivered;
    final deliveryDate = tanda.deliveryDateForTurn(participant.assignedTurn);
    return _InlineNotice(
      icon: delivered ? Symbols.check_circle : Symbols.inventory_2,
      title: delivered
          ? 'Entrega confirmada'
          : '${participant.displayName} recibe esta semana',
      body: 'Turno ${participant.assignedTurn} · ${tandaDate(deliveryDate)}',
      color: delivered ? AppColors.statusDeliveredFg : AppColors.statusRouteFg,
      action: delivered
          ? null
          : _MiniPillAction(
              label: 'Entregar',
              icon: Symbols.inventory_2,
              onTap: onDeliver,
            ),
    );
  }
}

class _LateNotice extends StatelessWidget {
  const _LateNotice({required this.count, required this.onProcess});

  final int count;
  final VoidCallback onProcess;

  @override
  Widget build(BuildContext context) {
    return _InlineNotice(
      icon: Symbols.warning,
      title: '$count ${count == 1 ? 'atraso activo' : 'atrasos activos'}',
      body: 'Revisa pagos pendientes antes de cerrar la semana.',
      color: AppColors.statusPendingFg,
      action: _MiniPillAction(
        label: 'Procesar',
        icon: Symbols.gavel,
        onTap: onProcess,
      ),
    );
  }
}

class _ParticipantLedgerRow extends StatelessWidget {
  const _ParticipantLedgerRow({
    required this.tanda,
    required this.participant,
    required this.onPay,
    required this.onUndoPay,
    required this.onDeliver,
    required this.onEdit,
  });

  final SellerTanda tanda;
  final SellerTandaParticipant participant;
  final VoidCallback onPay;
  final VoidCallback onUndoPay;
  final VoidCallback onDeliver;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final week = tanda.actionableWeek;
    final paid = week > 0 && participant.hasPaidWeek(week);
    final receives = week > 0 && participant.assignedTurn == week;
    final canDeliver = receives && !participant.isDelivered;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: participant.isLate
              ? AppColors.statusPendingFg.withValues(alpha: 0.26)
              : AppColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TurnBubble(
                turn: participant.assignedTurn,
                late: participant.isLate,
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
                        fontSize: 13.5,
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
              _PaymentStateChip(paid: paid, late: participant.isLate),
              const SizedBox(width: 4),
              _RoundAction(
                tooltip: 'Editar participante',
                icon: Symbols.more_horiz,
                onTap: onEdit,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _WeekStrip(tanda: tanda, participant: participant),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniPillAction(
                label: 'Registrar pago',
                icon: Symbols.payments,
                onTap: week == 0 || paid ? null : onPay,
              ),
              _MiniPillAction(
                label: 'Quitar pago',
                icon: Symbols.undo,
                onTap: paid ? onUndoPay : null,
                muted: true,
              ),
              _MiniPillAction(
                label: participant.isDelivered ? 'Entregado' : 'Entregar',
                icon: Symbols.inventory_2,
                onTap: canDeliver ? onDeliver : null,
                muted: !canDeliver,
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
          final winner = week == participant.assignedTurn;
          final Color bg;
          final Color fg;
          if (paid) {
            bg = AppColors.statusDeliveredBg;
            fg = AppColors.statusDeliveredFg;
          } else if (now) {
            bg = const Color(0xFFFFE1EC);
            fg = AppColors.neniDeep;
          } else if (winner) {
            bg = AppColors.statusRouteBg;
            fg = AppColors.statusRouteFg;
          } else {
            bg = AppColors.surface;
            fg = AppColors.ink3;
          }
          return Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
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

class _TandaBuilderSheet extends ConsumerStatefulWidget {
  const _TandaBuilderSheet({
    required this.products,
    required this.clients,
    required this.onCreateProduct,
    required this.onSubmit,
  });

  final List<SellerTandaProduct> products;
  final List<SellerTandaClient> clients;
  final Future<SellerTandaProduct> Function(String name, double basePrice)
  onCreateProduct;
  final Future<void> Function(CreateTandaRequest request) onSubmit;

  @override
  ConsumerState<_TandaBuilderSheet> createState() => _TandaBuilderSheetState();
}

class _TandaBuilderSheetState extends ConsumerState<_TandaBuilderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _productCtrl = TextEditingController();
  final _weeksCtrl = TextEditingController(text: '10');
  final _amountCtrl = TextEditingController(text: '100');
  final _penaltyCtrl = TextEditingController(text: '0');
  final _clientSearchCtrl = TextEditingController();

  SellerTandaProduct? _selectedProduct;
  DateTime _startDate = DateTime.now();
  int _selectedTurn = 1;
  bool _saving = false;
  late List<_TandaSlotDraft> _slots;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.products.isNotEmpty
        ? widget.products.first
        : null;
    _productCtrl.text = _selectedProduct?.name ?? '';
    if (_selectedProduct != null && _selectedProduct!.basePrice > 0) {
      _amountCtrl.text = _selectedProduct!.basePrice.toStringAsFixed(0);
    }
    _slots = List.generate(10, (index) => _TandaSlotDraft(turn: index + 1));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _productCtrl.dispose();
    _weeksCtrl.dispose();
    _amountCtrl.dispose();
    _penaltyCtrl.dispose();
    _clientSearchCtrl.dispose();
    super.dispose();
  }

  void _syncWeeks(String value) {
    final weeks = (int.tryParse(value.trim()) ?? 1).clamp(1, 52).toInt();
    setState(() {
      _slots = List.generate(weeks, (index) {
        if (index < _slots.length) return _slots[index]..turn = index + 1;
        return _TandaSlotDraft(turn: index + 1);
      });
      if (_selectedTurn > weeks) _selectedTurn = weeks;
    });
  }

  List<SellerTandaProduct> get _matchingProducts {
    final query = _productCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return widget.products.take(8).toList();
    return widget.products
        .where((product) => product.name.toLowerCase().contains(query))
        .take(8)
        .toList();
  }

  List<SellerTandaClient> get _matchingClients {
    final query = _clientSearchCtrl.text.trim().toLowerCase();
    final assigned = _slots
        .where((slot) => slot.turn != _selectedTurn)
        .map((slot) => slot.clientId)
        .whereType<int>()
        .toSet();
    return widget.clients
        .where((client) {
          if (assigned.contains(client.id)) return false;
          final label = client.label.toLowerCase();
          return query.isEmpty || label.contains(query);
        })
        .take(10)
        .toList();
  }

  bool get _complete => _slots.every((slot) => slot.clientId != null);

  void _selectProduct(SellerTandaProduct product) {
    setState(() {
      _selectedProduct = product;
      _productCtrl.text = product.name;
      if (_amountCtrl.text.trim().isEmpty && product.basePrice > 0) {
        _amountCtrl.text = product.basePrice.toStringAsFixed(0);
      }
    });
  }

  void _assignClient(SellerTandaClient client) {
    setState(() {
      _slots[_selectedTurn - 1].clientId = client.id;
      _slots[_selectedTurn - 1].clientName = client.name;
      _clientSearchCtrl.clear();
      for (final slot in _slots) {
        if (slot.clientId == null) {
          _selectedTurn = slot.turn;
          break;
        }
      }
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
    if (!_complete) {
      _toast('Asigna una clienta en cada lugar.');
      return;
    }

    setState(() => _saving = true);
    try {
      final product =
          _selectedProduct ??
          await widget.onCreateProduct(
            _productCtrl.text.trim(),
            double.tryParse(_amountCtrl.text.trim()) ?? 0,
          );
      final request = CreateTandaRequest(
        productId: product.id,
        name: _nameCtrl.text.trim(),
        totalWeeks: _slots.length,
        weeklyAmount: double.parse(_amountCtrl.text.trim()),
        penaltyAmount: double.tryParse(_penaltyCtrl.text.trim()) ?? 0,
        startDate: _startDate,
        participants: _slots
            .map(
              (slot) => CreateTandaParticipantDraft(
                customerId: slot.clientId!,
                assignedTurn: slot.turn,
                variant: slot.variant.trim().isEmpty
                    ? null
                    : slot.variant.trim(),
              ),
            )
            .toList(),
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
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            _SheetHeader(
              title: 'Configurar tanda',
              subtitle:
                  'Define producto, cobro semanal y el orden real de entrega.',
              trailing: _ProgressBadge(
                value:
                    '${_slots.where((slot) => slot.clientId != null).length}/${_slots.length}',
                label: 'lugares',
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final basics = _BuilderBasics(
                  nameCtrl: _nameCtrl,
                  productCtrl: _productCtrl,
                  weeksCtrl: _weeksCtrl,
                  amountCtrl: _amountCtrl,
                  penaltyCtrl: _penaltyCtrl,
                  startDate: _startDate,
                  matchingProducts: _matchingProducts,
                  selectedProduct: _selectedProduct,
                  onProductQueryChanged: (_) {
                    setState(() => _selectedProduct = null);
                  },
                  onSelectProduct: _selectProduct,
                  onWeeksChanged: _syncWeeks,
                  onPickDate: _pickDate,
                );
                final slots = _BuilderSlots(
                  slots: _slots,
                  selectedTurn: _selectedTurn,
                  clients: _matchingClients,
                  clientSearchCtrl: _clientSearchCtrl,
                  onSearchChanged: (_) => setState(() {}),
                  onSelectTurn: (turn) => setState(() => _selectedTurn = turn),
                  onAssignClient: _assignClient,
                  onClearClient: (turn) => setState(() {
                    final slot = _slots[turn - 1];
                    slot.clientId = null;
                    slot.clientName = null;
                    _selectedTurn = turn;
                  }),
                );
                if (!wide) {
                  return Column(
                    children: [basics, const SizedBox(height: 16), slots],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: basics),
                    const SizedBox(width: 16),
                    Expanded(flex: 6, child: slots),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            PillButton(
              label: _saving ? 'Creando...' : 'Crear tanda completa',
              icon: Symbols.save,
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _BuilderBasics extends StatelessWidget {
  const _BuilderBasics({
    required this.nameCtrl,
    required this.productCtrl,
    required this.weeksCtrl,
    required this.amountCtrl,
    required this.penaltyCtrl,
    required this.startDate,
    required this.matchingProducts,
    required this.selectedProduct,
    required this.onProductQueryChanged,
    required this.onSelectProduct,
    required this.onWeeksChanged,
    required this.onPickDate,
  });

  final TextEditingController nameCtrl;
  final TextEditingController productCtrl;
  final TextEditingController weeksCtrl;
  final TextEditingController amountCtrl;
  final TextEditingController penaltyCtrl;
  final DateTime startDate;
  final List<SellerTandaProduct> matchingProducts;
  final SellerTandaProduct? selectedProduct;
  final ValueChanged<String> onProductQueryChanged;
  final ValueChanged<SellerTandaProduct> onSelectProduct;
  final ValueChanged<String> onWeeksChanged;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final hasExactProduct =
        selectedProduct != null &&
        selectedProduct!.name.trim().toLowerCase() ==
            productCtrl.text.trim().toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetTextField(
          controller: nameCtrl,
          label: 'Nombre',
          hint: 'Ej. Tanda sartenes premium',
          validator: (value) =>
              value.trim().isEmpty ? 'Escribe un nombre.' : null,
        ),
        const SizedBox(height: 12),
        _SheetTextField(
          controller: productCtrl,
          label: 'Producto',
          hint: 'Buscar o crear producto',
          onChanged: onProductQueryChanged,
          validator: (value) =>
              value.trim().isEmpty ? 'Escribe un producto.' : null,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final product in matchingProducts)
              ChoiceChip(
                label: Text(product.name),
                selected: product.id == selectedProduct?.id,
                onSelected: (_) => onSelectProduct(product),
              ),
            if (!hasExactProduct && productCtrl.text.trim().isNotEmpty)
              _SoftChip(
                icon: Symbols.add,
                label: 'Se creara "${productCtrl.text.trim()}"',
                color: AppColors.statusDeliveredFg,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SheetTextField(
                controller: weeksCtrl,
                label: 'Lugares',
                keyboardType: TextInputType.number,
                onChanged: onWeeksChanged,
                validator: (value) {
                  final n = int.tryParse(value.trim());
                  if (n == null || n < 1 || n > 52) return 'Usa 1 a 52.';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SheetTextField(
                controller: amountCtrl,
                label: 'Abono',
                keyboardType: TextInputType.number,
                validator: (value) {
                  final n = double.tryParse(value.trim());
                  if (n == null || n <= 0) return 'Monto invalido.';
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
              child: _SheetTextField(
                controller: penaltyCtrl,
                label: 'Multa',
                keyboardType: TextInputType.number,
                validator: (value) {
                  final n = double.tryParse(value.trim());
                  if (n == null || n < 0) return 'Monto invalido.';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SheetLabel(
                label: 'Inicio',
                child: InkWell(
                  onTap: onPickDate,
                  borderRadius: AppRadii.fieldRadius,
                  child: InputDecorator(
                    decoration: _inputDecoration(),
                    child: Text(
                      DateFormat('dd MMM yyyy', 'es_MX').format(startDate),
                      style: AppTextStyles.body.copyWith(fontSize: 13),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _InlineNotice(
          icon: Symbols.info,
          title: 'Orden fijo desde el inicio',
          body: 'Cada lugar representa la semana en la que esa clienta recibe.',
          color: AppColors.statusRouteFg,
        ),
      ],
    );
  }
}

class _BuilderSlots extends StatelessWidget {
  const _BuilderSlots({
    required this.slots,
    required this.selectedTurn,
    required this.clients,
    required this.clientSearchCtrl,
    required this.onSearchChanged,
    required this.onSelectTurn,
    required this.onAssignClient,
    required this.onClearClient,
  });

  final List<_TandaSlotDraft> slots;
  final int selectedTurn;
  final List<SellerTandaClient> clients;
  final TextEditingController clientSearchCtrl;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onSelectTurn;
  final ValueChanged<SellerTandaClient> onAssignClient;
  final ValueChanged<int> onClearClient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7FA),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Asignacion de lugares',
                  style: AppTextStyles.h2.copyWith(fontSize: 15),
                ),
              ),
              _SoftChip(
                icon: Symbols.flag,
                label: 'Lugar #$selectedTurn',
                color: AppColors.neniDeep,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: clientSearchCtrl,
            onChanged: onSearchChanged,
            decoration: _inputDecoration(
              hint: 'Buscar clienta por nombre o telefono',
              prefixIcon: const Icon(Symbols.search, size: 20),
            ),
          ),
          const SizedBox(height: 8),
          if (clients.isEmpty)
            Text(
              'No encontre clientas disponibles con esa busqueda.',
              style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
            )
          else
            SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: clients.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final client = clients[index];
                  return _ClientPickChip(
                    client: client,
                    onTap: () => onAssignClient(client),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          for (final slot in slots) ...[
            _SlotCard(
              slot: slot,
              selected: slot.turn == selectedTurn,
              onTap: () => onSelectTurn(slot.turn),
              onClear: slot.clientId == null
                  ? null
                  : () => onClearClient(slot.turn),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _EditTandaSheet extends StatefulWidget {
  const _EditTandaSheet({required this.tanda, required this.onSubmit});

  final SellerTanda tanda;
  final Future<void> Function(UpdateTandaRequest request) onSubmit;

  @override
  State<_EditTandaSheet> createState() => _EditTandaSheetState();
}

class _EditTandaSheetState extends State<_EditTandaSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _weeksCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _penaltyCtrl;
  late DateTime _startDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.tanda.displayName);
    _weeksCtrl = TextEditingController(
      text: widget.tanda.totalWeeks.toString(),
    );
    _amountCtrl = TextEditingController(
      text: widget.tanda.weeklyAmount.toStringAsFixed(0),
    );
    _penaltyCtrl = TextEditingController(
      text: widget.tanda.penaltyAmount.toStringAsFixed(0),
    );
    _startDate = widget.tanda.startDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weeksCtrl.dispose();
    _amountCtrl.dispose();
    _penaltyCtrl.dispose();
    super.dispose();
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
    setState(() => _saving = true);
    try {
      await widget.onSubmit(
        UpdateTandaRequest(
          id: widget.tanda.id,
          name: _nameCtrl.text.trim(),
          totalWeeks: int.parse(_weeksCtrl.text.trim()),
          weeklyAmount: double.parse(_amountCtrl.text.trim()),
          penaltyAmount: double.tryParse(_penaltyCtrl.text.trim()) ?? 0,
          startDate: _startDate,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHeader(
              title: 'Editar tanda',
              subtitle: 'Ajusta informacion general sin tocar los pagos.',
            ),
            const SizedBox(height: 16),
            _SheetTextField(
              controller: _nameCtrl,
              label: 'Nombre',
              validator: (value) =>
                  value.trim().isEmpty ? 'Escribe un nombre.' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SheetTextField(
                    controller: _weeksCtrl,
                    label: 'Semanas',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final n = int.tryParse(value.trim());
                      if (n == null || n < 1 || n > 52) return 'Usa 1 a 52.';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SheetTextField(
                    controller: _amountCtrl,
                    label: 'Abono',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final n = double.tryParse(value.trim());
                      if (n == null || n <= 0) return 'Monto invalido.';
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
                  child: _SheetTextField(
                    controller: _penaltyCtrl,
                    label: 'Multa',
                    keyboardType: TextInputType.number,
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
            const SizedBox(height: 18),
            PillButton(
              label: _saving ? 'Guardando...' : 'Guardar cambios',
              icon: Symbols.save,
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddParticipantSheet extends StatefulWidget {
  const _AddParticipantSheet({
    required this.tanda,
    required this.clients,
    required this.onSubmit,
  });

  final SellerTanda tanda;
  final List<SellerTandaClient> clients;
  final Future<void> Function(AddTandaParticipantRequest request) onSubmit;

  @override
  State<_AddParticipantSheet> createState() => _AddParticipantSheetState();
}

class _AddParticipantSheetState extends State<_AddParticipantSheet> {
  final _searchCtrl = TextEditingController();
  final _variantCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  SellerTandaClient? _selectedClient;
  int? _selectedTurn;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final turns = _openTurns;
    _selectedTurn = turns.isNotEmpty ? turns.first : null;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _variantCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  List<int> get _openTurns {
    final used = widget.tanda.participants
        .map((participant) => participant.assignedTurn)
        .toSet();
    return [
      for (var turn = 1; turn <= widget.tanda.totalWeeks; turn++)
        if (!used.contains(turn)) turn,
    ];
  }

  List<SellerTandaClient> get _availableClients {
    final used = widget.tanda.participants
        .map((participant) => participant.customerId)
        .toSet();
    final query = _searchCtrl.text.trim().toLowerCase();
    return widget.clients
        .where((client) {
          if (used.contains(client.id)) return false;
          return query.isEmpty || client.label.toLowerCase().contains(query);
        })
        .take(12)
        .toList();
  }

  Future<void> _submit() async {
    final client = _selectedClient;
    final turn = _selectedTurn;
    if (client == null || turn == null) return;
    setState(() => _saving = true);
    try {
      await widget.onSubmit(
        AddTandaParticipantRequest(
          tandaId: widget.tanda.id,
          customerId: client.id,
          assignedTurn: turn,
          variant: _variantCtrl.text.trim().isEmpty
              ? null
              : _variantCtrl.text.trim(),
          weeklyAmount: double.tryParse(_amountCtrl.text.trim()),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final openTurns = _openTurns;
    return _SheetScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHeader(
            title: 'Inscribir clienta',
            subtitle: 'Usa un lugar libre y agrega variante si aplica.',
          ),
          const SizedBox(height: 16),
          if (openTurns.isEmpty)
            const _EmptyPanel(
              icon: Symbols.flag,
              title: 'No hay lugares libres',
              body:
                  'Aumenta las semanas de la tanda antes de inscribir mas clientas.',
            )
          else ...[
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration(
                hint: 'Buscar clienta',
                prefixIcon: const Icon(Symbols.search, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final client in _availableClients)
                  ChoiceChip(
                    label: Text(client.label),
                    selected: client.id == _selectedClient?.id,
                    onSelected: (_) => setState(() => _selectedClient = client),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _selectedTurn,
              decoration: _inputDecoration(),
              items: openTurns
                  .map(
                    (turn) => DropdownMenuItem(
                      value: turn,
                      child: Text('Lugar $turn'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedTurn = value),
            ),
            const SizedBox(height: 12),
            _SheetTextField(
              controller: _variantCtrl,
              label: 'Variante opcional',
              hint: 'Color, talla o detalle',
            ),
            const SizedBox(height: 12),
            _SheetTextField(
              controller: _amountCtrl,
              label: 'Abono distinto opcional',
              hint: tandaMoney(widget.tanda.weeklyAmount),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 18),
            PillButton(
              label: _saving ? 'Inscribiendo...' : 'Inscribir clienta',
              icon: Symbols.person_add,
              onPressed: _saving || _selectedClient == null ? null : _submit,
            ),
          ],
        ],
      ),
    );
  }
}

class _ParticipantEditorSheet extends StatefulWidget {
  const _ParticipantEditorSheet({
    required this.tanda,
    required this.participant,
    required this.onSave,
    required this.onRemove,
  });

  final SellerTanda tanda;
  final SellerTandaParticipant participant;
  final Future<void> Function(_ParticipantEditResult result) onSave;
  final Future<void> Function() onRemove;

  @override
  State<_ParticipantEditorSheet> createState() =>
      _ParticipantEditorSheetState();
}

class _ParticipantEditorSheetState extends State<_ParticipantEditorSheet> {
  late final TextEditingController _turnCtrl;
  late final TextEditingController _variantCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _turnCtrl = TextEditingController(
      text: widget.participant.assignedTurn.toString(),
    );
    _variantCtrl = TextEditingController(
      text: widget.participant.variant ?? '',
    );
  }

  @override
  void dispose() {
    _turnCtrl.dispose();
    _variantCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final turn = int.tryParse(_turnCtrl.text.trim());
    if (turn == null || turn < 1 || turn > widget.tanda.totalWeeks) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        _ParticipantEditResult(turn: turn, variant: _variantCtrl.text),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHeader(
            title: widget.participant.displayName,
            subtitle: 'Ajusta turno o variante de esta participante.',
          ),
          const SizedBox(height: 16),
          _SheetTextField(
            controller: _turnCtrl,
            label: 'Turno',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _SheetTextField(
            controller: _variantCtrl,
            label: 'Variante',
            hint: 'Color, talla o detalle',
          ),
          const SizedBox(height: 18),
          PillButton(
            label: _saving ? 'Guardando...' : 'Guardar cambios',
            icon: Symbols.save,
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(height: 10),
          PillButton(
            label: 'Retirar participante',
            icon: Symbols.delete,
            variant: PillButtonVariant.ghost,
            onPressed: _saving ? null : widget.onRemove,
          ),
        ],
      ),
    );
  }
}

class _ReorderParticipantsSheet extends StatefulWidget {
  const _ReorderParticipantsSheet({
    required this.tanda,
    required this.onSubmit,
  });

  final SellerTanda tanda;
  final Future<void> Function(List<String> orderedIds) onSubmit;

  @override
  State<_ReorderParticipantsSheet> createState() =>
      _ReorderParticipantsSheetState();
}

class _ReorderParticipantsSheetState extends State<_ReorderParticipantsSheet> {
  late List<SellerTandaParticipant> _participants;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _participants = widget.tanda.sortedParticipants;
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await widget.onSubmit(_participants.map((item) => item.id).toList());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHeader(
            title: 'Reordenar turnos',
            subtitle: 'Arrastra para definir el nuevo orden de entrega.',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 420,
            child: ReorderableListView.builder(
              itemCount: _participants.length,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final item = _participants.removeAt(oldIndex);
                  _participants.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final participant = _participants[index];
                return _ReorderTile(
                  key: ValueKey(participant.id),
                  participant: participant,
                  newTurn: index + 1,
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          PillButton(
            label: _saving ? 'Guardando...' : 'Guardar nuevo orden',
            icon: Symbols.save,
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _ReorderTile extends StatelessWidget {
  const _ReorderTile({
    super.key,
    required this.participant,
    required this.newTurn,
  });

  final SellerTandaParticipant participant;
  final int newTurn;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _TurnBubble(turn: newTurn, late: false),
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
                Text(
                  participant.variant?.trim().isEmpty ?? true
                      ? 'Sin variante'
                      : participant.variant!.trim(),
                  style: AppTextStyles.subtitle.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          const Icon(Symbols.drag_indicator, color: AppColors.ink3),
        ],
      ),
    );
  }
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({required this.child});

  final Widget child;

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: child,
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.h1.copyWith(fontSize: 21)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: AppTextStyles.subtitle.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        IconButton(
          tooltip: 'Cerrar',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Symbols.close, size: 22),
        ),
      ],
    );
  }
}

class _SheetTextField extends StatelessWidget {
  const _SheetTextField({
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

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.selected,
    required this.onTap,
    required this.onClear,
  });

  final _TandaSlotDraft slot;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.neniDeep.withValues(alpha: 0.35)
                  : AppColors.line,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _TurnBubble(turn: slot.turn, late: false),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slot.clientName ?? 'Selecciona clienta',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: slot.clientId == null
                                ? AppColors.ink3
                                : AppColors.ink,
                          ),
                        ),
                        Text(
                          slot.clientId == null
                              ? 'Lugar obligatorio'
                              : 'Turno de entrega #${slot.turn}',
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onClear != null)
                    IconButton(
                      tooltip: 'Quitar clienta',
                      onPressed: onClear,
                      icon: const Icon(Symbols.close, size: 18),
                    ),
                ],
              ),
              if (slot.clientId != null) ...[
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: slot.variant,
                  onChanged: (value) => slot.variant = value,
                  style: AppTextStyles.body.copyWith(fontSize: 12.5),
                  decoration: _inputDecoration(
                    hint: 'Variante opcional: color, talla, modelo',
                    dense: true,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientPickChip extends StatelessWidget {
  const _ClientPickChip({required this.client, required this.onTap});

  final SellerTandaClient client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 210,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              _InitialBadge(label: client.name),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  client.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitialBadge extends StatelessWidget {
  const _InitialBadge({required this.label});

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

class _TurnBubble extends StatelessWidget {
  const _TurnBubble({required this.turn, required this.late});

  final int turn;
  final bool late;

  @override
  Widget build(BuildContext context) {
    final color = late ? AppColors.statusPendingFg : AppColors.neniDeep;
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        turn.toString(),
        style: AppTextStyles.body.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _TinyMetric extends StatelessWidget {
  const _TinyMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF3F6),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 9.5,
              color: AppColors.ink3,
              fontWeight: FontWeight.w700,
            ),
          ),
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

class _ScoreItem extends StatelessWidget {
  const _ScoreItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.subtitle.copyWith(
            fontSize: 10,
            color: AppColors.ink3,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadii.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.chip.copyWith(fontSize: 10.5, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.tanda});

  final SellerTanda tanda;

  @override
  Widget build(BuildContext context) {
    final active = tanda.isActive;
    return _SoftChip(
      icon: active ? Symbols.check_circle : Symbols.flag,
      label: active ? 'Activa' : 'Finalizada',
      color: active ? AppColors.statusDeliveredFg : AppColors.ink2,
    );
  }
}

class _PaymentStateChip extends StatelessWidget {
  const _PaymentStateChip({required this.paid, required this.late});

  final bool paid;
  final bool late;

  @override
  Widget build(BuildContext context) {
    if (paid) {
      return const _SoftChip(
        icon: Symbols.check_circle,
        label: 'Pagado',
        color: AppColors.statusDeliveredFg,
      );
    }
    if (late) {
      return const _SoftChip(
        icon: Symbols.warning,
        label: 'Atraso',
        color: AppColors.statusPendingFg,
      );
    }
    return const _SoftChip(
      icon: Symbols.payments,
      label: 'Cobrar',
      color: AppColors.neniDeep,
    );
  }
}

class _MiniPillAction extends StatelessWidget {
  const _MiniPillAction({
    required this.label,
    required this.icon,
    this.onTap,
    this.muted = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = muted ? AppColors.ink2 : AppColors.neniDeep;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.pillRadius,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadii.pillRadius,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: AppTextStyles.chip.copyWith(
                    fontSize: 10.5,
                    color: color,
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

class _GhostAction extends StatelessWidget {
  const _GhostAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF3F6),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppColors.neniDeep),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.buttonSmall.copyWith(
                  fontSize: 12,
                  color: AppColors.neniDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.tooltip, required this.icon, this.onTap});

  final String tooltip;
  final IconData icon;
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
            borderRadius: BorderRadius.circular(13),
            child: Ink(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFBF3F6),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.line),
              ),
              child: Icon(icon, size: 19, color: AppColors.neniDeep),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.h2.copyWith(fontSize: 16)),
          Text(
            label,
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 9.5,
              color: AppColors.ink3,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
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

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
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
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: AppRadii.softRadius,
        border: Border.all(color: AppColors.neniDeep.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: AppColors.neniDeep),
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

class _CommandError extends StatelessWidget {
  const _CommandError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 90, 24, 24),
      children: [
        _EmptyPanel(
          icon: Symbols.cloud_off,
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

InputDecoration _inputDecoration({
  String? hint,
  Widget? prefixIcon,
  bool dense = false,
}) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: prefixIcon,
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

class _TandaSlotDraft {
  _TandaSlotDraft({required this.turn});

  int turn;
  int? clientId;
  String? clientName;
  String variant = '';
}

class _ParticipantEditResult {
  const _ParticipantEditResult({required this.turn, required this.variant});

  final int turn;
  final String variant;
}
