/// Copy compartido entre las tres pantallas que imprimen etiquetas (centro
/// de impresión masiva, bolsas dentro de un pedido, etiquetas de bodega)
/// para los mismos eventos — antes cada pantalla tenía su propia redacción
/// ligeramente distinta para exactamente lo mismo, lo que confundía más
/// que ayudaba (¿por qué el mismo evento se explica diferente según de
/// dónde se imprimió?).
library;

/// El PDF se entregó al selector de impresión nativo del sistema (no hay
/// impresora Bluetooth emparejada para este formato). [count] es el número
/// de etiquetas del trabajo (1 para impresiones individuales).
String printedViaSystemMessage(int count) {
  final plural = count == 1 ? 'etiqueta enviada' : 'etiquetas enviadas';
  return '$count $plural al selector de impresión. Empareja tu impresora en '
      'Configurar impresoras para imprimir directo la próxima vez.';
}

String printedDirectMessage(int count, String printerName) {
  final plural = count == 1 ? 'etiqueta enviada' : 'etiquetas enviadas';
  return '$count $plural a $printerName. La impresora recibió el trabajo.';
}

String connectingToPrinterMessage(String printerName) =>
    'Conectando con $printerName y enviando las etiquetas…';

const String preparingSystemPrintMessage =
    'Preparando las etiquetas para el selector de impresión…';

const String printUnknownFailureMessage =
    'No pudimos completar la impresión. Revisa la impresora y vuelve a intentarlo.';

/// La vendedora cerró/canceló el selector de impresión del sistema sin
/// elegir nada.
const String printCanceledMessage =
    'Cancelaste la impresión antes de enviarla.';
