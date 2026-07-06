import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/credential_storage.dart';
import '../storage/session_storage.dart';
import 'auth_repository.dart';
import 'session.dart';

/// Estado de autenticación de la app. `build()` carga la sesión persistida al
/// arrancar y, si el JWT expiró, intenta un re-login silencioso con las
/// credenciales guardadas para no pedir acceso en cada apertura.
class AuthController extends AsyncNotifier<Session?> {
  // Datos del flujo de verificación en curso (registro o confirmación pendiente).
  String? _pendingPhone;
  String? _pendingPassword;
  bool _pendingDevMode = false;

  // Token de Facebook en espera de teléfono (alta nueva con Facebook).
  String? _pendingFbToken;

  /// Teléfono al que se le envió el código de WhatsApp (lo usa la pantalla de
  /// verificación).
  String? get pendingPhone => _pendingPhone;
  bool get pendingDevMode => _pendingDevMode;

  @override
  Future<Session?> build() async {
    final storage = ref.read(sessionStorageProvider);
    final session = await storage.read();

    if (session != null && !session.isExpired) {
      return session;
    }
    if (session != null && session.isExpired) {
      await storage.clear();
    }

    // Sin sesión válida: re-login silencioso con las credenciales guardadas.
    final creds = await ref.read(credentialStorageProvider).read();
    if (creds == null) return null;
    try {
      final refreshed = await ref
          .read(authRepositoryProvider)
          .loginPhone(creds.phone, creds.password);
      await storage.write(refreshed);
      return refreshed;
    } catch (_) {
      // Credenciales inválidas o teléfono sin confirmar: pedir login manual.
      await ref.read(credentialStorageProvider).clear();
      return null;
    }
  }

  /// Paso 1 del registro: crea la cuenta y dispara el código por WhatsApp.
  Future<void> registerPhone({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
  }) async {
    final result = await ref.read(authRepositoryProvider).registerPhone(
          firstName: firstName,
          lastName: lastName,
          phone: phone,
          email: email,
          password: password,
        );
    _pendingPhone = phone;
    _pendingPassword = password;
    _pendingDevMode = result.devMode;
  }

  /// Paso 2 del registro (o confirmación de un teléfono pendiente): valida el
  /// código de WhatsApp, guarda la sesión y las credenciales.
  Future<void> confirmPhone(String code) async {
    final phone = _pendingPhone;
    if (phone == null) {
      throw AuthException('Primero regístrate o inicia sesión.');
    }
    final session =
        await ref.read(authRepositoryProvider).confirmPhone(phone, code);
    await _persist(session, phone: phone, password: _pendingPassword);
  }

  /// Acceso con teléfono + contraseña. Si el teléfono no está confirmado, lanza
  /// [PhoneNotVerifiedException] tras dejar el pendiente listo para /confirm.
  Future<void> loginPhone(String phone, String password) async {
    try {
      final session =
          await ref.read(authRepositoryProvider).loginPhone(phone, password);
      await _persist(session, phone: phone, password: password);
    } on PhoneNotVerifiedException {
      _pendingPhone = phone;
      _pendingPassword = password;
      _pendingDevMode = false;
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

  /// Acceso de equipo (correo + contraseña). No guarda credenciales para
  /// re-login automático (cuentas de administración/conductores).
  Future<void> loginEmail(String email, String password) async {
    final session =
        await ref.read(authRepositoryProvider).loginEmail(email, password);
    await ref.read(sessionStorageProvider).write(session);
    _clearPending();
    state = AsyncData<Session?>(session);
  }

  /// Acceso con Facebook. Abre el diálogo, canjea el token en el backend y guarda
  /// la sesión. Puede lanzar [FacebookCancelledException] (cancelación, sin
  /// error grave), [FacebookNeedsPhoneException] (cuenta nueva: pedir teléfono)
  /// o [AuthException] (error real).
  Future<void> loginFacebook() async {
    final repo = ref.read(authRepositoryProvider);
    final token = await repo.facebookAccessToken();
    _pendingFbToken = token;
    final session = await repo.facebookLogin(token);
    await _persistSocial(session);
  }

  /// Completa el alta con Facebook usando el teléfono capturado por la UI.
  Future<void> completeFacebookWithPhone(String phone) async {
    final token = _pendingFbToken;
    if (token == null) {
      throw AuthException('Vuelve a intentar con Facebook.');
    }
    final session =
        await ref.read(authRepositoryProvider).facebookLogin(token, phone: phone);
    await _persistSocial(session);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).facebookLogout();
    await ref.read(sessionStorageProvider).clear();
    await ref.read(credentialStorageProvider).clear();
    _clearPending();
    state = const AsyncData<Session?>(null);
  }

  void setActiveBusiness(int businessId) {
    final current = state.asData?.value;
    if (current == null) return;
    final updated = current.copyWith(activeBusinessId: businessId);
    state = AsyncData<Session?>(updated);
    ref.read(sessionStorageProvider).write(updated);
  }

  Future<void> _persist(
    Session session, {
    required String phone,
    String? password,
  }) async {
    await ref.read(sessionStorageProvider).write(session);
    if (password != null && password.isNotEmpty) {
      await ref
          .read(credentialStorageProvider)
          .write(SavedCredentials(phone: phone, password: password));
    }
    _clearPending();
    state = AsyncData<Session?>(session);
  }

  /// Guarda la sesión de un login social (Facebook). No persiste credenciales
  /// de teléfono/contraseña porque el acceso no las usa.
  Future<void> _persistSocial(Session session) async {
    await ref.read(sessionStorageProvider).write(session);
    _clearPending();
    state = AsyncData<Session?>(session);
  }

  void _clearPending() {
    _pendingPhone = null;
    _pendingPassword = null;
    _pendingDevMode = false;
    _pendingFbToken = null;
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, Session?>(
  AuthController.new,
);
