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
}
