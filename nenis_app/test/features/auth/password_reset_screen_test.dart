import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/core/auth/auth_repository.dart';
import 'package:nenis_app/core/theme/app_theme.dart';
import 'package:nenis_app/features/auth/screens/password_reset_screen.dart';

void main() {
  Widget buildSubject({AuthRepository? repository}) {
    return ProviderScope(
      overrides: [
        if (repository != null)
          authRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const PasswordResetScreen(),
      ),
    );
  }

  testWidgets('valida el teléfono antes de llamar al API', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.byKey(const Key('request-reset-code-button')));
    await tester.pump();

    expect(find.byKey(const Key('password-reset-error')), findsOneWidget);
    expect(find.text('Escribe tu teléfono a 10 dígitos.'), findsOneWidget);
  });

  testWidgets('avanza a la captura de código con la respuesta del API', (
    WidgetTester tester,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 202,
              data: {
                'message': 'Si la cuenta existe, enviaremos un código.',
                'devMode': false,
                'providerConfigured': true,
              },
            ),
          );
        },
      ),
    );

    await tester.pumpWidget(buildSubject(repository: AuthRepository(dio)));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('reset-phone-field')),
        matching: find.byType(TextField),
      ),
      '8681234567',
    );
    await tester.tap(find.byKey(const Key('request-reset-code-button')));
    await tester.pumpAndSettle();

    expect(find.text('Revisa tu WhatsApp'), findsOneWidget);
    expect(
      find.text('Si la cuenta existe, enviaremos un código.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('confirm-password-reset-button')),
      findsOneWidget,
    );
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
