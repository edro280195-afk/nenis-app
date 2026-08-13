import 'dart:async';

import 'package:bluetooth_print_plus/bluetooth_print_plus.dart' as classic;
import 'package:flutter/foundation.dart';
import 'package:niim_blue_flutter/niim_blue_flutter.dart';

import 'bluetooth_permissions.dart';
import 'bluetooth_retry.dart';
import 'bonded_bluetooth_devices.dart';
import 'raw_classic_bluetooth_socket.dart';

class NiimbotPrintException implements Exception {
  const NiimbotPrintException(this.message, {required this.code});

  final String message;

  /// Código corto y estable para diagnóstico remoto (se manda al backend
  /// como parte de `failureReason`); la vendedora nunca ve este valor, solo
  /// [message]. Antes toda falla de impresión NIIMBOT llegaba al backend
  /// como el mismo texto genérico fijo, sin poder distinguir causa.
  final String code;

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
      throw const NiimbotPrintException(
        'No se seleccionó una impresora NIIMBOT.',
        code: 'no_printer_selected',
      );
    }

    // Un solo intento se enfrentaba solo contra cualquier interferencia
    // momentánea (impresora ocupada, un poco lejos); con 2-3 intentos con
    // backoff, la mayoría de esos casos se resuelve sin que la vendedora
    // tenga que volver a tocar "Imprimir" a mano.
    await withBluetoothRetry((attempt) async {
      try {
        await RawClassicBluetoothSocket.connect(address);
      } catch (e) {
        throw NiimbotPrintException(
          'La NIIMBOT B1 no respondió. Enciéndela y acércala al teléfono. ($e)',
          code: 'connect_failed',
        );
      }
    });
    _connected = true;
    _dataSub = RawClassicBluetoothSocket.onData.listen(processRawPacket);

    try {
      await withBluetoothRetry((attempt) async {
        await initialNegotiate();
        await fetchPrinterInfo();
      });
    } catch (e) {
      // Antes este fallo se tragaba en silencio y la conexión se daba por
      // buena igual (_connected ya estaba en true): el problema solo se
      // revelaba minutos después, de forma confusa, si createPrintTask
      // devolvía null por no tener el modelo. Ahora, si tras varios
      // intentos la impresora nunca respondió el handshake de inicio de
      // sesión, cerramos la conexión y avisamos con un mensaje específico
      // en el momento en que realmente ocurre el problema.
      await disconnect();
      throw NiimbotPrintException(
        'La NIIMBOT B1 conectó pero no respondió al iniciar sesión. '
        'Apágala, enciéndela de nuevo y vuelve a intentarlo. ($e)',
        code: 'negotiation_failed',
      );
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
    final ok = await RawClassicBluetoothSocket.write(data);
    if (!ok) {
      // El canal nativo devuelve false en error de E/S; antes nadie
      // revisaba este resultado y el flujo seguía como si el byte se
      // hubiera enviado, arriesgando una etiqueta corrupta o un cuelgue
      // hasta el timeout de waitForFinished.
      throw const NiimbotPrintException(
        'Se perdió la conexión con la NIIMBOT B1 a mitad de la impresión.',
        code: 'write_failed',
      );
    }
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

  /// Pide el permiso de Bluetooth de forma proactiva antes de listar
  /// vinculados, escanear o conectar.
  Future<void> _ensurePermissions() async {
    final result = await BluetoothPermissions.ensureGranted();
    if (!result.granted) {
      throw NiimbotPrintException(
        result.message,
        code: result.permanentlyDenied ? 'permission_denied_permanently' : 'permission_denied',
      );
    }
  }

  /// Dispositivos NIIMBOT ya vinculados en Ajustes > Bluetooth del
  /// sistema. Una vez emparejada, la B1 deja de anunciarse por aire, así
  /// que este camino es más confiable que un escaneo nuevo.
  Future<List<({String name, String address})>> listBonded() async {
    await _ensurePermissions();
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
    await _ensurePermissions();
    final result = await classic.BluetoothPrintPlus.startScan(timeout: timeout);
    final devices = (result as List).cast<classic.BluetoothDevice>();
    final prefixes = getAllModelPrefixes();
    return devices
        .where((d) => prefixes.any((prefix) => d.name.startsWith(prefix)))
        .map((d) => (name: d.name, address: d.address))
        .toList();
  }

  /// Imprime un lote de etiquetas (una PNG por etiqueta) en una sola
  /// conexión, reusándola entre todas — antes cada etiqueta de un mismo
  /// trabajo reconectaba y renegociaba desde cero, multiplicando los
  /// puntos de fallo por cada una. `createPrintTask` es una fábrica sin
  /// estado propio (ver niim_blue_flutter B1PrintTask): crear una tarea
  /// nueva por etiqueta sobre el mismo cliente conectado es el uso previsto
  /// de la API, no un abuso de su ciclo de vida.
  Future<void> printBatch({
    required String address,
    required String name,
    required List<Uint8List> pngs,
    int copies = 1,
  }) async {
    await _ensurePermissions();
    final client = _NiimbotClassicClient()..setDevice(address);
    try {
      await client.connect();
      debugPrint(
        '[NiimbotB1] connect result=${client.info.connectResult} '
        'modelId=${client.info.modelId} protocolVersion=${client.info.protocolVersion}',
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
      await client.disconnect();
    }
  }

  Future<void> printLabel({
    required String address,
    required String name,
    required Uint8List png,
    int copies = 1,
  }) {
    return printBatch(address: address, name: name, pngs: [png], copies: copies);
  }

  Future<void> _printOne(
    _NiimbotClassicClient client,
    Uint8List png,
    int copies, {
    required int index,
    required int total,
  }) async {
    // density al máximo (5 en la B1): con la etiqueta saliendo en blanco
    // el sospechoso más probable es que el cabezal no está calentando
    // lo suficiente para este material, no un problema de datos.
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
}
