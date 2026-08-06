import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/interactive_bounce.dart';
import '../../../shared/widgets/pill_button.dart';
import '../../labels/data/label_print_models.dart';
import '../../labels/screens/label_print_options_sheet.dart';
import '../data/inventory_models.dart';
import '../data/inventory_repository.dart';
import '../services/inventory_nfc_service.dart';
import '../widgets/inventory_widgets.dart';

/// Ficha de caja nueva o edición. Devuelve código, nombre y ubicación.
Future<({String code, String name, String? location})?>
showInventoryBoxFormSheet(
  BuildContext context, {
  required String title,
  String? code,
  String? name,
  String? location,
}) {
  return showModalBottomSheet<({String code, String name, String? location})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BoxFormSheet(
      title: title,
      initialCode: code,
      initialName: name,
      initialLocation: location,
    ),
  );
}

/// Ficha de nuevo artículo. Devuelve nombre, variante, código y cantidad.
Future<({String name, String? variant, String? barcode, int quantity})?>
showInventoryItemFormSheet(BuildContext context) {
  return showModalBottomSheet<
    ({String name, String? variant, String? barcode, int quantity})
  >(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ItemFormSheet(),
  );
}

/// Ficha de traspaso entre cajas.
Future<({String destinationId, int quantity, String? note})?>
showInventoryTransferSheet(
  BuildContext context, {
  required InventoryItem item,
  required List<InventoryBoxSummary> destinations,
}) {
  return showModalBottomSheet<
    ({String destinationId, int quantity, String? note})
  >(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TransferFormSheet(item: item, destinations: destinations),
  );
}

/// Ficha de conteo físico con diferencias en vivo. Devuelve las cantidades.
Future<List<Map<String, Object>>?> showInventoryCountSheet(
  BuildContext context, {
  required InventoryBox box,
}) {
  return showModalBottomSheet<List<Map<String, Object>>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CountSheet(box: box),
  );
}

/// Ficha de formato de etiqueta para cajas y artículos de bodega.
Future<({LabelMediaSize mediaSize, int copies})?> showInventoryLabelSheet(
  BuildContext context, {
  required String subject,
}) {
  return showModalBottomSheet<({LabelMediaSize mediaSize, int copies})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LabelSheet(subject: subject),
  );
}

/// Overlay de vinculación NFC: escribe la tarjeta y confirma la caja.
/// Devuelve la caja actualizada o null si se canceló o falló.
Future<InventoryBox?> showInventoryNfcSheet(
  BuildContext context, {
  required WidgetRef ref,
  required InventoryBox box,
  int? pendingCount,
}) {
  return showModalBottomSheet<InventoryBox?>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.ink.withValues(alpha: 0.65),
    builder: (_) => _NfcBindSheet(
      ref: ref,
      box: box,
      pendingCount: pendingCount,
    ),
  );
}

/// ---------------- Shell común ----------------

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          22,
          10,
          22,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surfaceCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.ink3.withValues(alpha: 0.6),
                    borderRadius: AppRadii.pillRadius,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(title, style: AppTextStyles.h1.copyWith(fontSize: 22)),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                ),
              ],
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------- Caja (crear / editar) ----------------

class _BoxFormSheet extends StatefulWidget {
  const _BoxFormSheet({
    required this.title,
    this.initialCode,
    this.initialName,
    this.initialLocation,
  });

  final String title;
  final String? initialCode;
  final String? initialName;
  final String? initialLocation;

  @override
  State<_BoxFormSheet> createState() => _BoxFormSheetState();
}

class _BoxFormSheetState extends State<_BoxFormSheet> {
  late final TextEditingController _code =
      TextEditingController(text: widget.initialCode ?? '');
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName ?? '');
  late final TextEditingController _location =
      TextEditingController(text: widget.initialLocation ?? '');

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _code,
            decoration: const InputDecoration(
              labelText: 'Código visible · Ej. B-01',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '¿Qué guardarás?'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            decoration: const InputDecoration(
              labelText: 'Ubicación (opcional)',
            ),
          ),
          const SizedBox(height: 20),
          PillButton(
            label: widget.initialCode == null ? 'Crear caja' : 'Guardar caja',
            icon: Symbols.inventory_2,
            onPressed: () {
              if (_code.text.trim().isEmpty || _name.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(context, (
                code: _code.text.trim(),
                name: _name.text.trim(),
                location: _location.text.trim().isEmpty
                    ? null
                    : _location.text.trim(),
              ));
            },
          ),
        ],
      ),
    );
  }
}

