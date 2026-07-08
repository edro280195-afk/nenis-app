import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'seller_updates_models.dart';

class SellerUpdatesException implements Exception {
  SellerUpdatesException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Se lanza cuando ya hay un vivo activo — trae el aviso existente para que
/// la UI ofrezca "termínalo primero".
class LiveAlreadyActiveException extends SellerUpdatesException {
  LiveAlreadyActiveException(this.active, String message) : super(message);
  final SellerLiveAnnouncement active;
}

class SellerUpdatesRepository {
  SellerUpdatesRepository(this._dio);

  final Dio _dio;

  Future<SellerLiveAnnouncement?> getActiveLive() async {
    try {
      final res = await _dio.get('/api/business/live-announcements/active');
      if (res.statusCode == 204 || res.data == null) return null;
      return SellerLiveAnnouncement.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 204) return null;
      throw SellerUpdatesException(_message(e, 'No pudimos revisar tu vivo.'));
    }
  }

  Future<SellerLiveAnnouncement> startLive(String? title) async {
    try {
      final res = await _dio.post(
        '/api/business/live-announcements',
        data: {'title': title},
      );
      return SellerLiveAnnouncement.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final data = e.response?.data;
        final activeJson = data is Map ? data['active'] as Map<String, dynamic>? : null;
        if (activeJson != null) {
          throw LiveAlreadyActiveException(
            SellerLiveAnnouncement.fromJson(activeJson),
            (data['message'] as String?) ?? 'Ya tienes un vivo activo.',
          );
        }
      }
      throw SellerUpdatesException(_message(e, 'No pudimos avisar que estás en vivo.'));
    }
  }

  Future<void> endLive(int id) async {
    try {
      await _dio.post('/api/business/live-announcements/$id/end');
    } on DioException catch (e) {
      throw SellerUpdatesException(_message(e, 'No pudimos terminar el vivo.'));
    }
  }

  Future<SellerStorePost> createPost({
    required String body,
    String? imageUrl,
    required bool isVipOnly,
  }) async {
    try {
      final res = await _dio.post(
        '/api/business/posts',
        data: {'body': body, 'imageUrl': imageUrl, 'isVipOnly': isVipOnly},
      );
      return SellerStorePost.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) {
        throw SellerUpdatesException(
          'Marcar una novedad como VIP requiere el plan Pro o superior.',
        );
      }
      throw SellerUpdatesException(_message(e, 'No pudimos publicar tu novedad.'));
    }
  }

  Future<List<SellerStorePost>> getMyPosts({int page = 1, int pageSize = 20}) async {
    try {
      final res = await _dio.get(
        '/api/business/posts',
        queryParameters: {'page': page, 'pageSize': pageSize},
      );
      return ((res.data as List?) ?? const [])
          .map((e) => SellerStorePost.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw SellerUpdatesException(_message(e, 'No pudimos cargar tus novedades.'));
    }
  }

  Future<void> deletePost(int id) async {
    try {
      await _dio.delete('/api/business/posts/$id');
    } on DioException catch (e) {
      throw SellerUpdatesException(_message(e, 'No pudimos borrar esta novedad.'));
    }
  }

  Future<String> uploadImage(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.last),
      });
      final res = await _dio.post('/api/business/posts/image', data: formData);
      return (res.data as Map)['url'] as String;
    } on DioException catch (e) {
      throw SellerUpdatesException(_message(e, 'No pudimos subir la imagen.'));
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

final sellerUpdatesRepositoryProvider = Provider<SellerUpdatesRepository>((ref) {
  return SellerUpdatesRepository(ref.read(dioProvider));
});

final activeLiveAnnouncementProvider =
    FutureProvider.autoDispose<SellerLiveAnnouncement?>((ref) {
  return ref.read(sellerUpdatesRepositoryProvider).getActiveLive();
});

final myStorePostsProvider =
    FutureProvider.autoDispose<List<SellerStorePost>>((ref) {
  return ref.read(sellerUpdatesRepositoryProvider).getMyPosts();
});
