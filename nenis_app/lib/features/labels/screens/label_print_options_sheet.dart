import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/pill_button.dart';
import '../data/label_print_models.dart';

class LabelPrintOptions {
  const LabelPrintOptions({required this.mediaSize, required this.copies});

  final LabelMediaSize mediaSize;
  final int copies;
}

Future<LabelPrintOptions?> showLabelPrintOptionsSheet(
  BuildContext context, {
  required int packageCount,
}) {
  return showModalBottomSheet<LabelPrintOptions>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LabelPrintOptionsSheet(packageCount: packageCount),
  );
}

class _LabelPrintOptionsSheet extends StatefulWidget {
  const _LabelPrintOptionsSheet({required this.packageCount});

  final int packageCount;

  @override
  State<_LabelPrintOptionsSheet> createState() =>
      _LabelPrintOptionsSheetState();
}

class _LabelPrintOptionsSheetState extends State<_LabelPrintOptionsSheet> {
  LabelMediaSize _mediaSize = LabelMediaSize.shipping4x6;
  int _copies = 1;

  @override
  Widget build(BuildContext context) {
    final total = widget.packageCount * _copies;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
        decoration: const BoxDecoration(
          color: AppColors.surfaceCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 20),
            Text(
              'Antes de imprimir',
              style: AppTextStyles.h1.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 4),
            Text(
              '$total ${total == 1 ? 'etiqueta' : 'etiquetas'} · elegirás la impresora después',
              style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
            ),
            const SizedBox(height: 20),
            Text(
              'Formato de etiqueta',
              style: AppTextStyles.h2.copyWith(fontSize: 14.5),
            ),
            const SizedBox(height: 10),
            for (final size in LabelMediaSize.values) ...[
              _MediaChoice(
                size: size,
                selected: _mediaSize == size,
                onTap: () => setState(() => _mediaSize = size),
              ),
              const SizedBox(height: 9),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Copias por bolsa',
                        style: AppTextStyles.h2.copyWith(fontSize: 14.5),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Cada bolsa conserva su propio QR.',
                        style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                _CopiesControl(
                  value: _copies,
                  onChanged: (value) => setState(() => _copies = value),
                ),
              ],
            ),
            const SizedBox(height: 22),
            PillButton(
              label: 'Continuar a impresoras',
              icon: Symbols.print,
              onPressed: () => Navigator.of(
                context,
              ).pop(LabelPrintOptions(mediaSize: _mediaSize, copies: _copies)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaChoice extends StatelessWidget {
  const _MediaChoice({
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final LabelMediaSize size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.softRadius,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.neni.withValues(alpha: 0.11)
                  : AppColors.surface,
              borderRadius: AppRadii.softRadius,
              border: Border.all(
                color: selected ? AppColors.neniDeep : AppColors.lineSoft,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  size == LabelMediaSize.shipping4x6
                      ? Symbols.local_shipping
                      : Symbols.sell,
                  color: selected ? AppColors.neniDeep : AppColors.ink2,
                  size: 23,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        size.label,
                        style: AppTextStyles.h2.copyWith(fontSize: 14.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        size.detail,
                        style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Symbols.radio_button_checked
                      : Symbols.radio_button_unchecked,
                  color: selected ? AppColors.neniDeep : AppColors.ink3,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CopiesControl extends StatelessWidget {
  const _CopiesControl({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.lineSoft),
        borderRadius: AppRadii.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CopyButton(
            icon: Symbols.remove,
            onTap: value > 1 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 30,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppTextStyles.h2.copyWith(fontSize: 15),
            ),
          ),
          _CopyButton(
            icon: Symbols.add,
            onTap: value < 100 ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      color: AppColors.neniDeep,
      visualDensity: VisualDensity.compact,
      tooltip: icon == Symbols.add ? 'Aumentar copias' : 'Reducir copias',
    );
  }
}

class LabelFeatureLockedView extends StatelessWidget {
  const LabelFeatureLockedView({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.neni.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.neni.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Symbols.print,
              color: AppColors.neniDeep,
              size: 22,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Etiquetas de bolsas',
            style: AppTextStyles.h2.copyWith(fontSize: compact ? 16 : 19),
          ),
          const SizedBox(height: 4),
          Text(
            'Prepara bolsas con QR y manda a imprimir desde tu teléfono, con la impresora que tú elijas.',
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          PillButton(
            label: 'Ver planes Pro y Elite',
            expand: !compact,
            icon: Symbols.workspace_premium,
            onPressed: () => context.push('/seller/plan'),
          ),
        ],
      ),
    );
  }
}
