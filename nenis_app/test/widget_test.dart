import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nenis_app/main.dart';

void main() {
  testWidgets('NenisApp boots into splash', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: NenisApp()));
    await tester.pumpAndSettle();

    expect(find.text("Neni's"), findsOneWidget);
    expect(find.text('Compradora'), findsOneWidget);
    expect(find.text('Ver style gallery'), findsOneWidget);
  });
}
