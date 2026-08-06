import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';
import '../data/inventory_repository.dart';
import '../widgets/inventory_widgets.dart';

enum _LogFilter { all, entradas, salidas, ajustes, traspasos, conteos }

/// Bitácora de la bodega: timeline de todos los movimientos con filtros por
/// tipo. Si [boxId] no es nulo, muestra solo los de esa caja.
class InventoryLogScreen extends ConsumerStatefulWidget {
  const InventoryLogScreen({super.key, this.boxId, this.boxCode});

  final String? boxId;
  final String? boxCode;

  @override
  ConsumerState<InventoryLogScreen> createState() =>
      _InventoryLogScreenState();
}

class _InventoryLogScreenState extends ConsumerState<InventoryLogScreen> {
  _LogFilter _filter = _LogFilter.all;
  final ScrollController _scrollController = ScrollController();

  static const Set<String> _entradas = {'InitialCount', 'Added', 'TransferIn'};
  static const Set<String> _salidas = {'Removed', 'TransferOut'};
  static const Set<String> _traspasos = {'TransferOut', 'TransferIn'};

  InventoryLogQuery get _query =>
      (boxId: widget.boxId, boxCode: widget.boxCode);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(inventoryLogProvider(_query).notifier).loadMore();
    }
  }

  bool _matches(InventoryLogEntry entry) {
    final type = entry.movement.type;
    return switch (_filter) {
      _LogFilter.all => true,
      _LogFilter.entradas => _entradas.contains(type),
      _LogFilter.salidas => _salidas.contains(type),
      _LogFilter.ajustes => type == 'Adjusted',
      _LogFilter.traspasos => _traspasos.contains(type),
      _LogFilter.conteos => type == 'CountAdjustment',
    };
  }

  @override
  Widget build(BuildContext context) {
    final logState = ref.watch(inventoryLogProvider(_query));
    final entries = logState.entries.where(_matches).toList();

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                child: Row(
                  children: [
                    PillIconButton(
                      icon: Icons.adaptive.arrow_back,
                      onPressed: () => context.canPop() ? context.pop() : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bitácora',
                            style: AppTextStyles.h1.copyWith(fontSize: 23),
                          ),
                          Text(
                            widget.boxCode == null
                                ? 'Toda la bodega · ${logState.total > 0 ? '${logState.total} movimientos' : 'todo cambio queda registrado'}'
                                : 'Caja ${widget.boxCode} · ${logState.total > 0 ? '${logState.total} movimientos' : 'todo cambio queda registrado'}',
                            style: AppTextStyles.subtitle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (logState.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (logState.error != null && entries.isEmpty) {
                      return Center(
                        child: PillButton(
                          label: 'Reintentar',
                          onPressed: () => ref
                              .read(inventoryLogProvider(_query).notifier)
                              .refresh(),
                        ),
                      );
                    }
                    if (entries.isEmpty) {
                      return const _EmptyLog();
                    }
                    return Column(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 2,
                          ),
                          child: Row(
                            children: [
                              for (final filter in _LogFilter.values) ...[
                                InventoryFilterChip(
                                  label: switch (filter) {
                                    _LogFilter.all => 'Todos',
                                    _LogFilter.entradas => 'Entradas',
                                    _LogFilter.salidas => 'Salidas',
                                    _LogFilter.ajustes => 'Ajustes',
                                    _LogFilter.traspasos => 'Traspasos',
                                    _LogFilter.conteos => 'Conteos',
                                  },
                                  selected: _filter == filter,
                                  onTap: () =>
                                      setState(() => _filter = filter),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () => ref
                                .read(inventoryLogProvider(_query).notifier)
                                .refresh(),
                            child: ListView(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                6,
                                18,
                                28,
                              ),
                              children: [
                                _Timeline(entries: entries),
                                if (logState.isLoadingMore) ...[
                                  const SizedBox(height: 16),
                                  const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                Center(
                                  child: Text(
                                    'Los traspasos quedan registrados en la '
                                    'caja de origen y en la de destino.',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.subtitle.copyWith(
                                      fontSize: 9.5,
                                      color: AppColors.ink3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries});

  final List<InventoryLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 19,
          top: 24,
          bottom: 18,
          child: Container(width: 2, color: AppColors.line),
        ),
        Column(
          children: [
            for (final entry in entries)
              _TimelineEntry(entry: entry),
          ],
        ),
      ],
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.entry});

  final InventoryLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final movement = entry.movement;
    final view = inventoryMovementView(movement);
    final label = movement.itemName == null
        ? view.label
        : '${view.label} · ${movement.itemName}';
    final meta = [
      entry.boxCode,
      movement.performedBy,
      dayTime(movement.occurredAt),
      if (movement.note != null && movement.note!.isNotEmpty) movement.note!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: view.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(view.icon, size: 20, color: view.foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subtitle.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: view.pillBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    view.pillText,
                    style: AppTextStyles.chip.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: view.pillForeground,
                    ),
                  ),
                ),
                if (view.after != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    view.after!,
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 9,
                      color: AppColors.ink3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLog extends StatelessWidget {
  const _EmptyLog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.history, size: 54, color: AppColors.lavender),
            const SizedBox(height: 13),
            Text('Aún no hay movimientos', style: AppTextStyles.h2),
            const SizedBox(height: 6),
            Text(
              'Entradas, salidas, ajustes, traspasos y conteos aparecerán aquí.',
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle,
            ),
          ],
        ),
      ),
    );
  }
}
