import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../deeplinks/deep_link_service.dart';
import '../legal/legal_config.dart';
import '../notifications/push_service.dart';
import '../storage/session_storage.dart';
import '../../features/account/data/account_repository.dart';
import 'firebase_phone_auth_service.dart';
import 'auth_repository.dart';
import 'session.dart';

/// Estado de autenticación de la app. `build()` carga la sesión persistida y,
/// si el JWT expiró, la renueva en silencio con el refresh token (ya no se
/// guarda la contraseña en el dispositivo).
class AuthController extends AsyncNotifier<Session?> {
  // Datos del flujo de verificación en curso.
  String? _pendingPhone;
  String? _pendingFirebasePhone;
  FirebaseLoginProfile? _pendingFirebaseProfile;
  bool _pendingFirebaseAuth = false;
  bool _pendingDevMode = false;
  // Nombre pendiente para el alta passwordless pre-llenada desde el pedido.
  String? _pendingFirstName;
  String? _pendingLastName;
  AccountType? _pendingAccountType;
  String? _pendingBusinessName;
  String? _pendingCity;
  bool _pendingAcceptedLegal = false;
  String _pendingLegalVersion = LegalConfig.currentVersion;

  /// Marca que el login passwordless terminó y hay un pedido pendiente por
  /// deep link que debe "rescatarse" (reclamar). El router la usa para decidir
  /// a dónde llevar tras autenticar: `/pedido/{token}` (rescate) vs `/home`.
  bool _needsOrderRescue = false;

