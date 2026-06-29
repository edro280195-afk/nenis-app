import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'claim_models.dart';

class ClaimRepository {
  ClaimRepository(this._dio);

  final Dio _dio;

  /// Fan-out por teléfono: tiendas con un Client del mismo teléfono que aún
  /// no se ha reclamado.
  Future<List<ClaimCandidate>> candidates() async {
    final res = await _dio.get('/api/client-claims/candidates');
    final list = (res.data as List).cast<Map<String, dynamic>>();
    return list.map(ClaimCandidate.fromJson).toList();
  }

  /// Reclama un Client específico (la prueba es el teléfono ya verificado).
  Future<void> claimByPhone(int clientId) async {
    await _dio.post('/api/client-claims/by-phone/$clientId');
  }
}

final claimRepositoryProvider = Provider<ClaimRepository>((ref) {
  return ClaimRepository(ref.read(dioProvider));
});

final claimCandidatesProvider =
    FutureProvider.autoDispose<List<ClaimCandidate>>((ref) async {
  return ref.read(claimRepositoryProvider).candidates();
});
