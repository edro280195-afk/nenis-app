import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/labels/services/direct_print/bluetooth_retry.dart';

void main() {
  group('withBluetoothRetry', () {
    test('retorna el resultado del primer intento si no falla', () async {
      var attempts = 0;
      final result = await withBluetoothRetry<String>((attempt) async {
        attempts++;
        return 'ok';
      }, delaysBetweenAttempts: const []);

      expect(result, 'ok');
      expect(attempts, 1);
    });

    test('reintenta tras un fallo y se queda con el resultado del intento bueno', () async {
      var attempts = 0;
      final result = await withBluetoothRetry<String>((attempt) async {
        attempts++;
        if (attempts < 3) throw Exception('falla momentánea');
        return 'ok tras reintentos';
      }, delaysBetweenAttempts: const []);

      expect(result, 'ok tras reintentos');
      expect(attempts, 3);
    });

    test('respeta maxAttempts: no reintenta más allá del límite', () async {
      var attempts = 0;
      await expectLater(
        withBluetoothRetry<void>((attempt) async {
          attempts++;
          throw Exception('siempre falla');
        }, maxAttempts: 3, delaysBetweenAttempts: const []),
        throwsA(isA<Exception>()),
      );

      expect(attempts, 3);
    });

    test('propaga el error del último intento, no del primero', () async {
      var attempts = 0;
      await expectLater(
        withBluetoothRetry<void>((attempt) async {
          attempts++;
          throw Exception('intento $attempts');
        }, maxAttempts: 3, delaysBetweenAttempts: const []),
        throwsA(
          predicate((e) => e.toString().contains('intento 3')),
        ),
      );
    });

    test('pasa el número de intento (0-based) a la función', () async {
      final seenAttempts = <int>[];
      await withBluetoothRetry<void>((attempt) async {
        seenAttempts.add(attempt);
        if (attempt < 2) throw Exception('sigue intentando');
      }, delaysBetweenAttempts: const []);

      expect(seenAttempts, [0, 1, 2]);
    });

    test('espera el backoff configurado entre intentos', () async {
      final stopwatch = Stopwatch()..start();
      var attempts = 0;
      await withBluetoothRetry<void>((attempt) async {
        attempts++;
        if (attempts < 2) throw Exception('falla una vez');
      }, delaysBetweenAttempts: const [Duration(milliseconds: 60)]);
      stopwatch.stop();

      expect(attempts, 2);
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(55));
    });
  });
}
