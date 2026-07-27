import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/core/auth/auth_repository.dart';
import 'package:nenis_app/core/auth/session.dart';
import 'package:nenis_app/core/storage/session_storage.dart';
import 'package:nenis_app/core/theme/app_theme.dart';
import 'package:nenis_app/features/auth/screens/login_screen.dart';

void main() {
  Widget buildSubject({
    AuthRepository? repository,
    SessionStorage? sessionStorage,
  }) {
    return ProviderScope(
      overrides: [
        if (repository != null)
          authRepositoryProvider.overrideWithValue(repository),
        if (sessionStorage != null)
          sessionStorageProvider.overrideWithValue(sessionStorage),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const LoginScreen()),
    );
  }

  testWidgets('muestra el acceso de clienta como opción inicial', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-role-client')), findsOneWidget);
    expect(find.byKey(const Key('client-phone-field')), findsOneWidget);
    expect(find.text('Entrar a mis compras'), findsOneWidget);
    expect(find.text('Continuar con Facebook'), findsOneWidget);
    expect(find.byKey(const Key('forgot-password-client')), findsOneWidget);
    expect(find.text('Acceso de equipo'), findsNothing);
  });

  testWidgets('cambia al formulario propio de vendedora', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.byKey(const Key('login-role-seller')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('seller-email-field')), findsOneWidget);
    expect(find.text('Tu espacio de ventas'), findsOneWidget);
    expect(find.text('Entrar a mi tienda'), findsOneWidget);
    expect(find.byKey(const Key('seller-register-link')), findsOneWidget);
    expect(find.byKey(const Key('client-phone-field')), findsNothing);
    expect(find.text('Continuar con Facebook'), findsOneWidget);
    expect(find.byKey(const Key('forgot-password-seller')), findsOneWidget);
  });

  testWidgets('muestra un error claro cuando faltan las credenciales', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.ensureVisible(find.text('Entrar a mis compras'));
    await tester.tap(find.text('Entrar a mis compras'));
    await tester.pump();

    expect(find.byKey(const Key('login-error')), findsOneWidget);
    expect(find.text('Escribe tu teléfono a 10 dígitos.'), findsOneWidget);
  });

  testWidgets('permanece desplazable en una pantalla compacta', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.byType(Scrollable), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un conflicto terminal de Facebook ofrece una salida clara', (
    WidgetTester tester,
  ) async {
    final repository = _TerminalFacebookRepository();
    await tester.pumpWidget(
      buildSubject(
        repository: repository,
        sessionStorage: _FakeSessionStorage(),
      ),
    );

    await tester.ensureVisible(find.text('Continuar con Facebook'));
    await tester.tap(find.text('Continuar con Facebook'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Completa tu cuenta'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('facebook-legal-checkbox')),
    );
    await tester.tap(find.byKey(const Key('facebook-legal-checkbox')));
    await tester.ensureVisible(find.text('Guardar y continuar'));
    await tester.tap(find.text('Guardar y continuar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('facebook-terminal-conflict')), findsOneWidget);
    expect(find.text('No pudimos vincular las cuentas'), findsOneWidget);
    expect(
      find.text('Los datos pertenecen a cuentas distintas.'),
      findsOneWidget,
    );
    expect(repository.loggedOut, isTrue);

    await tester.tap(find.byKey(const Key('facebook-terminal-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('facebook-terminal-conflict')), findsNothing);
    expect(find.text('Entrar a mis compras'), findsOneWidget);
  });
}

class _TerminalFacebookRepository extends AuthRepository {
  _TerminalFacebookRepository()
    : super(Dio(BaseOptions(baseUrl: 'https://api.example.com')));

  bool loggedOut = false;

  @override
  Future<FacebookAccessCredential> facebookAccessToken() async {
    return const FacebookAccessCredential(
      token: 'facebook-token',
      type: FacebookTokenType.classic,
    );
  }

  @override
  Future<Session> facebookLogin(
    FacebookAccessCredential credential, {
    required FacebookAccountType accountType,
  }) async {
    throw FacebookProfileRequiredException(
      message: 'Completa tus datos.',
      accountType: FacebookAccountType.client,
      requiresExistingPassword: false,
      firstName: 'Ana',
      lastName: 'López',
      email: 'ana@example.com',
      phone: '8681234567',
      missingFields: const [],
    );
  }

  @override
  Future<Session> completeFacebookProfile(
    FacebookAccessCredential credential,
    FacebookProfileCompletion profile,
  ) async {
    throw FacebookTerminalConflictException(
      'Los datos pertenecen a cuentas distintas.',
      type: FacebookTerminalConflictType.identityConflict,
    );
  }

  @override
  Future<void> facebookLogout() async {
    loggedOut = true;
  }
}

class _FakeSessionStorage extends SessionStorage {
  _FakeSessionStorage() : super(const FlutterSecureStorage());

  @override
  Future<Session?> read() async => null;

  @override
  Future<void> write(Session session) async {}

  @override
  Future<void> clear() async {}
}
