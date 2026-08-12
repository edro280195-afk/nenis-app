import 'package:bluetooth_print_plus/bluetooth_print_plus.dart' show BluetoothPrintPlus, BluetoothDevice;
import 'package:flutter/foundation.dart';
import 'package:niim_blue_flutter/niim_blue_flutter.dart' show getAllModelPrefixes;

import 'aiyin_ble_transport.dart';
import 'bonded_bluetooth_devices.dart';
import 'tspl_command_builder.dart';

class AiyinPrintException implements Exception {
  const AiyinPrintException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Impresión directa a la AIYIN E40 Pro, sin pasar por su app de
/// configuración. El E40 Pro es una impresora de envío 4×6" (101.6mm ×
/// 152.4mm).
///
/// El comando TSPL se arma a mano con [TsplCommandBuilder] (el builder del
/// plugin bluetooth_print_plus es una caja negra, y de todos modos su
/// conexión Bluetooth clásica nunca hacía reaccionar a este equipo pese a
/// aceptar los bytes sin error). El transporte real es BLE
/// ([AiyinBleTransport]): este equipo anuncia una identidad BLE separada
/// (nombre + `_BLE`) con un servicio de impresión estilo UART
/// (FFF0/FFF2), que es el canal que sí imprime.
class AiyinE40PrintService {
  const AiyinE40PrintService();

  static const widthMm = 102;
  static const heightMm = 152;

  /// Dispositivos ya vinculados en Ajustes > Bluetooth del sistema, sin
  /// los que ya identificamos como NIIMBOT (esos se emparejan desde la
  /// tarjeta de la B1). El emparejamiento sigue siendo por Bluetooth
  /// clásico (así se identifica y guarda la impresora); solo el envío del
  /// trabajo de impresión usa BLE.
  Future<List<({String name, String address})>> listBonded() async {
    final prefixes = getAllModelPrefixes();
    final bonded = await BondedBluetoothDevices.list();
    return bonded
        .where((d) => !prefixes.any((prefix) => d.name.startsWith(prefix)))
        .toList();
  }

  Future<List<({String name, String address})>> scan({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final result = await BluetoothPrintPlus.startScan(timeout: timeout);
    final devices = (result as List).cast<BluetoothDevice>();
    return devices.map((d) => (name: d.name, address: d.address)).toList();
  }

  Future<void> printLabel({
    required String address,
    required String name,
    required Uint8List png,
    int copies = 1,
  }) async {
    try {
      debugPrint('[AiyinE40] building TSPL command');
      final command = TsplCommandBuilder.build(
        png: png,
        widthMm: widthMm,
        heightMm: heightMm,
        // 15 (máximo) era para descartar que el cabezal no calentara lo
        // suficiente; ya confirmado que imprime, con 15 sale todo saturado
        // de tinta. 8 es un punto medio razonable para arrancar.
        density: 8,
        copies: copies,
      );
      debugPrint('[AiyinE40] command bytes=${command.length}');

      final bleName = '${name}_BLE';
      debugPrint('[AiyinE40] printing via BLE to $bleName');
      await AiyinBleTransport.printViaBle(bleName, command);
      debugPrint('[AiyinE40] done');
    } on AiyinPrintException catch (e) {
      debugPrint('[AiyinE40] FAILED: $e');
      rethrow;
    } catch (e, st) {
      debugPrint('[AiyinE40] FAILED: $e\n$st');
      throw AiyinPrintException(
        'No pudimos imprimir en la AIYIN E40 Pro: revisa que esté encendida '
        'y cerca del teléfono. ($e)',
      );
    }
  }
}
