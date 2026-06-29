import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'raffles_models.dart';

class RafflesException implements Exception {
  RafflesException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RafflesRepository {
  RafflesRepository(this._dio);

  final Dio _dio;

  Future<List<BuyerRaffle>> getMyRaffles() async {
    try {
      final res = await _dio.get('/api/me/raffles');
      final list = (res.data as List?) ?? const [];
      return list
          .map((e) => BuyerRaffle.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = (data is Map && data['message'] is String)
          ? data['message'] as String
          : 'No pudimos cargar tus sorteos.';
      throw RafflesException(message);
    } catch (_) {
      throw RafflesException('No pudimos cargar tus sorteos.');
    }
  }
}

final rafflesRepositoryProvider = Provider<RafflesRepository>((ref) {
  return RafflesRepository(ref.read(dioProvider));
});

/// Controller de la pantalla "Sorteos". Mantiene el filtro actual y
/// deriva la lista filtrada en el cliente.
class RafflesController extends AsyncNotifier<List<BuyerRaffle>> {
  RafflesFilter _filter = RafflesFilter.active;

  RafflesFilter get filter => _filter;

  @override
  Future<List<BuyerRaffle>> build() async {
    final repo = ref.read(rafflesRepositoryProvider);
    return repo.getMyRaffles();
  }

  void setFilter(RafflesFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    ref.invalidateSelf();
  }
}

final rafflesControllerProvider =
    AsyncNotifierProvider<RafflesController, List<BuyerRaffle>>(
  RafflesController.new,
);
