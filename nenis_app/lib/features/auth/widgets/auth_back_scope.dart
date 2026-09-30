import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Hace que el botón atrás del sistema se comporte igual que la flecha de la
/// pantalla. Las pantallas de acceso se abren con `go` (no hay nada debajo en
/// la pila), así que sin esto el atrás de Android cerraba la app en vez de
/// volver a la pantalla anterior.
///
/// - [onBack]: acción propia (p. ej. retroceder un paso dentro de la pantalla).
///   Si es null, navega a [destination].
/// - [enabled]: en falso (p. ej. mientras se envía un formulario) el atrás no
///   hace nada, igual que la flecha deshabilitada.
class AuthBackScope extends StatelessWidget {
  const AuthBackScope({
    super.key,
    required this.child,
    this.destination = '/login',
    this.onBack,
    this.enabled = true,
  });

  final Widget child;
  final String destination;
  final VoidCallback? onBack;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !enabled) return;
        if (onBack != null) {
          onBack!();
        } else {
          context.go(destination);
        }
      },
      child: child,
    );
  }
}
