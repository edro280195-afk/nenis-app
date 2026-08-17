import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/core/auth/auth_repository.dart';

void main() {
  group('OtpRequestResult', () {
    test('lee el estado real informado por el API', () {
      final result = OtpRequestResult.fromJson({
        'devMode': false,
        'providerConfigured': true,
        'message': 'Código enviado.',
      });

      expect(result.devMode, isFalse);
      expect(result.providerConfigured, isTrue);
      expect(result.message, 'Código enviado.');
    });

    test('usa valores seguros cuando el API omite campos opcionales', () {
      final result = OtpRequestResult.fromJson({'message': '  '});

      expect(result.devMode, isFalse);
      expect(result.providerConfigured, isFalse);
      expect(result.message, 'Código enviado por WhatsApp.');
    });
  });

  group('Contrato HTTP de recuperación de contraseña', () {
    test('solicita el código sin enviar datos adicionales', () async {
      String? requestPath;
      Map<String, dynamic>? requestData;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestPath = options.path;
            requestData = Map<String, dynamic>.from(options.data as Map);
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 202,
                data: {
                  'message': 'Si la cuenta existe, enviaremos un código.',
                  'devMode': false,
                  'providerConfigured': true,
                },
              ),
            );
          },
        ),
      );
      final repository = AuthRepository(dio);

      final result = await repository.requestPasswordReset('8681234567');

      expect(requestPath, '/api/auth/password/reset/request');
      expect(requestData, {'phone': '8681234567'});
      expect(result.message, 'Si la cuenta existe, enviaremos un código.');
      expect(result.providerConfigured, isTrue);
    });

    test('confirma el código y la contraseña nueva', () async {
      String? requestPath;
      Map<String, dynamic>? requestData;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestPath = options.path;
            requestData = Map<String, dynamic>.from(options.data as Map);
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {'message': 'Contraseña actualizada.'},
              ),
            );
          },
        ),
      );
      final repository = AuthRepository(dio);

      final result = await repository.confirmPasswordReset(
        phone: '8681234567',
        code: '123456',
        newPassword: 'nueva-segura-123',
      );

      expect(requestPath, '/api/auth/password/reset/confirm');
      expect(requestData, {
        'phone': '8681234567',
        'code': '123456',
        'newPassword': 'nueva-segura-123',
      });
      expect(result.message, 'Contraseña actualizada.');
    });

    test('clasifica el código inválido usando el campo error', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 401,
                  data: {
                    'error': 'invalid_code',
                    'message': 'La verificación fue rechazada.',
                  },
                ),
              ),
            );
          },
        ),
      );
      final repository = AuthRepository(dio);

      await expectLater(
        repository.confirmPasswordReset(
          phone: '8681234567',
          code: '111111',
          newPassword: 'nueva-segura-123',
        ),
        throwsA(
          isA<PasswordResetException>()
              .having(
                (error) => error.failure,
                'failure',
                PasswordResetFailure.invalidCode,
              )
              .having(
                (error) => error.message,
                'message',
                'La verificación fue rechazada.',
              ),
        ),
      );
    });

    test('traduce el límite de intentos a un mensaje accionable', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 429,
                  data: {'message': 'Too many requests'},
                ),
              ),
            );
          },
        ),
      );
      final repository = AuthRepository(dio);

      await expectLater(
        repository.requestPasswordReset('8681234567'),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'message',
            'Hiciste varios intentos. Espera un minuto y vuelve a intentarlo.',
          ),
        ),
      );
    });

    test(
      'explica un problema de conexión sin mostrar detalles técnicos',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                ),
              );
            },
          ),
        );
        final repository = AuthRepository(dio);

        await expectLater(
          repository.requestPasswordReset('8681234567'),
          throwsA(
            isA<AuthException>().having(
              (error) => error.message,
              'message',
              'No pudimos conectar con el servidor. Revisa tu internet.',
            ),
          ),
        );
      },
    );

    test('oculta mensajes internos cuando el servidor falla', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 500,
                  data: {'message': 'NullReferenceException at AuthService'},
                ),
              ),
            );
          },
        ),
      );
      final repository = AuthRepository(dio);

      await expectLater(
        repository.requestPasswordReset('8681234567'),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'message',
            'El servicio no está disponible por el momento. Inténtalo más tarde.',
          ),
        ),
      );
    });

    test('identifica cuando la API publicada aún no tiene Firebase', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response<void>(
                  requestOptions: options,
                  statusCode: 405,
                  data: null,
                ),
              ),
            );
          },
        ),
      );
      final repository = AuthRepository(dio);

      await expectLater(
        repository.firebaseLogin(
          idToken: 'firebase-token',
          profile: const FirebaseLoginProfile(
            accountType: AccountType.client,
            acceptedLegal: true,
          ),
        ),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'message',
            'La autenticación por SMS está en actualización. Inténtalo en unos minutos.',
          ),
        ),
      );
    });
  });
}
