import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/label_template_models.dart';

class LabelTemplateCanvas extends StatelessWidget {
  const LabelTemplateCanvas({
    super.key,
    required this.design,
    required this.assets,
    required this.selectedId,
    required this.onSelect,
    required this.onMove,
    required this.onResize,
  });

  final LabelDesign design;
  final List<LabelAsset> assets;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final void Function(String id, Offset deltaMm) onMove;
  final void Function(String id, Offset deltaMm) onResize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, 390.0);
        final scale = width / design.widthMm;
        final height = design.heightMm * scale;
        final assetsById = {for (final asset in assets) asset.id: asset};
        return Center(
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: _toColor(design.background) ?? Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.ink.withValues(alpha: 0.25)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1C3A2233),
                  blurRadius: 20,
                  offset: Offset(0, 9),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: scale,
                  top: scale,
                  right: scale,
                  bottom: scale,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.neni.withValues(alpha: 0.28),
                          style: BorderStyle.solid,
                        ),
                      ),
                    ),
                  ),
                ),
                for (final element in design.elements.where(
                  (element) => element.visible,
                ))
                  _CanvasElement(
                    element: element,
                    asset: assetsById[element.properties['assetId']],
                    scale: scale,
                    selected: element.id == selectedId,
                    onTap: () => onSelect(element.id),
                    onMove: (delta) => onMove(element.id, delta / scale),
                    onResize: (delta) => onResize(element.id, delta / scale),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CanvasElement extends StatelessWidget {
  const _CanvasElement({
    required this.element,
    required this.asset,
    required this.scale,
    required this.selected,
    required this.onTap,
    required this.onMove,
    required this.onResize,
  });

  final LabelDesignElement element;
  final LabelAsset? asset;
  final double scale;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<Offset> onMove;
  final ValueChanged<Offset> onResize;

  @override
  Widget build(BuildContext context) {
    final width = element.width * scale;
    final height = element.height * scale;
    return Positioned(
      left: element.x * scale,
      top: element.y * scale,
      width: width,
      height: height,
      child: Transform.rotate(
        angle: element.rotation * math.pi / 180,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: onTap,
          onPanUpdate: selected ? (details) => onMove(details.delta) : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: selected
                        ? Border.all(color: AppColors.neniDeep, width: 1.5)
                        : null,
                    color: selected
                        ? AppColors.neni.withValues(alpha: 0.05)
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(1),
                    child: _PreviewElement(
                      element: element,
                      asset: asset,
                      scale: scale,
                    ),
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  right: -8,
                  bottom: -8,
                  child: GestureDetector(
                    onPanUpdate: (details) => onResize(details.delta),
                    child: Container(
                      width: 17,
                      height: 17,
                      decoration: BoxDecoration(
                        color: AppColors.neniDeep,
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(
                        Symbols.open_in_full,
                        size: 10,
                        color: Colors.white,
                      ),
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

class _PreviewElement extends StatelessWidget {
  const _PreviewElement({
    required this.element,
    required this.asset,
    required this.scale,
  });

  final LabelDesignElement element;
  final LabelAsset? asset;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final properties = element.properties;
    switch (element.type) {
      case 'qr':
        return const DecoratedBox(
          decoration: BoxDecoration(color: Colors.white),
          child: Center(child: Icon(Symbols.qr_code_2, color: Colors.black)),
        );
      case 'barcode':
        return const Center(child: Icon(Symbols.barcode, color: Colors.black));
      case 'image':
        if (asset == null) {
          return const Center(
            child: Icon(Symbols.broken_image, color: AppColors.liveRed),
          );
        }
        return Image.network(
          asset!.url,
          fit: properties['fit'] == 'cover' ? BoxFit.cover : BoxFit.contain,
          errorBuilder: (_, _, _) => const Center(
            child: Icon(Symbols.broken_image, color: AppColors.liveRed),
          ),
        );
      case 'shape':
        return DecoratedBox(
          decoration: BoxDecoration(
            color:
                _toColor(properties['fill']) ??
                AppColors.neni.withValues(alpha: 0.20),
            border: Border.all(
              color: _toColor(properties['borderColor']) ?? AppColors.neniDeep,
              width: (properties['borderWidth'] as num?)?.toDouble() ?? 1,
            ),
          ),
        );
      case 'line':
        return ColoredBox(
          color: _toColor(properties['color']) ?? AppColors.ink,
        );
      default:
        final text = element.type == 'data'
            ? _bindingPreview(properties['binding'] as String? ?? '')
            : (properties['text'] as String? ?? 'Texto');
        final align = switch (properties['align']) {
          'center' => TextAlign.center,
          'right' => TextAlign.right,
          _ => TextAlign.left,
        };
        final fontSize =
            ((properties['fontSize'] as num?)?.toDouble() ?? 10) * 0.78;
        return Align(
          alignment: switch (align) {
            TextAlign.center => Alignment.topCenter,
            TextAlign.right => Alignment.topRight,
            _ => Alignment.topLeft,
          },
          child: Text(
            text,
            maxLines: properties['wrap'] == true ? null : 1,
            overflow: TextOverflow.clip,
            textAlign: align,
            style: AppTextStyles.body.copyWith(
              color: _toColor(properties['color']) ?? Colors.black,
              fontSize: math.max(6, fontSize),
              fontWeight:
                  ((properties['fontWeight'] as num?)?.toInt() ?? 400) >= 700
                  ? FontWeight.w700
                  : FontWeight.w400,
              height: 1.05,
            ),
          ),
        );
    }
  }

  String _bindingPreview(String binding) => switch (binding) {
    'business.name' => 'Mi tienda',
    'order.clientName' => 'Nombre clienta',
    'order.phone' => 'Tel. 868 000 0000',
    'order.address' => 'Dirección de entrega',
    'order.itemSummary' => '1 x Producto\n2 x Otro producto',
    'order.deliveryInstructions' => 'Nota de entrega',
    'package.number' => '#1',
    'package.total' => '1 BOLSA',
    'package.qrCodeValue' => 'QR de bolsa',
    'box.code' => 'B-01',
    'box.name' => 'Caja blusas',
    'box.location' => 'Estante A · Nivel 2',
    'box.nfcUrl' => 'Enlace NFC de caja',
    'item.name' => 'Blusa satinada',
    'item.variant' => 'Rosa · M',
    'item.scannableCode' => 'NNI-000123',
    'item.barcode' => 'Código de barras',
    _ => 'Dato',
  };
}

Color? _toColor(Object? value) {
  if (value is! String) return null;
  final hex = value.replaceFirst('#', '');
  if (hex.length != 6) return null;
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(0xFF000000 | parsed);
}
