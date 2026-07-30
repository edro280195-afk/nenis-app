import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'label_print_models.dart';
import 'label_template_models.dart';

class LabelTemplateException implements Exception {
  const LabelTemplateException(this.message, {this.errors = const []});

  final String message;
  final List<String> errors;

  @override
  String toString() => message;
}

class LabelTemplateRepository {
  LabelTemplateRepository(this._dio);

  final Dio _dio;

  Future<LabelTemplateEditor> getDefault(
    LabelTemplateKind kind,
    LabelMediaSize mediaSize,
  ) async {
    try {
      final response = await _dio.get(
        '/api/label-templates/default',
        queryParameters: {'kind': kind.api, 'mediaSize': mediaSize.api},
      );
      return LabelTemplateEditor.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (error) {
      throw _exception(error, 'No pudimos abrir tu etiqueta.');
    }
  }

  Future<LabelTemplateEditor> saveDraft({
    required String templateId,
    required String designJson,
    required int expectedRevision,
  }) async {
    try {
      final response = await _dio.put(
        '/api/label-templates/$templateId/draft',
        data: {'designJson': designJson, 'expectedRevision': expectedRevision},
      );
      return LabelTemplateEditor.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (error) {
      throw _exception(error, 'No pudimos guardar tus cambios.');
    }
  }

  Future<LabelTemplateEditor> publish(String templateId) async {
    try {
      final response = await _dio.post(
        '/api/label-templates/$templateId/publish',
      );
      return LabelTemplateEditor.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (error) {
      throw _exception(error, 'No pudimos publicar la etiqueta.');
    }
  }

  Future<LabelTemplateEditor> resetDraft(String templateId) async {
    try {
      final response = await _dio.post(
        '/api/label-templates/$templateId/draft/reset',
      );
      return LabelTemplateEditor.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (error) {
      throw _exception(error, 'No pudimos recuperar la versión publicada.');
    }
  }

  Future<List<LabelAsset>> getAssets() async {
    try {
      final response = await _dio.get('/api/label-templates/assets');
      return ((response.data as List?) ?? const [])
          .map(
            (item) =>
                LabelAsset.fromJson((item as Map).cast<String, dynamic>()),
          )
          .toList();
    } on DioException catch (error) {
      throw _exception(error, 'No pudimos cargar tus imágenes.');
    }
  }

  Future<LabelAsset> uploadAsset(File file) async {
    try {
      final response = await _dio.post(
        '/api/label-templates/assets',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(
            file.path,
            filename: file.uri.pathSegments.last,
          ),
        }),
      );
      return LabelAsset.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (error) {
      throw _exception(error, 'No pudimos subir esta imagen.');
    }
  }

  LabelTemplateException _exception(DioException error, String fallback) {
    final data = error.response?.data;
    final errors = data is Map && data['errors'] is List
        ? (data['errors'] as List).map((item) => item.toString()).toList()
        : const <String>[];
    if (data is Map && data['message'] is String) {
      final message = (data['message'] as String).trim();
      if (message.isNotEmpty) {
        return LabelTemplateException(message, errors: errors);
      }
    }
    if (data is String && data.trim().isNotEmpty) {
      return LabelTemplateException(data.trim(), errors: errors);
    }
    return LabelTemplateException(fallback, errors: errors);
  }
}

final labelTemplateRepositoryProvider = Provider<LabelTemplateRepository>((
  ref,
) {
  return LabelTemplateRepository(ref.read(dioProvider));
});

final labelTemplateProvider = FutureProvider.autoDispose
    .family<
      LabelTemplateEditor,
      ({LabelTemplateKind kind, LabelMediaSize mediaSize})
    >((ref, key) {
      return ref
          .read(labelTemplateRepositoryProvider)
          .getDefault(key.kind, key.mediaSize);
    });

final labelAssetsProvider = FutureProvider.autoDispose<List<LabelAsset>>((ref) {
  return ref.read(labelTemplateRepositoryProvider).getAssets();
});
