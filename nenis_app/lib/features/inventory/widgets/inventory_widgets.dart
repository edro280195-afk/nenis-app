import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/interactive_bounce.dart';
import '../../labels/widgets/label_widgets.dart';
import '../data/inventory_models.dart';

/// Umbral para marcar un artículo como "quedan pocos" en la caja.
const int lowStockThreshold = 3;

/// "Actualizada hace 5 min", "hace 2 h", "hace 3 días", "recién".
String timeAgo(DateTime dateTime) {
  final difference = DateTime.now().difference(dateTime);
  if (difference.inMinutes < 1) return 'recién';
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return 'hace $minutes ${minutes == 1 ? 'min' : 'min'}';
  }
  if (difference.inHours < 24) {
    final hours = difference.inHours;
    return 'hace $hours ${hours == 1 ? 'h' : 'h'}';
  }
  if (difference.inDays < 7) {
    final days = difference.inDays;
    return 'hace $days ${days == 1 ? 'día' : 'días'}';
  }
  final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
  final today = DateTime.now();
  if (date.year == today.year) {
    return '${date.day}/${date.month}';
  }
  return '${date.day}/${date.month}/${date.year}';
}

/// "hoy 9:40", "ayer 18:02", "12 jul".
String dayTime(DateTime dateTime) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(dateTime.year, dateTime.month, dateTime.day);
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  if (that == today) return 'hoy $hour:$minute';
  if (that == today.subtract(const Duration(days: 1))) {
    return 'ayer $hour:$minute';
  }
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${dateTime.day} ${months[dateTime.month - 1]}';
}

/// Da formato legible a un UID NFC ("04A2B1C7" -> "04:A2:B1:C7").
String formatNfcUid(String? uid) {
  if (uid == null || uid.isEmpty) return 'Sin UID';
  final clean = uid
      .replaceAll(RegExp(r'[^0-9A-Fa-f]'), '')
      .toUpperCase();
  final parts = <String>[];
  for (var index = 0; index < clean.length; index += 2) {
    final end = index + 2;
    if (end > clean.length) break;
    parts.add(clean.substring(index, end));
  }
  return parts.join(':');
}

/// Tarjeta hero con gradiente rosa: título grande, subtítulo, pieza
/// decorativa y chips translúcidos. Corresponde al hero del mockup.
class InventoryHero extends StatelessWidget {
  const InventoryHero({
    super.key,
    required this.eyebrow,
    required this.headline,
    this.headlineSuffix,
    this.sub,
    this.trailing,
    this.chips = const [],
  });

