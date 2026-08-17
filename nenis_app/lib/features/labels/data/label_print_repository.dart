import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'label_print_models.dart';

class LabelPrintException implements Exception {
  const LabelPrintException(
    this.message, {
    this.isFeatureLocked = false,
    this.code = 'server_error',
  });

  final String message;
  final bool isFeatureLocked;

  /// Código corto y estable para diagnóstico remoto (se manda al backend
  /// como parte de `failureReason`); la vendedora nunca ve este valor, solo
  /// [message]. Derivado del tipo de [DioException] en [_exception].
  final String code;

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
    // Al crear el trabajo, el backend fija Output en 'SystemPrint' por
    // defecto porque todavía no se sabe qué camino se va a tomar (depende
    // de si hay una impresora emparejada). Aquí, ya con el resultado real
    // del intento de impresión, se corrige al valor real.
    String? output,
  }) async {
    try {
      await _dio.put(
        '/api/label-print-jobs/$jobId/status',
        data: {
          'status': status,
          if (failureReason != null && failureReason.trim().isNotEmpty)
            'failureReason': failureReason.trim(),
          if (output != null) 'output': output,
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
        code: 'feature_locked',
      );
    }
    // 'server_message' distingue, en el diagnóstico remoto, un rechazo
    // explícito del backend (ya con su propio texto) de una falla de red
    // genérica (timeout/sin conexión) que cae en el fallback de abajo.
    if (data is Map && data['message'] is String) {
      final message = (data['message'] as String).trim();
      if (message.isNotEmpty) {
        return LabelPrintException(message, code: 'server_message');
      }
    }
    if (data is String && data.trim().isNotEmpty) {
      return LabelPrintException(data.trim(), code: 'server_message');
    }
    return LabelPrintException(fallback, code: _networkErrorCode(error));
  }

  String _networkErrorCode(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'network_timeout',
      DioExceptionType.connectionError => 'network_error',
      DioExceptionType.badResponse => 'server_error',
      DioExceptionType.cancel => 'request_canceled',
      DioExceptionType.badCertificate || DioExceptionType.unknown => 'unknown',
    };
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
