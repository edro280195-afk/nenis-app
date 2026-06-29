import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';

enum OrderStatus { pending, route, delivered }

extension OrderStatusDisplay on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Pendiente';
      case OrderStatus.route:
        return 'En ruta';
      case OrderStatus.delivered:
        return 'Entregado';
    }
  }

  IconData get icon {
    switch (this) {
      case OrderStatus.pending:
        return Symbols.schedule;
      case OrderStatus.route:
        return Symbols.local_shipping;
      case OrderStatus.delivered:
        return Symbols.check_circle;
    }
  }

  Color get fg {
    switch (this) {
      case OrderStatus.pending:
        return AppColors.statusPendingFg;
      case OrderStatus.route:
        return AppColors.statusRouteFg;
      case OrderStatus.delivered:
        return AppColors.statusDeliveredFg;
    }
  }

  Color get bg {
    switch (this) {
      case OrderStatus.pending:
        return AppColors.statusPendingBg;
      case OrderStatus.route:
        return AppColors.statusRouteBg;
      case OrderStatus.delivered:
        return AppColors.statusDeliveredBg;
    }
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    this.onWhite = false,
  });

  final OrderStatus status;
  final bool onWhite;

  @override
  Widget build(BuildContext context) {
    final fg = onWhite ? AppColors.surface : status.fg;
    final bg = onWhite ? Colors.white.withValues(alpha: 0.22) : status.bg;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadii.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 15, color: fg),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: AppTextStyles.chip.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}
