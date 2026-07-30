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

  /// Camino principal del deep link: la posesión del `accessToken` (que la
  /// vendedora mandó por WhatsApp) es la prueba. Enlaza el `Client` del pedido
  /// con la cuenta autenticada. Requiere sesión (el interceptor inyecta el JWT).
  ///
  /// Nunca lanza: mapea los códigos del backend a un [ClaimByTokenResult] para
  /// que el llamador decida (los 4xx son definitivos; los de red son
  /// transitorios y conviene reintentar).
  Future<ClaimByTokenResult> claimByOrderToken(String accessToken) async {
    try {
      final res =
          await _dio.post('/api/client-claims/by-order-token/$accessToken');
      final data = (res.data as Map).cast<String, dynamic>();
      return ClaimByTokenResult(
        status: ClaimByTokenStatus.linked,
        businessName: data['businessName'] as String?,
        clientName: data['clientName'] as String?,
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      final map = data is Map ? data.cast<String, dynamic>() : null;
      final message = map?['message'] as String?;
      switch (e.response?.statusCode) {
        case 409:
          return ClaimByTokenResult(
              status: ClaimByTokenStatus.alreadyClaimedByOther,
              message: message);
        case 404:
          return ClaimByTokenResult(
              status: ClaimByTokenStatus.notFound, message: message);
        case 403:
          return ClaimByTokenResult(
              status: map?['error'] == 'no_proof'
                  ? ClaimByTokenStatus.noProof
                  : ClaimByTokenStatus.forbidden,
              message: message);
        default:
          return ClaimByTokenResult(
              status: ClaimByTokenStatus.error, message: message);
      }
    } catch (_) {
      return const ClaimByTokenResult(status: ClaimByTokenStatus.error);
    }
  }
}

final claimRepositoryProvider = Provider<ClaimRepository>((ref) {
  return ClaimRepository(ref.read(dioProvider));
});

final claimCandidatesProvider =
    FutureProvider.autoDispose<List<ClaimCandidate>>((ref) async {
  return ref.read(claimRepositoryProvider).candidates();
});
