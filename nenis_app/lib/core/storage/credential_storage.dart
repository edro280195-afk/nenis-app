import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Credenciales de la compradora guardadas para re-login automático cuando el
/// JWT expira. Viven en almacenamiento seguro del dispositivo (Keychain/Keystore).
class SavedCredentials {
  const SavedCredentials({required this.phone, required this.password});

  final String phone;
  final String password;

  Map<String, dynamic> toJson() => {'phone': phone, 'password': password};

  factory SavedCredentials.fromJson(Map<String, dynamic> j) => SavedCredentials(
        phone: (j['phone'] ?? '') as String,
        password: (j['password'] ?? '') as String,
      );
}

/// Persiste teléfono + contraseña para no pedir login en cada apertura de la app.
class CredentialStorage {
  CredentialStorage(this._storage);

  final FlutterSecureStorage _storage;
  static const _key = 'neni_credentials';

  Future<SavedCredentials?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final creds = SavedCredentials.fromJson(json);
      if (creds.phone.isEmpty || creds.password.isEmpty) return null;
      return creds;
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> write(SavedCredentials creds) =>
      _storage.write(key: _key, value: jsonEncode(creds.toJson()));

  Future<void> clear() => _storage.delete(key: _key);
}

final credentialStorageProvider = Provider<CredentialStorage>((ref) {
  return CredentialStorage(const FlutterSecureStorage());
});
