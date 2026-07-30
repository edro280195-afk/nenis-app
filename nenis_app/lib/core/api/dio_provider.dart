import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/subscription/data/subscription_repository.dart';
import '../auth/auth_controller.dart';
import '../auth/session.dart';
import '../config/app_config.dart';

/// Rutas públicas por token (no requieren `Authorization`).
const _publicPrefixes = [
  '/api/pedido/',
  '/api/driver/',
  '/api/public-tanda/',
  '/api/link-events',
];

void _applyAuthHeaders(RequestOptions options, Session? session) {
  if (session == null) return;
  options.headers['Authorization'] = 'Bearer ${session.token}';
  final businessId = session.activeBusinessId;
  if (businessId != null) {
    options.headers['X-Business-Id'] = businessId.toString();
  }
}

/// El backend de pruebas (Render, plan Free) se duerme tras ~15 min sin uso y
/// el próximo hit tarda hasta ~60s en despertar (ver DEPLOY.md). Sin retry,
/// eso se ve exactamente igual que un backend caído: el timeout salta a los
/// 15-20s y la pantalla muestra "No pudimos cargar..." aunque el servidor
/// hubiera respondido bien unos segundos después. Solo aplica a GET
/// (idempotente): un POST/PUT/DELETE puede haber llegado a procesarse en el
/// servidor aunque la respuesta no volviera a tiempo, así que reintentarlo
/// a ciegas podría duplicar la acción.
bool _isColdStartRetryable(DioException e) {
  if (e.requestOptions.method.toUpperCase() != 'GET') return false;
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return true;
    case DioExceptionType.badResponse:
      final status = e.response?.statusCode;
      return status != null && status >= 502 && status <= 504;
    default:
      return false;
  }
}

/// Configuración de cada reintento de cold-start. El backend de Render Free
/// tarda hasta ~60s en despertar, así que el último intento deja un margen
/// amplio de `receiveTimeout`. Los delays crecen para no saturar al servidor
/// recién despierto.
const _coldStartRetryDelays = [Duration(seconds: 2), Duration(seconds: 5)];
const _coldStartRetryReceive = [Duration(seconds: 45), Duration(seconds: 60)];

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

        // Cold start del backend: hasta 2 reintentos con delays y timeouts
        // crecientes (ver `_coldStartRetry*`). Solo GET idempotente.
        if (_isColdStartRetryable(e)) {
          final attempts =
              (options.extra['__coldStartAttempts'] as int?) ?? 0;
          if (attempts < _coldStartRetryDelays.length) {
            options.extra['__coldStartAttempts'] = attempts + 1;
            options.receiveTimeout = _coldStartRetryReceive[attempts];
            await Future<void>.delayed(_coldStartRetryDelays[attempts]);
            try {
              final response = await dio.fetch<dynamic>(options);
              return handler.resolve(response);
            } on DioException catch (retryError) {
              // Reentramos `onError` con el error del reintento: puede
              // tentar otro cold-start o caer al manejo de 401/402.
              return handler.next(retryError);
            }
          }
        }

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

        // 402 de cuenta bloqueada (prueba/plan vencido): refresca el estado
        // de suscripción para que el muro de `AppShell` se actualice solo.
        // El 402 de una sola feature (`feature_locked`) se queda como hoy,
        // manejado localmente por cada repositorio.
        final data = e.response?.data;
        if (e.response?.statusCode == 402 &&
            data is Map &&
            data['error'] == 'subscription_locked') {
          invalidateSubscriptionState(ref);
        }

        handler.next(e);
      },
    ),
  );

  return dio;
});
