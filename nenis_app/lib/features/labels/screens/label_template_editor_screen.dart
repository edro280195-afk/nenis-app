import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';
import '../data/label_print_models.dart';
import '../data/label_template_models.dart';
import '../data/label_template_repository.dart';
import '../widgets/label_template_canvas.dart';

class LabelTemplateEditorScreen extends ConsumerStatefulWidget {
  const LabelTemplateEditorScreen({
    super.key,
    required this.mediaSize,
    this.kind = LabelTemplateKind.orderPackage,
  });

  final LabelMediaSize mediaSize;
  final LabelTemplateKind kind;

  @override
  ConsumerState<LabelTemplateEditorScreen> createState() =>
      _LabelTemplateEditorScreenState();
}

class _LabelTemplateEditorScreenState
    extends ConsumerState<LabelTemplateEditorScreen> {
  LabelDesign? _design;
  String? _templateId;
  int _revision = 0;
  String _savedJson = '';
  String? _selectedId;
  bool _busy = false;

  bool get _isDirty => _design != null && _design!.toJson() != _savedJson;

  LabelDesignElement? get _selected {
    final id = _selectedId;
    if (id == null || _design == null) return null;
    for (final element in _design!.elements) {
      if (element.id == id) return element;
    }
    return null;
  }

  void _adopt(LabelTemplateEditor template) {
    final shouldReplace =
        _templateId != template.id ||
        _revision != template.draftVersion.revision;
    if (!shouldReplace) return;
    final design = LabelDesign.fromJson(
      template.draftVersion.designJson,
      template.mediaSize,
    );
    _templateId = template.id;
    _revision = template.draftVersion.revision;
    _design = design;
    _savedJson = design.toJson();
    _selectedId = null;
  }

  void _showMessage(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: color ?? AppColors.ink,
          content: Text(
            message,
            style: AppTextStyles.body.copyWith(color: Colors.white),
          ),
        ),
      );
  }

  void _updateElement(
    String id,
    LabelDesignElement Function(LabelDesignElement value) update,
  ) {
    final current = _design;
    if (current == null) return;
    setState(() {
      _design = current.copyWith(
        elements: current.elements
            .map((element) => element.id == id ? update(element) : element)
            .toList(),
      );
    });
  }

  void _moveElement(String id, Offset delta) {
    final design = _design;
    if (design == null) return;
    _updateElement(id, (element) {
      final x = (element.x + delta.dx)
          .clamp(0.0, math.max(0, design.widthMm - element.width))
          .toDouble();
      final y = (element.y + delta.dy)
          .clamp(0.0, math.max(0, design.heightMm - element.height))
          .toDouble();
      return element.copyWith(x: x, y: y);
    });
  }

  void _resizeElement(String id, Offset delta) {
    final design = _design;
    if (design == null) return;
    _updateElement(id, (element) {
      final minimum = element.type == 'qr'
          ? 20.0
          : element.type == 'barcode'
          ? 10.0
          : 3.0;
      var width = (element.width + delta.dx).clamp(
        minimum,
        design.widthMm - element.x,
      );
      var height = (element.height + delta.dy).clamp(
        minimum,
        design.heightMm - element.y,
      );
      if (element.type == 'qr') {
        final square = math.min(width, height);
        width = square;
        height = square;
      }
      return element.copyWith(width: width, height: height);
    });
  }

  void _addElement(_NewElementSpec spec) {
    final design = _design;
    if (design == null) return;
    final defaultWidth = spec.type == 'qr'
        ? 28.0
        : spec.type == 'barcode'
        ? 46.0
        : spec.type == 'line'
        ? 42.0
        : 40.0;
    final defaultHeight = spec.type == 'qr'
        ? 28.0
        : spec.type == 'barcode'
        ? 12.0
        : spec.type == 'line'
        ? 1.0
        : 8.0;
    final width = math.min(defaultWidth, design.widthMm - 6);
    final height = math.min(defaultHeight, design.heightMm - 6);
    final element = LabelDesignElement(
      id: '${spec.type}-${DateTime.now().microsecondsSinceEpoch}',
      type: spec.type,
      x: math.max(2, (design.widthMm - width) / 2),
      y: math.max(2, (design.heightMm - height) / 2),
      width: width,
      height: height,
      zIndex:
          design.elements.fold(
            0,
            (maxValue, item) => math.max(maxValue, item.zIndex),
          ) +
          1,
      properties: spec.properties,
    );
    setState(() {
      _design = design.copyWith(elements: [...design.elements, element]);
      _selectedId = element.id;
    });
  }

  Future<void> _showAddMenu() async {
    final spec = await showModalBottomSheet<_NewElementSpec>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddElementSheet(kind: widget.kind),
    );
    if (spec != null) _addElement(spec);
  }

  Future<void> _showAssetLibrary() async {
    final asset = await showModalBottomSheet<LabelAsset>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _AssetLibrarySheet(
        onUpload: () {
          Navigator.of(sheetContext).pop();
          _pickAndUploadAsset();
        },
      ),
    );
    if (asset != null) {
      _addElement(
        _NewElementSpec('image', {'assetId': asset.id, 'fit': 'contain'}),
      );
    }
  }

  Future<void> _pickAndUploadAsset() async {
    if (_busy) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 1800,
      maxHeight: 1800,
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final asset = await ref
          .read(labelTemplateRepositoryProvider)
          .uploadAsset(File(picked.path));
      ref.invalidate(labelAssetsProvider);
      _addElement(
        _NewElementSpec('image', {'assetId': asset.id, 'fit': 'contain'}),
      );
      _showMessage(
        'Imagen agregada a tu biblioteca.',
        color: AppColors.lavender,
      );
    } on LabelTemplateException catch (error) {
      _showMessage(error.message, color: AppColors.liveRed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _save(LabelTemplateEditor template) async {
    final design = _design;
    if (design == null || !_isDirty) return true;
    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(labelTemplateRepositoryProvider)
          .saveDraft(
            templateId: template.id,
            designJson: design.toJson(),
            expectedRevision: _revision,
          );
      if (!mounted) return true;
      setState(() => _adopt(updated));
      ref.invalidate(
        labelTemplateProvider((kind: widget.kind, mediaSize: widget.mediaSize)),
      );
      _showMessage('Borrador guardado.', color: AppColors.lavender);
      return true;
    } on LabelTemplateException catch (error) {
      _showMessage(
        error.errors.isEmpty ? error.message : error.errors.first,
        color: AppColors.liveRed,
      );
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish(LabelTemplateEditor template) async {
    if (!await _save(template) || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('¿Publicar esta etiqueta?'),
        content: const Text(
          'Las próximas impresiones usarán este diseño. Tus impresiones anteriores conservarán su versión original.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Publicar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(labelTemplateRepositoryProvider)
          .publish(template.id);
      if (!mounted) return;
      setState(() => _adopt(updated));
      ref.invalidate(
        labelTemplateProvider((kind: widget.kind, mediaSize: widget.mediaSize)),
      );
      _showMessage(
        'Etiqueta publicada. Ya se usará al imprimir.',
        color: AppColors.lavender,
      );
    } on LabelTemplateException catch (error) {
      _showMessage(
        error.errors.isEmpty ? error.message : error.errors.first,
        color: AppColors.liveRed,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset(LabelTemplateEditor template) async {
    if (!_isDirty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Descartar cambios?'),
        content: const Text(
          'El borrador volverá a la última versión publicada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(labelTemplateRepositoryProvider)
          .resetDraft(template.id);
      if (!mounted) return;
      setState(() => _adopt(updated));
      ref.invalidate(
        labelTemplateProvider((kind: widget.kind, mediaSize: widget.mediaSize)),
      );
      _showMessage('Borrador recuperado.');
    } on LabelTemplateException catch (error) {
      _showMessage(error.message, color: AppColors.liveRed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _back(LabelTemplateEditor template) async {
    if (_isDirty) {
      final choice = await showDialog<_LeaveChoice>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Tienes cambios sin guardar'),
          content: const Text(
            'Guárdalos para conservarlos como borrador o descártalos antes de salir.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_LeaveChoice.cancel),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_LeaveChoice.discard),
              child: const Text('Descartar'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_LeaveChoice.save),
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
      if (choice == null || choice == _LeaveChoice.cancel) return;
      if (choice == _LeaveChoice.save && !await _save(template)) return;
    }
    if (!mounted) return;
    context.canPop() ? context.pop() : context.go('/seller/labels');
  }

  @override
  Widget build(BuildContext context) {
    final templateAsync = ref.watch(
      labelTemplateProvider((kind: widget.kind, mediaSize: widget.mediaSize)),
    );
    final assetsAsync = ref.watch(labelAssetsProvider);
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: templateAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.neniDeep),
            ),
            error: (error, _) =>
                _EditorError(onBack: () => context.go('/seller/labels')),
            data: (template) {
              _adopt(template);
              final design = _design!;
              final assets = assetsAsync.asData?.value ?? const <LabelAsset>[];
              final selected = _selected;
              return Column(
                children: [
                  _EditorHeader(
                    template: template,
                    dirty: _isDirty,
                    busy: _busy,
                    onBack: () => _back(template),
                    onSave: () => _save(template),
                    onPublish: () => _publish(template),
                    onReset: () => _reset(template),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                      children: [
                        _FormatSwitch(
                          current: widget.mediaSize,
                          kind: widget.kind,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Arrastra un elemento para moverlo. Usa la esquina rosa para cambiar su tamaño.',
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LabelTemplateCanvas(
                          design: design,
                          assets: assets,
                          selectedId: _selectedId,
                          onSelect: (id) => setState(() => _selectedId = id),
                          onMove: _moveElement,
                          onResize: _resizeElement,
                        ),
                        const SizedBox(height: 14),
                        _ElementToolbar(
                          onAdd: _showAddMenu,
                          onImage: _showAssetLibrary,
                        ),
                        const SizedBox(height: 14),
                        _Inspector(
                          element: selected,
                          bindings: _bindingsFor(widget.kind),
                          onUpdate: (updated) =>
                              _updateElement(updated.id, (_) => updated),
                          onDelete: () {
                            final target = _selected;
                            if (target == null || target.isRequired) return;
                            setState(() {
                              _design = design.copyWith(
                                elements: design.elements
                                    .where((element) => element.id != target.id)
                                    .toList(),
                              );
                              _selectedId = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

enum _LeaveChoice { cancel, discard, save }

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({
    required this.template,
    required this.dirty,
    required this.busy,
    required this.onBack,
    required this.onSave,
    required this.onPublish,
    required this.onReset,
  });

  final LabelTemplateEditor template;
  final bool dirty;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onPublish;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 7, 16, 8),
    child: Row(
      children: [
        BackIconButton(onPressed: busy ? null : onBack),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Diseñar etiqueta',
                style: AppTextStyles.h1.copyWith(fontSize: 21),
              ),
              Text(
                'Borrador v${template.draftVersion.versionNumber}${dirty ? ' · sin guardar' : ''}',
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: 11.5,
                  color: dirty ? AppColors.neniDeep : AppColors.ink2,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Más opciones',
          onSelected: (value) {
            if (value == 'reset') onReset();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'reset', child: Text('Recuperar publicada')),
          ],
          icon: const Icon(Symbols.more_horiz, color: AppColors.ink),
        ),
        const SizedBox(width: 2),
        TextButton(
          onPressed: busy || !dirty ? null : onSave,
          child: const Text('Guardar'),
        ),
        const SizedBox(width: 3),
        FilledButton(
          onPressed: busy ? null : onPublish,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.neniDeep,
            foregroundColor: Colors.white,
          ),
          child: const Text('Publicar'),
        ),
      ],
    ),
  );
}

class _FormatSwitch extends StatelessWidget {
  const _FormatSwitch({required this.current, required this.kind});
  final LabelMediaSize current;
  final LabelTemplateKind kind;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final size in LabelMediaSize.values) ...[
        Expanded(
          child: _FormatOption(
            label: size == LabelMediaSize.shipping4x6 ? '4 × 6”' : '50 × 50 mm',
            active: size == current,
            onTap: size == current
                ? null
                : () => context.go(
                    '/seller/labels/editor?kind=${kind.api}&mediaSize=${size.api}',
                  ),
          ),
        ),
        if (size != LabelMediaSize.values.last) const SizedBox(width: 8),
      ],
    ],
  );
}

class _FormatOption extends StatelessWidget {
  const _FormatOption({required this.label, required this.active, this.onTap});
  final String label;
  final bool active;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: active ? AppColors.neni.withValues(alpha: 0.12) : AppColors.surface,
    borderRadius: AppRadii.pillRadius,
    child: InkWell(
      onTap: onTap,
      borderRadius: AppRadii.pillRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppColors.neniDeep : AppColors.ink2,
          ),
        ),
      ),
    ),
  );
}

class _ElementToolbar extends StatelessWidget {
  const _ElementToolbar({required this.onAdd, required this.onImage});
  final VoidCallback onAdd;
  final VoidCallback onImage;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadii.softRadius,
      boxShadow: AppShadows.small,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _Tool(icon: Symbols.add, label: 'Añadir', onTap: onAdd),
        _Tool(icon: Symbols.image, label: 'Imagen', onTap: onImage),
        const _Tool(icon: Symbols.touch_app, label: 'Mover', onTap: null),
        const _Tool(icon: Symbols.crop_free, label: 'Tamaño', onTap: null),
      ],
    ),
  );
}

class _Tool extends StatelessWidget {
  const _Tool({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: AppRadii.iconBtnRadius,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: onTap == null ? AppColors.ink3 : AppColors.neniDeep,
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.subtitle.copyWith(fontSize: 10)),
        ],
      ),
    ),
  );
}

class _Inspector extends StatelessWidget {
  const _Inspector({
    required this.element,
    required this.bindings,
    required this.onUpdate,
    required this.onDelete,
  });
  final LabelDesignElement? element;
  final List<(String, String)> bindings;
  final ValueChanged<LabelDesignElement> onUpdate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final selected = element;
    if (selected == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.cardRadius,
        ),
        child: Row(
          children: [
            const Icon(Symbols.ads_click, color: AppColors.neniDeep),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Toca un elemento para editar su contenido, estilo y posición.',
                style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
              ),
            ),
          ],
        ),
      );
    }
    final properties = Map<String, dynamic>.from(selected.properties);
    final isText = selected.type == 'text' || selected.type == 'data';
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _iconFor(selected.type),
                color: AppColors.neniDeep,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _labelFor(selected),
                  style: AppTextStyles.h2.copyWith(fontSize: 16),
                ),
              ),
              if (!selected.isRequired)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Symbols.delete, color: AppColors.liveRed),
                  tooltip: 'Eliminar elemento',
                ),
            ],
          ),
          if (selected.isRequired)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Dato obligatorio para que la bolsa se pueda identificar.',
                style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
              ),
            ),
          if (selected.type == 'text') ...[
            TextFormField(
              initialValue: properties['text'] as String? ?? '',
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Texto'),
              onChanged: (value) {
                properties['text'] = value;
                onUpdate(selected.copyWith(properties: properties));
              },
            ),
          ],
          if (selected.type == 'data') ...[
            DropdownButtonFormField<String>(
              initialValue: properties['binding'] as String?,
              decoration: const InputDecoration(
                labelText: 'Dato de la etiqueta',
              ),
              items: bindings
                  .map(
                    (binding) => DropdownMenuItem(
                      value: binding.$1,
                      child: Text(binding.$2),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                properties['binding'] = value;
                onUpdate(selected.copyWith(properties: properties));
              },
            ),
          ],
          if (isText) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                Text(
                  'Tamaño',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${((properties['fontSize'] as num?)?.toDouble() ?? 10).round()} pt',
                  style: AppTextStyles.subtitle,
                ),
              ],
            ),
            Slider(
              value: ((properties['fontSize'] as num?)?.toDouble() ?? 10).clamp(
                6,
                42,
              ),
              min: 6,
              max: 42,
              divisions: 36,
              activeColor: AppColors.neniDeep,
              onChanged: (value) {
                properties['fontSize'] = value.round();
                onUpdate(selected.copyWith(properties: properties));
              },
            ),
            Wrap(
              spacing: 7,
              children: ['left', 'center', 'right']
                  .map(
                    (align) => ChoiceChip(
                      label: Icon(
                        align == 'left'
                            ? Symbols.format_align_left
                            : align == 'center'
                            ? Symbols.format_align_center
                            : Symbols.format_align_right,
                        size: 18,
                      ),
                      selected: properties['align'] == align,
                      selectedColor: AppColors.neni.withValues(alpha: 0.18),
                      onSelected: (_) {
                        properties['align'] = align;
                        onUpdate(selected.copyWith(properties: properties));
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
          if (selected.type == 'image') ...[
            const SizedBox(height: 5),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Recortar para llenar'),
              value: properties['fit'] == 'cover',
              activeThumbColor: AppColors.neniDeep,
              onChanged: (value) {
                properties['fit'] = value ? 'cover' : 'contain';
                onUpdate(selected.copyWith(properties: properties));
              },
            ),
          ],
          const SizedBox(height: 8),
          _PositionControls(element: selected, onUpdate: onUpdate),
        ],
      ),
    );
  }
}

