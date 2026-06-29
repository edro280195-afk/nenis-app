import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/session.dart';

/// Persiste la sesión (JWT + memberships + negocio activo) en almacenamiento
/// seguro del dispositivo.
class SessionStorage {
  SessionStorage(this._storage);

  final FlutterSecureStorage _storage;
  static const _key = 'neni_session';

  Future<Session?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return Session.decode(raw);
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> write(Session session) =>
      _storage.write(key: _key, value: session.encode());

  Future<void> clear() => _storage.delete(key: _key);
}

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  return SessionStorage(const FlutterSecureStorage());
});
