import 'dart:async';

/// Reintenta [attempt] hasta [maxAttempts] veces, con una espera creciente
/// entre intentos, antes de rendirse.
///
/// Ningún paso de conexión Bluetooth de este módulo reintentaba
/// automáticamente: un solo intento de escaneo/conexión/negociación se
/// enfrentaba solo contra cualquier interferencia momentánea (impresora
/// ocupada, un poco lejos, otro dispositivo Bluetooth cerca), y la vendedora
/// terminaba siendo el único mecanismo de reintento ("tap y tap" hasta que
/// conectara). Este helper cubre exactamente eso.
///
/// Solo se usa para envolver la FASE DE CONEXIÓN (buscar/conectar/negociar),
/// nunca la fase de escritura de una etiqueta ya en curso: reintentar un
/// envío que pudo haber llegado parcialmente a la impresora podría imprimir
/// la misma etiqueta dos veces.
Future<T> withBluetoothRetry<T>(
  Future<T> Function(int attempt) attempt, {
  int maxAttempts = 3,
  List<Duration> delaysBetweenAttempts = const [
    Duration(milliseconds: 400),
    Duration(seconds: 1),
    Duration(seconds: 2),
  ],
}) async {
  Object? lastError;
  StackTrace? lastStackTrace;
  for (var i = 0; i < maxAttempts; i++) {
    try {
      return await attempt(i);
    } catch (e, st) {
      lastError = e;
      lastStackTrace = st;
      final isLastAttempt = i == maxAttempts - 1;
      if (isLastAttempt) break;
      // Lista vacía = reintentar de inmediato, sin espera (útil en tests);
      // .last sobre una lista vacía lanzaría StateError.
      final delay = delaysBetweenAttempts.isEmpty
          ? Duration.zero
          : (i < delaysBetweenAttempts.length
                ? delaysBetweenAttempts[i]
                : delaysBetweenAttempts.last);
      await Future.delayed(delay);
    }
  }
  Error.throwWithStackTrace(lastError!, lastStackTrace!);
}
