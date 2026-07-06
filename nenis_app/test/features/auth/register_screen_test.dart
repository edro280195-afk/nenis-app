import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/core/theme/app_theme.dart';
import 'package:nenis_app/features/auth/screens/register_screen.dart';

void main() {
  Widget buildSubject() {
    return ProviderScope(
      child: MaterialApp(theme: AppTheme.light(), home: const RegisterScreen()),
    );
  }

  testWidgets('muestra un error claro cuando faltan nombre y apellido', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.ensureVisible(find.text('Crear cuenta'));
    await tester.tap(find.text('Crear cuenta'));
    await tester.pump();

    expect(find.byKey(const Key('register-error')), findsOneWidget);
    expect(find.text('Escribe tu nombre y tu apellido.'), findsOneWidget);
  });

  testWidgets('valida que el teléfono tenga exactamente 10 dígitos', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('register-first-name-field')),
        matching: find.byType(TextField),
      ),
      'Ana',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('register-last-name-field')),
        matching: find.byType(TextField),
      ),
      'López',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('register-email-field')),
        matching: find.byType(TextField),
      ),
      'ana@example.com',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('register-phone-field')),
        matching: find.byType(TextField),
      ),
      '86812345678',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('register-password-field')),
        matching: find.byType(TextField),
      ),
      'segura-123',
    );
    await tester.ensureVisible(find.text('Crear cuenta'));
    await tester.tap(find.text('Crear cuenta'));
    await tester.pump();

    expect(find.byKey(const Key('register-error')), findsOneWidget);
    expect(find.text('Escribe tu teléfono a 10 dígitos.'), findsOneWidget);
  });
}
