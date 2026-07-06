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

  group('FacebookProfileRequiredException', () {
    test('lee el perfil sugerido y el tipo de cuenta del API', () {
      final result = FacebookProfileRequiredException.fromJson({
        'message': 'Completa tus datos.',
        'accountType': 'seller',
        'requiresExistingPassword': false,
        'firstName': 'Ana',
        'lastName': 'López',
        'email': 'ana@example.com',
        'phone': '8681234567',
        'missingFields': ['businessName'],
      }, fallbackAccountType: FacebookAccountType.client);

      expect(result.accountType, FacebookAccountType.seller);
      expect(result.firstName, 'Ana');
      expect(result.lastName, 'López');
      expect(result.email, 'ana@example.com');
      expect(result.phone, '8681234567');
      expect(result.missingFields, ['businessName']);
      expect(result.requiresExistingPassword, isFalse);
    });

    test('usa el tipo solicitado si el API omite accountType', () {
      final result = FacebookProfileRequiredException.fromJson(
        const {},
        fallbackAccountType: FacebookAccountType.seller,
      );

      expect(result.accountType, FacebookAccountType.seller);
      expect(result.missingFields, isEmpty);
    });
  });

  group('FacebookProfileCompletion', () {
    test('envía los datos de negocio requeridos para una vendedora', () {
      const profile = FacebookProfileCompletion(
        accountType: FacebookAccountType.seller,
        firstName: 'Ana',
        lastName: 'López',
        email: 'ana@example.com',
        phone: '8681234567',
        businessName: 'Regi Bazar',
        city: 'Matamoros',
      );

      expect(
        profile.toJson(
          const FacebookAccessCredential(
            token: 'facebook-token',
            type: FacebookTokenType.classic,
          ),
        ),
        {
          'accessToken': 'facebook-token',
          'tokenType': 'classic',
          'accountType': 'seller',
          'firstName': 'Ana',
          'lastName': 'López',
          'email': 'ana@example.com',
          'phone': '8681234567',
          'businessName': 'Regi Bazar',
          'city': 'Matamoros',
        },
      );
    });

    test('solo envía la contraseña cuando se vincula una cuenta existente', () {
      const profile = FacebookProfileCompletion(
        accountType: FacebookAccountType.client,
        firstName: 'Ana',
        lastName: 'López',
        email: 'ana@example.com',
        phone: '8681234567',
        existingPassword: 'correcta-123',
      );

      final json = profile.toJson(
        const FacebookAccessCredential(
          token: 'facebook-token',
          type: FacebookTokenType.limited,
        ),
      );

      expect(json['existingPassword'], 'correcta-123');
      expect(json['tokenType'], 'limited');
      expect(json.containsKey('businessName'), isFalse);
      expect(json.containsKey('city'), isFalse);
    });
  });

  group('Contrato HTTP de Facebook', () {
    test('envía rol y tipo de token al iniciar sesión', () async {
      Map<String, dynamic>? requestData;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestData = Map<String, dynamic>.from(options.data as Map);
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 409,
                  data: {
                    'message': 'Completa tus datos.',
                    'accountType': 'seller',
                    'requiresExistingPassword': false,
                    'missingFields': ['businessName'],
                  },
                ),
              ),
            );
          },
        ),
      );
      final repository = AuthRepository(dio);

      await expectLater(
        repository.facebookLogin(
          const FacebookAccessCredential(
            token: 'limited-token',
            type: FacebookTokenType.limited,
          ),
          accountType: FacebookAccountType.seller,
        ),
        throwsA(isA<FacebookProfileRequiredException>()),
      );

      expect(requestData?['accessToken'], 'limited-token');
      expect(requestData?['tokenType'], 'limited');
      expect(requestData?['accountType'], 'seller');
    });

    test('interpreta el alta aceptada como verificación de teléfono', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 202,
                data: {
                  'message': 'Código enviado por WhatsApp.',
                  'needsPhoneVerification': true,
                  'phone': '8681234567',
                  'devMode': false,
                  'providerConfigured': true,
                },
              ),
            );
          },
        ),
      );
      final repository = AuthRepository(dio);

      await expectLater(
        repository.completeFacebookProfile(
          const FacebookAccessCredential(
            token: 'classic-token',
            type: FacebookTokenType.classic,
          ),
          const FacebookProfileCompletion(
            accountType: FacebookAccountType.seller,
            firstName: 'Ana',
            lastName: 'López',
            email: 'ana@example.com',
            phone: '8681234567',
            businessName: 'Regi Bazar',
          ),
        ),
        throwsA(
          isA<FacebookPhoneVerificationRequiredException>()
              .having((error) => error.phone, 'phone', '8681234567')
              .having(
                (error) => error.providerConfigured,
                'providerConfigured',
                isTrue,
              ),
        ),
      );
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
  });
}
