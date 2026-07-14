import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../deeplinks/deep_link_service.dart';
import '../legal/legal_config.dart';
import '../notifications/push_service.dart';
import '../storage/session_storage.dart';
import 'auth_repository.dart';
import 'session.dart';

/// Estado de autenticación de la app. `build()` carga la sesión persistida y,
/// si el JWT expiró, la renueva en silencio con el refresh token (ya no se
/// guarda la contraseña en el dispositivo).
class AuthController extends AsyncNotifier<Session?> {
  // Datos del flujo de verificación en curso.
  String? _pendingPhone;
  bool _pendingDevMode = false;
  // Nombre pendiente para el alta passwordless pre-llenada desde el pedido.
  String? _pendingFirstName;
  String? _pendingLastName;
  FacebookAccountType? _pendingAccountType;
  String? _pendingBusinessName;
  String? _pendingCity;
  bool _pendingAcceptedLegal = false;
  String _pendingLegalVersion = LegalConfig.currentVersion;

  // Datos del Facebook en espera de completar perfil o verificar teléfono.
  FacebookAccessCredential? _pendingFacebookCredential;

  /// Marca que el login passwordless terminó y hay un pedido pendiente por
  /// deep link que debe "rescatarse" (reclamar). El router la usa para decidir
  /// a dónde llevar tras autenticar: `/pedido/{token}` (rescate) vs `/home`.
  bool _needsOrderRescue = false;

  /// Teléfono al que se le envió el código de WhatsApp (lo usa la pantalla de
  /// verificación).
  String? get pendingPhone => _pendingPhone;
  bool get pendingDevMode => _pendingDevMode;
  bool get needsOrderRescue => _needsOrderRescue;

  @override
  Future<Session?> build() async {
    final storage = ref.read(sessionStorageProvider);
    // Timeout defensivo: `flutter_secure_storage` puede bloquearse si el
    // keystore de Android está bloqueado (tras mucho tiempo sin abrir la app
    // o un reinicio del dispositivo). Sin esto, el `build()` nunca termina y
    // la app se queda en el splash para siempre. Mejor salir a login.
    final Session? session;
    try {
      session = await storage.read().timeout(const Duration(seconds: 5));
    } catch (_) {
      await _safeClear(storage);
      return null;
    }
    if (session == null) return null;
    if (!session.isExpired) return session;
    // JWT expirado: renovar con el refresh token (o limpiar si ya no sirve).
    return _refreshOrClear(session);
  }

  Future<Session?> _refreshOrClear(Session stale) async {
    final storage = ref.read(sessionStorageProvider);
    final rt = stale.refreshToken;
    if (rt == null || rt.isEmpty) {
      await _safeClear(storage);
      return null;
    }
    try {
      final refreshed = await ref.read(authRepositoryProvider).refresh(rt);
      // El `write` va fire-and-forget con timeout: si el keystore se cuelga,
      // el `build()` igual retorna y el `state` se setea (evitamos splash
      // infinito). La sesión vive en memoria; se persiste en background.
      unawaited(
        storage
            .write(refreshed)
            .timeout(const Duration(seconds: 5), onTimeout: () {}),
      );
      return refreshed;
    } catch (_) {
      await _safeClear(storage);
      return null;
    }
  }

  Future<void> _safeClear(SessionStorage storage) async {
    try {
      await storage
          .clear()
          .timeout(const Duration(seconds: 3), onTimeout: () {});
    } catch (_) {
      // Si ni siquiera podemos borrar, no bloqueamos: el state en null igual
      // manda a la usuaria a login.
    }
  }

  // ── Renovación reactiva (la usa el interceptor Dio ante un 401) ──

  Future<bool>? _refreshing;

  /// Renueva la sesión de forma idempotente ante 401 concurrentes. Devuelve
  /// `true` si quedó una sesión válida.
  Future<bool> tryRefresh() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _doRefresh() async {
    final rt = state.asData?.value?.refreshToken;
    if (rt == null || rt.isEmpty) return false;
    try {
      final refreshed = await ref.read(authRepositoryProvider).refresh(rt);
      // El `state` se actualiza síncrono: aunque el storage tarde, la app ya
      // tiene la sesión nueva en memoria y las llamadas en cola pueden
      // reintentar. El `write` va con timeout para no colgar el `_refreshing`
      // compartido (que todas las llamadas 401 esperan).
      state = AsyncData<Session?>(refreshed);
      unawaited(
        ref
            .read(sessionStorageProvider)
            .write(refreshed)
            .timeout(const Duration(seconds: 5), onTimeout: () {}),
      );
      return true;
    } catch (_) {
      await _safeClear(ref.read(sessionStorageProvider));
      state = const AsyncData<Session?>(null);
      return false;
    }
  }

  // ── Passwordless (clienta): teléfono + código, sin contraseña ──

