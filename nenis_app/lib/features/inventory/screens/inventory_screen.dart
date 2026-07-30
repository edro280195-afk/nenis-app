import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/deeplinks/deep_link_service.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';
import '../data/inventory_models.dart';
import '../data/inventory_repository.dart';
import '../services/inventory_nfc_service.dart';
import '../../labels/data/label_print_models.dart';
import '../../labels/data/label_template_models.dart';
import '../../labels/screens/label_print_options_sheet.dart';
import '../../labels/services/label_print_service.dart';
import '../../subscription/data/subscription_repository.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key, this.tagToken});

  final String? tagToken;

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  InventoryBox? _box;
  bool _busy = false;
  String? _loadedToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openTag());
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

  Future<void> _openBox(String id) async {
    setState(() => _busy = true);
    try {
      final box = await ref.read(inventoryRepositoryProvider).getBox(id);
      if (mounted) setState(() => _box = box);
    } catch (_) {
      _message('No pudimos abrir esta caja.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openTag() async {
    final token = widget.tagToken;
    if (token == null || token == _loadedToken) return;

    _loadedToken = token;
    setState(() => _busy = true);
    try {
      final box = await ref
          .read(inventoryRepositoryProvider)
          .getBoxByToken(token);
      ref.read(pendingInventoryDeepLinkProvider.notifier).clear();
      if (mounted) setState(() => _box = box);
    } catch (_) {
      _message(
        'La tarjeta no pertenece a una caja activa de esta tienda.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createBox() async {
    final result = await _boxForm('Nueva caja');
    if (result == null) return;

    setState(() => _busy = true);
    try {
      final box = await ref
          .read(inventoryRepositoryProvider)
          .createBox(code: result.$1, name: result.$2, location: result.$3);
      ref.invalidate(inventoryBoxesProvider);
      if (mounted) setState(() => _box = box);
    } catch (_) {
      _message(
        'No pudimos crear la caja. Revisa que el código sea único.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addItem() async {
    final box = _box;
    if (box == null) return;
    final result = await _itemForm();
    if (result == null) return;

    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(inventoryRepositoryProvider)
          .addItem(
            box.id,
            name: result.$1,
            variant: result.$2,
            barcode: result.$3,
            quantity: result.$4,
          );
      ref.invalidate(inventoryBoxesProvider);
      if (mounted) setState(() => _box = updated);
    } catch (_) {
      _message('No pudimos guardar este artículo.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _adjust(InventoryItem item, int delta) async {
    if (_busy || item.quantity + delta < 0) return;

    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(inventoryRepositoryProvider)
          .adjustItem(item.id, delta);
      ref.invalidate(inventoryBoxesProvider);
      if (mounted) setState(() => _box = updated);
    } catch (_) {
      _message('No pudimos actualizar la existencia.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeCount() async {
    final box = _box;
    if (box == null || box.items.isEmpty || _busy) return;
    final items = await _countForm(box);
    if (items == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(inventoryRepositoryProvider)
          .completeCount(box.id, items, note: 'Conteo físico desde Nenis');
      ref.invalidate(inventoryBoxesProvider);
      if (mounted) {
        setState(() => _box = updated);
        _message('Conteo físico guardado en la bitácora.');
      }
    } catch (_) {
      _message('No pudimos guardar el conteo físico.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _transferItem(InventoryItem item) async {
    final sourceBox = _box;
    if (sourceBox == null || _busy || item.quantity == 0) return;
    final boxes = await ref.read(inventoryBoxesProvider.future);
    final destinations = boxes.where((box) => box.id != sourceBox.id).toList();
    if (destinations.isEmpty) {
      _message('Crea otra caja antes de mover mercancía.', error: true);
      return;
    }
    final transfer = await _transferForm(item, destinations);
    if (transfer == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .transfer(
            sourceBoxId: sourceBox.id,
            destinationBoxId: transfer.destinationId,
            itemId: item.id,
            quantity: transfer.quantity,
            note: transfer.note,
          );
      final updatedSource = await ref
          .read(inventoryRepositoryProvider)
          .getBox(sourceBox.id);
      ref.invalidate(inventoryBoxesProvider);
      if (mounted) {
        setState(() => _box = updatedSource);
        _message('Mercancía movida y registrada en la bitácora.');
      }
    } catch (_) {
      _message('No pudimos mover este artículo.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bindNfc() async {
    final box = _box;
    if (box == null || _busy) return;

    setState(() => _busy = true);
    try {
      final tagUid = await InventoryNfcService().writeBoxLink(box.nfcUrl);
      final updated = await ref
          .read(inventoryRepositoryProvider)
          .bindNfc(box.id, tagUid);
      ref.invalidate(inventoryBoxesProvider);
      if (mounted) {
        setState(() => _box = updated);
        _message('Tarjeta NFC vinculada. Acércala para abrir esta caja.');
      }
    } on InventoryNfcException catch (error) {
      _message(error.message, error: true);
    } catch (_) {
      _message('No pudimos vincular la tarjeta NFC.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printLabel({
    required LabelTemplateKind kind,
    required String targetId,
    required String name,
  }) async {
    if (_busy) return;
    final options = await _printOptions();
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
                failureReason: 'No se pudo preparar o entregar la etiqueta.',
              );
        } catch (_) {}
      }
      _message('No pudimos preparar esta etiqueta para imprimir.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<({LabelMediaSize mediaSize, int copies})?> _printOptions() async {
    var mediaSize = LabelMediaSize.square50x50;
    var copies = 1;
    return showModalBottomSheet<({LabelMediaSize mediaSize, int copies})>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => _Sheet(
          title: 'Imprimir etiqueta',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Elige el tamaño que ya usas. Nenis no obliga una impresora.',
                style: AppTextStyles.subtitle,
              ),
              const SizedBox(height: 12),
              SegmentedButton<LabelMediaSize>(
                segments: const [
                  ButtonSegment(
                    value: LabelMediaSize.square50x50,
                    label: Text('50 × 50 mm'),
                  ),
                  ButtonSegment(
                    value: LabelMediaSize.shipping4x6,
                    label: Text('4 × 6”'),
                  ),
                ],
                selected: {mediaSize},
                onSelectionChanged: (value) =>
                    setSheetState(() => mediaSize = value.first),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Copias',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: copies == 1
                        ? null
                        : () => setSheetState(() => copies--),
                    icon: const Icon(Symbols.remove_circle_outline),
                  ),
                  Text('$copies', style: AppTextStyles.h2),
                  IconButton(
                    onPressed: copies == 100
                        ? null
                        : () => setSheetState(() => copies++),
                    icon: const Icon(Symbols.add_circle),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              PillButton(
                label: 'Abrir impresión',
                icon: Symbols.print,
                onPressed: () => Navigator.pop(context, (
                  mediaSize: mediaSize,
                  copies: copies,
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<(String, String, String?)?> _boxForm(String title) async {
    final code = TextEditingController();
    final name = TextEditingController();
    final location = TextEditingController();

    final result = await showModalBottomSheet<(String, String, String?)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _Sheet(
        title: title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: code,
              decoration: const InputDecoration(
                labelText: 'Código visible · Ej. B-01',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '¿Qué guardarás?'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: location,
              decoration: const InputDecoration(
                labelText: 'Ubicación (opcional)',
              ),
            ),
            const SizedBox(height: 20),
            PillButton(
              label: 'Crear caja',
              onPressed: () {
                if (code.text.trim().isEmpty || name.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(context, (
                  code.text.trim(),
                  name.text.trim(),
                  location.text.trim().isEmpty ? null : location.text.trim(),
                ));
              },
            ),
          ],
        ),
      ),
    );
    code.dispose();
    name.dispose();
    location.dispose();
    return result;
  }

  Future<(String, String?, String?, int)?> _itemForm() async {
    final name = TextEditingController();
    final variant = TextEditingController();
    final barcode = TextEditingController();
    final quantity = TextEditingController(text: '1');

    final result = await showModalBottomSheet<(String, String?, String?, int)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _Sheet(
        title: 'Agregar artículo',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Artículo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: variant,
              decoration: const InputDecoration(
                labelText: 'Talla, color o variante',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: barcode,
              decoration: const InputDecoration(
                labelText: 'Código de barras (opcional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad'),
            ),
            const SizedBox(height: 20),
            PillButton(
              label: 'Guardar artículo',
              onPressed: () {
                final amount = int.tryParse(quantity.text) ?? 0;
                if (name.text.trim().isEmpty || amount <= 0) return;
                Navigator.pop(context, (
                  name.text.trim(),
                  variant.text.trim().isEmpty ? null : variant.text.trim(),
                  barcode.text.trim().isEmpty ? null : barcode.text.trim(),
                  amount,
                ));
              },
            ),
          ],
        ),
      ),
    );
    name.dispose();
    variant.dispose();
    barcode.dispose();
    quantity.dispose();
    return result;
  }

  Future<List<Map<String, Object>>?> _countForm(InventoryBox box) async {
    final quantities = <String, int>{
      for (final item in box.items) item.id: item.quantity,
    };
    return showModalBottomSheet<List<Map<String, Object>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => _Sheet(
          title: 'Conteo físico · ${box.code}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Confirma lo que realmente hay. Cada diferencia quedará registrada.',
                style: AppTextStyles.subtitle,
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 310),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: box.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = box.items[index];
                    final quantity = quantities[item.id] ?? 0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name),
                      subtitle: Text('Sistema: ${item.quantity}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: quantity == 0
                                ? null
                                : () => setSheetState(
                                    () => quantities[item.id] = quantity - 1,
                                  ),
                            icon: const Icon(Symbols.remove_circle_outline),
                          ),
                          Text('$quantity', style: AppTextStyles.h2),
                          IconButton(
                            onPressed: () => setSheetState(
                              () => quantities[item.id] = quantity + 1,
                            ),
                            icon: const Icon(Symbols.add_circle),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              PillButton(
                label: 'Guardar conteo',
                icon: Symbols.fact_check,
                onPressed: () => Navigator.pop(
                  context,
                  box.items
                      .map(
                        (item) => <String, Object>{
                          'inventoryItemId': item.id,
                          'actualQuantity': quantities[item.id] ?? 0,
                        },
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<({String destinationId, int quantity, String? note})?> _transferForm(
    InventoryItem item,
    List<InventoryBoxSummary> destinations,
  ) async {
    var destinationId = destinations.first.id;
    var quantity = 1;
    final note = TextEditingController();
    final result =
        await showModalBottomSheet<
          ({String destinationId, int quantity, String? note})
        >(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => StatefulBuilder(
            builder: (context, setSheetState) => _Sheet(
              title: 'Mover ${item.name}',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: destinationId,
                    decoration: const InputDecoration(
                      labelText: 'Caja destino',
                    ),
                    items: destinations
                        .map(
                          (box) => DropdownMenuItem(
                            value: box.id,
                            child: Text('${box.code} · ${box.name}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => destinationId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Cantidad',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: quantity == 1
                            ? null
                            : () => setSheetState(() => quantity--),
                        icon: const Icon(Symbols.remove_circle_outline),
                      ),
                      Text(
                        '$quantity de ${item.quantity}',
                        style: AppTextStyles.h2,
                      ),
                      IconButton(
                        onPressed: quantity == item.quantity
                            ? null
                            : () => setSheetState(() => quantity++),
                        icon: const Icon(Symbols.add_circle),
                      ),
                    ],
                  ),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(
                      labelText: 'Motivo (opcional)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  PillButton(
                    label: 'Mover artículos',
                    icon: Symbols.swap_horiz,
                    onPressed: () => Navigator.pop(context, (
                      destinationId: destinationId,
                      quantity: quantity,
                      note: note.text.trim().isEmpty ? null : note.text.trim(),
                    )),
                  ),
                ],
              ),
            ),
          ),
        );
    note.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final boxes = ref.watch(inventoryBoxesProvider);
    final session = ref.watch(authControllerProvider).asData?.value;
    final canDesignLabels = session?.canManageLabels ?? false;
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/seller/labels'),
                      icon: const Icon(Symbols.arrow_back),
                    ),
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
                    IconButton(
                      onPressed: _busy || !unlocked ? null : _createBox,
                      icon: const Icon(Symbols.add_box),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: !unlocked
                    ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: Center(child: LabelFeatureLockedView()),
                      )
                    : boxes.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, _) => Center(
                          child: PillButton(
                            label: 'Reintentar',
                            onPressed: () =>
                                ref.invalidate(inventoryBoxesProvider),
                          ),
                        ),
                        data: (items) => Row(
                          children: [
                            SizedBox(
                              width: 142,
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  4,
                                  8,
                                  100,
                                ),
                                children: items
                                    .map(
                                      (item) => _BoxTile(
                                        item: item,
                                        selected: item.id == _box?.id,
                                        onTap: () => _openBox(item.id),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            Expanded(
                              child: _box == null
                                  ? const _EmptyBox()
                                  : _BoxDetail(
                                      box: _box!,
                                      busy: _busy,
                                      onAdd: _addItem,
                                      onBind: _bindNfc,
                                      onAdjust: _adjust,
                                      onCount: _completeCount,
                                      onTransfer: _transferItem,
                                      onPrintBox: () => _printLabel(
                                        kind: LabelTemplateKind.inventoryBox,
                                        targetId: _box!.id,
                                        name: _box!.code,
                                      ),
                                      onPrintItem: (item) => _printLabel(
                                        kind: LabelTemplateKind.inventoryItem,
                                        targetId: item.id,
                                        name: item.name,
                                      ),
                                      canDesignLabels: canDesignLabels,
                                      onDesign: () => context.push(
                                        '/seller/labels/editor?kind=InventoryBox&mediaSize=Square50x50',
                                      ),
                                    ),
                            ),
                          ],
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

class _BoxTile extends StatelessWidget {
  const _BoxTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final InventoryBoxSummary item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: selected
          ? AppColors.neni.withValues(alpha: .14)
          : AppColors.surface,
      borderRadius: AppRadii.softRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.softRadius,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Symbols.inventory_2, color: AppColors.neniDeep),
              const SizedBox(height: 7),
              Text(
                item.code,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.subtitle.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 5),
              Text(
                '${item.totalUnits} piezas${item.isNfcBound ? ' · NFC' : ''}',
                style: AppTextStyles.subtitle.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.inventory_2, size: 54, color: AppColors.lavender),
          const SizedBox(height: 13),
          Text('Todo tiene su cajita', style: AppTextStyles.h2),
          const SizedBox(height: 6),
          Text(
            'Crea o abre una caja para organizar tu mercancía.',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle,
          ),
        ],
      ),
    ),
  );
}

class _BoxDetail extends StatelessWidget {
  const _BoxDetail({
    required this.box,
    required this.busy,
    required this.onAdd,
    required this.onBind,
    required this.onAdjust,
    required this.onCount,
    required this.onTransfer,
    required this.onPrintBox,
    required this.onPrintItem,
    required this.canDesignLabels,
    required this.onDesign,
  });

  final InventoryBox box;
  final bool busy;
  final VoidCallback onAdd;
  final VoidCallback onBind;
  final void Function(InventoryItem, int) onAdjust;
  final VoidCallback onCount;
  final ValueChanged<InventoryItem> onTransfer;
  final VoidCallback onPrintBox;
  final ValueChanged<InventoryItem> onPrintItem;
  final bool canDesignLabels;
  final VoidCallback onDesign;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(12, 4, 18, 110),
    children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.cardRadius,
          boxShadow: AppShadows.small,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              box.code.toUpperCase(),
              style: AppTextStyles.eyebrow(AppColors.neniDeep),
            ),
            Text(box.name, style: AppTextStyles.h2),
            if (box.location != null)
              Text(box.location!, style: AppTextStyles.subtitle),
            const SizedBox(height: 13),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PillButton(
                  label: box.isNfcBound ? 'NFC vinculada' : 'Vincular NFC',
                  onPressed: busy || box.isNfcBound ? null : onBind,
                  icon: Symbols.nfc,
                  expand: false,
                ),
                if (canDesignLabels)
                  OutlinedButton.icon(
                    onPressed: onDesign,
                    icon: const Icon(Symbols.design_services),
                    label: const Text('Diseñar'),
                  ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onPrintBox,
                  icon: const Icon(Symbols.print),
                  label: const Text('Imprimir'),
                ),
                OutlinedButton.icon(
                  onPressed: busy || box.items.isEmpty ? null : onCount,
                  icon: const Icon(Symbols.fact_check),
                  label: const Text('Conteo'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Text(
            'Artículos (${box.items.length})',
            style: AppTextStyles.h2.copyWith(fontSize: 17),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: busy ? null : onAdd,
            icon: const Icon(Symbols.add),
            label: const Text('Agregar'),
          ),
        ],
      ),
      ...box.items.map(
        (item) => Card(
          child: ListTile(
            title: Text(item.name),
            subtitle: Text(
              '${item.variant ?? 'Sin variante'} · ${item.barcode ?? item.labelCode}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: busy || item.quantity == 0
                      ? null
                      : () => onAdjust(item, -1),
                  icon: const Icon(Symbols.remove_circle_outline),
                ),
                Text(
                  '${item.quantity}',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  onPressed: busy ? null : () => onAdjust(item, 1),
                  icon: const Icon(Symbols.add_circle),
                ),
                IconButton(
                  onPressed: busy ? null : () => onPrintItem(item),
                  icon: const Icon(Symbols.print),
                  tooltip: 'Imprimir etiqueta del artículo',
                ),
                IconButton(
                  onPressed: busy || item.quantity == 0
                      ? null
                      : () => onTransfer(item),
                  icon: const Icon(Symbols.swap_horiz),
                  tooltip: 'Mover a otra caja',
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Material(
      color: AppColors.surfaceCream,
      borderRadius: AppRadii.cardRadius,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.h2),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    ),
  );
}
