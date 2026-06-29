import 'package:flutter/material.dart';

class AppShadows {
  AppShadows._();

  static const Color _pinkGlow = Color(0x38D6336C);
  static const Color _pinkGlowLight = Color(0x2ED6336C);
  static const Color _inkGlow = Color(0x1A3A2233);

  static List<BoxShadow> card = const [
    BoxShadow(
      color: _pinkGlow,
      offset: Offset(0, 18),
      blurRadius: 40,
      spreadRadius: -12,
    ),
    BoxShadow(
      color: _inkGlow,
      offset: Offset(0, 6),
      blurRadius: 16,
      spreadRadius: -8,
    ),
  ];

  static List<BoxShadow> small = const [
    BoxShadow(
      color: _pinkGlowLight,
      offset: Offset(0, 8),
      blurRadius: 20,
      spreadRadius: -10,
    ),
  ];

  static List<BoxShadow> nav = const [
    BoxShadow(
      color: Color(0x667C1F4A),
      offset: Offset(0, 20),
      blurRadius: 40,
      spreadRadius: -16,
    ),
  ];

  static List<BoxShadow> brandPrimary(Color brand) => [
        BoxShadow(
          color: brand.withValues(alpha: 0.45),
          offset: const Offset(0, 14),
          blurRadius: 26,
          spreadRadius: -12,
        ),
      ];

  static List<BoxShadow> brandSmall(Color brand) => [
        BoxShadow(
          color: brand.withValues(alpha: 0.4),
          offset: const Offset(0, 10),
          blurRadius: 20,
          spreadRadius: -8,
        ),
      ];
}
