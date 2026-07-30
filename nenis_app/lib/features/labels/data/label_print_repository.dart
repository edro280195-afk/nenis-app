import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'label_print_models.dart';

class LabelPrintException implements Exception {
  const LabelPrintException(this.message, {this.isFeatureLocked = false});

  final String message;
  final bool isFeatureLocked;

  @override
  String toString() => message;
}

class LabelPrintRepository {
  LabelPrintRepository(this._dio);

  final Dio _dio;

  Future<List<AvailableLabelPackage>> getAvailablePackages() async {
    try {
      final response = await _dio.get(
        '/api/label-print-jobs/available-packages',
      );
      return ((response.data as List?) ?? const [])
          .map(
            (item) => AvailableLabelPackage.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw _exception(error, 'No pudimos cargar las bolsas por imprimir.');
    }
  }

  Future<List<OrderPackageLabel>> getOrderPackages(int orderId) async {
    try {
      final response = await _dio.get('/api/orders/$orderId/packages');
      return ((response.data as List?) ?? const [])
          .map(
            (item) => OrderPackageLabel.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw _exception(error, 'No pudimos cargar las bolsas del pedido.');
    }
  }

  Future<List<OrderPackageLabel>> generateOrderPackages({
    required int orderId,
    required int count,
  }) async {
    try {
      final response = await _dio.post(
        '/api/orders/$orderId/packages/generate',
        data: {'count': count},
      );
      return ((response.data as List?) ?? const [])
          .map(
            (item) => OrderPackageLabel.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw _exception(error, 'No pudimos crear las bolsas del pedido.');
    }
  }

  Future<LabelPrintJob> createJob({
    required List<String> packageIds,
    required LabelMediaSize mediaSize,
    required int copies,
  }) async {
    try {
      final response = await _dio.post(
        '/api/label-print-jobs',
        data: {
          'packageIds': packageIds,
          'mediaSize': mediaSize.api,
          'copies': copies,
          'output': 'SystemPrint',
        },
      );
      return LabelPrintJob.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (error) {
      throw _exception(error, 'No pudimos preparar las etiquetas.');
    }
  }

  Future<void> updateJobStatus({
    required String jobId,
    required String status,
    String? failureReason,
  }) async {
    try {
      await _dio.put(
        '/api/label-print-jobs/$jobId/status',
        data: {
          'status': status,
          if (failureReason != null && failureReason.trim().isNotEmpty)
            'failureReason': failureReason.trim(),
        },
      );
    } on DioException catch (error) {
      throw _exception(error, 'No pudimos guardar el resultado de impresión.');
    }
  }

  LabelPrintException _exception(DioException error, String fallback) {
    final data = error.response?.data;
    final isFeatureLocked =
        error.response?.statusCode == 402 &&
        data is Map &&
        data['error'] == 'feature_locked';
    if (isFeatureLocked) {
      return const LabelPrintException(
        'Las etiquetas de bolsas están disponibles con Pro o Elite.',
        isFeatureLocked: true,
      );
    }
    if (data is Map && data['message'] is String) {
      final message = (data['message'] as String).trim();
      if (message.isNotEmpty) return LabelPrintException(message);
    }
    if (data is String && data.trim().isNotEmpty) {
      return LabelPrintException(data.trim());
    }
    return LabelPrintException(fallback);
  }
}

final labelPrintRepositoryProvider = Provider<LabelPrintRepository>((ref) {
  return LabelPrintRepository(ref.read(dioProvider));
});

final availableLabelPackagesProvider =
    FutureProvider.autoDispose<List<AvailableLabelPackage>>((ref) {
      return ref.read(labelPrintRepositoryProvider).getAvailablePackages();
    });

final orderLabelPackagesProvider = FutureProvider.autoDispose
    .family<List<OrderPackageLabel>, int>((ref, orderId) {
      return ref.read(labelPrintRepositoryProvider).getOrderPackages(orderId);
    });
