import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'store_posts_models.dart';
import 'store_repository.dart';

class StorePostsException implements Exception {
  StorePostsException(this.message);
  final String message;
  @override
  String toString() => message;
}

class StorePostsRepository {
  StorePostsRepository(this._dio);

  final Dio _dio;

  Future<List<StorePostFeedItem>> getPosts(int businessId, {int page = 1, int pageSize = 20}) async {
    try {
      final res = await _dio.get(
        '/api/me/store/$businessId/posts',
        queryParameters: {'page': page, 'pageSize': pageSize},
      );
      return ((res.data as List?) ?? const [])
          .map((e) => StorePostFeedItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      throw StorePostsException('No pudimos cargar las novedades.');
    }
  }
}

final storePostsRepositoryProvider = Provider<StorePostsRepository>((ref) {
  return StorePostsRepository(ref.read(dioProvider));
});

/// Novedades de la tienda actualmente abierta (`storeBusinessIdProvider`).
class StorePostsController extends AsyncNotifier<List<StorePostFeedItem>> {
  @override
  Future<List<StorePostFeedItem>> build() async {
    final businessId = ref.watch(storeBusinessIdProvider);
    if (businessId == null) return const [];
    return ref.read(storePostsRepositoryProvider).getPosts(businessId);
  }
}

final storePostsControllerProvider =
    AsyncNotifierProvider<StorePostsController, List<StorePostFeedItem>>(
  StorePostsController.new,
);
