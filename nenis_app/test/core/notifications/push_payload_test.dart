import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/core/auth/session.dart';
import 'package:nenis_app/core/notifications/push_payload.dart';

void main() {
  group('PushPayload.fromData', () {
    test(
      'lee los campos que manda el backend (FCM los entrega como texto)',
      () {
        final payload = PushPayload.fromData({
          'type': 'saldos-sin-cobrar',
          'audience': 'seller',
          'businessId': '7',
          'accountId': '42',
          'url': '/orders',
        });

        expect(payload.type, 'saldos-sin-cobrar');
        expect(payload.audience, PushAudience.seller);
        expect(payload.businessId, 7);
        expect(payload.accountId, 42);
        expect(payload.url, '/orders');
      },
    );

    test('tolera datos faltantes, vacíos o basura sin lanzar', () {
      final payload = PushPayload.fromData({
        'audience': 'admin',
        'businessId': 'abc',
        'accountId': '',
        'url': '   ',
      });

      expect(payload.audience, isNull);
      expect(payload.businessId, isNull);
      expect(payload.accountId, isNull);
      expect(payload.url, isNull);
      expect(PushPayload.fromData(const {}).type, isNull);
    });
  });

  group('PushPayload.encode / decode (notificación local)', () {
    test('ida y vuelta conserva todos los campos', () {
      const original = PushPayload(
        type: 'delivered',
        audience: PushAudience.buyer,
        businessId: 3,
        accountId: 9,
        url: '/o/abc',
      );

      final decoded = PushPayload.decode(original.encode());

      expect(decoded.type, 'delivered');
      expect(decoded.audience, PushAudience.buyer);
      expect(decoded.businessId, 3);
      expect(decoded.accountId, 9);
      expect(decoded.url, '/o/abc');
    });

    test('acepta el formato anterior: solo la URL', () {
      final decoded = PushPayload.decode('/store/5');

      expect(decoded.url, '/store/5');
      expect(decoded.audience, isNull);
      expect(decoded.accountId, isNull);
    });

    test('un JSON roto o vacío no trae datos (y por tanto no navega)', () {
      expect(PushPayload.decode('{no es json').hasInternalUrl, isFalse);
      expect(PushPayload.decode('').hasInternalUrl, isFalse);
      expect(PushPayload.decode(null).hasInternalUrl, isFalse);
    });
  });

  group('PushPayload.isFor — el aviso solo es de quien debe', () {
    test('un aviso de UNA cuenta no es para la sesión de otra', () {
      const payload = PushPayload(
        audience: PushAudience.buyer,
        accountId: 10,
        url: '/o/abc',
      );

      expect(payload.isFor(_session(accountId: 10)), isTrue);
      expect(payload.isFor(_session(accountId: 11)), isFalse);
    });

    test(
      'un aviso de tienda solo es para dueña/administradora de ese negocio',
      () {
        const payload = PushPayload(
          audience: PushAudience.seller,
          businessId: 7,
          url: '/orders',
        );

        expect(
          payload.isFor(_session(memberships: [_member(7, 'Owner')])),
          isTrue,
        );
        expect(
          payload.isFor(_session(memberships: [_member(7, 'admin')])),
          isTrue,
        );
        // Chofer o escaneador del mismo negocio: no.
        expect(
          payload.isFor(_session(memberships: [_member(7, 'Driver')])),
          isFalse,
        );
        expect(
          payload.isFor(_session(memberships: [_member(7, 'Scaner')])),
          isFalse,
        );
        // Dueña de OTRO negocio: no.
        expect(
          payload.isFor(_session(memberships: [_member(8, 'Owner')])),
          isFalse,
        );
        // Una clienta (sin negocio): jamás.
        expect(payload.isFor(_session()), isFalse);
      },
    );

    test('un aviso de tienda sin negocio basta con ser dueña de alguno', () {
      const payload = PushPayload(audience: PushAudience.seller);

      expect(
        payload.isFor(_session(memberships: [_member(1, 'Owner')])),
        isTrue,
      );
      expect(payload.isFor(_session()), isFalse);
    });

    test(
      'un aviso de clienta sin cuenta concreta (en vivo) vale para la sesión',
      () {
        const payload = PushPayload(
          audience: PushAudience.buyer,
          businessId: 4,
        );

        expect(payload.isFor(_session()), isTrue);
      },
    );

    test('sin destinatario (prueba de notificaciones) vale para la sesión', () {
      expect(const PushPayload(type: 'test').isFor(_session()), isTrue);
    });

    test('un aviso de tienda de una cuenta concreta exige ambas cosas', () {
      const payload = PushPayload(
        audience: PushAudience.seller,
        businessId: 7,
        accountId: 10,
      );

      expect(
        payload.isFor(
          _session(accountId: 10, memberships: [_member(7, 'Owner')]),
        ),
        isTrue,
      );
      expect(
        payload.isFor(
          _session(accountId: 11, memberships: [_member(7, 'Owner')]),
        ),
        isFalse,
      );
    });
  });

  group('PushPayload.hasInternalUrl', () {
    test('solo navega a rutas internas de la app', () {
      expect(const PushPayload(url: '/orders').hasInternalUrl, isTrue);
      expect(
        const PushPayload(url: 'https://evil.example').hasInternalUrl,
        isFalse,
      );
      expect(const PushPayload(url: '').hasInternalUrl, isFalse);
      expect(const PushPayload().hasInternalUrl, isFalse);
    });
  });

  group('Session.managesBusiness', () {
    test('reconoce Owner/Admin sin importar mayúsculas', () {
      final session = _session(
        memberships: [_member(1, 'OWNER'), _member(2, 'Driver')],
      );

      expect(session.managesBusiness(1), isTrue);
      expect(session.managesBusiness(2), isFalse);
      expect(session.managesBusiness(null), isTrue);
      expect(session.managesBusiness(99), isFalse);
    });
  });
}

Membership _member(int businessId, String role) => Membership(
  businessId: businessId,
  businessName: 'Tienda $businessId',
  role: role,
);

Session _session({
  int accountId = 1,
  List<Membership> memberships = const [],
}) => Session(
  token: 'jwt',
  accountId: accountId,
  displayName: 'Prueba',
  role: memberships.isEmpty ? 'None' : memberships.first.role,
  expiresAt: DateTime.now().add(const Duration(days: 1)),
  memberships: memberships,
);
