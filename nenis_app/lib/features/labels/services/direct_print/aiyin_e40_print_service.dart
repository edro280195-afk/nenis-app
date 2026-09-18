import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'aiyin_ble_transport.dart';
import 'bluetooth_permissions.dart';
import 'tspl_command_builder.dart';

class AiyinPrintException implements Exception {
  const AiyinPrintException(this.message, {required this.code});

  final String message;

  /// Código corto y estable para diagnóstico remoto (se manda al backend
  /// como parte de `failureReason`); la vendedora nunca ve este valor, solo
  /// [message].
  final String code;

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

  /// Pide el permiso de Bluetooth de forma proactiva antes de escanear o
  /// conectar. Antes, la única vía que disparaba el diálogo del sistema era
  /// un efecto secundario de `BluetoothPrintPlus.startScan()` (solo usado
  /// para el descubrimiento clásico) — la conexión BLE real de impresión
  /// nunca pasaba por ahí, así que si la vendedora no había escaneado antes
  /// con esta pantalla, la impresión fallaba en silencio por falta de
  /// permiso, con un mensaje que culpaba al hardware.
  Future<void> _ensurePermissions() async {
    final result = await BluetoothPermissions.ensureGranted();
    if (!result.granted) {
      throw AiyinPrintException(
        result.message,
        code: result.permanentlyDenied
            ? 'permission_denied_permanently'
            : 'permission_denied',
      );
    }
  }

  Future<List<({String name, String address})>> scan({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    await _ensurePermissions();
    final devices = await AiyinBleTransport.discoverDevices(timeout: timeout);
    return devices
        .where((device) => _isAiyinName(_deviceName(device)))
        .map(
          (device) => (
            name: _baseName(_deviceName(device)),
            address: device.remoteId.str,
          ),
        )
        .toList();
  }

  /// Imprime un lote de etiquetas (una PNG por etiqueta) en una conexión BLE
  /// persistente. El transporte aprende y guarda la identidad BLE real a
  /// partir de la dirección clásica con la que se emparejó la impresora.
  Future<void> printBatch({
    required String address,
    required String name,
    String? bleRemoteId,
    required List<Uint8List> pngs,
    int copies = 1,
  }) async {
    await _ensurePermissions();
    try {
      debugPrint('[AiyinE40] building ${pngs.length} comando(s) TSPL');
      final commands = pngs
          .map(
            (png) => TsplCommandBuilder.build(
              png: png,
              widthMm: widthMm,
              heightMm: heightMm,
              // 15 (máximo) era para descartar que el cabezal no calentara
              // lo suficiente; ya confirmado que imprime, con 15 sale todo
              // saturado de tinta. 8 es un punto medio razonable.
              density: 8,
              copies: copies,
              compress: true,
            ),
          )
          .toList();

      final bleName = _bleName(name);
      debugPrint(
        '[AiyinE40] printing ${commands.length} etiqueta(s) via BLE to $bleName',
      );
      await AiyinBleTransport.printBatch(
        bleName,
        commands,
        classicAddress: address,
        preferredRemoteId: bleRemoteId,
      );
      debugPrint('[AiyinE40] done');
    } on AiyinPrintException catch (e) {
      debugPrint('[AiyinE40] FAILED: $e');
      rethrow;
    } catch (e, st) {
      debugPrint('[AiyinE40] FAILED: $e\n$st');
      throw AiyinPrintException(
        'No pudimos imprimir en la AIYIN E40 Pro: revisa que esté encendida '
        'y cerca del teléfono. ($e)',
        code: 'unknown',
      );
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

  static String _deviceName(BluetoothDevice device) {
    final platformName = device.platformName.trim();
    if (platformName.isNotEmpty) return platformName;
    return device.advName.trim();
  }

  static bool _isAiyinName(String name) {
    final upper = name.toUpperCase();
    return upper.contains('AIYIN') ||
        upper.contains('E40') ||
        upper.endsWith('_BLE');
  }

  static String _baseName(String name) {
    const suffix = '_BLE';
    return name.toUpperCase().endsWith(suffix)
        ? name.substring(0, name.length - suffix.length)
        : name;
  }

  static String _bleName(String name) {
    final normalized = name.trim();
    return normalized.toUpperCase().endsWith('_BLE')
        ? normalized
        : '${normalized}_BLE';
  }
}
