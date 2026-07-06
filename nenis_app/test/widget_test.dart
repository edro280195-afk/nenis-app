import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nenis_app/core/auth/session.dart';
import 'package:nenis_app/core/storage/credential_storage.dart';
import 'package:nenis_app/core/storage/session_storage.dart';
import 'package:nenis_app/main.dart';

void main() {
  testWidgets('NenisApp manda al login cuando no hay sesión guardada', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(_FakeSessionStorage(null)),
          credentialStorageProvider
              .overrideWithValue(_FakeCredentialStorage()),
        ],
        child: const NenisApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Acceso de equipo'), findsOneWidget);
  });
}

class _FakeSessionStorage extends SessionStorage {
  _FakeSessionStorage(this._session) : super(const FlutterSecureStorage());

  final Session? _session;
  Session? written;
  var cleared = false;

  @override
  Future<Session?> read() async => _session;

  @override
  Future<void> write(Session session) async {
    written = session;
  }

  @override
  Future<void> clear() async {
    cleared = true;
  }
}

class _FakeCredentialStorage extends CredentialStorage {
  _FakeCredentialStorage() : super(const FlutterSecureStorage());

  @override
  Future<SavedCredentials?> read() async => null;

  @override
  Future<void> write(SavedCredentials creds) async {}

  @override
  Future<void> clear() async {}
}
