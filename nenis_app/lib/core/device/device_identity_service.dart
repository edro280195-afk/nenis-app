import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Identificador aleatorio de esta instalacion. No usa IMEI, Android ID ni
/// otro dato personal del telefono; sirve como segunda senal antifraude y se
/// conserva en el almacenamiento seguro de la app.
class DeviceIdentityService {
  DeviceIdentityService(this._storage);

  static const _storageKey = 'nenis_device_identity_v1';
  final FlutterSecureStorage _storage;
  Future<String>? _cached;

  Future<String> getOrCreate() => _cached ??= _loadOrCreate();

  Future<String> _loadOrCreate() async {
    try {
      final stored = await _storage
          .read(key: _storageKey)
          .timeout(const Duration(seconds: 3));
      if (_isValid(stored)) return stored!;
    } catch (_) {
      // La identidad en memoria permite continuar si el keystore esta
      // temporalmente bloqueado. El telefono verificado sigue siendo la
      // proteccion principal del registro.
    }

    final generated = _randomHex(32);
    try {
      await _storage
          .write(key: _storageKey, value: generated)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Se conserva en [_cached] durante esta ejecucion.
    }
    return generated;
  }

  bool _isValid(String? value) =>
      value != null && RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

  String _randomHex(int bytes) {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var index = 0; index < bytes; index++) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

final deviceIdentityServiceProvider = Provider<DeviceIdentityService>((ref) {
  return DeviceIdentityService(const FlutterSecureStorage());
});
