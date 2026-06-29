import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../config/app_config.dart';

/// Rutas públicas por token (no requieren `Authorization`).
const _publicPrefixes = [
  '/api/pedido/',
  '/api/driver/',
  '/api/public-tanda/',
];

/// Cliente HTTP hacia `sellgeneral-api`. El interceptor inyecta el `Bearer` y
/// el `X-Business-Id` del negocio activo en las peticiones autenticadas.
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
          final session = ref.read(authControllerProvider).asData?.value;
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.token}';
            final businessId = session.activeBusinessId;
            if (businessId != null) {
              options.headers['X-Business-Id'] = businessId.toString();
            }
          }
        }
        handler.next(options);
      },
    ),
  );

  return dio;
});
