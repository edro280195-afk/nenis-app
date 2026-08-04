import 'dart:convert';

/// Relación persona ↔ negocio con un rol (Owner/Admin/Driver/Scaner).
class Membership {
  const Membership({
    required this.businessId,
    required this.businessName,
    required this.role,
  });

  final int businessId;
  final String businessName;
  final String role;

  factory Membership.fromJson(Map<String, dynamic> j) => Membership(
    businessId: (j['businessId'] as num).toInt(),
    businessName: (j['businessName'] ?? '') as String,
    role: (j['role'] ?? 'None') as String,
  );

  Map<String, dynamic> toJson() => {
    'businessId': businessId,
    'businessName': businessName,
    'role': role,
  };
}

class AccountOnboarding {
  const AccountOnboarding({
    required this.buyerCompleted,
    required this.sellerCompleted,
    required this.hasVerifiedPhone,
  });

  /// Compatibilidad durante despliegues escalonados: la API anterior no
  /// enviaba este objeto ni tenia el endpoint para completarlo.
  const AccountOnboarding.legacyCompleted()
    : buyerCompleted = true,
      sellerCompleted = true,
      hasVerifiedPhone = false;

  final bool buyerCompleted;
  final bool sellerCompleted;
  final bool hasVerifiedPhone;

  factory AccountOnboarding.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AccountOnboarding.legacyCompleted();
    return AccountOnboarding(
      buyerCompleted: json['buyerCompleted'] as bool? ?? false,
      sellerCompleted: json['sellerCompleted'] as bool? ?? false,
      hasVerifiedPhone: json['hasVerifiedPhone'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'buyerCompleted': buyerCompleted,
    'sellerCompleted': sellerCompleted,
    'hasVerifiedPhone': hasVerifiedPhone,
  };
}

/// Sesión autenticada de la compradora. El JWT trae `sub = AccountId`.
class Session {
  const Session({
    required this.token,
    required this.accountId,
    required this.displayName,
    required this.role,
    required this.expiresAt,
    required this.memberships,
    this.onboarding = const AccountOnboarding.legacyCompleted(),
    this.activeBusinessId,
    this.refreshToken,
  });

  final String token;
  final int accountId;
  final String displayName;
  final String role;
  final DateTime expiresAt;
  final List<Membership> memberships;
  final AccountOnboarding onboarding;

  /// Negocio activo (para el header `X-Business-Id`). Una compradora sin
  /// memberships lo deja en null; con una sola, se autoselecciona.
  final int? activeBusinessId;

  /// Refresh token opaco (90 días) para renovar el JWT sin re-autenticar.
  /// Reemplaza al guardado de contraseña en el dispositivo.
  final String? refreshToken;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get hasMembership => memberships.isNotEmpty;
  Membership? get activeMembership {
    if (memberships.isEmpty) return null;
    final active = activeBusinessId;
    if (active == null) {
      return memberships.length == 1 ? memberships.first : null;
    }
    for (final membership in memberships) {
      if (membership.businessId == active) return membership;
    }
    return null;
  }

  bool hasActiveBusinessRole(Set<String> allowedRoles) {
    final normalizedRoles = allowedRoles
        .map((role) => role.trim().toLowerCase())
        .toSet();

    bool isAllowed(Membership membership) =>
        normalizedRoles.contains(membership.role.trim().toLowerCase());

    final active = activeMembership;
    if (active != null) return isAllowed(active);
    if (activeBusinessId != null) return false;
    return memberships.any(isAllowed);
  }

  bool get canAccessRoutes =>
      hasActiveBusinessRole(const {'Owner', 'Admin', 'Driver'});

  bool get canManageLabels => hasActiveBusinessRole(const {'Owner', 'Admin'});

  bool get canManageStoreEngagement =>
      hasActiveBusinessRole(const {'Owner', 'Admin'});

  /// Construye desde el `LoginResponse` del backend (camelCase).
  factory Session.fromLoginJson(Map<String, dynamic> j) {
    final memberships = ((j['memberships'] as List?) ?? const [])
        .map((m) => Membership.fromJson(m as Map<String, dynamic>))
        .toList();
    return Session(
      token: j['token'] as String,
      accountId: (j['accountId'] as num).toInt(),
      displayName: (j['name'] ?? '') as String,
      role: (j['role'] ?? 'None') as String,
      expiresAt:
          DateTime.tryParse((j['expiresAt'] ?? '') as String)?.toLocal() ??
          DateTime.now().add(const Duration(days: 7)),
      memberships: memberships,
      onboarding: AccountOnboarding.fromJson(
        (j['onboarding'] as Map?)?.cast<String, dynamic>(),
      ),
      activeBusinessId: memberships.length == 1
          ? memberships.first.businessId
          : null,
      refreshToken: j['refreshToken'] as String?,
    );
  }

  factory Session.fromJson(Map<String, dynamic> j) {
    final memberships = ((j['memberships'] as List?) ?? const [])
        .map((m) => Membership.fromJson(m as Map<String, dynamic>))
        .toList();
    return Session(
      token: j['token'] as String,
      accountId: (j['accountId'] as num).toInt(),
      displayName: (j['name'] ?? '') as String,
      role: (j['role'] ?? 'None') as String,
      expiresAt:
          DateTime.tryParse((j['expiresAt'] ?? '') as String) ?? DateTime.now(),
      memberships: memberships,
      onboarding: AccountOnboarding.fromJson(
        (j['onboarding'] as Map?)?.cast<String, dynamic>(),
      ),
      activeBusinessId: (j['activeBusinessId'] as num?)?.toInt(),
      refreshToken: j['refreshToken'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'accountId': accountId,
    'name': displayName,
    'role': role,
    'expiresAt': expiresAt.toIso8601String(),
    'memberships': memberships.map((m) => m.toJson()).toList(),
    'onboarding': onboarding.toJson(),
    'activeBusinessId': activeBusinessId,
    'refreshToken': refreshToken,
  };

  Session copyWith({
    int? activeBusinessId,
    String? refreshToken,
    AccountOnboarding? onboarding,
  }) => Session(
    token: token,
    accountId: accountId,
    displayName: displayName,
    role: role,
    expiresAt: expiresAt,
    memberships: memberships,
    onboarding: onboarding ?? this.onboarding,
    activeBusinessId: activeBusinessId ?? this.activeBusinessId,
    refreshToken: refreshToken ?? this.refreshToken,
  );

  String encode() => jsonEncode(toJson());

  static Session decode(String raw) =>
      Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