class _PositionControls extends StatelessWidget {
  const _PositionControls({required this.element, required this.onUpdate});
  final LabelDesignElement element;
  final ValueChanged<LabelDesignElement> onUpdate;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        'Posición: ${element.x.toStringAsFixed(0)}, ${element.y.toStringAsFixed(0)} mm',
        style: AppTextStyles.subtitle.copyWith(fontSize: 11),
      ),
      const Spacer(),
      IconButton(
        onPressed: () =>
            onUpdate(element.copyWith(x: math.max(0, element.x - 1))),
        icon: const Icon(Symbols.chevron_left),
        tooltip: 'Mover a la izquierda',
      ),
      IconButton(
        onPressed: () =>
            onUpdate(element.copyWith(y: math.max(0, element.y - 1))),
        icon: const Icon(Symbols.keyboard_arrow_up),
        tooltip: 'Mover arriba',
      ),
      IconButton(
        onPressed: () => onUpdate(element.copyWith(y: element.y + 1)),
        icon: const Icon(Symbols.keyboard_arrow_down),
        tooltip: 'Mover abajo',
      ),
      IconButton(
        onPressed: () => onUpdate(element.copyWith(x: element.x + 1)),
        icon: const Icon(Symbols.chevron_right),
        tooltip: 'Mover a la derecha',
      ),
    ],
  );
}

