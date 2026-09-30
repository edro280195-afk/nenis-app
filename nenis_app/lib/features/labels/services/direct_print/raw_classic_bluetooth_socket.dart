import 'dart:async';

import 'package:flutter/services.dart';

/// Socket RFCOMM/SPP crudo por Bluetooth clásico, sin ningún SDK de
/// impresora de por medio. Para impresoras con protocolo propio (NIIMBOT)
/// que no hablan ESC/TSPL/CPCL/ZPL, así que no pueden pasar el handshake
/// de verificación de bluetooth_print_plus.
class RawClassicBluetoothSocket {
  static const _methodChannel = MethodChannel('nenis_app/raw_bluetooth_socket');
  static const _dataChannel = EventChannel(
    'nenis_app/raw_bluetooth_socket/data',
  );

  static Stream<Uint8List>? _dataStream;

  static Stream<Uint8List> get onData {
    return _dataStream ??= _dataChannel.receiveBroadcastStream().map(
      (event) => event as Uint8List,
    );
  }

  static Future<void> connect(String address) {
    // El lado nativo (MainActivity.kt) ya acota su propio socket.connect()
    // a ~8s y responde con error si expira; este timeout es una red de
    // seguridad adicional por si esa respuesta nunca llegara (p.ej. un
    // deadlock nativo no previsto), para no dejar la UI esperando
    // indefinidamente un canal de plataforma que nunca resuelve.
    return _methodChannel
        .invokeMethod('connect', {'address': address})
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException(
            'Tiempo de espera agotado conectando por Bluetooth clásico.',
          ),
        );
  }

  static Future<bool> write(Uint8List data) async {
    final ok = await _methodChannel.invokeMethod<bool>('write', {'data': data});
    return ok ?? false;
  }

  static Future<void> disconnect() {
    return _methodChannel.invokeMethod('disconnect');
  }
}