  final String eyebrow;
  final String headline;
  final String? headlineSuffix;
  final String? sub;
  final Widget? trailing;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x8CE84E83),
            offset: Offset(0, 18),
            blurRadius: 34,
            spreadRadius: -16,
          ),
        ],
        gradient: const LinearGradient(
          colors: [AppColors.neni, AppColors.neniDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            const Positioned(
              right: -30,
              top: -30,
              child: _HeroBubble(size: 150, opacity: 0.14),
            ),
            const Positioned(
              right: 34,
              bottom: -44,
              child: _HeroBubble(size: 120, opacity: 0.10),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
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
                              eyebrow.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                  color: Colors.white,
                                ),
                                children: [
                                  TextSpan(text: headline),
                                  if (headlineSuffix != null)
                                    TextSpan(
                                      text: ' $headlineSuffix',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (sub != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                sub!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 10),
                        trailing!,
                      ],
                    ],
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(spacing: 7, runSpacing: 7, children: chips),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBubble extends StatelessWidget {
  const _HeroBubble({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      shape: BoxShape.circle,
    ),
  );
}

/// Chip translúcido que se muestra dentro del hero.
class InventoryGhostChip extends StatelessWidget {
  const InventoryGhostChip({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: AppRadii.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return InteractiveBounce(onPressed: onTap, child: chip);
  }
}

/// Fila de estadísticas con separadores verticales (Artículos, Piezas, …).
class InventoryStatRow extends StatelessWidget {
  const InventoryStatRow({super.key, required this.stats});

  final List<({String value, String label})> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.small,
      ),
      child: Row(
        children: [
          for (var index = 0; index < stats.length; index++) ...[
            if (index > 0)
              const VerticalDivider(width: 1, color: AppColors.line),
            Expanded(
              child: Column(
                children: [
                  Text(
                    stats[index].value,
                    style: AppTextStyles.h2.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    stats[index].label,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle.copyWith(fontSize: 9.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chip de filtro plegable (Todas, Con NFC, Sin NFC, Entradas, …).
class InventoryFilterChip extends StatelessWidget {
  const InventoryFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InteractiveBounce(
      onPressed: onTap,
      scaleFactor: 0.94,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          borderRadius: AppRadii.pillRadius,
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.line,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.chip.copyWith(
            fontSize: 11,
            color: selected ? Colors.white : AppColors.ink2,
          ),
        ),
      ),
    );
  }
}

/// Encabezado de sección con icono, título y una acción opcional a la derecha.
class InventorySectionHeader extends StatelessWidget {
  const InventorySectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.neniDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.h2.copyWith(fontSize: 14.5),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AppColors.neniDeep,
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Insignia pequeña del estado NFC de una caja.
class InventoryNfcBadge extends StatelessWidget {
  const InventoryNfcBadge({super.key, required this.bound});

  final bool bound;

  @override
  Widget build(BuildContext context) {
    final background = bound
        ? AppColors.lavender.withValues(alpha: 0.14)
        : AppColors.statusPendingBg;
    final foreground = bound ? AppColors.lavender : AppColors.statusPendingFg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.pillRadius,
      ),
      child: Text(
        bound ? 'NFC' : 'Sin NFC',
        style: AppTextStyles.chip.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: foreground,
        ),
      ),
    );
  }
}

/// Tarjeta de caja del Resumen: icono, código + estado NFC, nombre,
/// ubicación, artículos/piezas y última actualización.
class InventoryBoxCard extends StatelessWidget {
  const InventoryBoxCard({super.key, required this.box, required this.onTap});

  final InventoryBoxSummary box;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lavender = box.code.hashCode.isEven;
    final meta = [
      if (box.location != null) box.location!,
      '${box.articleTypesCount} ${box.articleTypesCount == 1 ? 'artículo' : 'artículos'}',
      '${box.totalUnits} ${box.totalUnits == 1 ? 'pieza' : 'piezas'}',
    ].join(' · ');
    return InteractiveBounce(
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.cardRadius,
          boxShadow: AppShadows.small,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: lavender
                    ? AppColors.lavender.withValues(alpha: 0.14)
                    : AppColors.neni.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Symbols.inventory_2,
                size: 22,
                color: lavender ? AppColors.lavender : AppColors.neniDeep,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          box.code,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      InventoryNfcBadge(bound: box.isNfcBound),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    box.name,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subtitle.copyWith(fontSize: 10.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Actualizada ${timeAgo(box.updatedAt)}',
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 9,
                      color: AppColors.ink3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Symbols.chevron_right, size: 20, color: AppColors.ink3),
          ],
        ),
      ),
    );
  }
}

/// Fila de artículo dentro de la caja: miniatura de etiqueta, información,
/// stepper de cantidad y acciones de imprimir/mover.
class InventoryItemRow extends StatelessWidget {
  const InventoryItemRow({
    super.key,
    required this.item,
    required this.busy,
    required this.onAdjust,
    required this.onPrint,
    required this.onTransfer,
  });

  final InventoryItem item;
  final bool busy;
  final ValueChanged<int> onAdjust;
  final VoidCallback onPrint;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    final scannable = item.barcode ?? item.labelCode;
    final low = item.quantity > 0 && item.quantity <= lowStockThreshold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        boxShadow: AppShadows.small,
      ),
      child: Row(
        children: [
          MiniLabelPreview(code: scannable),
          const SizedBox(width: 11),
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
                  '${item.variant ?? 'Sin variante'} · $scannable',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 10),
                ),
                if (low) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Symbols.warning,
                        size: 13,
                        color: Color(0xFFD43B3B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '¡Quedan $item.quantity!',
                        style: AppTextStyles.chip.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFD43B3B),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          _QtyStepper(
            quantity: item.quantity,
            enabled: !busy,
            onAdjust: onAdjust,
          ),
          const SizedBox(width: 6),
          _ItemAction(icon: Symbols.print, onTap: busy ? null : onPrint),
          const SizedBox(width: 5),
          _ItemAction(
            icon: Symbols.swap_horiz,
            swap: true,
            onTap: busy || item.quantity == 0 ? null : onTransfer,
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.quantity,
    required this.enabled,
    required this.onAdjust,
  });

  final int quantity;
  final bool enabled;
  final ValueChanged<int> onAdjust;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.lineSoft,
        borderRadius: AppRadii.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Symbols.remove,
            onTap: enabled && quantity > 0 ? () => onAdjust(-1) : null,
          ),
          SizedBox(
            width: 20,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _StepButton(
            icon: Symbols.add,
            onTap: enabled ? () => onAdjust(1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});

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
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 15,
              color: enabled ? AppColors.neniDeep : AppColors.ink3,
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemAction extends StatelessWidget {
  const _ItemAction({required this.icon, this.onTap, this.swap = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool swap;

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
          borderRadius: BorderRadius.circular(11),
          child: Ink(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: swap
                  ? AppColors.lineSoft
                  : AppColors.neni.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 18,
              color: enabled
                  ? (swap ? AppColors.ink2 : AppColors.neniDeep)
                  : AppColors.ink3,
            ),
          ),
        ),
      ),
    );
  }
}

/// Estilo visual de un movimiento según su tipo.
class InventoryMovementView {
  const InventoryMovementView({
    required this.icon,
    required this.foreground,
    required this.background,
    required this.label,
    required this.pillText,
    required this.pillForeground,
    required this.pillBackground,
    this.after,
  });

  final IconData icon;
  final Color foreground;
  final Color background;
  final String label;
  final String pillText;
  final Color pillForeground;
  final Color pillBackground;
  final String? after;

