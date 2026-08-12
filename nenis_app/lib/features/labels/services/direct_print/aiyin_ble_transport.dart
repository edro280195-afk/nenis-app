import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'aiyin_e40_print_service.dart';

/// Transporte BLE para la AIYIN E40 Pro. La conexión Bluetooth clásica
/// acepta los bytes sin error pero la impresora nunca reacciona — este
/// equipo también anuncia una identidad BLE separada (nombre + `_BLE`)
/// con un servicio de impresión estilo UART
/// (FFF0/FFF1/FFF2, la convención más común en impresoras térmicas BLE
/// baratas).
class AiyinBleTransport {
  static final Guid _serviceUuid = Guid('0000fff0-0000-1000-8000-00805f9b34fb');
  static final Guid _writeCharUuid = Guid('0000fff2-0000-1000-8000-00805f9b34fb');

  static Future<void> printViaBle(String bleName, Uint8List command) async {
    debugPrint('[AiyinBLE] scanning for $bleName...');
    final device = await _findDevice(bleName);
    if (device == null) {
      throw AiyinPrintException('No encontramos $bleName por BLE. Enciéndela y acércala al teléfono.');
    }

    debugPrint('[AiyinBLE] connecting to ${device.platformName}...');
    await device.connect(timeout: const Duration(seconds: 10), autoConnect: false);
    try {
      var mtu = 23;
      try {
        mtu = await device.requestMtu(247);
      } catch (e) {
        debugPrint('[AiyinBLE] requestMtu failed, using default: $e');
      }
      debugPrint('[AiyinBLE] mtu=$mtu');

      final services = await device.discoverServices();
      final service = services.firstWhere(
        (s) => s.uuid == _serviceUuid,
        orElse: () => throw const AiyinPrintException(
          'La AIYIN E40 Pro no tiene el servicio de impresión BLE esperado.',
        ),
      );
      final writeChar = service.characteristics.firstWhere(
        (c) => c.uuid == _writeCharUuid,
        orElse: () => throw const AiyinPrintException(
          'La AIYIN E40 Pro no tiene la característica de escritura esperada.',
        ),
      );

      final chunkSize = (mtu - 3).clamp(20, 244);
      debugPrint('[AiyinBLE] writing ${command.length} bytes in chunks of $chunkSize');
      var offset = 0;
      while (offset < command.length) {
        final end = (offset + chunkSize).clamp(0, command.length);
        await writeChar.write(
          command.sublist(offset, end),
          withoutResponse: writeChar.properties.writeWithoutResponse,
        );
        offset = end;
      }
      debugPrint('[AiyinBLE] write done');
      await Future.delayed(const Duration(seconds: 2));
    } finally {
      await device.disconnect();
    }
  }

  static Future<BluetoothDevice?> _findDevice(
    String name, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    BluetoothDevice? found;
    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.device.platformName == name) found = r.device;
      }
    });
    await FlutterBluePlus.startScan(timeout: timeout);
    await Future.delayed(timeout);
    await sub.cancel();
    return found;
  }
}
