import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'seller_vip_models.dart';

class SellerVipException implements Exception {
  SellerVipException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SellerVipRepository {
  SellerVipRepository(this._dio);

  final Dio _dio;

  Future<List<SellerFollowerAdmin>> getFollowers() async {
    try {
      final res = await _dio.get('/api/business/followers');
      return ((res.data as List?) ?? const [])
          .map((e) => SellerFollowerAdmin.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw SellerVipException(_message(e, 'No pudimos cargar tus seguidoras.'));
    }
  }

  Future<SellerFollowerAdmin> setVip(int accountId, bool isVip) async {
    try {
      final res = await _dio.put(
        '/api/business/followers/$accountId/vip',
        data: {'isVip': isVip},
      );
      return SellerFollowerAdmin.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) {
        throw SellerVipException('El grupo VIP requiere el plan Pro o superior.');
      }
      throw SellerVipException(_message(e, 'No pudimos actualizar el estatus VIP.'));
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

final sellerVipRepositoryProvider = Provider<SellerVipRepository>((ref) {
  return SellerVipRepository(ref.read(dioProvider));
});

class SellerVipController extends AsyncNotifier<List<SellerFollowerAdmin>> {
  @override
  Future<List<SellerFollowerAdmin>> build() {
    return ref.read(sellerVipRepositoryProvider).getFollowers();
  }

  Future<void> setVip(int accountId, bool isVip) async {
    final current = state.value;
    if (current == null) return;

    final index = current.indexWhere((f) => f.accountId == accountId);
    if (index == -1) return;

    final optimistic = [...current];
    optimistic[index] = optimistic[index].copyWith(isVip: isVip);
    state = AsyncData(optimistic);

    try {
      final updated = await ref.read(sellerVipRepositoryProvider).setVip(accountId, isVip);
      final withUpdate = [...optimistic];
      withUpdate[index] = updated;
      state = AsyncData(withUpdate);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }
}

final sellerVipControllerProvider =
    AsyncNotifierProvider<SellerVipController, List<SellerFollowerAdmin>>(
  SellerVipController.new,
);
