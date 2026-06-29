import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'points_models.dart';

class PointsException implements Exception {
  PointsException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PointsRepository {
  PointsRepository(this._dio);

  final Dio _dio;

  Future<List<RewardsByBusiness>> getRewards() async {
    try {
      final res = await _dio.get('/api/me/rewards');
      final list = (res.data as List?) ?? const [];
      return list
          .map((e) => RewardsByBusiness.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = (data is Map && data['message'] is String)
          ? data['message'] as String
          : 'No pudimos cargar tus puntos.';
      throw PointsException(message);
    } catch (_) {
      throw PointsException('No pudimos cargar tus puntos.');
    }
  }
}

final pointsRepositoryProvider = Provider<PointsRepository>((ref) {
  return PointsRepository(ref.read(dioProvider));
});

/// Catálogo de recompensas por tienda. Devuelve una lista (vacía si la
/// compradora no tiene ninguna tienda reclamada).
final pointsFeedProvider =
    FutureProvider.autoDispose<List<RewardsByBusiness>>((ref) {
  return ref.read(pointsRepositoryProvider).getRewards();
});
