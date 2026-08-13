/// Arma el texto de `failureReason` que se manda al backend anteponiendo
/// el código corto y estable de diagnóstico al mensaje ya orientado a la
/// vendedora, para poder agrupar/filtrar fallas de impresión por causa real
/// (permisos, timeout, negociación, plantilla, red...) sin tener que
/// parsear texto libre. Lo que ve la vendedora en el SnackBar no cambia —
/// esto solo enriquece lo que queda registrado en el backend.
String printFailureReason(String code, String message) => '$code: $message';

/// Igual, para excepciones no anticipadas (el `catch (_)` genérico de cada
/// pantalla de impresión). Antes esas fallas siempre mandaban el mismo
/// texto fijo al backend ("El sistema no pudo abrir la impresión."), sin
/// ninguna pista de la causa real; ahora al menos queda el tipo y el
/// mensaje crudo de la excepción, truncado por si acaso es muy largo.
String unknownPrintFailureReason(Object error) {
  const maxLength = 500;
  final detail = '${error.runtimeType}: $error';
  final truncated = detail.length > maxLength ? '${detail.substring(0, maxLength)}…' : detail;
  return 'unknown: $truncated';
}
