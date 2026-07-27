import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/core/auth/auth_repository.dart';
import 'package:nenis_app/core/theme/app_theme.dart';
import 'package:nenis_app/features/auth/screens/password_reset_screen.dart';
import 'package:nenis_app/shared/widgets/pill_button.dart';

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

    // En el Paso 2, esperamos ver el mensaje de confirmación y el título.
    expect(find.text('Revisa tu WhatsApp'), findsOneWidget);

    // Ingresar código OTP de 6 dígitos para avanzar al Paso 3
    final otpFields = find.byType(TextField);
    for (int i = 0; i < 6; i++) {
      await tester.enterText(otpFields.at(i), '0');
      await tester.pump();
    }
    await tester.pumpAndSettle();

    // En el Paso 3, debemos ver la sección de Nueva contraseña y el botón de confirmar
    expect(find.text('Nueva contraseña'), findsOneWidget);
    expect(
      find.byKey(const Key('confirm-password-reset-button')),
      findsOneWidget,
    );
  });

  testWidgets('limpia el error anterior al capturar un nuevo código correcto', (
    WidgetTester tester,
  ) async {
    var confirmCalls = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.endsWith('/request')) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 202,
                data: {
                  'message': 'Código solicitado.',
                  'devMode': false,
                  'providerConfigured': true,
                },
              ),
            );
            return;
          }

          confirmCalls++;
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 401,
                data: {
                  'error': 'invalid_code',
                  'message': 'La verificación fue rechazada.',
                },
              ),
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
    await _enterOtp(tester, '111111');

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('reset-new-password-field')),
        matching: find.byType(TextField),
      ),
      'nueva-segura-123',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('reset-confirm-password-field')),
        matching: find.byType(TextField),
      ),
      'nueva-segura-123',
    );
    await tester.pump();
    final confirmButton = tester.widget<PillButton>(
      find.descendant(
        of: find.byKey(const Key('confirm-password-reset-button')),
        matching: find.byType(PillButton),
      ),
    );
    expect(confirmButton.onPressed, isNotNull);
    confirmButton.onPressed!();
    await tester.pumpAndSettle();

    expect(confirmCalls, 1);
    expect(find.text('Revisa tu WhatsApp'), findsOneWidget);
    expect(find.text('La verificación fue rechazada.'), findsOneWidget);

    await _enterOtp(tester, '222222');

    expect(find.text('Nueva contraseña'), findsOneWidget);
    expect(find.text('La verificación fue rechazada.'), findsNothing);
    expect(find.byKey(const Key('password-reset-error')), findsNothing);
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

Future<void> _enterOtp(WidgetTester tester, String code) async {
  final otpFields = find.byType(TextField);
  expect(otpFields, findsNWidgets(6));
  for (var index = 0; index < code.length; index++) {
    await tester.enterText(otpFields.at(index), code[index]);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
