import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'reserve_models.dart';

class ReserveException implements Exception {
  ReserveException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ReserveRepository {
  ReserveRepository(this._dio);

  final Dio _dio;

  Future<ReserveResult> reserve(ReserveRequest request) async {
    try {
      final res = await _dio.post(
        '/api/me/reserve',
        data: request.toJson(),
      );
      return ReserveResult.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      final message = (data is Map && data['message'] is String)
          ? data['message'] as String
          : (status == 404
              ? 'No pudimos encontrar este producto.'
              : status == 400
                  ? 'No se pudo apartar este producto.'
                  : 'No pudimos apartar este producto.');
      throw ReserveException(message);
    } catch (_) {
      throw ReserveException('No pudimos apartar este producto.');
    }
  }
}

final reserveRepositoryProvider = Provider<ReserveRepository>((ref) {
  return ReserveRepository(ref.read(dioProvider));
});
