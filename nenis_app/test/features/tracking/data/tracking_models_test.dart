import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/tracking/data/tracking_models.dart';

void main() {
  group('TrackingStatus timelineStep', () {
    test('mapea estados normales al avance esperado', () {
      expect(TrackingStatus.pending.timelineStep, 1);
      expect(TrackingStatus.confirmed.timelineStep, 2);
      expect(TrackingStatus.shipped.timelineStep, 3);
      expect(TrackingStatus.inRoute.timelineStep, 3);
      expect(TrackingStatus.inTransit.timelineStep, 3);
      expect(TrackingStatus.delivered.timelineStep, 4);
    });

    test('mapea estados excepcionales sin dejar el timeline en gris', () {
      expect(TrackingStatus.postponed.timelineStep, 2);
      expect(TrackingStatus.notDelivered.timelineStep, 4);
      expect(TrackingStatus.canceled.timelineStep, 4);
    });

    test('mantiene unknown sin etapa aplicable', () {
      expect(TrackingStatus.unknown.timelineStep, 0);
    });
  });
}
