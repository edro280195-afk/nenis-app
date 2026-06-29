import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';

@immutable
class BrandTheme {
  const BrandTheme({
    required this.id,
    required this.name,
    required this.primary,
    required this.primaryDeep,
    required this.onPrimary,
    required this.gradientStart,
    required this.gradientEnd,
  });

  final String id;
  final String name;
  final Color primary;
  final Color primaryDeep;
  final Color onPrimary;
  final Color gradientStart;
  final Color gradientEnd;

  static const BrandTheme neni = BrandTheme(
    id: 'neni',
    name: "Neni's",
    primary: AppColors.neni,
    primaryDeep: AppColors.neniDeep,
    onPrimary: AppColors.surface,
    gradientStart: AppColors.neni,
    gradientEnd: AppColors.neniDeep,
  );

  static const BrandTheme regiBazar = BrandTheme(
    id: 'regi',
    name: 'Regi Bazar',
    primary: Color(0xFFFF0072),
    primaryDeep: Color(0xFFCC005B),
    onPrimary: AppColors.surface,
    gradientStart: Color(0xFFFF3D8B),
    gradientEnd: Color(0xFFFF0072),
  );

  static const BrandTheme lunaBella = BrandTheme(
    id: 'luna',
    name: 'Luna Bella',
    primary: Color(0xFFFF7A59),
    primaryDeep: Color(0xFFCC623F),
    onPrimary: AppColors.surface,
    gradientStart: Color(0xFFFF9A6B),
    gradientEnd: Color(0xFFFF7A59),
  );

  static const BrandTheme aurora = BrandTheme(
    id: 'aurora',
    name: 'Aurora',
    primary: Color(0xFF8E6BE6),
    primaryDeep: Color(0xFF6E4EBE),
    onPrimary: AppColors.surface,
    gradientStart: Color(0xFFA98CF0),
    gradientEnd: Color(0xFF8E6BE6),
  );

  static const BrandTheme miaJoya = BrandTheme(
    id: 'mia',
    name: 'Mía Joya',
    primary: Color(0xFF16B5A0),
    primaryDeep: Color(0xFF0F8C7C),
    onPrimary: AppColors.surface,
    gradientStart: Color(0xFF3AD1B8),
    gradientEnd: Color(0xFF16B5A0),
  );

  static const List<BrandTheme> all = [
    neni,
    regiBazar,
    lunaBella,
    aurora,
    miaJoya,
  ];

  static BrandTheme byId(String id) {
    return all.firstWhere(
      (b) => b.id == id,
      orElse: () => neni,
    );
  }
}

class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({
    required this.brand,
  });

  final BrandTheme brand;

  @override
  BrandColors copyWith({BrandTheme? brand}) =>
      BrandColors(brand: brand ?? this.brand);

  @override
  BrandColors lerp(ThemeExtension<BrandColors>? other, double t) {
    if (other is! BrandColors) return this;
    return BrandColors(brand: t < 0.5 ? brand : other.brand);
  }
}

extension BrandColorsX on BuildContext {
  BrandTheme get brand {
    final ext = Theme.of(this).extension<BrandColors>();
    return ext?.brand ?? BrandTheme.neni;
  }
}

class BrandNotifier extends Notifier<BrandTheme> {
  @override
  BrandTheme build() => BrandTheme.neni;

  void set(BrandTheme brand) => state = brand;
  void setById(String id) => state = BrandTheme.byId(id);
}

final activeBrandProvider = NotifierProvider<BrandNotifier, BrandTheme>(
  BrandNotifier.new,
);
