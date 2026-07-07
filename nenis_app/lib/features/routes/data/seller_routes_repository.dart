import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'seller_routes_models.dart';

class SellerRoutesException implements Exception {
  SellerRoutesException(this.message);
  final String message;

  @override
  String toString() => message;
}

String _friendly(Object e, String fallback) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map) {
      if (data['message'] is String) return data['message'] as String;
      if (data['error'] == 'feature_locked') {
        return 'Tu plan actual no permite crear más rutas activas.';
      }
    }
    if (data is String && data.trim().isNotEmpty) return data;
  }
  return fallback;
}

class SellerRoutesRepository {
  SellerRoutesRepository(this._dio);

  final Dio _dio;

  Future<SellerRoutesWorkspace> getWorkspace() async {
    try {
      final responses = await Future.wait([
        _dio.get('/api/routes'),
        _dio.get('/api/orders'),
        _dio.get('/api/routes/available-tandas'),
      ]);

      final routes = ((responses[0].data as List?) ?? const [])
          .map((e) => SellerRoute.fromJson(e as Map<String, dynamic>))
          .toList();

      final orderCandidates = ((responses[1].data as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
          .where(_isRouteEligibleOrder)
          .map(RouteCandidate.fromOrderJson)
          .toList();

      final tandaCandidates = ((responses[2].data as List?) ?? const [])
          .map((e) => RouteCandidate.fromTandaJson(e as Map<String, dynamic>))
          .toList();

      return SellerRoutesWorkspace(
        routes: routes,
        candidates: [...orderCandidates, ...tandaCandidates],
      );
    } catch (e) {
      throw SellerRoutesException(_friendly(e, 'No pudimos cargar las rutas.'));
    }
  }

  Future<RoutePreview> previewRoute(Iterable<RouteCandidate> candidates) async {
    final orderIds = <int>[];
    final tandaIds = <String>[];
    for (final candidate in candidates) {
      final orderId = candidate.orderId;
      final tandaId = candidate.tandaParticipantId;
      if (orderId != null) orderIds.add(orderId);
      if (tandaId != null) tandaIds.add(tandaId);
    }

    try {
      final res = await _dio.post(
        '/api/routes/preview',
        data: {'orderIds': orderIds, 'tandaParticipantIds': tandaIds},
      );
      return RoutePreview.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw SellerRoutesException(_friendly(e, 'No pudimos calcular la ruta.'));
    }
  }

  Future<SellerRoute> createRoute(Iterable<RouteCandidate> candidates) async {
    final orderIds = <int>[];
    final tandaIds = <String>[];
    for (final candidate in candidates) {
      final orderId = candidate.orderId;
      final tandaId = candidate.tandaParticipantId;
      if (orderId != null) orderIds.add(orderId);
      if (tandaId != null) tandaIds.add(tandaId);
    }

    try {
      final res = await _dio.post(
        '/api/routes',
        data: {
          'orderIds': orderIds,
          'tandaParticipantIds': tandaIds,
          'preOptimized': false,
        },
      );
      final data = res.data as Map<String, dynamic>;
      return SellerRoute.fromJson(data['route'] as Map<String, dynamic>);
    } catch (e) {
      throw SellerRoutesException(_friendly(e, 'No pudimos crear la ruta.'));
    }
  }

  Future<void> optimizeRoute(int routeId) async {
    try {
      await _dio.post('/api/routes/$routeId/optimize');
    } catch (e) {
      throw SellerRoutesException(
        _friendly(e, 'No pudimos optimizar la ruta.'),
      );
    }
  }

  Future<void> reorderRoute(int routeId, List<int> deliveryIdsInOrder) async {
    try {
      await _dio.put('/api/routes/$routeId/reorder', data: deliveryIdsInOrder);
    } catch (e) {
      throw SellerRoutesException(_friendly(e, 'No pudimos guardar el orden.'));
    }
  }

  Future<void> deleteRoute(int routeId) async {
    try {
      await _dio.delete('/api/routes/$routeId');
    } catch (e) {
      throw SellerRoutesException(_friendly(e, 'No pudimos eliminar la ruta.'));
    }
  }

  bool _isRouteEligibleOrder(Map<String, dynamic> order) {
    final status = (order['status'] ?? '').toString().toLowerCase();
    final orderType = (order['orderType'] ?? '').toString().toLowerCase();
    final routeId = order['deliveryRouteId'];
    return status != 'canceled' &&
        status != 'delivered' &&
        orderType != 'pickup' &&
        routeId == null;
  }
}

final sellerRoutesRepositoryProvider = Provider<SellerRoutesRepository>((ref) {
  return SellerRoutesRepository(ref.read(dioProvider));
});

final sellerRoutesWorkspaceProvider =
    FutureProvider.autoDispose<SellerRoutesWorkspace>((ref) {
      return ref.read(sellerRoutesRepositoryProvider).getWorkspace();
    });
