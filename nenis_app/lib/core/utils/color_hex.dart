import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Convierte un hex "#RRGGBB" (o "#AARRGGBB") del backend a un [Color].
/// Fallback al acento Neni's si viene nulo o inválido.
Color colorFromHex(String? hex) {
  if (hex == null || hex.isEmpty) return AppColors.neni;
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final value = int.tryParse(h, radix: 16);
  return value == null ? AppColors.neni : Color(value);
}

/// Aclara un color (para el inicio del degradado de marca).
Color lighten(Color color, [double amount = 0.12]) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}