  bool get isDiff => pillForeground == AppColors.statusPendingFg;
}

InventoryMovementView inventoryMovementView(InventoryMovement movement) {
  final delta = movement.quantityDelta;
  const greenFg = AppColors.statusDeliveredFg;
  const greenBg = AppColors.statusDeliveredBg;
  const redFg = AppColors.liveRed;
  const redBg = Color(0x17FF2D55);
  const blueFg = AppColors.statusRouteFg;
  const blueBg = AppColors.statusRouteBg;
  const lavFg = AppColors.lavender;
  const lavBg = Color(0x249B7BE0);
  const goldFg = AppColors.statusPendingFg;
  const goldBg = AppColors.statusPendingBg;

  switch (movement.type) {
    case 'InitialCount':
      return InventoryMovementView(
        icon: Symbols.add_box,
        foreground: goldFg,
        background: goldBg,
        label: 'Cantidad inicial',
        pillText: '+$delta',
        pillForeground: greenFg,
        pillBackground: greenBg,
        after: 'inicial ${movement.quantityAfter}',
      );
    case 'Added':
      return InventoryMovementView(
        icon: Symbols.add_circle,
        foreground: greenFg,
        background: greenBg,
        label: 'Agregados $delta',
        pillText: '+$delta',
        pillForeground: greenFg,
        pillBackground: greenBg,
        after: 'ahora ${movement.quantityAfter}',
      );
    case 'Removed':
      return InventoryMovementView(
        icon: Symbols.remove_circle,
        foreground: redFg,
        background: redBg,
        label: 'Salida',
        pillText: '$delta',
        pillForeground: redFg,
        pillBackground: redBg,
        after: 'ahora ${movement.quantityAfter}',
      );
    case 'Adjusted':
      return InventoryMovementView(
        icon: Symbols.tune,
        foreground: blueFg,
        background: blueBg,
        label: 'Ajuste manual',
        pillText: delta > 0 ? '+$delta' : '$delta',
        pillForeground: delta > 0 ? greenFg : redFg,
        pillBackground: delta > 0 ? greenBg : redBg,
        after: 'ahora ${movement.quantityAfter}',
      );
    case 'TransferOut':
      return InventoryMovementView(
        icon: Symbols.arrow_outward,
        foreground: lavFg,
        background: lavBg,
        label: 'Traspaso saliente',
        pillText: '$delta',
        pillForeground: redFg,
        pillBackground: redBg,
        after: 'ahora ${movement.quantityAfter}',
      );
    case 'TransferIn':
      return InventoryMovementView(
        icon: Symbols.call_received,
        foreground: lavFg,
        background: lavBg,
        label: 'Traspaso entrante',
        pillText: '+$delta',
        pillForeground: greenFg,
        pillBackground: greenBg,
        after: 'ahora ${movement.quantityAfter}',
      );
    case 'CountAdjustment':
      final hasDifference = delta != 0;
      return InventoryMovementView(
        icon: Symbols.fact_check,
        foreground: goldFg,
        background: goldBg,
        label: 'Conteo físico',
        pillText: hasDifference ? '$delta dif' : '0 dif',
        pillForeground: goldFg,
        pillBackground: goldBg,
        after: hasDifference ? 'ahora ${movement.quantityAfter}' : null,
      );
    default:
      return InventoryMovementView(
        icon: Symbols.history,
        foreground: AppColors.ink2,
        background: AppColors.lineSoft,
        label: 'Movimiento',
        pillText: delta > 0 ? '+$delta' : '$delta',
        pillForeground: delta > 0 ? greenFg : redFg,
        pillBackground: delta > 0 ? greenBg : redBg,
        after: 'ahora ${movement.quantityAfter}',
      );
  }
}

/// Entrada de movimiento reutilizable (movimientos recientes y bitácora).
class InventoryMovementRow extends StatelessWidget {
  const InventoryMovementRow({
    super.key,
    required this.movement,
    this.meta,
    this.showAfter = false,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  final InventoryMovement movement;
  final String? meta;
  final bool showAfter;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final view = inventoryMovementView(movement);
    final line = meta ??
        '${movement.performedBy} · ${dayTime(movement.occurredAt)}';
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: view.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(view.icon, size: 16, color: view.foreground),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  view.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 9.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: view.pillBackground,
                  borderRadius: AppRadii.pillRadius,
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
              if (showAfter && view.after != null) ...[
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
        ],
      ),
    );
  }
}

/// Tarjeta lavanda del estado NFC de la caja.
class InventoryNfcCard extends StatelessWidget {
  const InventoryNfcCard({
    super.key,
    required this.bound,
    required this.uid,
    required this.actionLabel,
    required this.onAction,
  });

  final bool bound;
  final String? uid;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.lavender.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.lavender.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            child: const Icon(Symbols.nfc, size: 21, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bound ? 'Tarjeta NFC vinculada' : 'Sin tarjeta NFC',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  bound
                      ? 'UID ${formatNfcUid(uid)} · acércala para abrir esta caja'
                      : 'Vincula una tarjeta para abrir esta caja acercándola.',
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 10,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: AppColors.lavender,
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
