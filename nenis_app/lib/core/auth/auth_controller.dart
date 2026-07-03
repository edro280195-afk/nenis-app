import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/session_storage.dart';
import 'auth_repository.dart';
import 'session.dart';

/// Estado de autenticación de la app. `build()` carga la sesión persistida al
/// arrancar; los métodos manejan login/logout y el negocio activo.
class AuthController extends AsyncNotifier<Session?> {
  String? _pendingPhone;
  bool _pendingOtpDevMode = false;

  /// Teléfono al que se le pidió el OTP (lo usa la pantalla de verificación).
  String? get pendingPhone => _pendingPhone;
  bool get pendingOtpDevMode => _pendingOtpDevMode;

  @override
  Future<Session?> build() async {
    final storage = ref.read(sessionStorageProvider);
    final session = await storage.read();
    if (session == null) return null;
    if (session.isExpired) {
      await storage.clear();
      return null;
    }
    return session;
  }

  Future<void> requestOtp(String phone) async {
    final result = await ref.read(authRepositoryProvider).requestOtp(phone);
    _pendingPhone = phone;
    _pendingOtpDevMode = result.devMode;
  }

  Future<void> verifyOtp(String code) async {
    final phone = _pendingPhone;
    if (phone == null) {
      throw AuthException('Primero pide el código.');
    }
    final session = await ref
        .read(authRepositoryProvider)
        .verifyOtp(phone, code);
    await ref.read(sessionStorageProvider).write(session);
    _pendingPhone = null;
    _pendingOtpDevMode = false;
    state = AsyncData<Session?>(session);
  }

  Future<void> loginEmail(String email, String password) async {
    final session = await ref
        .read(authRepositoryProvider)
        .loginEmail(email, password);
    await ref.read(sessionStorageProvider).write(session);
    state = AsyncData<Session?>(session);
  }

  Future<void> logout() async {
    await ref.read(sessionStorageProvider).clear();
    _pendingPhone = null;
    _pendingOtpDevMode = false;
    state = const AsyncData<Session?>(null);
  }

  void setActiveBusiness(int businessId) {
    final current = state.asData?.value;
    if (current == null) return;
    final updated = current.copyWith(activeBusinessId: businessId);
    state = AsyncData<Session?>(updated);
    ref.read(sessionStorageProvider).write(updated);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, Session?>(
  AuthController.new,
);
