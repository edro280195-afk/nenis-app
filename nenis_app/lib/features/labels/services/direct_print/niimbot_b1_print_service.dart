import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:niim_blue_flutter/niim_blue_flutter.dart';

import 'bluetooth_permissions.dart';
import 'bluetooth_retry.dart';

class NiimbotPrintException implements Exception {
  const NiimbotPrintException(this.message, {required this.code});

  final String message;

  /// Código corto y estable para diagnóstico remoto (se manda al backend
  /// como parte de `failureReason`); la vendedora nunca ve este valor, solo
  /// [message].
  final String code;

  @override
  String toString() => message;
}

/// Impresión directa a la NIIMBOT B1 por BLE.
///
/// La implementación anterior usaba RFCOMM/SPP y la lista de dispositivos
/// clásicos vinculados de Android. Eso hacía que el Motorola dependiera de
/// un vínculo hecho en otro teléfono y dejaba a iOS sin una ruta de
/// transporte compatible. La B1 usa ahora el cliente BLE de
/// `niim_blue_flutter`, igual en Android y en iOS.
class NiimbotB1PrintService {
  const NiimbotB1PrintService();

  static const labelPixels = 400;

  static const _scanTimeout = Duration(seconds: 6);

  Future<void> _ensurePermissions() async {
    final result = await BluetoothPermissions.ensureGranted();
    if (!result.granted) {
      throw NiimbotPrintException(
        result.message,
        code: result.permanentlyDenied
            ? 'permission_denied_permanently'
            : 'permission_denied',
      );
    }
  }

  /// Busca por BLE, sin depender de "Ajustes > Bluetooth" ni de los vínculos
  /// que existan en otro teléfono. No se filtra por servicio en la radio:
  /// algunas revisiones de firmware anuncian el servicio NIIMBOT solo en el
  /// primer paquete; filtramos por modelo después de recibir el anuncio.
  Future<List<({String name, String address})>> scan({
    Duration timeout = _scanTimeout,
  }) async {
    await _ensurePermissions();
    final devices = await _scanBleDevices(timeout: timeout);
    return devices
        .map(
          (device) => (name: _deviceName(device), address: device.remoteId.str),
        )
        .toList();
  }

  /// Imprime un lote de etiquetas en una sola conexión BLE.
  ///
  /// [bleRemoteId] es el identificador guardado durante el emparejamiento.
  /// [address] se conserva como fallback para emparejamientos antiguos que
  /// todavía solo tenían una dirección clásica guardada.
  Future<void> printBatch({
    required String address,
    required String name,
    String? bleRemoteId,
    required List<Uint8List> pngs,
    int copies = 1,
  }) async {
    await _ensurePermissions();
    NiimbotBluetoothClient? client;
    try {
      client = await withBluetoothRetry<NiimbotBluetoothClient>((
        attempt,
      ) async {
        final next = NiimbotBluetoothClient();
        try {
          final savedId = attempt == 0
              ? _firstNonBlank(bleRemoteId) ?? _firstNonBlank(address)
              : null;
          final device = savedId == null
              ? await _findDevice(name: name)
              : BluetoothDevice.fromId(savedId);
          next.setDevice(device);
          await next.connect();
          return next;
        } catch (_) {
          await next.dispose();
          rethrow;
        }
      });

      debugPrint(
        '[NiimbotB1] connect result=${client.info.connectResult} '
        'modelId=${client.info.modelId} '
        'protocolVersion=${client.info.protocolVersion}',
      );

      for (var i = 0; i < pngs.length; i++) {
        await _printOne(client, pngs[i], copies, index: i, total: pngs.length);
      }
      debugPrint('[NiimbotB1] batch done (${pngs.length} etiqueta(s))');
    } on NiimbotPrintException catch (e) {
      debugPrint('[NiimbotB1] FAILED: $e');
      rethrow;
    } catch (e, st) {
      debugPrint('[NiimbotB1] FAILED: $e\n$st');
      throw NiimbotPrintException(
        'No pudimos imprimir en la NIIMBOT B1: revisa que esté encendida y '
        'cerca del teléfono. ($e)',
        code: 'unknown',
      );
    } finally {
      await client?.dispose();
    }
  }

  Future<void> printLabel({
    required String address,
    required String name,
    String? bleRemoteId,
    required Uint8List png,
    int copies = 1,
  }) {
    return printBatch(
      address: address,
      name: name,
      bleRemoteId: bleRemoteId,
      pngs: [png],
      copies: copies,
    );
  }

  Future<void> _printOne(
    NiimbotAbstractClient client,
    Uint8List png,
    int copies, {
    required int index,
    required int total,
  }) async {
    final task = client.createPrintTask(
      const PrintOptions(totalPages: 1, density: 5),
    );
    if (task == null) {
      throw const NiimbotPrintException(
        'No reconocimos el modelo de esta impresora NIIMBOT.',
        code: 'model_not_recognized',
      );
    }

    final page = PrintPage(labelPixels, labelPixels);
    page.addImageFromBuffer(
      ImageFromBufferOptions(
        x: 0,
        y: 0,
        width: labelPixels,
        height: labelPixels,
        buffer: png,
      ),
    );

    debugPrint('[NiimbotB1] (${index + 1}/$total) printInit');
    await task.printInit();
    debugPrint('[NiimbotB1] (${index + 1}/$total) printPage');
    await task.printPage(page.toEncodedImage(), copies);
    debugPrint('[NiimbotB1] (${index + 1}/$total) waitForFinished');
    await task.waitForFinished();
    await task.printEnd();
  }

  Future<List<BluetoothDevice>> _scanBleDevices({
    required Duration timeout,
  }) async {
    final prefixes = getAllModelPrefixes();
    final found = <String, BluetoothDevice>{};
    final subscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final name = _deviceName(result.device);
        if (prefixes.any((prefix) => name.startsWith(prefix))) {
          found[result.device.remoteId.str] = result.device;
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: timeout);
      await Future<void>.delayed(timeout);
    } finally {
      await subscription.cancel();
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    }
    return found.values.toList();
  }

  Future<BluetoothDevice> _findDevice({required String name}) async {
    final devices = await _scanBleDevices(timeout: _scanTimeout);
    final expected = name.trim().toLowerCase();
    final match = devices.where((device) {
      final candidate = _deviceName(device).toLowerCase();
      return expected.isEmpty ||
          candidate == expected ||
          candidate.startsWith(expected) ||
          expected.startsWith(candidate);
    }).firstOrNull;
    if (match != null) return match;

    throw const NiimbotPrintException(
      'No encontramos la NIIMBOT B1 por BLE. Enciéndela y acércala al teléfono.',
      code: 'device_not_found',
    );
  }

  static String _deviceName(BluetoothDevice device) {
    final platformName = device.platformName.trim();
    if (platformName.isNotEmpty) return platformName;
    return device.advName.trim();
  }

  static String? _firstNonBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
