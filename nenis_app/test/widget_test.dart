import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nenis_app/core/auth/session.dart';
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
        ],
        child: const NenisApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Compra bonito.\nCompra local.'), findsOneWidget);
    expect(find.text('Entrar con mi teléfono'), findsOneWidget);
    expect(find.text('Crear mi cuenta'), findsOneWidget);
    expect(find.text("NENI'S"), findsOneWidget);
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
