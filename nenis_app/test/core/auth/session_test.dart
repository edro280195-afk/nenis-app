import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/core/auth/session.dart';

void main() {
  group('Session.canAccessRoutes', () {
    test('permite Owner, Admin y Driver', () {
      expect(_session(role: 'Owner').canAccessRoutes, isTrue);
      expect(_session(role: 'Admin').canAccessRoutes, isTrue);
      expect(_session(role: 'Driver').canAccessRoutes, isTrue);
    });

    test('bloquea Scaner aunque tenga negocio activo', () {
      expect(_session(role: 'Scaner').canAccessRoutes, isFalse);
    });

    test('usa el rol del negocio activo cuando hay varias membresias', () {
      final session = _baseSession(
        activeBusinessId: 2,
        memberships: const [
          Membership(businessId: 1, businessName: 'A', role: 'Owner'),
          Membership(businessId: 2, businessName: 'B', role: 'Scaner'),
        ],
      );

      expect(session.canAccessRoutes, isFalse);
    });
  });

  group('Session.canManageStoreEngagement', () {
    test('permite Owner y Admin', () {
      expect(_session(role: 'Owner').canManageStoreEngagement, isTrue);
      expect(_session(role: 'Admin').canManageStoreEngagement, isTrue);
    });

    test('bloquea Driver y Scaner', () {
      expect(_session(role: 'Driver').canManageStoreEngagement, isFalse);
      expect(_session(role: 'Scaner').canManageStoreEngagement, isFalse);
    });
  });

  test('lee y conserva el estado de onboarding del servidor', () {
    final session = Session.fromLoginJson({
      'token': 'token',
      'accountId': 7,
      'name': 'Ana',
      'role': 'None',
      'expiresAt': DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String(),
      'memberships': <Object>[],
      'onboarding': {
        'buyerCompleted': true,
        'sellerCompleted': false,
        'hasVerifiedPhone': true,
      },
    });

    expect(session.onboarding.buyerCompleted, isTrue);
    expect(session.onboarding.sellerCompleted, isFalse);
    expect(session.onboarding.hasVerifiedPhone, isTrue);
    expect(Session.decode(session.encode()).onboarding.buyerCompleted, isTrue);
  });

  test('una respuesta de API anterior no bloquea la navegación', () {
    final session = Session.fromLoginJson({
      'token': 'token',
      'accountId': 8,
      'name': 'Ana',
      'role': 'None',
      'expiresAt': DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String(),
      'memberships': <Object>[],
    });

    expect(session.onboarding.buyerCompleted, isTrue);
    expect(session.onboarding.sellerCompleted, isTrue);
  });
}

Session _session({required String role}) => _baseSession(
  activeBusinessId: 1,
  memberships: [Membership(businessId: 1, businessName: 'Tienda', role: role)],
);

Session _baseSession({
  required int? activeBusinessId,
  required List<Membership> memberships,
}) => Session(
  token: 'token',
  accountId: 1,
  displayName: 'Eduardo',
  role: memberships.isEmpty ? 'None' : memberships.first.role,
  expiresAt: DateTime.now().add(const Duration(days: 1)),
  memberships: memberships,
  activeBusinessId: activeBusinessId,
);
