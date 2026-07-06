import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/core/theme/app_theme.dart';
import 'package:nenis_app/features/auth/screens/login_screen.dart';

void main() {
  Widget buildSubject() {
    return ProviderScope(
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
}
