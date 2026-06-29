import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'account_models.dart';

class AccountException implements Exception {
  AccountException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AccountRepository {
  AccountRepository(this._dio);

  final Dio _dio;

  Future<List<ClaimedClientSummary>> getMyClaimedClients() async {
    try {
      final res = await _dio.get('/api/client-claims/mine');
      final list = (res.data as List?) ?? const [];
      return list
          .map((e) => ClaimedClientSummary.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = (data is Map && data['message'] is String)
          ? data['message'] as String
          : 'No pudimos cargar tu cuenta.';
      throw AccountException(message);
    } catch (_) {
      throw AccountException('No pudimos cargar tu cuenta.');
    }
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.read(dioProvider));
});

/// Lista de tiendas que la compradora tiene reclamadas. Vacía si todavía
/// no ha vinculado ninguna.
final myClaimedClientsProvider =
    FutureProvider.autoDispose<List<ClaimedClientSummary>>((ref) {
  return ref.read(accountRepositoryProvider).getMyClaimedClients();
});
