import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'follow_models.dart';
import 'store_repository.dart';

class FollowException implements Exception {
  FollowException(this.message);
  final String message;
  @override
  String toString() => message;
}

class FollowRepository {
  FollowRepository(this._dio);

  final Dio _dio;

  Future<FollowState> getState(int businessId) async {
    try {
      final res = await _dio.get('/api/me/follow/$businessId');
      return FollowState.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      throw FollowException('No pudimos revisar si sigues esta tienda.');
    }
  }

  Future<FollowState> follow(int businessId) async {
    try {
      final res = await _dio.post('/api/me/follow/$businessId');
      return FollowState.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw FollowException(_message(e, 'No pudimos seguir esta tienda.'));
    } catch (_) {
      throw FollowException('No pudimos seguir esta tienda.');
    }
  }

  Future<void> unfollow(int businessId) async {
    try {
      await _dio.delete('/api/me/follow/$businessId');
    } on DioException catch (e) {
      throw FollowException(_message(e, 'No pudimos dejar de seguir esta tienda.'));
    } catch (_) {
      throw FollowException('No pudimos dejar de seguir esta tienda.');
    }
  }

  String _message(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return fallback;
  }
}

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return FollowRepository(ref.read(dioProvider));
});

/// Acción de seguir/dejar de seguir la tienda actualmente abierta
/// (`storeBusinessIdProvider`). No duplica el estado de `BuyerStoreDetail`:
/// muta directamente `storeControllerProvider` de forma optimista (para que
/// el botón y el contador reaccionen al instante) y hace rollback si el
/// backend falla. El `bool` que expone es "hay una acción en curso" (para
/// deshabilitar el botón mientras se resuelve).
class FollowController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> toggle() async {
    final businessId = ref.read(storeBusinessIdProvider);
    if (businessId == null || state) return;

    final storeNotifier = ref.read(storeControllerProvider.notifier);
    final current = ref.read(storeControllerProvider).value;
    if (current == null || current.businessId != businessId) return;

    final wasFollowing = current.isFollowing;

    state = true;
    storeNotifier.applyLocalUpdate((c) => c.copyWith(
          isFollowing: !wasFollowing,
          followerCount: c.followerCount + (wasFollowing ? -1 : 1),
          isVip: wasFollowing ? false : c.isVip,
        ));
    try {
      final repo = ref.read(followRepositoryProvider);
      if (wasFollowing) {
        await repo.unfollow(businessId);
      } else {
        await repo.follow(businessId);
      }
    } catch (_) {
      // Rollback: vuelve al estado previo si el backend falla.
      storeNotifier.applyLocalUpdate((_) => current);
      rethrow;
    } finally {
      state = false;
    }
  }
}

final followControllerProvider = NotifierProvider<FollowController, bool>(
  FollowController.new,
);