  /// Teléfono al que se le envió el código (E.164 para Firebase; nacional en
  /// los flujos legacy).
  String? get pendingPhone => _pendingFirebasePhone ?? _pendingPhone;
  bool get pendingFirebaseAuth => _pendingFirebaseAuth;
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
    if (!session.isExpired) {
      // Multi-tienda sin negocio activo: autoselecciona el primero y persiste
      // para que el próximo arranque sea estable (y el header X-Business-Id
      // se envíe desde el primer hit).
      if (session.activeBusinessId == null && session.memberships.isNotEmpty) {
        final normalized = _withDefaultBusiness(session);
        unawaited(
          storage
              .write(normalized)
              .timeout(const Duration(seconds: 5), onTimeout: () {}),
        );
        return normalized;
      }
      return session;
    }
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
      final normalized = _withDefaultBusiness(refreshed);
      // El `write` va fire-and-forget con timeout: si el keystore se cuelga,
      // el `build()` igual retorna y el `state` se setea (evitamos splash
      // infinito). La sesión vive en memoria; se persiste en background.
      unawaited(
        storage
            .write(normalized)
            .timeout(const Duration(seconds: 5), onTimeout: () {}),
      );
      return normalized;
    } catch (_) {
      await _safeClear(storage);
      return null;
    }
  }

  Future<void> _safeClear(SessionStorage storage) async {
    try {
      await storage.clear().timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
    } catch (_) {
      // Si ni siquiera podemos borrar, no bloqueamos: el state en null igual
      // manda a la usuaria a login.
    }
  }

  /// Garantiza que la sesión tenga un `activeBusinessId` cuando la cuenta
  /// tiene memberships. Si tiene varias tiendas y ninguna seleccionada,
  /// autoselecciona la primera. Sin esto, el header `X-Business-Id` no se
  /// envía y el backend cae a `DefaultBusinessId = 1`, que puede no
  /// pertenecer a la vendedora → vería los datos de otro negocio.
  Session _withDefaultBusiness(Session s) {
    if (s.activeBusinessId != null) return s;
    if (s.memberships.isEmpty) return s;
    return s.copyWith(activeBusinessId: s.memberships.first.businessId);
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
      final normalized = _withDefaultBusiness(refreshed);
      // El `state` se actualiza síncrono: aunque el storage tarde, la app ya
      // tiene la sesión nueva en memoria y las llamadas en cola pueden
      // reintentar. El `write` va con timeout para no colgar el `_refreshing`
      // compartido (que todas las llamadas 401 esperan).
      state = AsyncData<Session?>(normalized);
      unawaited(
        ref
            .read(sessionStorageProvider)
            .write(normalized)
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
    _pendingAccountType = AccountType.client;
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

  /// Guarda el perfil local mientras Firebase envía el SMS. La identidad real
  /// se valida después, al canjear el ID token en la API.
  void beginFirebaseAuth({
    required String phone,
    required FirebaseLoginProfile profile,
  }) {
    _pendingFirebaseAuth = true;
    _pendingFirebasePhone = phone;
    _pendingFirebaseProfile = profile;
    _pendingPhone = null;
    _pendingFirstName = profile.firstName;
    _pendingLastName = profile.lastName;
    _pendingAccountType = profile.accountType;
    _pendingBusinessName = profile.businessName;
    _pendingCity = profile.city;
    _pendingAcceptedLegal = profile.acceptedLegal;
    _pendingLegalVersion = profile.legalVersion;
    _pendingDevMode = false;
  }

  /// Canjea el ID token de Firebase por el JWT de Nenis y conserva el flujo
  /// actual de refresh token, memberships y selección de negocio.
  Future<void> loginWithFirebaseIdToken(String idToken) async {
    final profile = _pendingFirebaseProfile;
    if (!_pendingFirebaseAuth || profile == null) {
      throw AuthException('Primero solicita un código por SMS.');
    }
    final session = await ref
        .read(authRepositoryProvider)
        .firebaseLogin(idToken: idToken, profile: profile);
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
    required AccountType accountType,
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

  Future<void> logout() async {
    // 1. Capturamos lo necesario ANTES de tocar el estado.
    final rt = state.asData?.value?.refreshToken;
    final repo = ref.read(authRepositoryProvider);
    final push = ref.read(pushServiceProvider);
    final firebase = ref.read(firebasePhoneAuthServiceProvider);
    final storage = ref.read(sessionStorageProvider);

    // 2. Logout LOCAL inmediato e incondicional: limpiamos estado pendiente,
    //    storage y `state`. Esto dispara el redirect a /login al instante, sin
    //    esperar a Firebase ni al backend. Si la red está caída o Firebase no
    //    responde, la usuaria sale igual. El `state = null` es lo que importa.
    _clearPending();
    state = const AsyncData<Session?>(null);
    await _safeClear(storage);

    // 3. Cleanup del backend "fire and forget": revocar el refresh token y
    //    desregistrar el push. Ninguno debe bloquear el
    //    logout (ya ocurrió) ni fallar de forma visible. El timeout protege
    //    contra `FirebaseMessaging.getToken()`, que no tiene timeout propio y
    //    puede colgarse indefinidamente.
    unawaited(
      _cleanupAfterLogout(
        repo: repo,
        push: push,
        firebase: firebase,
        refreshToken: rt,
      ),
    );
  }

  Future<void> deleteAccount() async {
    final repo = ref.read(accountRepositoryProvider);
    final firebase = ref.read(firebasePhoneAuthServiceProvider);
    final storage = ref.read(sessionStorageProvider);

    // Solo se limpia la sesión local después de que la API confirma la baja.
    // Si falla la red, la usuaria conserva su sesión y puede reintentar.
    await repo.deleteAccount();
    await firebase.signOut();
    _clearPending();
    state = const AsyncData<Session?>(null);
    await _safeClear(storage);
  }

  Future<void> completeOnboarding(String role) async {
    final current = state.asData?.value;
    if (current == null) {
      throw AuthException('Tu sesion ya no esta disponible.');
    }

    final onboarding = await ref
        .read(authRepositoryProvider)
        .completeOnboarding(role);
    final updated = current.copyWith(onboarding: onboarding);
    state = AsyncData<Session?>(updated);
    await ref
        .read(sessionStorageProvider)
        .write(updated)
        .timeout(const Duration(seconds: 5), onTimeout: () {});
  }

  Future<void> _cleanupAfterLogout({
    required AuthRepository repo,
    required PushService push,
    required FirebasePhoneAuthService firebase,
    required String? refreshToken,
  }) async {
    try {
      await Future.any([
        _doCleanup(
          repo: repo,
          push: push,
          firebase: firebase,
          refreshToken: refreshToken,
        ),
        Future<void>.delayed(const Duration(seconds: 8)),
      ]);
    } catch (_) {
      // Silencioso: el logout local ya ocurrió.
    }
  }

  Future<void> _doCleanup({
    required AuthRepository repo,
    required PushService push,
    required FirebasePhoneAuthService firebase,
    required String? refreshToken,
  }) async {
    await Future.wait([
      if (refreshToken != null && refreshToken.isNotEmpty)
        repo.revokeRefreshToken(refreshToken),
      push.unregisterCurrentToken(),
      firebase.signOut(),
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
    final normalized = _withDefaultBusiness(session);
    _clearPending();
    // El `state` se setea síncrono para que el router redirija a /home al
    // instante. El persistir en storage va en background con timeout: si el
    // keystore se cuelga, no bloqueamos el login (la sesión vive en memoria).
    state = AsyncData<Session?>(normalized);
    unawaited(
      ref
          .read(sessionStorageProvider)
          .write(normalized)
          .timeout(const Duration(seconds: 5), onTimeout: () {}),
    );
    // Best-effort: registra el token de push de este dispositivo para la
    // cuenta recién autenticada. Nunca debe tumbar el login.
    unawaited(ref.read(pushServiceProvider).registerCurrentToken());
  }

  void _clearPending() {
    _pendingPhone = null;
    _pendingFirebasePhone = null;
    _pendingFirebaseProfile = null;
    _pendingFirebaseAuth = false;
    _pendingFirstName = null;
    _pendingLastName = null;
    _pendingAccountType = null;
    _pendingBusinessName = null;
    _pendingCity = null;
    _pendingAcceptedLegal = false;
    _pendingLegalVersion = LegalConfig.currentVersion;
    _pendingDevMode = false;
    _needsOrderRescue = false;
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, Session?>(
  AuthController.new,
);
