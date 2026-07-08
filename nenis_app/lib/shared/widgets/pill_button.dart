import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/brand_theme.dart';
import 'interactive_bounce.dart';

enum PillButtonVariant { primary, brand, ghost, facebook }

class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PillButtonVariant.primary,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final PillButtonVariant variant;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final disabled = onPressed == null;
    final isBrand = variant == PillButtonVariant.brand;
    final isPrimary = variant == PillButtonVariant.primary;
    final isFb = variant == PillButtonVariant.facebook;

    final Color bg;
    final Color fg;
    final List<BoxShadow> shadow;
    final Border? border;

    if (isPrimary) {
      bg = AppColors.neni;
      fg = AppColors.surface;
      shadow = AppShadows.brandPrimary(AppColors.neniDeep);
      border = null;
    } else if (isBrand) {
      bg = brand.primary;
      fg = brand.onPrimary;
      shadow = AppShadows.brandPrimary(brand.primary);
      border = null;
    } else if (isFb) {
      bg = AppColors.facebook;
      fg = AppColors.surface;
      shadow = const [
        BoxShadow(
          color: Color(0x991877F2),
          offset: Offset(0, 14),
          blurRadius: 26,
          spreadRadius: -12,
        ),
      ];
      border = null;
    } else {
      bg = AppColors.surface;
      fg = AppColors.ink;
      shadow = AppShadows.small;
      border = Border.all(color: AppColors.line, width: 1.5);
    }

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: fg),
          const SizedBox(width: 10),
        ],
        Text(
          label,
          style: AppTextStyles.button
              .copyWith(color: fg)
              .copyWith(fontSize: 16),
        ),
      ],
    );

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: InteractiveBounce(
        onPressed: onPressed,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: AppRadii.pillRadius,
            child: Ink(
              width: expand ? double.infinity : null,
              height: 56,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: AppRadii.pillRadius,
                border: border,
                boxShadow: disabled ? const [] : shadow,
                gradient: (isPrimary || isBrand || isFb)
                    ? LinearGradient(
                        colors: isPrimary
                            ? const [AppColors.neni, AppColors.neniDeep]
                            : isBrand
                            ? [brand.gradientStart, brand.gradientEnd]
                            : const [Color(0xFF2190F8), AppColors.facebook],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class PillIconButton extends StatelessWidget {
  const PillIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.background = AppColors.surface,
    this.iconColor = AppColors.ink,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color background;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InteractiveBounce(
      onPressed: onPressed,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadii.iconBtnRadius,
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: background,
              borderRadius: AppRadii.iconBtnRadius,
              boxShadow: AppShadows.small,
            ),
            child: Icon(icon, size: 23, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class BackIconButton extends StatelessWidget {
  const BackIconButton({super.key, this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return PillIconButton(
      icon: Icons.adaptive.arrow_back,
      onPressed: onPressed,
      size: 48,
    );
  }
}
