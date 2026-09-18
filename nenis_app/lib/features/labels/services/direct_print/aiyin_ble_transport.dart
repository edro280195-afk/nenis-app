import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'aiyin_e40_print_service.dart';
import 'bluetooth_retry.dart';

/// Transporte BLE para la AIYIN E40 Pro.
///
/// La E40 anuncia una identidad BLE separada de la identidad Bluetooth
/// clásica que aparece en Ajustes. El canal probado en este equipo es el
/// servicio FFF0 y su característica FFF2. El transporte conserva esa
/// selección, pero evita el coste que hacía lenta la implementación anterior:
/// escaneo completo en cada trabajo, MTU limitado a 247, una espera por cada
/// fragmento y una pausa fija de dos segundos al terminar.
class AiyinBleTransport {
  static final Guid _serviceUuid = Guid('0000fff0-0000-1000-8000-00805f9b34fb');
  static final Guid _writeCharUuid = Guid(
    '0000fff2-0000-1000-8000-00805f9b34fb',
  );
  static const _remoteIdKeyPrefix = 'labels.aiyin_e40.ble_remote_id.';

  // flutter_blue_plus serializes BLE operations globally. Serializing jobs at
  // this boundary makes that constraint explicit and prevents two print
  // taps from interleaving their TSPL streams on the same characteristic.
  static Future<void> _jobQueue = Future<void>.value();
  static _BleWriteTarget? _cachedTarget;

  /// Imprime un lote de comandos TSPL.
  ///
  /// [classicAddress] is used only as the key for the persisted BLE identity.
  /// [preferredRemoteId] comes from a previously paired/learned BLE scan.
  /// The connection remains open for subsequent foreground jobs and is
  /// discarded only when the link fails or a different printer is selected.
  static Future<void> printBatch(
    String bleName,
    List<Uint8List> commands, {
    String? classicAddress,
    String? preferredRemoteId,
  }) {
    final job = _jobQueue.then(
      (_) => _printBatch(
        bleName,
        commands,
        classicAddress: classicAddress,
        preferredRemoteId: preferredRemoteId,
      ),
    );
    // Keep the queue usable after a failed job while preserving the error for
    // the caller that owns this particular Future.
    _jobQueue = job.catchError((_) {});
    return job;
  }

  static Future<void> printViaBle(
    String bleName,
    Uint8List command, {
    String? classicAddress,
    String? preferredRemoteId,
  }) {
    return printBatch(
      bleName,
      [command],
      classicAddress: classicAddress,
      preferredRemoteId: preferredRemoteId,
    );
  }

  /// Descubre una vez la identidad BLE asociada a un nombre de AIYIN.
  /// Pairing uses this to eliminate the scan from the first print too; the
  /// print path still has a fallback because Android may rotate a BLE address.
  static Future<String?> discoverRemoteId(
    String bleName, {
    String? classicAddress,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final device = await _findDevice(bleName, timeout: timeout);
    final remoteId = device?.remoteId.str;
    if (remoteId != null) {
      await _rememberRemoteId(classicAddress, remoteId);
    }
    return remoteId;
  }

  /// Descubre las identidades BLE visibles en este teléfono. La lista no
  /// depende de dispositivos vinculados en Ajustes ni de otro teléfono; el
  /// filtrado de modelos lo hace [AiyinE40PrintService] por nombre antes de
  /// mostrar resultados a la vendedora.
  static Future<List<BluetoothDevice>> discoverDevices({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final found = <String, BluetoothDevice>{};
    final subscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        found[result.device.remoteId.str] = result.device;
      }
    });

