import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color ink = Color(0xFF3A2233);
  static const Color ink2 = Color(0xFF8A6F82);
  static const Color ink3 = Color(0xFFB6A4B1);

  /// Texto secundario que SÍ cumple contraste AA (6.2:1 o más sobre
  /// `surface` y `surfaceCream`). `ink2` (4.4:1) e `ink3` (2.3:1) quedan para
  /// decoración o texto grande. Usar este para explicaciones y avisos.
  static const Color textAa = Color(0xFF6E5468);

  /// Rosa para enlaces y acciones de texto pequeñas (4.8:1 o más). El
  /// `neniDeep` (3.5:1) solo cumple en texto grande o iconos.
  static const Color linkAa = Color(0xFFC2366B);
  static const Color surface = Color(0xFFFFFCFD);
  static const Color line = Color(0x143A2233);
  static const Color lineSoft = Color(0x0D3A2233);

  static const Color neni = Color(0xFFFB6F9C);
  static const Color neniDeep = Color(0xFFE84E83);
  static const Color lavender = Color(0xFF9B7BE0);
  static const Color gold = Color(0xFFF3B341);

  static const Color statusPendingFg = Color(0xFFB5730A);
  static const Color statusPendingBg = Color(0xFFFCECD2);
  static const Color statusRouteFg = Color(0xFF2E6BD6);
  static const Color statusRouteBg = Color(0xFFE4ECFF);
  static const Color statusDeliveredFg = Color(0xFF1F9A6A);
  static const Color statusDeliveredBg = Color(0xFFD9F3E6);

  static const Color surfaceCream = Color(0xFFFDF4F7);

  static const Color liveRed = Color(0xFFFF2D55);

  static const Color glassFill = Color(0xB8FFFFFF);
  static const Color glassBorder = Color(0xB3FFFFFF);
  static const Color segTrack = Color(0x0D3A2233);
}
