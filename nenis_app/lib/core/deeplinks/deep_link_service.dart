import 'dart:async';

import 'package:android_play_install_referrer/android_play_install_referrer.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pending_claim_store.dart';

/// Token del pedido que llegó por deep link / referrer y que debe abrirse (y
/// reclamarse tras autenticar). El router observa este provider para redirigir
/// a `/pedido/{token}`; la pantalla lo limpia al consumirlo.
class PendingDeepLink extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String token) {
    final t = token.trim();
    if (t.isEmpty || t == state) return;
    state = t;
  }

  void clear() {
    if (state != null) state = null;
  }
}

final pendingDeepLinkProvider =
    NotifierProvider<PendingDeepLink, String?>(PendingDeepLink.new);

/// Extrae el `accessToken` de una URL de pedido. Soporta el short-link
/// `/o/{token}` y la ruta larga `/pedido/{token}`, con o sin dominio y con el
/// scheme propio `nenis://o/{token}`.
String? extractOrderToken(Uri uri) {
  final segments = uri.pathSegments;
  for (var i = 0; i < segments.length - 1; i++) {
    if (segments[i] == 'o' || segments[i] == 'pedido') {
      final token = segments[i + 1].trim();
      if (token.isNotEmpty) return token;
    }
  }
  // Scheme propio tipo `nenis://o/abc`: el host es "o" y el token el 1er path.
  if ((uri.host == 'o' || uri.host == 'pedido') && segments.isNotEmpty) {
    final token = segments.first.trim();
    if (token.isNotEmpty) return token;
  }
  return null;
}

/// Orquesta la captura de deep links hacia un pedido:
///  - link inicial (cold start) y stream (warm) vía [AppLinks];
///  - Install Referrer de Google Play (deferred deep link en Android);
///  - re-siembra desde [PendingClaimStore] al arrancar (sobrevive la muerte de
///    proceso durante el OTP y la reinstalación).
///
/// No navega directamente: sólo alimenta [pendingDeepLinkProvider] + el store,
/// y el router reacciona. Así el token sobrevive el "bounce" al splash mientras
/// carga la sesión.
class DeepLinkService {
  DeepLinkService(this._ref);

  final Ref _ref;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    // 1) Token pendiente persistido (OTP interrumpido / reinstalación).
    try {
      final saved = await _ref.read(pendingClaimStoreProvider).read();
      if (saved != null) {
        _ref.read(pendingDeepLinkProvider.notifier).set(saved);
      }
    } catch (_) {}

    // 2) Link que abrió la app en frío.
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) await _handleUri(initial);
    } catch (_) {}

    // 3) Links que llegan con la app viva.
    _sub = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (_) {},
    );

    // 4) Deferred deep link por Install Referrer (Android, tras instalar).
    unawaited(_readInstallReferrer());
  }

  Future<void> _handleUri(Uri uri) async {
    final token = extractOrderToken(uri);
    if (token == null) return;
    await _persistAndSet(token);
  }

  Future<void> _persistAndSet(String token) async {
    try {
      await _ref.read(pendingClaimStoreProvider).write(token);
    } catch (_) {}
    _ref.read(pendingDeepLinkProvider.notifier).set(token);
  }

  /// Lee el Install Referrer una sola vez en la vida de la instalación. El muro
  /// de descarga adjunta `&referrer=token%3D{token}` a la URL de Play, que Play
  /// entrega aquí como query string (p. ej. `token=abc&utm_source=wa`).
  Future<void> _readInstallReferrer() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final store = _ref.read(pendingClaimStoreProvider);
    try {
      if (await store.isReferrerConsumed()) return;
      // Si ya tenemos un token (por link directo), no hace falta el referrer.
      if (_ref.read(pendingDeepLinkProvider) == null) {
        final details = await AndroidPlayInstallReferrer.installReferrer;
        final raw = details.installReferrer;
        if (raw != null && raw.isNotEmpty) {
          final token = Uri.splitQueryString(raw)['token']?.trim();
          if (token != null && token.isNotEmpty) {
            await _persistAndSet(token);
          }
        }
      }
      await store.markReferrerConsumed();
    } catch (_) {}
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService(ref);
  ref.onDispose(service.dispose);
  return service;
});
