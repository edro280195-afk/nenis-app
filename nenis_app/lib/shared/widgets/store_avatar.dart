import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/brand_theme.dart';

class StoreAvatar extends StatelessWidget {
  const StoreAvatar({
    super.key,
    required this.label,
    this.gradientStart,
    this.gradientEnd,
    this.size = 46,
    this.radius = AppRadii.avatar,
    this.fontSize = 18,
    this.borderColor,
  });

  final String label;
  final Color? gradientStart;
  final Color? gradientEnd;
  final double size;
  final double radius;
  final double fontSize;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final start = gradientStart ?? brand.gradientStart;
    final end = gradientEnd ?? brand.gradientEnd;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [start, end],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 4)
            : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A3A2233),
            offset: Offset(0, 8),
            blurRadius: 20,
            spreadRadius: -10,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.surface,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
        ),
      ),
    );
  }
}

class StoreAvatarXl extends StatelessWidget {
  const StoreAvatarXl({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return StoreAvatar(
      label: label,
      size: 74,
      radius: AppRadii.avatarLg,
      fontSize: 30,
      borderColor: AppColors.surface,
    );
  }
}

class StoreAvatarLg extends StatelessWidget {
  const StoreAvatarLg({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return StoreAvatar(
      label: label,
      size: 72,
      radius: 24,
      fontSize: 24,
    );
  }
}

class StoreAvatarSm extends StatelessWidget {
  const StoreAvatarSm({super.key, required this.label, this.gradientStart, this.gradientEnd});
  final String label;
  final Color? gradientStart;
  final Color? gradientEnd;

  @override
  Widget build(BuildContext context) {
    return StoreAvatar(
      label: label,
      size: 50,
      radius: 15,
      fontSize: 18,
      gradientStart: gradientStart,
      gradientEnd: gradientEnd,
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.label, this.size = 46});
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD2E3), Color(0xFFD9C6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2ED6336C),
            offset: Offset(0, 8),
            blurRadius: 20,
            spreadRadius: -10,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.neniDeep,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }
}
