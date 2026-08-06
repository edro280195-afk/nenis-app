import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/interactive_bounce.dart';
import '../../../shared/widgets/pill_button.dart';
import '../data/label_print_models.dart';
import '../widgets/label_widgets.dart';

class LabelPrintOptions {
  const LabelPrintOptions({required this.mediaSize, required this.copies});

  final LabelMediaSize mediaSize;
  final int copies;
}

Future<LabelPrintOptions?> showLabelPrintOptionsSheet(
  BuildContext context, {
  required int packageCount,
  LabelMediaSize? initialMediaSize,
}) {
  return showModalBottomSheet<LabelPrintOptions>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.ink.withValues(alpha: 0.55),
    builder: (_) => _LabelPrintOptionsSheet(
      packageCount: packageCount,
      initialMediaSize: initialMediaSize,
    ),
  );
}

class _LabelPrintOptionsSheet extends StatefulWidget {
  const _LabelPrintOptionsSheet({
    required this.packageCount,
    this.initialMediaSize,
  });

  final int packageCount;
  final LabelMediaSize? initialMediaSize;

  @override
  State<_LabelPrintOptionsSheet> createState() =>
      _LabelPrintOptionsSheetState();
}

class _LabelPrintOptionsSheetState extends State<_LabelPrintOptionsSheet> {
  late LabelMediaSize _mediaSize =
      widget.initialMediaSize ?? LabelMediaSize.shipping4x6;
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
                    color: AppColors.line,
                    borderRadius: AppRadii.pillRadius,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Antes de imprimir',
                style: AppTextStyles.h1.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 3),
              Text(
                '${widget.packageCount} ${widget.packageCount == 1 ? 'etiqueta' : 'etiquetas'} · eliges la impresora después',
                style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
              ),
              const SizedBox(height: 18),
              const LabelFieldLabel(icon: Symbols.sell, label: 'Formato de etiqueta'),
              const SizedBox(height: 9),
              for (final size in LabelMediaSize.values) ...[
                LabelMediaChoice(
                  size: size,
                  selected: _mediaSize == size,
                  onTap: () => setState(() => _mediaSize = size),
                ),
                const SizedBox(height: 9),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Copias por bolsa',
                          style: AppTextStyles.body.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Cada bolsa conserva su propio QR.',
                          style: AppTextStyles.subtitle.copyWith(fontSize: 10.5),
                        ),
                      ],
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
                  border: Border.all(color: AppColors.lineSoft),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Text(
                      '${widget.packageCount} ${widget.packageCount == 1 ? 'bolsa' : 'bolsas'} × $_copies ${_copies == 1 ? 'copia' : 'copias'}',
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
                label: 'Continuar a impresoras',
                icon: Symbols.print,
                onPressed: () => Navigator.of(context).pop(
                  LabelPrintOptions(mediaSize: _mediaSize, copies: _copies),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LabelFieldLabel extends StatelessWidget {
  const LabelFieldLabel({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: AppColors.neniDeep),
      const SizedBox(width: 7),
      Text(
        label,
        style: AppTextStyles.body.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class LabelMediaChoice extends StatelessWidget {
  const LabelMediaChoice({
    super.key,
    required this.size,
    required this.selected,
    required this.onTap,
    this.detailOverride,
  });

  final LabelMediaSize size;
  final bool selected;
  final VoidCallback onTap;
  final String? detailOverride;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.neni.withValues(alpha: 0.06)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.neniDeep : AppColors.lineSoft,
                width: selected ? 1.6 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.neniDeep.withValues(alpha: 0.40),
                        offset: const Offset(0, 8),
                        blurRadius: 18,
                        spreadRadius: -10,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                LabelFormatPreview(size: size),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        size.label,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        detailOverride ?? size.detail,
                        style: AppTextStyles.subtitle.copyWith(
                          fontSize: 10.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                LabelRadioDot(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LabelFormatPreview extends StatelessWidget {
  const LabelFormatPreview({super.key, required this.size});

  final LabelMediaSize size;

  @override
  Widget build(BuildContext context) {
    final ship = size == LabelMediaSize.shipping4x6;
    return Container(
      width: ship ? 44 : 40,
      height: ship ? 56 : 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.12)),
      ),
      child: ship
          ? const _BarcodeBars(
              widths: [3, 5, 3, 6, 3, 5, 3, 6],
              barHeight: 14,
            )
          : const LabelQrPlaceholder(size: 26),
    );
  }
}

class _BarcodeBars extends StatelessWidget {
  const _BarcodeBars({required this.widths, required this.barHeight});

  final List<double> widths;
  final double barHeight;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (final width in widths) ...[
        Container(width: width, height: barHeight, color: AppColors.ink),
        const SizedBox(width: 2),
      ],
    ],
  );
}

class LabelRadioDot extends StatelessWidget {
  const LabelRadioDot({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
      border: Border.all(
        color: selected ? AppColors.neniDeep : AppColors.ink3,
        width: 1.8,
      ),
    ),
    child: selected
        ? Container(
            margin: const EdgeInsets.all(5.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.neni, AppColors.neniDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          )
        : null,
  );
}

class LabelCopiesControl extends StatelessWidget {
  const LabelCopiesControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.lineSoft),
        borderRadius: AppRadii.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LabelCopyButton(
            icon: Symbols.remove,
            onTap: value > 1 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppTextStyles.h2.copyWith(fontSize: 14),
            ),
          ),
          LabelCopyButton(
            icon: Symbols.add,
            onTap: value < 100 ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class LabelCopyButton extends StatelessWidget {
  const LabelCopyButton({super.key, required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InteractiveBounce(
      onPressed: onTap,
      scaleFactor: 0.88,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.neni.withValues(alpha: 0.12)
                  : Colors.transparent,
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
