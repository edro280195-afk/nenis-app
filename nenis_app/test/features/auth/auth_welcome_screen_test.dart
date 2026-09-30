import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nenis_app/core/theme/app_theme.dart';
import 'package:nenis_app/features/auth/screens/auth_welcome_screen.dart';

void main() {
  /// Devuelve la ruta a la que navegó la bienvenida (con query incluida).
  Widget buildSubject(ValueNotifier<String?> visited) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const AuthWelcomeScreen(),
        ),
        GoRoute(
          path: '/login-otp',
          builder: (context, state) {
            visited.value = state.uri.toString();
            return const Scaffold(body: Text('otp'));
          },
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) {
            visited.value = state.uri.toString();
            return const Scaffold(body: Text('registro'));
          },
        ),
        GoRoute(
          path: '/login-password',
          builder: (context, state) {
            visited.value = state.uri.toString();
            return const Scaffold(body: Text('contraseña'));
          },
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
    );
  }

  testWidgets('muestra entrar con teléfono y los dos caminos de igual peso', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(ValueNotifier(null)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('welcome-phone-login')), findsOneWidget);
    expect(find.text('Soy clienta'), findsOneWidget);
    expect(find.text('Vendo en Neni\'s'), findsOneWidget);
    expect(find.text('¿Primera vez en Neni\'s?'), findsOneWidget);
  });

  testWidgets('"Soy clienta" lleva al registro de clienta', (tester) async {
    final visited = ValueNotifier<String?>(null);
    await tester.pumpWidget(buildSubject(visited));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('welcome-create-client')));
    await tester.tap(find.byKey(const Key('welcome-create-client')));
    await tester.pumpAndSettle();

    expect(visited.value, '/register');
  });

  testWidgets('"Vendo en Neni\'s" lleva al registro con rol de vendedora', (
    tester,
  ) async {
    final visited = ValueNotifier<String?>(null);
    await tester.pumpWidget(buildSubject(visited));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('welcome-create-seller')));
    await tester.tap(find.byKey(const Key('welcome-create-seller')));
    await tester.pumpAndSettle();

    expect(visited.value, '/register?role=seller');
  });

  testWidgets('entrar con teléfono y con contraseña navegan a su pantalla', (
    tester,
  ) async {
    final visited = ValueNotifier<String?>(null);
    await tester.pumpWidget(buildSubject(visited));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('welcome-phone-login')));
    await tester.pumpAndSettle();
    expect(visited.value, '/login-otp');
  });

  testWidgets('no desborda en pantalla chica con letra al 150 %', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280); // ~360 dp a 2x
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const AuthWelcomeScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: const TextScaler.linear(1.5),
          ),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('welcome-phone-login')), findsOneWidget);
  });
}