    try {
      // No imponemos FFF0 como filtro de radio: algunas unidades solo
      // publican el servicio después de conectar y, en iOS, un filtro de
      // servicio solo encuentra servicios incluidos en el anuncio.
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

  static Future<void> _printBatch(
    String bleName,
    List<Uint8List> commands, {
    String? classicAddress,
    String? preferredRemoteId,
  }) async {
    if (commands.isEmpty) return;

    final storedRemoteId = await _readRemoteId(classicAddress);
    final remoteId = _nonBlank(preferredRemoteId) ?? storedRemoteId;
    final target = await withBluetoothRetry(
      (attempt) =>
          _getOrOpenConnection(bleName, attempt, preferredRemoteId: remoteId),
    );

    try {
      for (final command in commands) {
        await _writeCommand(target, command);
      }
      await _rememberRemoteId(classicAddress, target.device.remoteId.str);
      debugPrint('[AiyinBLE] batch accepted (${commands.length} etiqueta(s))');
    } catch (_) {
      // A partial write must never be retried automatically: the printer may
      // already have buffered a valid prefix. Drop the session so the next
      // user-initiated job starts from a clean GATT connection.
      await _discardSession(target);
      rethrow;
    }
  }

  static Future<_BleWriteTarget> _getOrOpenConnection(
    String bleName,
    int attempt, {
    String? preferredRemoteId,
  }) async {
    final cached = _cachedTarget;
    if (cached != null &&
        cached.bleName == bleName &&
        cached.device.isConnected) {
      debugPrint('[AiyinBLE] reusing connected session for $bleName');
      return cached;
    }

    if (cached != null) {
      await _disconnect(cached.device);
      _cachedTarget = null;
    }

    final target = await _openConnection(
      bleName,
      attempt,
      preferredRemoteId: preferredRemoteId,
    );
    _cachedTarget = target;
    return target;
  }

  /// Busca y conecta; si un remoteId guardado quedó obsoleto, cae de
  /// inmediato a un escaneo filtrado por nombre y aprende la nueva identidad.
  static Future<_BleWriteTarget> _openConnection(
    String bleName,
    int attempt, {
    String? preferredRemoteId,
  }) async {
    debugPrint('[AiyinBLE] resolving $bleName (intento ${attempt + 1})...');

    final saved = _nonBlank(preferredRemoteId);
    if (saved != null) {
      final device = BluetoothDevice.fromId(saved);
      try {
        return await _connectAndDiscover(device, bleName);
      } catch (error) {
        debugPrint(
          '[AiyinBLE] saved remoteId no longer works; rescanning: $error',
        );
        final scanned = await _findDevice(bleName);
        if (scanned == null) rethrow;
        return _connectAndDiscover(scanned, bleName);
      }
    }

    final device = await _findDevice(bleName);
    if (device == null) {
      throw const AiyinPrintException(
        'No encontramos la AIYIN E40 Pro por BLE. Enciéndela y acércala al teléfono.',
        code: 'device_not_found',
      );
    }
    return _connectAndDiscover(device, bleName);
  }

  static Future<_BleWriteTarget> _connectAndDiscover(
    BluetoothDevice device,
    String bleName,
  ) async {
    final displayName = device.platformName.isEmpty
        ? device.remoteId.str
        : device.platformName;
    debugPrint('[AiyinBLE] connecting to $displayName...');
    try {
      if (!device.isConnected) {
        // Ask for the largest useful ATT MTU. The E40 can cap it (the current
        // unit returns 247), but requesting 512 avoids imposing the old 244
        // byte ceiling on models/phones that negotiate more.
        await device.connect(
          timeout: const Duration(seconds: 10),
          autoConnect: false,
          mtu: null,
        );
      }

      var mtu = device.mtuNow;
      try {
        mtu = await device.requestMtu(512);
      } catch (error) {
        debugPrint('[AiyinBLE] requestMtu(512) failed, using mtu=$mtu: $error');
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
      debugPrint(
        '[AiyinBLE] GATT ${service.uuid}/${writeChar.uuid} '
        'writeWithoutResponse=${writeChar.properties.writeWithoutResponse}',
      );
      return _BleWriteTarget(
        bleName: bleName,
        device: device,
        characteristic: writeChar,
        mtu: mtu,
      );
    } catch (error) {
      await _disconnect(device);
      rethrow;
    }
  }

  static Future<void> _writeCommand(
    _BleWriteTarget target,
    Uint8List command,
  ) async {
    final chunkSize = (target.mtu - 3).clamp(20, 512);
    final withoutResponse =
        target.characteristic.properties.writeWithoutResponse;
    final chunkCount = (command.length + chunkSize - 1) ~/ chunkSize;
    debugPrint(
      '[AiyinBLE] writing ${command.length} bytes in $chunkCount chunks '
      'of $chunkSize (withoutResponse=$withoutResponse)',
    );

    var offset = 0;
    while (offset < command.length) {
      final end = (offset + chunkSize).clamp(0, command.length);
      await target.characteristic.write(
        command.sublist(offset, end),
        withoutResponse: withoutResponse,
      );
      offset = end;
    }
    debugPrint('[AiyinBLE] write done');
  }

  static Future<BluetoothDevice?> _findDevice(
    String name, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    BluetoothDevice? match(List<ScanResult> results) {
      for (final result in results) {
        if (result.device.platformName == name ||
            result.device.advName == name) {
          return result.device;
        }
      }
      return null;
    }

    final previous = match(FlutterBluePlus.lastScanResults);
    if (previous != null) return previous;

    final found = Completer<BluetoothDevice?>();
    Timer? timer;
    late final StreamSubscription<List<ScanResult>> subscription;

    void finish(BluetoothDevice? device) {
      if (!found.isCompleted) found.complete(device);
    }

    subscription = FlutterBluePlus.scanResults.listen((results) {
      final device = match(results);
      if (device != null) {
        finish(device);
        unawaited(FlutterBluePlus.stopScan());
      }
    });

    try {
      // startScan returns once the native scan has started; its timeout only
      // schedules stopScan. Waiting for another full timeout was the main
      // fixed six-second penalty in the previous implementation.
      await FlutterBluePlus.startScan(timeout: timeout, withNames: [name]);
      timer = Timer(timeout, () => finish(null));
      return await found.future;
    } finally {
      timer?.cancel();
      await subscription.cancel();
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    }
  }

  static Future<String?> _readRemoteId(String? classicAddress) async {
    final address = _nonBlank(classicAddress);
    if (address == null) return null;
    final prefs = await SharedPreferences.getInstance();
    return _nonBlank(prefs.getString('$_remoteIdKeyPrefix$address'));
  }

  static Future<void> _rememberRemoteId(
    String? classicAddress,
    String remoteId,
  ) async {
    final address = _nonBlank(classicAddress);
    if (address == null || remoteId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_remoteIdKeyPrefix$address', remoteId);
  }

  static String? _nonBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static Future<void> _discardSession(_BleWriteTarget target) async {
    if (identical(_cachedTarget, target)) _cachedTarget = null;
    await _disconnect(target.device);
  }

  static Future<void> _disconnect(BluetoothDevice device) async {
    if (!device.isConnected) return;
    try {
      await device.disconnect();
    } catch (error) {
      debugPrint('[AiyinBLE] disconnect ignored: $error');
    }
  }
}

class _BleWriteTarget {
  const _BleWriteTarget({
    required this.bleName,
    required this.device,
    required this.characteristic,
    required this.mtu,
  });

  final String bleName;
  final BluetoothDevice device;
  final BluetoothCharacteristic characteristic;
  final int mtu;
}