  /// Paso 1: pide el código por WhatsApp y recuerda el teléfono + nombre
  /// (pre-llenado del pedido) para el paso 2.
  Future<void> requestPasswordlessOtp(
    String phone, {
    String? firstName,
    String? lastName,
    bool acceptedLegal = false,
    String legalVersion = LegalConfig.currentVersion,
  }) async {
    final result = await ref
        .read(authRepositoryProvider)
        .requestPhoneOtp(phone);
    _pendingPhone = phone;
    _pendingFirstName = firstName;
    _pendingLastName = lastName;
    _pendingAccountType = FacebookAccountType.client;
    _pendingBusinessName = null;
    _pendingCity = null;
    _pendingAcceptedLegal = acceptedLegal;
    _pendingLegalVersion = legalVersion;
    _pendingDevMode = result.devMode;
  }

  /// Paso 2: valida el código, crea/loguea la cuenta (sin contraseña) y guarda
  /// la sesión. Si hay un pedido pendiente por deep link, marca
  /// [needsOrderRescue] para que el router lo lleve a rescatarlo.
  Future<void> verifyPasswordlessOtp(String code) async {
    final phone = _pendingPhone;
    if (phone == null) {
      throw AuthException('Primero pide un código.');
    }
    final session = await ref
        .read(authRepositoryProvider)
        .verifyPhoneOtp(
          phone,
          code,
          firstName: _pendingFirstName,
          lastName: _pendingLastName,
          acceptedLegal: _pendingAcceptedLegal,
          legalVersion: _pendingLegalVersion,
          accountType: _pendingAccountType,
          businessName: _pendingBusinessName,
          city: _pendingCity,
        );
    _needsOrderRescue = ref.read(pendingDeepLinkProvider) != null;
    await _apply(session);
  }

  // ── Registro/login por contraseña (se conserva; ya no guarda la contraseña) ──

  /// Paso 1 del registro con contraseña: crea la cuenta y dispara el código.
  Future<void> registerPhone({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
    required FacebookAccountType accountType,
    required bool acceptedLegal,
    String legalVersion = LegalConfig.currentVersion,
    String? businessName,
    String? city,
  }) async {
    final result = await ref
        .read(authRepositoryProvider)
        .registerPhone(
          firstName: firstName,
          lastName: lastName,
          phone: phone,
          email: email,
          password: password,
          accountType: accountType,
          acceptedLegal: acceptedLegal,
          legalVersion: legalVersion,
          businessName: businessName,
          city: city,
        );
    _pendingPhone = phone;
    _pendingFirstName = firstName;
    _pendingLastName = lastName;
    _pendingAccountType = accountType;
    _pendingBusinessName = businessName;
    _pendingCity = city;
    _pendingAcceptedLegal = acceptedLegal;
    _pendingLegalVersion = legalVersion;
    _pendingDevMode = result.devMode;
  }

  /// Paso 2 del registro (o confirmación de un teléfono pendiente): valida el
  /// código de WhatsApp y guarda la sesión.
  Future<void> confirmPhone(String code) async {
    final phone = _pendingPhone;
    if (phone == null) {
      throw AuthException('Primero regístrate o inicia sesión.');
    }
    final session = await ref
        .read(authRepositoryProvider)
        .confirmPhone(
          phone,
          code,
          accountType: _pendingAccountType,
          businessName: _pendingBusinessName,
          city: _pendingCity,
          acceptedLegal: _pendingAcceptedLegal,
          legalVersion: _pendingLegalVersion,
        );
    await _apply(session);
  }

  /// Acceso con teléfono + contraseña. Si el teléfono no está confirmado, lanza
  /// [PhoneNotVerifiedException] tras dejar el pendiente listo para /confirm.
  Future<void> loginPhone(String phone, String password) async {
    try {
      final session = await ref
          .read(authRepositoryProvider)
          .loginPhone(phone, password);
      await _apply(session);
    } on PhoneNotVerifiedException {
      _pendingPhone = phone;
      _pendingDevMode = false;
      _pendingAccountType = null;
      _pendingBusinessName = null;
      _pendingCity = null;
      _pendingAcceptedLegal = false;
      _pendingLegalVersion = LegalConfig.currentVersion;
      rethrow;
    }
  }

  /// Reenvía el código de verificación por WhatsApp al teléfono pendiente.
  Future<void> resendCode() async {
    final phone = _pendingPhone;
    if (phone == null) return;
    final result = await ref.read(authRepositoryProvider).resendCode(phone);
    _pendingDevMode = result.devMode;
  }

  /// Acceso de vendedora con correo y contraseña.
  Future<void> loginEmail(String email, String password) async {
    final session = await ref
        .read(authRepositoryProvider)
        .loginEmail(email, password);
    await _apply(session);
  }

