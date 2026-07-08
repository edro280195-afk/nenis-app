import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import '../../account/data/seller_settings_repository.dart';
import 'subscription_models.dart';

class SubscriptionException implements Exception {
  SubscriptionException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SubscriptionRepository {
  SubscriptionRepository(this._dio);

  final Dio _dio;

  Future<SubscriptionAccountState> getStatus() async {
    try {
      final res = await _dio.get('/api/business/subscription/status');
      return SubscriptionAccountState.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw SubscriptionException(_message(e, 'No pudimos cargar tu plan.'));
    }
  }

  Future<SubscriptionPricing> getPricing() async {
    try {
      final res = await _dio.get('/api/business/subscription/pricing');
      return SubscriptionPricing.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw SubscriptionException(_message(e, 'No pudimos cargar los precios.'));
    }
  }

  /// Ajusta el plan/periodicidad de una suscripción YA activa (sin pasar
  /// por el checkout de tarjeta) — upgrade inmediato o downgrade programado.
  Future<void> updatePlan({
    required String planTier,
    required String periodicity,
  }) async {
    try {
      await _dio.put(
        '/api/business/subscription/preapproval',
        data: {'planTier': planTier, 'periodicity': periodicity},
      );
    } on DioException catch (e) {
      throw SubscriptionException(_message(e, 'No pudimos cambiar tu plan.'));
    }
  }

  Future<void> cancel() async {
    try {
      await _dio.delete('/api/business/subscription/preapproval');
    } on DioException catch (e) {
      throw SubscriptionException(
        _message(e, 'No pudimos cancelar tu suscripción.'),
      );
    }
  }

  String _message(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      final message = (data['message'] as String).trim();
      if (message.isNotEmpty) return message;
    }
    return fallback;
  }
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ref.read(dioProvider));
});

final subscriptionStatusProvider =
    FutureProvider.autoDispose<SubscriptionAccountState>((ref) {
  return ref.read(subscriptionRepositoryProvider).getStatus();
});

final subscriptionPricingProvider =
    FutureProvider.autoDispose<SubscriptionPricing>((ref) {
  return ref.read(subscriptionRepositoryProvider).getPricing();
});

/// Refresca todo lo que depende del estado de la suscripción (usado tras
/// cambiar de plan/cancelar, y por el interceptor 402 de `dio_provider.dart`).
/// `Ref`/`WidgetRef` no comparten un supertipo público en Riverpod 3, así
/// que hay una variante de cada una — ambas hacen exactamente lo mismo.
void invalidateSubscriptionState(Ref ref) {
  ref.invalidate(subscriptionStatusProvider);
  ref.invalidate(sellerBusinessSettingsProvider);
}

void invalidateSubscriptionStateFromWidget(WidgetRef ref) {
  ref.invalidate(subscriptionStatusProvider);
  ref.invalidate(sellerBusinessSettingsProvider);
}
