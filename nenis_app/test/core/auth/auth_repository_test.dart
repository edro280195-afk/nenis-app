import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/core/auth/auth_repository.dart';

void main() {
  group('OtpRequestResult', () {
    test('lee el estado real informado por el API', () {
      final result = OtpRequestResult.fromJson({
        'devMode': false,
        'providerConfigured': true,
      });

      expect(result.devMode, isFalse);
      expect(result.providerConfigured, isTrue);
    });

    test('usa valores seguros cuando el API omite campos opcionales', () {
      final result = OtpRequestResult.fromJson({});

      expect(result.devMode, isFalse);
      expect(result.providerConfigured, isFalse);
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
}
