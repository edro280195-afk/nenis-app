import 'dart:async';
import 'dart:io';

import 'package:android_play_install_referrer/android_play_install_referrer.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/dio_provider.dart';
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
///  - re-siembra desde [PendingClaimStore] al arrancar (sobrevive la muerte de
///    proceso durante el OTP y la reinstalación);
///  - **Install Referrer de Google Play** (deep linking diferido): si la app
///    se instala desde el muro /o/{token}, el referrer `token=...` se captura
///    una sola vez por instalación y se siembra como pending deep link.
///
/// El referrer de iOS se cubre con Universal Links + Smart App Banner (no hay
/// equivalente al Install Referrer; el rescate por match de teléfono cierra
/// el hueco).
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

    // 2) Install Referrer de Google Play (deep linking diferido). Sólo se
    //    consume una vez por instalación para no re-abrir el pedido en cada
    //    cold start. En iOS/web es no-op (el plugin lanza; va en try/catch).
    await _readInstallReferrer();

    // 3) Link que abrió la app en frío.
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) await _handleUri(initial);
    } catch (_) {}

    // 4) Links que llegan con la app viva.
    _sub = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (_) {},
    );
  }

  /// Lee el Install Referrer de Google Play y, si trae `token=...`, lo siembra
  /// como pending deep link y reporta el evento `install_referrer` al backend
  /// (analítica auto-alojada). No-op en iOS/web y si ya se consumió.
  Future<void> _readInstallReferrer() async {
    if (!kIsWeb && !Platform.isAndroid) return;
    final store = _ref.read(pendingClaimStoreProvider);
    try {
      if (await store.isReferrerConsumed()) return;
      final details = await AndroidPlayInstallReferrer.installReferrer;
      final raw = details.installReferrer;
      if (raw == null || raw.isEmpty) {
        await store.markReferrerConsumed();
        return;
      }
      final token = _extractTokenFromReferrer(raw);
      if (token != null) {
        await _persistAndSet(token);
        await _reportInstallReferrer(token, raw);
      }
      // Marca consumido haya o no token: si Play no trajo nada, no reintentamos.
      await store.markReferrerConsumed();
    } catch (_) {
      // El plugin lanza en iOS o si no hay Play Services. No marcamos consumido
      // para reintentar en el siguiente arranque (raro, pero defensivo).
    }
  }

  /// Extrae `token=...` del referrer (p. ej. `token=ABC` o `utm_source=...&token=ABC`).
  String? _extractTokenFromReferrer(String referrer) {
    try {
      final uri = Uri(query: referrer);
      final token = uri.queryParameters['token'];
      if (token != null && token.trim().isNotEmpty) return token.trim();
    } catch (_) {}
    // Fallback: buscar `token=...` a mano si el referrer no es un query string.
    final m = RegExp(r'token=([^\s&=]+)').firstMatch(referrer);
    return m?.group(1);
  }

  /// Reporta el evento `install_referrer` al backend (analítica auto-alojada).
  /// Fire-and-forget: si falla, no rompe el flujo de deep link.
  Future<void> _reportInstallReferrer(String token, String rawReferrer) async {
    try {
      await _ref.read(dioProvider).post<dynamic>(
        '/api/link-events',
        data: {
          'AccessToken': token,
          'Event': 'install_referrer',
          'Referrer': rawReferrer,
        },
      );
    } catch (_) {}
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
