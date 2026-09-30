import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/core/utils/text_scale.dart';

Future<double> _ratioAt(WidgetTester tester, double textScale) async {
  late double result;
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Builder(
          builder: (context) {
            result = scaledAspectRatio(context, 1.5);
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return result;
}

void main() {
  testWidgets('a escala normal no cambia la proporción', (tester) async {
    expect(await _ratioAt(tester, 1.0), 1.5);
  });

  testWidgets('con letra grande la tarjeta crece en alto', (tester) async {
    expect(await _ratioAt(tester, 1.5), closeTo(1.0, 0.001));
  });

  testWidgets('letra menor a 1.0 no encoge la tarjeta', (tester) async {
    expect(await _ratioAt(tester, 0.8), 1.5);
  });

  testWidgets('la escala se limita a 2.0', (tester) async {
    expect(await _ratioAt(tester, 3.0), closeTo(0.75, 0.001));
  });
}
