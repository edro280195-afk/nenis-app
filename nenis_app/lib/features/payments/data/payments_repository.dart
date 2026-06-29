import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'payments_models.dart';

class PaymentsException implements Exception {
  PaymentsException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PaymentsRepository {
  PaymentsRepository(this._dio);

  final Dio _dio;

  Future<List<BuyerPayment>> getMyPayments() async {
    try {
      final res = await _dio.get('/api/me/payments');
      final list = (res.data as List?) ?? const [];
      return list
          .map((e) => BuyerPayment.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (_) {
      throw PaymentsException('No pudimos cargar tus pagos.');
    } catch (_) {
      throw PaymentsException('No pudimos cargar tus pagos.');
    }
  }
}

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  return PaymentsRepository(ref.read(dioProvider));
});

/// Controller de la pantalla "Mis pagos". Solo lectura; se hidrata con
/// `FutureProvider.autoDispose` ya que no hay filtros ni paginación.
final paymentsFeedProvider =
    FutureProvider.autoDispose<List<BuyerPayment>>((ref) {
  return ref.read(paymentsRepositoryProvider).getMyPayments();
});
