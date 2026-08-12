import 'dart:async';

import 'package:bluetooth_print_plus/bluetooth_print_plus.dart' as classic;
import 'package:flutter/foundation.dart';
import 'package:niim_blue_flutter/niim_blue_flutter.dart';

import 'bonded_bluetooth_devices.dart';
import 'raw_classic_bluetooth_socket.dart';

class NiimbotPrintException implements Exception {
  const NiimbotPrintException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Cliente NIIMBOT sobre Bluetooth clásico (RFCOMM/SPP). La B1 de bodega
/// está emparejada como dispositivo clásico en Android (no anuncia por
/// BLE), así que en vez del cliente BLE de niim_blue_flutter reusamos su
/// lógica de protocolo pura (paquetes, checksums, tareas de impresión).
///
/// El transporte es un socket RFCOMM/SPP crudo propio (no
/// bluetooth_print_plus): el SDK de esa librería exige un handshake de
/// verificación en ESC/TSPL/CPCL/ZPL antes de reportar "conectado", y el
/// protocolo propio de NIIMBOT no es ninguno de esos, así que ese
/// handshake nunca pasa.
class _NiimbotClassicClient extends NiimbotAbstractClient {
  String? _address;
  StreamSubscription<Uint8List>? _dataSub;
  bool _connected = false;

  void setDevice(String address) {
    _address = address;
  }

  @override
  Future<ConnectionInfo> connect() async {
    final address = _address;
    if (address == null) {
      throw const NiimbotPrintException('No se seleccionó una impresora NIIMBOT.');
    }

    try {
      await RawClassicBluetoothSocket.connect(address);
    } catch (e) {
      throw NiimbotPrintException(
        'La NIIMBOT B1 no respondió. Enciéndela y acércala al teléfono. ($e)',
      );
    }
    _connected = true;
    _dataSub = RawClassicBluetoothSocket.onData.listen(processRawPacket);

    try {
      await initialNegotiate();
      await fetchPrinterInfo();
    } catch (_) {
      // El modelo/serie son informativos; si fallan seguimos con lo
      // negociado en initialNegotiate.
    }

    final connectionInfo = ConnectionInfo(
      deviceName: address,
      result: info.connectResult ?? ConnectResult.disconnect,
    );
    emit(ClientEvents.connected, connectionInfo);
    return connectionInfo;
  }

  @override
  Future<void> disconnect() async {
    await _dataSub?.cancel();
    _dataSub = null;
    _connected = false;
    await RawClassicBluetoothSocket.disconnect();
    emit(ClientEvents.disconnected, null);
  }

  @override
  bool isConnected() => _connected;

  @override
  Future<void> sendRaw(Uint8List data, {bool force = false}) async {
    await RawClassicBluetoothSocket.write(data);
    if (!force) {
      await Future.delayed(Duration(milliseconds: packetIntervalMs));
    }
  }
}

/// Impresión directa a la NIIMBOT B1 por Bluetooth clásico, sin pasar por
/// la app oficial de NIIMBOT. La B1 tiene un cabezal de 400 puntos (50mm ×
/// 8 puntos/mm), así que cada etiqueta cuadrada se manda como bitmap
/// 400×400.
class NiimbotB1PrintService {
  const NiimbotB1PrintService();

  static const labelPixels = 400;

  /// Dispositivos NIIMBOT ya vinculados en Ajustes > Bluetooth del
  /// sistema. Una vez emparejada, la B1 deja de anunciarse por aire, así
  /// que este camino es más confiable que un escaneo nuevo.
  Future<List<({String name, String address})>> listBonded() async {
    final prefixes = getAllModelPrefixes();
    final bonded = await BondedBluetoothDevices.list();
    return bonded
        .where((d) => prefixes.any((prefix) => d.name.startsWith(prefix)))
        .toList();
  }

  /// Busca impresoras NIIMBOT nuevas (aún no emparejadas) visibles por
  /// Bluetooth clásico, filtrando por el nombre anunciado.
  Future<List<({String name, String address})>> scan({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final result = await classic.BluetoothPrintPlus.startScan(timeout: timeout);
    final devices = (result as List).cast<classic.BluetoothDevice>();
    final prefixes = getAllModelPrefixes();
    return devices
        .where((d) => prefixes.any((prefix) => d.name.startsWith(prefix)))
        .map((d) => (name: d.name, address: d.address))
        .toList();
  }

  Future<void> printLabel({
    required String address,
    required String name,
    required Uint8List png,
    int copies = 1,
  }) async {
    final client = _NiimbotClassicClient()..setDevice(address);
    try {
      await client.connect();
      debugPrint(
        '[NiimbotB1] connect result=${client.info.connectResult} '
        'modelId=${client.info.modelId} protocolVersion=${client.info.protocolVersion}',
      );

      // density al máximo (5 en la B1): con la etiqueta saliendo en blanco
      // el sospechoso más probable es que el cabezal no está calentando
      // lo suficiente para este material, no un problema de datos.
      final task = client.createPrintTask(
        const PrintOptions(totalPages: 1, density: 5),
      );
      if (task == null) {
        throw const NiimbotPrintException(
          'No reconocimos el modelo de esta impresora NIIMBOT.',
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

      debugPrint('[NiimbotB1] printInit');
      await task.printInit();
      debugPrint('[NiimbotB1] printPage');
      await task.printPage(page.toEncodedImage(), copies);
      debugPrint('[NiimbotB1] waitForFinished');
      await task.waitForFinished();
      await task.printEnd();
      debugPrint('[NiimbotB1] done');
    } on NiimbotPrintException catch (e) {
      debugPrint('[NiimbotB1] FAILED: $e');
      rethrow;
    } catch (e, st) {
      debugPrint('[NiimbotB1] FAILED: $e\n$st');
      throw NiimbotPrintException(
        'No pudimos imprimir en la NIIMBOT B1: revisa que esté encendida y '
        'cerca del teléfono. ($e)',
      );
    } finally {
      await client.disconnect();
    }
  }
}
