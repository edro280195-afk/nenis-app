import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/core/theme/app_theme.dart';
import 'package:nenis_app/shared/widgets/otp_cell.dart';

void main() {
  testWidgets('adapta las seis celdas a una pantalla compacta', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: OtpInput(length: 6, onCompleted: (_) {}),
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsNWidgets(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('avanza al siguiente dígito después de cada captura', (
    WidgetTester tester,
  ) async {
    String? completedCode;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: OtpInput(
            length: 6,
            onCompleted: (code) => completedCode = code,
          ),
        ),
      ),
    );

    final fields = find.byType(TextField);
    await tester.tap(fields.at(0));
    await tester.enterText(fields.at(0), '1');
    await tester.pump();

    expect(tester.widget<TextField>(fields.at(1)).focusNode!.hasFocus, isTrue);

    for (var i = 1; i < 6; i++) {
      await tester.enterText(fields.at(i), '${i + 1}');
    }
    await tester.pump();

    expect(completedCode, '123456');
  });
}
