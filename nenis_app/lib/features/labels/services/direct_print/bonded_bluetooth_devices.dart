import 'package:flutter/services.dart';

/// Lee la lista de dispositivos Bluetooth clásicos ya vinculados en
/// Ajustes del sistema. Un dispositivo emparejado deja de anunciarse en un
/// escaneo nuevo, así que para reconectar una impresora que la vendedora
/// ya emparejó fuera de la app hace falta leer esta lista en vez de
/// escanear.
class BondedBluetoothDevices {
  static const _channel = MethodChannel('nenis_app/bonded_bluetooth_devices');

  static Future<List<({String name, String address})>> list() async {
    final result = await _channel.invokeMethod<List<Object?>>('list');
    return (result ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .map(
          (m) => (
            name: (m['name'] ?? '') as String,
            address: (m['address'] ?? '') as String,
          ),
        )
        .toList();
  }
}
