import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/devices/data/device_repository.dart';

void main() {
  test('parsea el diagnóstico del backend', () {
    final r = DevicePushTest.fromJson({
      'firebaseConfigured': true,
      'projectId': 'nenisapp-60810',
      'tokensRegistered': 2,
      'sent': 1,
      'failed': 1,
      'errors': ['SenderIdMismatch'],
    });
    expect(r.firebaseConfigured, isTrue);
    expect(r.projectId, 'nenisapp-60810');
    expect(r.tokensRegistered, 2);
    expect(r.sent, 1);
    expect(r.failed, 1);
    expect(r.errors, ['SenderIdMismatch']);
  });

  test('tolera respuestas incompletas sin lanzar', () {
    final r = DevicePushTest.fromJson({});
    expect(r.firebaseConfigured, isFalse);
    expect(r.projectId, isNull);
    expect(r.tokensRegistered, 0);
    expect(r.sent, 0);
    expect(r.errors, isEmpty);
  });
}
