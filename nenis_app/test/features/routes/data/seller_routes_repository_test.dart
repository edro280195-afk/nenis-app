import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/routes/data/seller_routes_models.dart';
import 'package:nenis_app/features/routes/data/seller_routes_repository.dart';

void main() {
  test(
    'createRoute envía el orden intercalado de la previsualización',
    () async {
      Map<String, dynamic>? requestData;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestData = Map<String, dynamic>.from(options.data as Map);
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'route': {
                    'id': 12,
                    'driverToken': 'abc123',
                    'driverLink': 'https://app.example.com/repartidor/abc123',
                    'status': 'Pending',
                    'createdAt': '2026-07-27T10:00:00Z',
                    'deliveries': <Map<String, dynamic>>[],
                  },
                  'skipped': <Map<String, dynamic>>[],
                },
              ),
            );
          },
        ),
      );
      final repository = SellerRoutesRepository(dio);
      const tandaId = '5f764386-9173-43dd-8cf4-8e20c68efbef';
      final candidates = [
        RouteCandidate.fromOrderJson({
          'id': 10,
          'clientId': 77,
          'clientName': 'Ana',
          'total': 100,
        }),
        RouteCandidate.fromTandaJson({
          'tandaParticipantId': tandaId,
          'clientId': 88,
          'clientName': 'Luisa',
        }),
      ];
      final previewStops = [
        RoutePreviewStop.fromJson({
          'kind': 'Order',
          'orderId': 10,
          'sortOrder': 2,
          'clientName': 'Ana',
          'total': 100,
          'hasCoords': true,
        }),
        RoutePreviewStop.fromJson({
          'kind': 'Tanda',
          'tandaParticipantId': tandaId,
          'sortOrder': 1,
          'clientName': 'Luisa',
          'total': 0,
          'hasCoords': true,
        }),
      ];

      await repository.createRoute(candidates, previewStops);

      expect(requestData?['orderIds'], [10]);
      expect(requestData?['tandaParticipantIds'], [tandaId]);
      expect(requestData?['preOptimized'], isTrue);
      expect(requestData?['orderedStopIds'], ['tanda:$tandaId', 'order:10']);
    },
  );
}
