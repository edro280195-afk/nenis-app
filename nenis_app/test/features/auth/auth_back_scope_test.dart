import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nenis_app/core/theme/app_theme.dart';
import 'package:nenis_app/features/auth/screens/login_otp_screen.dart';
import 'package:nenis_app/features/auth/widgets/auth_back_scope.dart';

/// El atrás del sistema, en una pantalla abierta con `go` (sin nada debajo en
/// la pila), cerraba la app. Estas pruebas simulan ese botón con
/// `handlePopRoute` y comprueban que regresa a la bienvenida.
void main() {
  Widget app(GoRouter router) => ProviderScope(
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );

  GoRouter routerWith(String initial, Widget screen, {String? at}) => GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(body: Text('bienvenida')),
      ),
      GoRoute(path: at ?? initial, builder: (context, state) => screen),
    ],
  );

  testWidgets('el atrás del sistema regresa a la bienvenida', (tester) async {
    final router = routerWith(
      '/register',
      const AuthBackScope(child: Scaffold(body: Text('registro'))),
    );
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();
    expect(find.text('registro'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('bienvenida'), findsOneWidget);
    expect(find.text('registro'), findsNothing);
  });

  testWidgets('con enabled:false el atrás no hace nada (formulario enviando)', (
    tester,
  ) async {
    final router = routerWith(
      '/register',
      const AuthBackScope(
        enabled: false,
        child: Scaffold(body: Text('registro')),
      ),
    );
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('registro'), findsOneWidget);
  });

  testWidgets('onBack propio tiene prioridad sobre el destino', (tester) async {
    var calls = 0;
    final router = routerWith(
      '/forgot-password',
      AuthBackScope(
        onBack: () => calls++,
        child: const Scaffold(body: Text('recuperar')),
      ),
    );
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('recuperar'), findsOneWidget);
  });

  testWidgets('el acceso por SMS también regresa a la bienvenida', (
    tester,
  ) async {
    final router = routerWith('/login-otp', const LoginOtpScreen());
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();
    expect(find.text('Entra con tu teléfono'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('bienvenida'), findsOneWidget);
  });
}
