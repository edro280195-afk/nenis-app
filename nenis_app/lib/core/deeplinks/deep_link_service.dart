import 'dart:async';

import 'package:app_links/app_links.dart';
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
///  - re-siembra desde [PendingClaimStore] al arrancar (sobrevive la muerte de
///    proceso durante el OTP y la reinstalación).
///
/// Nota: el deep link diferido de Android por Google Play Install Referrer se
/// dejó fuera por ahora (el plugin obliga a subir compileSdk y las apps aún no
/// están publicadas). El rescate por match de teléfono cubre ese caso. Se puede
/// re-agregar al publicar.
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
