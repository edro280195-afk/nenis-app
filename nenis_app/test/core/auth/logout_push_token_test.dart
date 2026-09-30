import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/core/auth/auth_controller.dart';
import 'package:nenis_app/core/auth/auth_repository.dart';
import 'package:nenis_app/core/auth/firebase_phone_auth_service.dart';
import 'package:nenis_app/core/auth/session.dart';
import 'package:nenis_app/core/notifications/push_service.dart';
import 'package:nenis_app/core/storage/session_storage.dart';

/// Al cerrar sesión el teléfono deja de recibir los avisos de esa cuenta: el token de
/// push se quita con la credencial de la sesión que sale. Antes `logout()` borraba la
/// sesión primero y el `DELETE` del token salía sin credenciales, el backend lo
/// rechazaba y el token seguía registrado a la cuenta que ya había salido.
void main() {
  test(
    'logout quita el token de push con el JWT de la sesión que sale',
    () async {
      final pushes = <_RecordingPushService>[];
      final container = _container(
        storage: _FakeSessionStorage(_session('jwt-de-ana')),
        onPush: pushes.add,
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      await container.read(authControllerProvider.notifier).logout();
      await pumpEventQueue();

      // La sesión ya no existe en la app…
      expect(container.read(authControllerProvider).value, isNull);
      // …pero el token se quitó presentando la credencial que tenía al salir.
      expect(pushes, hasLength(1));
      expect(pushes.single.unregisterTokens, ['jwt-de-ana']);
    },
  );

  test('logout sin sesión no rompe ni manda credenciales', () async {
    final pushes = <_RecordingPushService>[];
    final container = _container(
      storage: _FakeSessionStorage(null),
      onPush: pushes.add,
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await container.read(authControllerProvider.notifier).logout();
    await pumpEventQueue();

    expect(pushes.single.unregisterTokens, [null]);
  });
}

ProviderContainer _container({
  required SessionStorage storage,
  required void Function(_RecordingPushService) onPush,
}) {
  return ProviderContainer(
    overrides: [
      sessionStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(_QuietAuthRepository()),
      firebasePhoneAuthServiceProvider.overrideWithValue(
        FirebasePhoneAuthService(null),
      ),
      pushServiceProvider.overrideWith((ref) {
        final push = _RecordingPushService(ref);
        onPush(push);
        return push;
      }),
    ],
  );
}

Session _session(String jwt) => Session(
  token: jwt,
  accountId: 7,
  displayName: 'Ana',
  role: 'None',
  expiresAt: DateTime.now().add(const Duration(days: 1)),
  memberships: const [],
  refreshToken: 'refresh-de-ana',
);

/// Push que solo recuerda con qué credencial le pidieron quitar el token.
class _RecordingPushService extends PushService {
  _RecordingPushService(super.ref);

  final unregisterTokens = <String?>[];

  @override
  Future<void> unregisterCurrentToken({String? accessToken}) async {
    unregisterTokens.add(accessToken);
  }
}

class _QuietAuthRepository extends AuthRepository {
  _QuietAuthRepository() : super(Dio());

  @override
  Future<void> revokeRefreshToken(String refreshToken) async {}
}

class _FakeSessionStorage extends SessionStorage {
  _FakeSessionStorage(this._session) : super(const FlutterSecureStorage());

  final Session? _session;

  @override
  Future<Session?> read() async => _session;

  @override
  Future<void> write(Session session) async {}

  @override
  Future<void> clear() async {}
}
