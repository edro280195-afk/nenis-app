import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persiste el `accessToken` del pedido que llegó por deep link para que
/// sobreviva el ida-y-vuelta del OTP de WhatsApp (durante el cual el SO puede
/// matar el proceso) e incluso el reinicio de la app tras instalar.
///
/// Vive en almacenamiento seguro del dispositivo, igual que la sesión.
///
/// Además guarda un flag `referrerConsumed` para que el Install Referrer de
/// Google Play sólo se consuma una vez por instalación (si no, cada cold start
/// re-abriría el pedido). El flag se borra al desinstalar (secure storage se
/// limpia), así que una reinstalación sí vuelve a disparar el referrer.
class PendingClaimStore {
  PendingClaimStore(this._storage);

  final FlutterSecureStorage _storage;
  static const _key = 'neni_pending_order_token';
  static const _referrerConsumedKey = 'neni_referrer_consumed';

  Future<String?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  Future<void> write(String token) =>
      _storage.write(key: _key, value: token.trim());

  Future<void> clear() => _storage.delete(key: _key);

  /// ¿Ya consumimos el Install Referrer de Play en esta instalación?
  Future<bool> isReferrerConsumed() async =>
      (await _storage.read(key: _referrerConsumedKey)) == '1';

  /// Marca el referrer como consumido para no re-dispararlo en cada cold start.
  Future<void> markReferrerConsumed() =>
      _storage.write(key: _referrerConsumedKey, value: '1');
}

final pendingClaimStoreProvider = Provider<PendingClaimStore>((ref) {
  return PendingClaimStore(const FlutterSecureStorage());
});
