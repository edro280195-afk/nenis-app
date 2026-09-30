import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color ink = Color(0xFF3A2233);

  // ── Texto secundario y terciario con contraste AA ──────────────────────────
  // Los tres colores de abajo (`ink2`, `ink3`, `neniDeep`) cumplen 4.5:1 sobre
  // TODOS los fondos de la app, incluido el caso más duro: el brillo rosa de
  // `NeniBackground` (#FFE1EE) y los chips rosados (#FFE1EC). Conservan el tono
  // de la marca; solo son más oscuros que antes (8A6F82 / B6A4B1 / E84E83, que
  // daban 3.7 / 1.9 / 3.0:1 en ese caso).

  /// Texto secundario (subtítulos, explicaciones, etiquetas). 5.6:1 o más.
  static const Color ink2 = Color(0xFF695563);

  /// Texto terciario (horas, pistas, contadores) e iconos de apoyo. 4.6:1 o más.
  static const Color ink3 = Color(0xFF786072);

  /// Solo para controles DESHABILITADOS (las WCAG los eximen de contraste): es el
  /// `ink3` de antes, suave a propósito para que se note que no se puede tocar.
  /// Nunca para texto que la persona necesita leer.
  static const Color inkDisabled = Color(0xFFB6A4B1);

  /// Alias histórico de [ink2] (la pantalla de acceso lo usaba antes de que
  /// `ink2` cumpliera AA).
  static const Color textAa = ink2;

  /// Alias histórico de [neniDeep] (enlaces y acciones de texto pequeñas).
  static const Color linkAa = neniDeep;
  static const Color surface = Color(0xFFFFFCFD);
  static const Color line = Color(0x143A2233);
  static const Color lineSoft = Color(0x0D3A2233);

  static const Color neni = Color(0xFFFB6F9C);

  /// Rosa profundo de marca para texto, enlaces, iconos y acentos. 4.6:1 o más sobre
  /// todos los fondos (antes #E84E83, 3.0:1 en el caso más duro). El rosa claro
  /// [neni] sigue siendo para rellenos y decoración, no para texto.
  static const Color neniDeep = Color(0xFFC71A56);
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