class _AddElementSheet extends StatelessWidget {
  const _AddElementSheet({required this.kind});
  final LabelTemplateKind kind;
  @override
  Widget build(BuildContext context) => _SheetFrame(
    title: 'Añadir a la etiqueta',
    child: Column(
      children: [
        _AddOption(
          icon: Symbols.text_fields,
          title: 'Texto libre',
          subtitle: 'Título, instrucción o mensaje',
          onTap: () => Navigator.pop(
            context,
            const _NewElementSpec('text', {
              'text': 'Texto nuevo',
              'fontSize': 12,
              'fontWeight': 600,
              'align': 'left',
            }),
          ),
        ),
        _AddOption(
          icon: Symbols.data_object,
          title: 'Dato de la etiqueta',
          subtitle: 'Información que cambia en cada impresión',
          onTap: () => _chooseBinding(context),
        ),
        _AddOption(
          icon: Symbols.qr_code_2,
          title: kind == LabelTemplateKind.orderPackage
              ? 'Código QR de la bolsa'
              : 'Código QR de la etiqueta',
          subtitle: 'Se conserva para escanear',
          onTap: () => Navigator.pop(
            context,
            _NewElementSpec('qr', {'binding': _qrBinding(kind)}),
          ),
        ),
        _AddOption(
          icon: Symbols.barcode,
          title: 'Código de barras',
          subtitle: 'Para formatos compatibles',
          onTap: () => Navigator.pop(
            context,
            _NewElementSpec('barcode', {
              'binding': _barcodeBinding(kind),
              'displayValue': false,
            }),
          ),
        ),
        _AddOption(
          icon: Symbols.horizontal_rule,
          title: 'Línea',
          subtitle: 'Separador visual',
          onTap: () => Navigator.pop(
            context,
            const _NewElementSpec('line', {'color': '#3A2233'}),
          ),
        ),
        _AddOption(
          icon: Symbols.rectangle,
          title: 'Forma',
          subtitle: 'Bloque de color o marco',
          onTap: () => Navigator.pop(
            context,
            const _NewElementSpec('shape', {
              'fill': '#FDE4EC',
              'borderColor': '#FB6F9C',
              'borderWidth': 1,
            }),
          ),
        ),
      ],
    ),
  );

