import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/labels/data/label_print_models.dart';
import 'package:nenis_app/features/labels/data/label_print_repository.dart';

LabelPrintRepository _repositoryThatFailsWith(DioException Function(RequestOptions options) buildError) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.reject(buildError(options)),
    ),
  );
  return LabelPrintRepository(dio);
}

Future<LabelPrintException> _captured(Future<void> Function() action) async {
  try {
    await action();
  } on LabelPrintException catch (e) {
    return e;
  }
  fail('se esperaba un LabelPrintException');
}

void main() {
  group('LabelPrintRepository — código de diagnóstico derivado del error', () {
    test('feature_locked (402) queda con code feature_locked e isFeatureLocked', () async {
      final repository = _repositoryThatFailsWith(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: options,
            statusCode: 402,
            data: {'error': 'feature_locked'},
          ),
        ),
      );

      final error = await _captured(() => repository.createJob(
            packageIds: const ['p1'],
            mediaSize: LabelMediaSize.shipping4x6,
            copies: 1,
          ));

      expect(error.code, 'feature_locked');
      expect(error.isFeatureLocked, isTrue);
      expect(error.message, 'Las etiquetas de bolsas están disponibles con Pro o Elite.');
    });

    test('mensaje explícito del backend queda con code server_message', () async {
      final repository = _repositoryThatFailsWith(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: options,
            statusCode: 400,
            data: {'message': 'La bolsa ya fue impresa.'},
          ),
        ),
      );

      final error = await _captured(() => repository.createJob(
            packageIds: const ['p1'],
            mediaSize: LabelMediaSize.shipping4x6,
            copies: 1,
          ));

      expect(error.code, 'server_message');
      expect(error.isFeatureLocked, isFalse);
      expect(error.message, 'La bolsa ya fue impresa.');
    });

    test('cuerpo de error como texto plano también queda como server_message', () async {
      final repository = _repositoryThatFailsWith(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: options,
            statusCode: 500,
            data: 'Internal error de verdad feo',
          ),
        ),
      );

      final error = await _captured(() => repository.createJob(
            packageIds: const ['p1'],
            mediaSize: LabelMediaSize.shipping4x6,
            copies: 1,
          ));

      expect(error.code, 'server_message');
      expect(error.message, 'Internal error de verdad feo');
    });

    test('timeout de conexión queda con code network_timeout y el mensaje de fallback', () async {
      final repository = _repositoryThatFailsWith(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final error = await _captured(() => repository.createJob(
            packageIds: const ['p1'],
            mediaSize: LabelMediaSize.shipping4x6,
            copies: 1,
          ));

      expect(error.code, 'network_timeout');
      expect(error.message, 'No pudimos preparar las etiquetas.');
    });

    test('sin conexión de red queda con code network_error', () async {
      final repository = _repositoryThatFailsWith(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );

      final error = await _captured(() => repository.createJob(
            packageIds: const ['p1'],
            mediaSize: LabelMediaSize.shipping4x6,
            copies: 1,
          ));

      expect(error.code, 'network_error');
    });

    test('respuesta de error sin mensaje utilizable queda con code server_error', () async {
      final repository = _repositoryThatFailsWith(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: options,
            statusCode: 500,
            data: {'unrelated': true},
          ),
        ),
      );

      final error = await _captured(() => repository.createJob(
            packageIds: const ['p1'],
            mediaSize: LabelMediaSize.shipping4x6,
            copies: 1,
          ));

      expect(error.code, 'server_error');
    });
  });
}
