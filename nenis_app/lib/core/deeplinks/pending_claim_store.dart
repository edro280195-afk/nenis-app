import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persiste el `accessToken` del pedido que llegó por deep link para que
/// sobreviva el ida-y-vuelta del OTP de WhatsApp (durante el cual el SO puede
/// matar el proceso) e incluso el reinicio de la app tras instalar.
///
/// Vive en almacenamiento seguro del dispositivo, igual que
/// [CredentialStorage] y [SessionStorage].
class PendingClaimStore {
  PendingClaimStore(this._storage);

  final FlutterSecureStorage _storage;
  static const _key = 'neni_pending_order_token';
  static const _referrerKey = 'neni_install_referrer_consumed';

  Future<String?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  Future<void> write(String token) =>
      _storage.write(key: _key, value: token.trim());

  Future<void> clear() => _storage.delete(key: _key);

  /// El Install Referrer de Google Play sólo importa la primera vez que se
  /// abre la app tras instalar. Se marca como consumido para no re-procesar un
  /// referrer viejo (Play lo conserva) y re-abrir un pedido ya atendido.
  Future<bool> isReferrerConsumed() async =>
      (await _storage.read(key: _referrerKey)) == '1';

  Future<void> markReferrerConsumed() =>
      _storage.write(key: _referrerKey, value: '1');
}

final pendingClaimStoreProvider = Provider<PendingClaimStore>((ref) {
  return PendingClaimStore(const FlutterSecureStorage());
});
