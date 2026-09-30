import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/core/theme/app_theme.dart';
import 'package:nenis_app/features/auth/screens/login_otp_screen.dart';
import 'package:nenis_app/features/auth/widgets/auth_otp_notices.dart';

void main() {
  Widget buildSubject({double textScale = 1.0}) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(textScale),
            ),
            child: const LoginOtpScreen(),
          ),
        ),
      ),
    );
  }

  testWidgets('explica qué es el código y la verificación del navegador', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('otp-explainer')), findsOneWidget);
    expect(find.text('¿Qué es el código?'), findsOneWidget);
    expect(find.text('Verificación de seguridad'), findsOneWidget);
    // El aviso del navegador tiene que estar ANTES de pedir el SMS.
    expect(find.textContaining('se abre tu navegador'), findsOneWidget);
    expect(find.textContaining('No la compartas'), findsOneWidget);
  });

  testWidgets('pide un teléfono de 10 dígitos antes de enviar', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-otp-phone-field')),
      '8681',
    );
    await tester.ensureVisible(find.byKey(const Key('login-otp-send')));
    await tester.tap(find.byKey(const Key('login-otp-send')));
    await tester.pump();

    expect(find.byKey(const Key('login-otp-error')), findsOneWidget);
    expect(find.text('Escribe tu teléfono a 10 dígitos.'), findsOneWidget);
  });

  testWidgets('exige aceptar los términos aunque el teléfono sea válido', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-otp-phone-field')),
      '8681452290',
    );
    await tester.ensureVisible(find.byKey(const Key('login-otp-send')));
    await tester.tap(find.byKey(const Key('login-otp-send')));
    await tester.pump();

    expect(
      find.text('Acepta los Términos y el Aviso de privacidad para continuar.'),
      findsOneWidget,
    );
  });

  testWidgets('ofrece el camino de vendedora sin salir del acceso', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-otp-sell')), findsOneWidget);
  });

  testWidgets('no desborda en pantalla chica con letra al 150 %', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSubject(textScale: 1.5));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('OtpExplainer', () {
    Widget wrap(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

    testWidgets('versión compacta solo recuerda no compartir el código', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const OtpExplainer(compact: true)));

      expect(find.textContaining('No compartas este código'), findsOneWidget);
      expect(find.text('¿Qué es el código?'), findsNothing);
    });

    testWidgets('BrowserCheckHint indica qué hacer si se abre el navegador', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const BrowserCheckHint()));

      expect(find.textContaining('Si se abre tu navegador'), findsOneWidget);
      expect(find.textContaining('regresa a Neni'), findsOneWidget);
    });
  });
}
