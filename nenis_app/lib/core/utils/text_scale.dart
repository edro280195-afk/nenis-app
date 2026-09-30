import 'package:flutter/widgets.dart';

/// Ajusta un `childAspectRatio` fijo a la escala de letra del sistema.
///
/// Con letra grande (accesibilidad de Android) el texto de una tarjeta crece
/// pero una cuadrícula con proporción fija no, y el contenido se desborda.
/// Dividir entre la escala hace que la tarjeta crezca en alto a la par.
/// A escala normal (1.0) devuelve [base] sin cambios.
double scaledAspectRatio(BuildContext context, double base) {
  final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 2.0);
  return base / scale;
}