  Future<void> _chooseBinding(BuildContext context) async {
    final binding = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetFrame(
        title: 'Dato de ${kind.label}',
        child: Column(
          children: _bindingsFor(kind)
              .map(
                (binding) => _AddOption(
                  icon: Symbols.data_object,
                  title: binding.$2,
                  subtitle: binding.$1,
                  onTap: () => Navigator.pop(context, binding.$1),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (binding == null || !context.mounted) return;
    Navigator.pop(
      context,
      _NewElementSpec('data', {
        'binding': binding,
        'fontSize': 12,
        'fontWeight': 600,
        'align': 'left',
        'wrap': binding == 'order.address' || binding == 'order.itemSummary',
      }),
    );
  }
}

class _AssetLibrarySheet extends ConsumerWidget {
  const _AssetLibrarySheet({required this.onUpload});
  final VoidCallback onUpload;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(labelAssetsProvider);
    return _SheetFrame(
      title: 'Imágenes de la etiqueta',
      trailing: TextButton.icon(
        onPressed: onUpload,
        icon: const Icon(Symbols.add_photo_alternate),
        label: const Text('Subir'),
      ),
      child: assets.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(28),
          child: CircularProgressIndicator(color: AppColors.neniDeep),
        ),
        error: (_, _) => Text(
          'No pudimos cargar las imágenes.',
          style: AppTextStyles.subtitle,
        ),
        data: (items) => items.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Column(
                  children: [
                    const Icon(Symbols.image, size: 34, color: AppColors.ink3),
                    const SizedBox(height: 8),
                    Text(
                      'Sube un logo, sello o imagen para empezar.',
                      style: AppTextStyles.subtitle,
                    ),
                  ],
                ),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 9,
                  mainAxisSpacing: 9,
                ),
                itemBuilder: (_, index) {
                  final asset = items[index];
                  return InkWell(
                    onTap: () => Navigator.pop(context, asset),
                    borderRadius: BorderRadius.circular(AppRadii.smallTile),
                    child: Ink(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(asset.url),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity,
                          color: Colors.black45,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 2,
                          ),
                          child: Text(
                            asset.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;
  List<Widget> get _trailing => trailing == null ? const [] : [trailing!];
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: AppRadii.pillRadius,
                ),
              ),
            ),
            const SizedBox(height: 17),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.h2.copyWith(fontSize: 18),
                  ),
                ),
                ..._trailing,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    ),
  );
}

