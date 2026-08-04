import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';
import '../../labels/data/label_template_models.dart';
import '../../labels/services/label_print_service.dart';
import '../../labels/widgets/label_widgets.dart';
import '../../subscription/data/subscription_repository.dart';
import '../data/inventory_models.dart';
import '../data/inventory_repository.dart';
import '../widgets/inventory_widgets.dart';
import 'inventory_sheets.dart';

/// Detalle de una caja: hero, estadísticas, NFC, artículos con stepper,
/// movimientos recientes y acciones de conteo/traspaso/etiquetas.
class InventoryBoxScreen extends ConsumerStatefulWidget {
  const InventoryBoxScreen({super.key, required this.boxId});

  final String boxId;

  @override
  ConsumerState<InventoryBoxScreen> createState() =>
      _InventoryBoxScreenState();
}

class _InventoryBoxScreenState extends ConsumerState<InventoryBoxScreen> {
  bool _busy = false;

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

  Future<void> _refresh() async {
    ref.invalidate(inventoryBoxProvider(widget.boxId));
    ref.invalidate(inventoryBoxesProvider);
  }

  Future<void> _editBox(InventoryBox box) async {
    if (_busy) return;
    final result = await showInventoryBoxFormSheet(
      context,
      title: 'Editar caja',
      code: box.code,
      name: box.name,
      location: box.location,
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .updateBox(box.id, code: result.code, name: result.name, location: result.location);
      await _refresh();
    } catch (_) {
      _message('No pudimos guardar los cambios.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addItem(InventoryBox box) async {
    if (_busy) return;
    final result = await showInventoryItemFormSheet(context);
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .addItem(
            box.id,
            name: result.name,
            variant: result.variant,
            barcode: result.barcode,
            quantity: result.quantity,
          );
      await _refresh();
    } catch (_) {
      _message('No pudimos guardar este artículo.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _adjust(InventoryBox box, InventoryItem item, int delta) async {
    if (_busy || item.quantity + delta < 0) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .adjustItem(item.id, delta);
      await _refresh();
    } catch (_) {
      _message('No pudimos actualizar la existencia.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeCount(InventoryBox box) async {
    if (_busy || box.items.isEmpty) return;
    final items = await showInventoryCountSheet(context, box: box);
    if (items == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .completeCount(box.id, items, note: 'Conteo físico desde Nenis');
      await _refresh();
      _message('Conteo físico guardado en la bitácora.');
    } catch (_) {
      _message('No pudimos guardar el conteo físico.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _transferItem(InventoryBox box, InventoryItem item) async {
    if (_busy || item.quantity == 0) return;
    final boxes = await ref.read(inventoryBoxesProvider.future);
    if (!mounted) return;
    final destinations = boxes.where((b) => b.id != box.id).toList();
    if (destinations.isEmpty) {
      _message('Crea otra caja antes de mover mercancía.', error: true);
      return;
    }
    final transfer = await showInventoryTransferSheet(
      context,
      item: item,
      destinations: destinations,
    );
    if (transfer == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .transfer(
            sourceBoxId: box.id,
            destinationBoxId: transfer.destinationId,
            itemId: item.id,
            quantity: transfer.quantity,
            note: transfer.note,
          );
      await _refresh();
      _message('Mercancía movida y registrada en la bitácora.');
    } catch (_) {
      _message('No pudimos mover este artículo.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bindNfc(InventoryBox box) async {
    if (_busy) return;
    final updated = await showInventoryNfcSheet(context, ref: ref, box: box);
    if (updated == null || !mounted) return;
    await _refresh();
    _message('Tarjeta NFC vinculada. Acércala para abrir esta caja.');
  }

  Future<void> _printLabel({
    required LabelTemplateKind kind,
    required String targetId,
    required String name,
  }) async {
    if (_busy) return;
    final options = await showInventoryLabelSheet(
      context,
      subject: name,
    );
    if (options == null || !mounted) return;

    setState(() => _busy = true);
    InventoryLabelPrint? print;
    try {
      print = await ref
          .read(inventoryRepositoryProvider)
          .createLabelPrint(
            kind: kind,
            targetId: targetId,
            mediaSize: options.mediaSize,
            copies: options.copies,
          );
      final handedOff = await const LabelPrintService().handOffData(
        designJson: print.templateVersion.designJson,
        mediaSize: print.mediaSize,
        assets: print.assets,
        documents: [print.data],
        copies: print.copies,
        name: 'Etiqueta · $name',
      );
      await ref
          .read(inventoryRepositoryProvider)
          .updateLabelPrintStatus(
            print.id,
            handedOff ? 'SentToSystem' : 'Canceled',
          );
      if (mounted) {
        _message(
          handedOff
              ? 'Etiqueta entregada al selector de impresión.'
              : 'Cancelaste la impresión antes de enviarla.',
        );
      }
    } catch (_) {
      if (print != null) {
        try {
          await ref
              .read(inventoryRepositoryProvider)
              .updateLabelPrintStatus(
                print.id,
                'Failed',
                failureReason:
                    'No se pudo preparar o entregar la etiqueta.',
              );
        } catch (_) {}
      }
      _message('No pudimos preparar esta etiqueta para imprimir.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = ref.watch(inventoryBoxProvider(widget.boxId));
    final session = ref.watch(authControllerProvider).asData?.value;
    final canManageLabels = session?.canManageLabels ?? false;
    final activePlan = ref
        .watch(subscriptionStatusProvider)
        .asData
        ?.value
        .effectivePlan;
    final unlocked =
        activePlan == null || activePlan == 'Pro' || activePlan == 'Elite';

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: box.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: PillButton(
                label: 'Reintentar',
                onPressed: () =>
                    ref.invalidate(inventoryBoxProvider(widget.boxId)),
              ),
            ),
            data: (value) => _BoxBody(
              box: value,
              busy: _busy,
              unlocked: unlocked,
              canManageLabels: canManageLabels,
              onBack: () => context.canPop() ? context.pop() : context.go('/seller/inventory'),
              onEdit: () => _editBox(value),
              onAdd: () => _addItem(value),
              onAdjust: (item, delta) => _adjust(value, item, delta),
              onCount: () => _completeCount(value),
              onTransfer: (item) => _transferItem(value, item),
              onBind: () => _bindNfc(value),
              onPrintBox: () => _printLabel(
                kind: LabelTemplateKind.inventoryBox,
                targetId: value.id,
                name: value.code,
              ),
              onPrintItem: (item) => _printLabel(
                kind: LabelTemplateKind.inventoryItem,
                targetId: item.id,
                name: item.name,
              ),
              onDesign: () => context.push(
                '/seller/labels/editor?kind=InventoryBox&mediaSize=Square50x50',
              ),
              onLog: () => context.push(
                '/seller/inventory/log?box=${value.id}&code=${Uri.encodeComponent(value.code)}',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BoxBody extends StatelessWidget {
  const _BoxBody({
    required this.box,
    required this.busy,
    required this.unlocked,
    required this.canManageLabels,
    required this.onBack,
    required this.onEdit,
    required this.onAdd,
    required this.onAdjust,
    required this.onCount,
    required this.onTransfer,
    required this.onBind,
    required this.onPrintBox,
    required this.onPrintItem,
    required this.onDesign,
    required this.onLog,
  });

  final InventoryBox box;
  final bool busy;
  final bool unlocked;
  final bool canManageLabels;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onAdd;
  final void Function(InventoryItem, int) onAdjust;
  final VoidCallback onCount;
  final ValueChanged<InventoryItem> onTransfer;
  final VoidCallback onBind;
  final VoidCallback onPrintBox;
  final ValueChanged<InventoryItem> onPrintItem;
  final VoidCallback onDesign;
  final VoidCallback onLog;

  List<InventoryMovement> get _recent {
    final sorted = [...box.movements]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return sorted.take(5).toList();
  }

  int get _differencesToday {
    final today = DateTime.now();
    return box.movements
        .where(
          (m) =>
              m.type == 'CountAdjustment' &&
              m.quantityDelta != 0 &&
              m.occurredAt.year == today.year &&
              m.occurredAt.month == today.month &&
              m.occurredAt.day == today.day,
        )
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
          child: Row(
            children: [
              PillIconButton(icon: Icons.adaptive.arrow_back, onPressed: onBack),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Caja ${box.code}',
                      style: AppTextStyles.h1.copyWith(fontSize: 23),
                    ),
                    Text(
                      box.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subtitle,
                    ),
                  ],
                ),
              ),
              PillIconButton(
                icon: Symbols.edit_square,
                onPressed: busy ? null : onEdit,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
            children: [
              InventoryHero(
                eyebrow: box.location ?? 'Sin ubicación',
                headline: box.code,
                sub: '${box.name} · actualizada ${timeAgo(box.updatedAt)}',
                trailing: MiniLabelPreview(format: MiniLabelFormat.square50, code: box.code),
                chips: [
                  InventoryGhostChip(
                    icon: Symbols.nfc,
                    label: box.isNfcBound ? 'NFC vinculada' : 'Sin NFC',
                  ),
                  if (canManageLabels)
                    InventoryGhostChip(
                      icon: Symbols.design_services,
                      label: 'Diseñar etiqueta',
                      onTap: onDesign,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              InventoryStatRow(
                stats: [
                  (value: '${box.articleTypesCount}', label: 'Artículos'),
                  (value: '${box.totalUnits}', label: 'Piezas'),
                  (value: '${box.movementCount}', label: 'Movimientos'),
                  (value: '$_differencesToday', label: 'Diferencias hoy'),
                ],
              ),
              const SizedBox(height: 12),
              InventoryNfcCard(
                bound: box.isNfcBound,
                uid: box.nfcTagUid,
                actionLabel: box.isNfcBound ? 'Reprogramar' : 'Vincular',
                onAction: busy ? () {} : onBind,
              ),
              const SizedBox(height: 16),
              InventorySectionHeader(
                icon: Symbols.inventory_2,
                title: 'Artículos (${box.items.length})',
                actionLabel: '+ Agregar',
                onAction: busy ? null : onAdd,
              ),
              const SizedBox(height: 9),
              if (box.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      'Esta caja aún no tiene artículos.',
                      style: AppTextStyles.subtitle,
                    ),
                  ),
                )
              else
                for (final item in box.items) ...[
                  InventoryItemRow(
                    item: item,
                    busy: busy,
                    onAdjust: (delta) => onAdjust(item, delta),
                    onPrint: () => onPrintItem(item),
                    onTransfer: () => onTransfer(item),
                  ),
                  const SizedBox(height: 9),
                ],
              const SizedBox(height: 7),
              InventorySectionHeader(
                icon: Symbols.history,
                title: 'Movimientos recientes',
                actionLabel: 'Ver bitácora',
                onAction: onLog,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.lineSoft),
                ),
                child: _recent.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: Text(
                            'Aún no hay movimientos registrados.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.ink2,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (var index = 0; index < _recent.length; index++) ...[
                            InventoryMovementRow(
                              movement: _recent[index],
                              meta:
                                  '${_recent[index].itemName ?? 'Caja ${box.code}'}'
                                  ' · ${_recent[index].performedBy} · '
                                  '${dayTime(_recent[index].occurredAt)}',
                              showAfter: true,
                              padding: EdgeInsets.symmetric(
                                vertical: index == 0 ? 6 : 8,
                              ),
                            ),
                            if (index < _recent.length - 1)
                              const Divider(height: 1, color: AppColors.line),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
        _DockedBox(
          box: box,
          busy: busy,
          unlocked: unlocked,
          onCount: onCount,
          onPrintBox: onPrintBox,
          onAdd: onAdd,
        ),
      ],
    );
  }
}

class _DockedBox extends StatelessWidget {
  const _DockedBox({
    required this.box,
    required this.busy,
    required this.unlocked,
    required this.onCount,
    required this.onPrintBox,
    required this.onAdd,
  });

  final InventoryBox box;
  final bool busy;
  final bool unlocked;
  final VoidCallback onCount;
  final VoidCallback onPrintBox;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final canCount = !busy && box.items.isNotEmpty;
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
                      '${box.articleTypesCount} '
                      '${box.articleTypesCount == 1 ? 'artículo' : 'artículos'}'
                      ' · ${box.totalUnits} '
                      '${box.totalUnits == 1 ? 'pieza' : 'piezas'}',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    'Bitácora y conteo disponibles',
                    style: AppTextStyles.subtitle.copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: 'Conteo',
                    icon: Symbols.fact_check,
                    onPressed: canCount ? onCount : null,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: PillButton(
                    label: 'Imprimir',
                    icon: Symbols.print,
                    onPressed: busy || !unlocked ? null : onPrintBox,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            PillButton(
              label: 'Agregar artículo',
              icon: Symbols.add,
              onPressed: busy ? null : onAdd,
            ),
          ],
        ),
      ),
    );
  }
}
