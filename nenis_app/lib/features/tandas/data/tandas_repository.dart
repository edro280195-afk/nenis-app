import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'tandas_models.dart';

class TandasException implements Exception {
  TandasException(this.message);
  final String message;
  @override
  String toString() => message;
}

class TandasRepository {
  TandasRepository(this._dio);

  final Dio _dio;

  Future<List<BuyerTanda>> getMyTandas() async {
    try {
      final res = await _dio.get('/api/me/tandas');
      final list = (res.data as List?) ?? const [];
      return list
          .map((e) => BuyerTanda.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = (data is Map && data['message'] is String)
          ? data['message'] as String
          : 'No pudimos cargar tus tandas.';
      throw TandasException(message);
    } catch (_) {
      throw TandasException('No pudimos cargar tus tandas.');
    }
  }
}

final tandasRepositoryProvider = Provider<TandasRepository>((ref) {
  return TandasRepository(ref.read(dioProvider));
});

/// Controller de la pantalla "Tandas". Mantiene el filtro actual (mine vs
/// available) y deriva la lista filtrada en el cliente.
class TandasController extends AsyncNotifier<List<BuyerTanda>> {
  TandasFilter _filter = TandasFilter.mine;

  TandasFilter get filter => _filter;

  @override
  Future<List<BuyerTanda>> build() async {
    final repo = ref.read(tandasRepositoryProvider);
    return repo.getMyTandas();
  }

  void setFilter(TandasFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    // No necesitamos refetch: la lista ya está cacheada en `state`. Solo
    // forzamos un rebuild de quien escucha `filter`.
    ref.invalidateSelf();
  }
}

final tandasControllerProvider =
    AsyncNotifierProvider<TandasController, List<BuyerTanda>>(
  TandasController.new,
);