class _AddOption extends StatelessWidget {
  const _AddOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: AppColors.neniDeep),
    title: Text(
      title,
      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      subtitle,
      style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
    ),
    trailing: const Icon(Symbols.chevron_right, color: AppColors.ink3),
    onTap: onTap,
  );
}

class _EditorError extends StatelessWidget {
  const _EditorError({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.cloud_off, size: 44, color: AppColors.ink3),
          const SizedBox(height: 12),
          Text(
            'No pudimos abrir el editor de etiquetas.',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 15),
          PillButton(
            label: 'Volver a etiquetas',
            expand: false,
            onPressed: onBack,
          ),
        ],
      ),
    ),
  );
}

class _NewElementSpec {
  const _NewElementSpec(this.type, this.properties);
  final String type;
  final Map<String, dynamic> properties;
}

const _orderBindings = <(String, String)>[
  ('business.name', 'Nombre de tu tienda'),
  ('order.clientName', 'Nombre de la clienta'),
  ('order.phone', 'Teléfono'),
  ('order.address', 'Dirección'),
  ('order.itemSummary', 'Contenido de la bolsa'),
  ('order.deliveryInstructions', 'Nota de entrega'),
  ('package.number', 'Número de bolsa'),
  ('package.total', 'Total de bolsas'),
];

