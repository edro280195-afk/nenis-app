import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import 'pill_button.dart';

/// Tarjeta que reemplaza una función bloqueada por el plan (LivePush,
/// VipDrops, etc.) con un upsell hacia "Mi plan". El backend ya bloquea el
/// endpoint con 402; esto es solo la capa visual.
class FeatureLockedCard extends StatelessWidget {
  const FeatureLockedCard({
    super.key,
    required this.title,
    required this.body,
    this.requiredPlan = 'Pro',
  });

  final String title;
  final String body;
  final String requiredPlan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        boxShadow: AppShadows.small,
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.neniDeep, AppColors.neni]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Symbols.lock, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: AppTextStyles.h2.copyWith(fontSize: 16)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: AppTextStyles.subtitle.copyWith(fontSize: 12.5)),
          const SizedBox(height: 16),
          PillButton(
            label: 'Ver plan $requiredPlan',
            icon: Symbols.workspace_premium,
            expand: false,
            variant: PillButtonVariant.brand,
            onPressed: () => context.push('/seller/plan'),
          ),
        ],
      ),
    );
  }
}
