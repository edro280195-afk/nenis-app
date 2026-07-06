import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/seller_orders_data.dart';

/// Presentación (label/icono/colores) para cada estatus de pedido de vendedora.
extension SellerOrderStatusUi on SellerOrderStatus {
  String get label => switch (this) {
        SellerOrderStatus.pending => 'Pendiente',
        SellerOrderStatus.confirmed => 'Confirmado',
        SellerOrderStatus.route => 'En ruta',
        SellerOrderStatus.delivered => 'Entregado',
      };

  IconData get icon => switch (this) {
        SellerOrderStatus.pending => Symbols.schedule,
        SellerOrderStatus.confirmed => Symbols.favorite,
        SellerOrderStatus.route => Symbols.local_shipping,
        SellerOrderStatus.delivered => Symbols.check_circle,
      };

  Color get fg => switch (this) {
        SellerOrderStatus.pending => AppColors.statusPendingFg,
        SellerOrderStatus.confirmed => AppColors.neniDeep,
        SellerOrderStatus.route => AppColors.statusRouteFg,
        SellerOrderStatus.delivered => AppColors.statusDeliveredFg,
      };

  Color get bg => switch (this) {
        SellerOrderStatus.pending => AppColors.statusPendingBg,
        SellerOrderStatus.confirmed => const Color(0xFFFFE1EC),
        SellerOrderStatus.route => AppColors.statusRouteBg,
        SellerOrderStatus.delivered => AppColors.statusDeliveredBg,
      };
}

class SellerStatusChip extends StatelessWidget {
  const SellerStatusChip({super.key, required this.status});

  final SellerOrderStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 27,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: AppRadii.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 15, color: status.fg),
          const SizedBox(width: 4),
          Text(status.label, style: AppTextStyles.chip.copyWith(color: status.fg)),
        ],
      ),
    );
  }
}