/// ---------------- Artículo ----------------

class _ItemFormSheet extends StatefulWidget {
  const _ItemFormSheet();

  @override
  State<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<_ItemFormSheet> {
  late final TextEditingController _name = TextEditingController();
  late final TextEditingController _variant = TextEditingController();
  late final TextEditingController _barcode = TextEditingController();
  late final TextEditingController _quantity = TextEditingController(text: '1');

  @override
  void dispose() {
    _name.dispose();
    _variant.dispose();
    _barcode.dispose();
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Agregar artículo',
      subtitle: 'Si repites nombre y variante, la cantidad se suma.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Artículo'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _variant,
            decoration: const InputDecoration(
              labelText: 'Talla, color o variante',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _barcode,
            decoration: const InputDecoration(
              labelText: 'Código de barras (opcional)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cantidad'),
          ),
          const SizedBox(height: 20),
          PillButton(
            label: 'Guardar artículo',
            icon: Symbols.add,
            onPressed: () {
              final amount = int.tryParse(_quantity.text) ?? 0;
              if (_name.text.trim().isEmpty || amount <= 0) return;
              Navigator.pop(context, (
                name: _name.text.trim(),
                variant: _variant.text.trim().isEmpty
                    ? null
                    : _variant.text.trim(),
                barcode: _barcode.text.trim().isEmpty
                    ? null
                    : _barcode.text.trim(),
                quantity: amount,
              ));
            },
          ),
        ],
      ),
    );
  }
}

/// ---------------- Traspaso ----------------

class _TransferFormSheet extends StatefulWidget {
  const _TransferFormSheet({required this.item, required this.destinations});

  final InventoryItem item;
  final List<InventoryBoxSummary> destinations;

  @override
  State<_TransferFormSheet> createState() => _TransferFormSheetState();
}

class _TransferFormSheetState extends State<_TransferFormSheet> {
  late String _destinationId = widget.destinations.first.id;
  int _quantity = 1;
  late final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return _Sheet(
      title: 'Mover ${item.name}',
      subtitle: 'El traspaso queda registrado en ambas cajas.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _destinationId,
            decoration: const InputDecoration(labelText: 'Caja destino'),
            items: widget.destinations
                .map(
                  (box) => DropdownMenuItem(
                    value: box.id,
                    child: Text('${box.code} · ${box.name}'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _destinationId = value);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cantidad',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _CountStepper(
                value: _quantity,
                min: 1,
                max: item.quantity,
                onChanged: (value) => setState(() => _quantity = value),
              ),
              const SizedBox(width: 6),
              Text(
                'de ${item.quantity}',
                style: AppTextStyles.subtitle.copyWith(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
          ),
          const SizedBox(height: 16),
          PillButton(
            label: 'Mover artículos',
            icon: Symbols.swap_horiz,
            onPressed: () => Navigator.pop(context, (
              destinationId: _destinationId,
              quantity: _quantity,
              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            )),
          ),
        ],
      ),
    );
  }
}

/// ---------------- Conteo físico ----------------

class _CountSheet extends StatefulWidget {
  const _CountSheet({required this.box});

  final InventoryBox box;

  @override
  State<_CountSheet> createState() => _CountSheetState();
}

class _CountSheetState extends State<_CountSheet> {
  late final Map<String, int> _quantities = {
    for (final item in widget.box.items) item.id: item.quantity,
  };

  List<(InventoryItem, int)> get _differences => widget.box.items
      .where((item) => (item.quantity - _quantities[item.id]!) != 0)
      .map((item) => (item, _quantities[item.id]! - item.quantity))
      .toList();