const _inventoryBoxBindings = <(String, String)>[
  ('business.name', 'Nombre de tu tienda'),
  ('box.code', 'Código de caja'),
  ('box.name', 'Nombre de caja'),
  ('box.location', 'Ubicación'),
  ('box.nfcUrl', 'Enlace NFC de la caja'),
];

const _inventoryItemBindings = <(String, String)>[
  ('business.name', 'Nombre de tu tienda'),
  ('item.name', 'Nombre del artículo'),
  ('item.variant', 'Talla, color o variante'),
  ('item.scannableCode', 'Código escaneable'),
  ('item.barcode', 'Código de barras'),
];

List<(String, String)> _bindingsFor(LabelTemplateKind kind) => switch (kind) {
  LabelTemplateKind.inventoryBox => _inventoryBoxBindings,
  LabelTemplateKind.inventoryItem => _inventoryItemBindings,
  LabelTemplateKind.orderPackage => _orderBindings,
};

String _qrBinding(LabelTemplateKind kind) => switch (kind) {
  LabelTemplateKind.inventoryBox => 'box.nfcUrl',
  LabelTemplateKind.inventoryItem => 'item.scannableCode',
  LabelTemplateKind.orderPackage => 'package.qrCodeValue',
};

String _barcodeBinding(LabelTemplateKind kind) => switch (kind) {
  LabelTemplateKind.inventoryBox => 'box.code',
  LabelTemplateKind.inventoryItem => 'item.scannableCode',
  LabelTemplateKind.orderPackage => 'package.qrCodeValue',
};

IconData _iconFor(String type) => switch (type) {
  'text' => Symbols.text_fields,
  'data' => Symbols.data_object,
  'qr' => Symbols.qr_code_2,
  'barcode' => Symbols.barcode,
  'image' => Symbols.image,
  'shape' => Symbols.rectangle,
  _ => Symbols.horizontal_rule,
};

String _labelFor(LabelDesignElement element) => switch (element.type) {
  'text' => 'Texto libre',
  'data' => _bindingLabel(element.binding),
  'qr' => 'Código QR',
  'barcode' => 'Código de barras',
  'image' => 'Imagen',
  'shape' => 'Forma',
  _ => 'Línea',
};

String _bindingLabel(String? binding) {
  for (final item in [
    ..._orderBindings,
    ..._inventoryBoxBindings,
    ..._inventoryItemBindings,
  ]) {
    if (item.$1 == binding) return item.$2;
  }
  return 'Dato del pedido';
}
