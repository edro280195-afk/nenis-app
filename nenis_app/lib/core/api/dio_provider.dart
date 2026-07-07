import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/session.dart';
import '../config/app_config.dart';

/// Rutas públicas por token (no requieren `Authorization`).
const _publicPrefixes = [
  '/api/pedido/',
  '/api/driver/',
  '/api/public-tanda/',
];

void _applyAuthHeaders(RequestOptions options, Session? session) {
  if (session == null) return;
  options.headers['Authorization'] = 'Bearer ${session.token}';
  final businessId = session.activeBusinessId;
  if (businessId != null) {
    options.headers['X-Business-Id'] = businessId.toString();
  }
}

/// Cliente HTTP hacia `sellgeneral-api`. Inyecta el `Bearer` + `X-Business-Id`
/// en las peticiones autenticadas y, ante un 401 (JWT vencido), renueva la
/// sesión con el refresh token y reintenta la petición una sola vez.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final isPublic =
            _publicPrefixes.any((p) => options.path.startsWith(p));
        if (!isPublic) {
          _applyAuthHeaders(
            options,
            ref.read(authControllerProvider).asData?.value,
          );
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        final options = e.requestOptions;
        final isAuthEndpoint = options.path.contains('/api/auth/');
        final alreadyRetried = options.extra['__retried'] == true;

        // 401 en una petición autenticada: intentar renovar y reintentar 1 vez.
        if (e.response?.statusCode == 401 &&
            !isAuthEndpoint &&
            !alreadyRetried) {
          final renewed =
              await ref.read(authControllerProvider.notifier).tryRefresh();
          if (renewed) {
            final session = ref.read(authControllerProvider).asData?.value;
            _applyAuthHeaders(options, session);
            options.extra['__retried'] = true;
            try {
              final response = await dio.fetch<dynamic>(options);
              return handler.resolve(response);
            } on DioException catch (retryError) {
              return handler.next(retryError);
            }
          }
        }

        handler.next(e);
      },
    ),
  );

  return dio;
});