  @override
  Widget build(BuildContext context) {
    final differences = _differences;
    final diffText = switch (differences.length) {
      0 => 'sin diferencias',
      1 => '${differences.first.$1.name}: '
          '${differences.first.$2 > 0 ? '+' : ''}${differences.first.$2}',
      _ => '${differences.first.$1.name}: '
          '${differences.first.$2 > 0 ? '+' : ''}${differences.first.$2} '
          '(+${differences.length - 1} más)',
    };
    return _Sheet(
      title: 'Conteo físico · ${widget.box.code}',
      subtitle:
          'Confirma lo que realmente hay. Cada diferencia quedará registrada en la bitácora.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.box.items.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.line),
              itemBuilder: (context, index) {
                final item = widget.box.items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body.copyWith(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Sistema: ${item.quantity}',
                              style: AppTextStyles.subtitle
                                  .copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _CountStepper(
                        value: _quantities[item.id] ?? 0,
                        min: 0,
                        max: 100000,
                        onChanged: (value) =>
                            setState(() => _quantities[item.id] = value),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.lineSoft),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.box.items.length} '
                    '${widget.box.items.length == 1 ? 'artículo' : 'artículos'}'
                    ' · ${differences.length} '
                    '${differences.length == 1 ? 'diferencia' : 'diferencias'} '
                    '${differences.isEmpty ? 'detectadas' : 'detectada'}',
                    style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    diffText,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h2.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: differences.isEmpty
                          ? AppColors.ink2
                          : AppColors.liveRed,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PillButton(
            label: 'Guardar conteo',
            icon: Symbols.fact_check,
            onPressed: () => Navigator.pop(
              context,
              widget.box.items
                  .map(
                    (item) => <String, Object>{
                      'inventoryItemId': item.id,
                      'actualQuantity': _quantities[item.id] ?? 0,
                    },
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------- Etiquetas ----------------

class _LabelSheet extends StatefulWidget {
  const _LabelSheet({required this.subject});

  final String subject;

  @override
  State<_LabelSheet> createState() => _LabelSheetState();
}

class _LabelSheetState extends State<_LabelSheet> {
  LabelMediaSize _mediaSize = LabelMediaSize.square50x50;
  int _copies = 1;

  String? _detailFor(LabelMediaSize size) => switch (size) {
    LabelMediaSize.shipping4x6 => 'Ideal para cajas con dirección y contenido',
    LabelMediaSize.square50x50 =>
      'Compacta para pegar en la caja o el artículo',
  };

  @override
  Widget build(BuildContext context) {
    final total = _copies;
    return _Sheet(
      title: 'Imprimir etiqueta',
      subtitle: '${widget.subject} · eliges la impresora después',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LabelFieldLabel(
            icon: Symbols.sell,
            label: 'Formato de etiqueta',
          ),
          const SizedBox(height: 9),
          for (final size in LabelMediaSize.values) ...[
            LabelMediaChoice(
              size: size,
              selected: _mediaSize == size,
              detailOverride: _detailFor(size),
              onTap: () => setState(() => _mediaSize = size),
            ),
            const SizedBox(height: 9),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Copias',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              LabelCopiesControl(
                value: _copies,
                onChanged: (value) => setState(() => _copies = value),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.lineSoft),
            ),
            child: Row(
              children: [
                Text(
                  '1 caja × $_copies '
                  '${_copies == 1 ? 'copia' : 'copias'}',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                ),
                const Spacer(),
                Text(
                  '$total ${total == 1 ? 'etiqueta' : 'etiquetas'}',
                  style: AppTextStyles.h2.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.neniDeep,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PillButton(
            label: 'Abrir impresión',
            icon: Symbols.print,
            onPressed: () => Navigator.pop(context, (
              mediaSize: _mediaSize,
              copies: _copies,
            )),
          ),
        ],
      ),
    );
  }
}

/// ---------------- NFC ----------------

enum _NfcStage { idle, scanning, done, error }

class _NfcBindSheet extends ConsumerStatefulWidget {
  const _NfcBindSheet({
    required this.ref,
    required this.box,
    this.pendingCount,
  });

  final WidgetRef ref;
  final InventoryBox box;
  final int? pendingCount;

  @override
  ConsumerState<_NfcBindSheet> createState() => _NfcBindSheetState();
}

class _NfcBindSheetState extends ConsumerState<_NfcBindSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);
  _NfcStage _stage = _NfcStage.idle;
  String? _error;
  InventoryBox? _updated;
  String? _uid;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _bind() async {
    if (_stage == _NfcStage.scanning) return;
    setState(() {
      _stage = _NfcStage.scanning;
      _error = null;
    });
    try {
      final uid = await InventoryNfcService().writeBoxLink(widget.box.nfcUrl);
      final updated = await widget.ref
          .read(inventoryRepositoryProvider)
          .bindNfc(widget.box.id, uid);
      widget.ref.invalidate(inventoryBoxesProvider);
      if (!mounted) return;
      setState(() {
        _stage = _NfcStage.done;
        _updated = updated;
        _uid = uid;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) Navigator.of(context).pop(_updated);
    } on InventoryNfcException catch (error) {
      _fail(error.message);
    } catch (_) {
      _fail('No pudimos vincular la tarjeta NFC.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _stage = _NfcStage.error;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.92),
      child: Stack(
        children: [
          const Positioned.fill(child: _NfcBackdrop()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceCream,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: AppColors.ink3.withValues(alpha: 0.6),
                            borderRadius: AppRadii.pillRadius,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Vincular tarjeta NFC',
                        style: AppTextStyles.h1.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Caja ${widget.box.code} · la tarjeta guarda solo un '
                        'enlace; el inventario vive en Nenis.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) {
                          final t = _pulse.value;
                          return Container(
                            width: 96,
                            height: 96,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.lavender.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: AppColors.lavender.withValues(
                                  alpha: 0.35 * (0.6 + 0.4 * t),
                                ),
                                width: 2,
                              ),
                            ),
                            child: Transform.scale(
                              scale: 0.92 + 0.22 * t,
                              child: const Icon(
                                Symbols.nfc,
                                size: 46,
                                color: AppColors.lavender,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      const _NfcSteps(),
                      const SizedBox(height: 16),
                      if (_stage == _NfcStage.scanning) ...[
                        ClipRRect(
                          borderRadius: AppRadii.pillRadius,
                          child: const LinearProgressIndicator(
                            minHeight: 6,
                            backgroundColor: AppColors.lineSoft,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.neni,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Buscando tarjeta…',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.ink2,
                          ),
                        ),
                      ],
                      if (_stage == _NfcStage.done) ...[
                        const SizedBox(height: 4),
                        _SuccessBar(uid: formatNfcUid(_uid)),
                      ],
                      if (_stage == _NfcStage.error) ...[
                        const SizedBox(height: 4),
                        _ErrorBar(message: _error ?? 'No pudimos continuar.'),
                      ],
                      const SizedBox(height: 16),
                      PillButton(
                        label: _stage == _NfcStage.done
                            ? 'Listo'
                            : 'Vincular tarjeta',
                        icon: Symbols.nfc,
                        onPressed: _stage == _NfcStage.done
                            ? () => Navigator.of(context).pop(_updated)
                            : _stage == _NfcStage.scanning
                            ? null
                            : _bind,
                      ),
                      if (widget.pendingCount != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Aún faltan ${widget.pendingCount} '
                          '${widget.pendingCount == 1 ? 'caja' : 'cajas'} '
                          'por vincular de esta bodega.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 10,
                            color: AppColors.ink3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NfcSteps extends StatelessWidget {
  const _NfcSteps();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StepRow(number: 1, text: 'Acerca la tarjeta a la parte trasera de tu teléfono'),
        const SizedBox(height: 8),
        _StepRow(
          number: 2,
          text: 'Mantén el teléfono quieto hasta que vibre',
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.lavender.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$number',
            style: AppTextStyles.chip.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.lavender,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
          ),
        ),
      ],
    );
  }
}

class _SuccessBar extends StatelessWidget {
  const _SuccessBar({required this.uid});

  final String? uid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.statusDeliveredBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Symbols.check_circle,
            size: 18,
            color: AppColors.statusDeliveredFg,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Tarjeta vinculada · UID $uid',
              style: AppTextStyles.chip.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.statusDeliveredFg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  const _ErrorBar({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.liveRed.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Symbols.error, size: 18, color: AppColors.liveRed),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.chip.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.liveRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fondo oscuro difuminado con manchas de color, como en el mockup.
class _NfcBackdrop extends StatelessWidget {
  const _NfcBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B1F33), Color(0xFF1E1524)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: 18,
            top: 20,
            right: 18,
            height: 150,
            child: _BackdropBlob(color: AppColors.neni),
          ),
          Positioned(
            left: 34,
            top: 210,
            width: 150,
            height: 120,
            child: _BackdropBlob(
              color: AppColors.lavender.withValues(alpha: 0.4),
            ),
          ),
          Positioned(
            right: 30,
            top: 340,
            width: 130,
            height: 110,
            child: _BackdropBlob(
              color: AppColors.gold.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackdropBlob extends StatelessWidget {
  const _BackdropBlob({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
    );
  }
}

/// ---------------- Stepper de conteo/traspaso ----------------

class _CountStepper extends StatelessWidget {
  const _CountStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: AppRadii.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CountButton(
            icon: Symbols.remove,
            onTap: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _CountButton(
            icon: Symbols.add,
            onTap: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _CountButton extends StatelessWidget {
  const _CountButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InteractiveBounce(
      onPressed: onTap,
      scaleFactor: 0.86,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.neni.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: enabled ? AppColors.neniDeep : AppColors.ink3,
            ),
          ),
        ),
      ),
    );
  }
}