  /// Acceso con Facebook para clientas o vendedoras. Una cuenta vinculada y
  /// completa entra directamente; una nueva solicita los datos restantes.
  Future<void> loginFacebook(FacebookAccountType accountType) async {
    final repo = ref.read(authRepositoryProvider);
    final credential = await repo.facebookAccessToken();
    _pendingFacebookCredential = credential;
    _pendingAccountType = accountType;
    final session = await repo.facebookLogin(
      credential,
      accountType: accountType,
    );
    await _apply(session);
  }

  /// Completa una cuenta nueva o vincula una existente con Facebook. Si falta
  /// validar el teléfono, deja los datos listos para la pantalla de código.
  Future<void> completeFacebookProfile(
    FacebookProfileCompletion profile,
  ) async {
    final credential = _pendingFacebookCredential;
    if (credential == null) {
      throw AuthException('Vuelve a intentar con Facebook.');
    }
    _pendingAccountType = profile.accountType;
    _pendingBusinessName = profile.businessName;
    _pendingCity = profile.city;
    _pendingAcceptedLegal = profile.acceptedLegal;
    _pendingLegalVersion = profile.legalVersion;

    try {
      final session = await ref
          .read(authRepositoryProvider)
          .completeFacebookProfile(credential, profile);
      await _apply(session);
    } on FacebookPhoneVerificationRequiredException catch (e) {
      _pendingPhone = e.phone;
      _pendingDevMode = e.devMode;
      rethrow;
    }
  }

  Future<void> logout() async {
    // 1. Capturamos lo necesario ANTES de tocar el estado.
    final rt = state.asData?.value?.refreshToken;
    final repo = ref.read(authRepositoryProvider);
    final push = ref.read(pushServiceProvider);
    final storage = ref.read(sessionStorageProvider);

    // 2. Logout LOCAL inmediato e incondicional: limpiamos estado pendiente,
    //    storage y `state`. Esto dispara el redirect a /login al instante, sin
    //    esperar a Firebase ni al backend. Si la red está caída o Firebase no
    //    responde, la usuaria sale igual. El `state = null` es lo que importa.
    _clearPending();
    state = const AsyncData<Session?>(null);
    await _safeClear(storage);

    // 3. Cleanup del backend "fire and forget": revocar el refresh token,
    //    desregistrar el push y cerrar Facebook. Ninguno debe bloquear el
    //    logout (ya ocurrió) ni fallar de forma visible. El timeout protege
    //    contra `FirebaseMessaging.getToken()`, que no tiene timeout propio y
    //    puede colgarse indefinidamente.
    unawaited(
      _cleanupAfterLogout(repo: repo, push: push, refreshToken: rt),
    );
  }

  Future<void> _cleanupAfterLogout({
    required AuthRepository repo,
    required PushService push,
    required String? refreshToken,
  }) async {
    try {
      await Future.any([
        _doCleanup(repo: repo, push: push, refreshToken: refreshToken),
        Future<void>.delayed(const Duration(seconds: 8)),
      ]);
    } catch (_) {
      // Silencioso: el logout local ya ocurrió.
    }
  }

  Future<void> _doCleanup({
    required AuthRepository repo,
    required PushService push,
    required String? refreshToken,
  }) async {
    await Future.wait([
      if (refreshToken != null && refreshToken.isNotEmpty)
        repo.revokeRefreshToken(refreshToken),
      push.unregisterCurrentToken(),
      repo.facebookLogout(),
    ]);
  }

  void setActiveBusiness(int businessId) {
    final current = state.asData?.value;
    if (current == null) return;
    final updated = current.copyWith(activeBusinessId: businessId);
    state = AsyncData<Session?>(updated);
    ref.read(sessionStorageProvider).write(updated);
  }

  /// Guarda la sesión (con su refresh token) y limpia el estado pendiente.
  Future<void> _apply(Session session) async {
    _clearPending();
    // El `state` se setea síncrono para que el router redirija a /home al
    // instante. El persistir en storage va en background con timeout: si el
    // keystore se cuelga, no bloqueamos el login (la sesión vive en memoria).
    state = AsyncData<Session?>(session);
    unawaited(
      ref
          .read(sessionStorageProvider)
          .write(session)
          .timeout(const Duration(seconds: 5), onTimeout: () {}),
    );
    // Best-effort: registra el token de push de este dispositivo para la
    // cuenta recién autenticada. Nunca debe tumbar el login.
    unawaited(ref.read(pushServiceProvider).registerCurrentToken());
  }

  void _clearPending() {
    _pendingPhone = null;
    _pendingFirstName = null;
    _pendingLastName = null;
    _pendingAccountType = null;
    _pendingBusinessName = null;
    _pendingCity = null;
    _pendingAcceptedLegal = false;
    _pendingLegalVersion = LegalConfig.currentVersion;
    _pendingDevMode = false;
    _needsOrderRescue = false;
    _pendingFacebookCredential = null;
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, Session?>(
  AuthController.new,
);
