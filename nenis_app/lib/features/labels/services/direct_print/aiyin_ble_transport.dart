import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'aiyin_e40_print_service.dart';
import 'bluetooth_retry.dart';

/// Transporte BLE para la AIYIN E40 Pro. La conexión Bluetooth clásica
/// acepta los bytes sin error pero la impresora nunca reacciona — este
/// equipo también anuncia una identidad BLE separada (nombre + `_BLE`)
/// con un servicio de impresión estilo UART
/// (FFF0/FFF1/FFF2, la convención más común en impresoras térmicas BLE
/// baratas).
class AiyinBleTransport {
  static final Guid _serviceUuid = Guid('0000fff0-0000-1000-8000-00805f9b34fb');
  static final Guid _writeCharUuid = Guid('0000fff2-0000-1000-8000-00805f9b34fb');

  /// Imprime un lote de comandos TSPL ya armados (uno por etiqueta) en una
  /// sola conexión BLE: busca y conecta una vez (con reintento), escribe
  /// cada comando en orden, y desconecta al final. Antes cada etiqueta de
  /// un mismo lote repetía scan+connect+discoverServices desde cero,
  /// multiplicando los puntos de fallo por cada etiqueta impresa.
  static Future<void> printBatch(String bleName, List<Uint8List> commands) async {
    final target = await withBluetoothRetry((attempt) => _openConnection(bleName, attempt));
    try {
      for (final command in commands) {
        await _writeCommand(target, command);
        // Respiro fijo entre etiquetas del mismo lote para dar tiempo al
        // cabezal térmico entre impresiones consecutivas (mismo ajuste
        // empírico que ya se usaba tras cada escritura individual).
        await Future.delayed(const Duration(seconds: 2));
      }
      debugPrint('[AiyinBLE] batch done (${commands.length} etiqueta(s))');
    } finally {
      await target.device.disconnect();
    }
  }

  static Future<void> printViaBle(String bleName, Uint8List command) {
    return printBatch(bleName, [command]);
  }

  /// Busca y conecta a [bleName], negocia el MTU y ubica la característica
  /// de escritura. No imprime nada — solo deja la conexión lista. Si algo
  /// falla a mitad del handshake, desconecta antes de propagar el error
  /// para que un reintento posterior no choque con "already connected".
  static Future<_BleWriteTarget> _openConnection(String bleName, int attempt) async {
    debugPrint('[AiyinBLE] scanning for $bleName (intento ${attempt + 1})...');
    final device = await _findDevice(bleName);
    if (device == null) {
      throw AiyinPrintException(
        'No encontramos $bleName por BLE. Enciéndela y acércala al teléfono.',
        code: 'device_not_found',
      );
    }

    debugPrint('[AiyinBLE] connecting to ${device.platformName}...');
    try {
      try {
        await device.connect(timeout: const Duration(seconds: 10), autoConnect: false);
      } catch (e) {
        throw AiyinPrintException(
          'No pudimos conectar con la AIYIN E40 Pro. Enciéndela y acércala al teléfono. ($e)',
          code: 'connect_failed',
        );
      }

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
          code: 'service_not_found',
        ),
      );
      final writeChar = service.characteristics.firstWhere(
        (c) => c.uuid == _writeCharUuid,
        orElse: () => throw const AiyinPrintException(
          'La AIYIN E40 Pro no tiene la característica de escritura esperada.',
          code: 'characteristic_not_found',
        ),
      );
      return _BleWriteTarget(device: device, characteristic: writeChar, mtu: mtu);
    } catch (e) {
      try {
        await device.disconnect();
      } catch (_) {
        // Ya estaba desconectado o el error de desconexión no es relevante
        // frente al error original que vamos a propagar.
      }
      rethrow;
    }
  }

  static Future<void> _writeCommand(_BleWriteTarget target, Uint8List command) async {
    final chunkSize = (target.mtu - 3).clamp(20, 244);
    debugPrint('[AiyinBLE] writing ${command.length} bytes in chunks of $chunkSize');
    var offset = 0;
    while (offset < command.length) {
      final end = (offset + chunkSize).clamp(0, command.length);
      await target.characteristic.write(
        command.sublist(offset, end),
        withoutResponse: target.characteristic.properties.writeWithoutResponse,
      );
      offset = end;
    }
    debugPrint('[AiyinBLE] write done');
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

class _BleWriteTarget {
  const _BleWriteTarget({required this.device, required this.characteristic, required this.mtu});

  final BluetoothDevice device;
  final BluetoothCharacteristic characteristic;
  final int mtu;
}
