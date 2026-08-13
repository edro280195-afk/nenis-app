import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/labels/services/print_failure_reason.dart';

void main() {
  group('printFailureReason', () {
    test('antepone el código al mensaje separados por dos puntos', () {
      expect(
        printFailureReason('connect_timeout', 'La NIIMBOT B1 no respondió.'),
        'connect_timeout: La NIIMBOT B1 no respondió.',
      );
    });
  });

  group('unknownPrintFailureReason', () {
    test('incluye el tipo y el texto de la excepción bajo el código unknown', () {
      final reason = unknownPrintFailureReason(StateError('algo raro pasó'));
      expect(reason, startsWith('unknown: StateError'));
      expect(reason, contains('algo raro pasó'));
    });

    test('trunca detalles muy largos para no exceder el límite razonable', () {
      final longMessage = 'x' * 1000;
      final reason = unknownPrintFailureReason(Exception(longMessage));

      // 'unknown: ' (9) + hasta 500 caracteres truncados + '…'
      expect(reason.length, lessThan(520));
      expect(reason, endsWith('…'));
    });
  });
}
