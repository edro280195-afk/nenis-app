import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/deeplinks/deep_link_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';
import '../../labels/screens/label_print_options_sheet.dart';
import '../../subscription/data/subscription_repository.dart';
import '../data/inventory_models.dart';
import '../data/inventory_repository.dart';
import '../widgets/inventory_widgets.dart';
import 'inventory_sheets.dart';

enum _BoxFilter { all, nfc, noNfc }

/// Resumen de "Mi Bodega": hero con totales, búsqueda, filtros por NFC y
/// tarjetas de caja. Al tocar una caja abre [InventoryBoxScreen].
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key, this.tagToken});

  /// Token de un deep link NFC (https://app.nenisapp.com/caja/…).
  final String? tagToken;

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  late final TextEditingController _search = TextEditingController();
  _BoxFilter _filter = _BoxFilter.all;
  String? _loadedToken;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openTag());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? AppColors.liveRed : AppColors.ink,
          content: Text(text),
        ),
      );
  }

  Future<void> _openTag() async {
    final token = widget.tagToken;
    if (token == null || token == _loadedToken || !mounted) return;
    _loadedToken = token;
    setState(() => _busy = true);
    try {
      final box = await ref
          .read(inventoryRepositoryProvider)
          .getBoxByToken(token);
      ref.read(pendingInventoryDeepLinkProvider.notifier).clear();
      if (!mounted) return;
      await context.push('/seller/inventory/box/${box.id}');
    } catch (_) {
      if (mounted) {
        _message(
          'La tarjeta no pertenece a una caja activa de esta tienda.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createBox() async {
    if (_busy) return;
    final result = await showInventoryBoxFormSheet(
      context,
      title: 'Nueva caja',
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final box = await ref
          .read(inventoryRepositoryProvider)
          .createBox(code: result.code, name: result.name, location: result.location);
      ref.invalidate(inventoryBoxesProvider);
      if (!mounted) return;
      await context.push('/seller/inventory/box/${box.id}');
    } catch (_) {
      _message(
        'No pudimos crear la caja. Revisa que el código sea único.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<InventoryBoxSummary> _visible(List<InventoryBoxSummary> boxes) {
    final query = _search.text.trim().toLowerCase();
    return boxes.where((box) {
      final matchesQuery = query.isEmpty ||
          box.code.toLowerCase().contains(query) ||
          box.name.toLowerCase().contains(query) ||
          (box.location?.toLowerCase().contains(query) ?? false);
      if (!matchesQuery) return false;
      return switch (_filter) {
        _BoxFilter.all => true,
        _BoxFilter.nfc => box.isNfcBound,
        _BoxFilter.noNfc => !box.isNfcBound,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final boxes = ref.watch(inventoryBoxesProvider);
    final session = ref.watch(authControllerProvider).asData?.value;
    final activePlan = ref
        .watch(subscriptionStatusProvider)
        .asData
        ?.value
        .effectivePlan;
    final unlocked =
        activePlan == null || activePlan == 'Pro' || activePlan == 'Elite';
    final canManageLabels = session?.canManageLabels ?? false;

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
                    if (context.canPop())
                      PillIconButton(
                        icon: Icons.adaptive.arrow_back,
                        onPressed: () => context.pop(),
                      )
                    else
                      const SizedBox.shrink(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mi bodega',
                            style: AppTextStyles.h1.copyWith(fontSize: 23),
                          ),
                          Text(
                            'Cajas, etiquetas y tarjetas NFC',
                            style: AppTextStyles.subtitle,
                          ),
                        ],
                      ),
                    ),
                    PillIconButton(
                      icon: Symbols.add_box,
                      onPressed: _busy || !unlocked ? null : _createBox,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: !unlocked
                    ? const Center(child: LabelFeatureLockedView())
                    : boxes.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: (_, _) => Center(
                          child: PillButton(
                            label: 'Reintentar',
                            onPressed: () =>
                                ref.invalidate(inventoryBoxesProvider),
                          ),
                        ),
                        data: (items) => _ResumenBody(
                          boxes: _visible(items),
                          allCount: items.length,
                          nfcCount: items.where((b) => b.isNfcBound).length,
                          noNfcCount:
                              items.where((b) => !b.isNfcBound).length,
                          filter: _filter,
                          query: _search.text,
                          onSearchChanged: (value) => setState(() {}),
                          onFilterChanged: (filter) =>
                              setState(() => _filter = filter),
                          onBoxTap: (box) => context
                              .push('/seller/inventory/box/${box.id}'),
                          onCreateBox: _createBox,
                          busy: _busy,
                          canDesignLabels: canManageLabels,
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

class _ResumenBody extends StatelessWidget {
  const _ResumenBody({
    required this.boxes,
    required this.allCount,
    required this.nfcCount,
    required this.noNfcCount,
    required this.filter,
    required this.query,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onBoxTap,
    required this.onCreateBox,
    required this.busy,
    required this.canDesignLabels,
  });

  final List<InventoryBoxSummary> boxes;
  final int allCount;
  final int nfcCount;
  final int noNfcCount;
  final _BoxFilter filter;
  final String query;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_BoxFilter> onFilterChanged;
  final ValueChanged<InventoryBoxSummary> onBoxTap;
  final VoidCallback onCreateBox;
  final bool busy;
  final bool canDesignLabels;

  @override
  Widget build(BuildContext context) {
    final articleTypes = boxes.fold<int>(
      0,
      (sum, box) => sum + box.articleTypesCount,
    );
    final filteredByNfc =
        filter == _BoxFilter.all
        ? boxes
        : boxes
              .where((b) =>
                  filter == _BoxFilter.nfc ? b.isNfcBound : !b.isNfcBound)
              .toList();
    final hasBoxes = filteredByNfc.isNotEmpty;
    final onlyNfcLabel = filter == _BoxFilter.noNfc ? 'Vincular NFC' : 'NFC';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
            children: [
              InventoryHero(
                eyebrow: 'En bodega ahora',
                headline: _formatThousands(
                  filteredByNfc.fold(0, (sum, b) => sum + b.totalUnits),
                ),
                headlineSuffix: 'piezas',
                sub: '${_plural(articleTypes, 'artículo', 'artículos')} '
                    'repartidos en ${_plural(filteredByNfc.length, 'caja', 'cajas')}',
                chips: [
                  InventoryGhostChip(
                    icon: Symbols.schedule,
                    label: boxes.isEmpty
                        ? 'Aún sin cajas'
                        : 'Actualizado ${timeAgo(_newestUpdate())}',
                  ),
                  InventoryGhostChip(
                    icon: Symbols.nfc,
                    label: onlyNfcLabel,
                    onTap: () => onFilterChanged(
                      filter == _BoxFilter.noNfc
                          ? _BoxFilter.all
                          : _BoxFilter.noNfc,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SearchField(
                query: query,
                onChanged: onSearchChanged,
              ),
              const SizedBox(height: 12),
              InventoryStatRow(
                stats: [
                  (value: '$allCount', label: 'Cajas'),
                  (value: _formatThousands(
                    boxes.fold(0, (sum, b) => sum + b.articleTypesCount),
                  ), label: 'Artículos'),
                  (value: '$noNfcCount', label: 'Sin NFC'),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InventoryFilterChip(
                    label: 'Todas · $allCount',
                    selected: filter == _BoxFilter.all,
                    onTap: () => onFilterChanged(_BoxFilter.all),
                  ),
                  InventoryFilterChip(
                    label: 'Con NFC · $nfcCount',
                    selected: filter == _BoxFilter.nfc,
                    onTap: () => onFilterChanged(_BoxFilter.nfc),
                  ),
                  InventoryFilterChip(
                    label: 'Sin NFC · $noNfcCount',
                    selected: filter == _BoxFilter.noNfc,
                    onTap: () => onFilterChanged(_BoxFilter.noNfc),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InventorySectionHeader(
                icon: Symbols.inventory_2,
                title: _plural(filteredByNfc.length, 'caja', 'cajas'),
                actionLabel: canDesignLabels ? 'Diseñar' : null,
                onAction: canDesignLabels
                    ? () => context.push(
                        '/seller/labels/editor?kind=InventoryBox&mediaSize=Square50x50',
                      )
                    : null,
              ),
              if (hasBoxes) ...[
                const SizedBox(height: 9),
                for (final box in filteredByNfc) ...[
                  InventoryBoxCard(box: box, onTap: () => onBoxTap(box)),
                  const SizedBox(height: 9),
                ],
              ] else ...[
                const SizedBox(height: 20),
                const _EmptyResumen(),
              ],
            ],
          ),
        ),
        _DockedResumen(
          boxesCount: filteredByNfc.length,
          nfcCount: filteredByNfc.where((b) => b.isNfcBound).length,
          pendingNfc: noNfcCount,
          onNewBox: onCreateBox,
          busy: busy,
        ),
      ],
    );
  }

  DateTime _newestUpdate() {
    var newest = DateTime.fromMillisecondsSinceEpoch(0);
    for (final box in boxes) {
      if (box.updatedAt.isAfter(newest)) newest = box.updatedAt;
    }
    return newest;
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.query, required this.onChanged});

  final String query;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.small,
      ),
      child: TextField(
        onChanged: onChanged,
        decoration: const InputDecoration(
          hintText: 'Buscar caja, artículo o código…',
          prefixIcon: Icon(Symbols.search, size: 20, color: AppColors.ink3),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

class _EmptyResumen extends StatelessWidget {
  const _EmptyResumen();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Icon(
            Symbols.inventory_2,
            size: 54,
            color: AppColors.lavender,
          ),
          const SizedBox(height: 13),
          Text('Todo tiene su cajita', style: AppTextStyles.h2),
          const SizedBox(height: 6),
          Text(
            'Crea una caja para organizar tu mercancía y vincular sus tarjetas NFC.',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle,
          ),
        ],
      ),
    );
  }
}

class _DockedResumen extends StatelessWidget {
  const _DockedResumen({
    required this.boxesCount,
    required this.nfcCount,
    required this.pendingNfc,
    required this.onNewBox,
    required this.busy,
  });

  final int boxesCount;
  final int nfcCount;
  final int pendingNfc;
  final VoidCallback onNewBox;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCream,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$boxesCount ${boxesCount == 1 ? 'caja' : 'cajas'} · '
                      '$nfcCount con tarjeta NFC',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '$pendingNfc '
                    '${pendingNfc == 1 ? 'pendiente' : 'pendientes'} de vincular',
                    style: AppTextStyles.subtitle.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            PillButton(
              label: 'Nueva caja',
              icon: Symbols.add_box,
              onPressed: busy ? null : onNewBox,
            ),
          ],
        ),
      ),
    );
  }
}

String _plural(int count, String singular, String plural) =>
    '$count ${count == 1 ? singular : plural}';

String _formatThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}
