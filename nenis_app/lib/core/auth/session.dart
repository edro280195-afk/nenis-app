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

/// Sesión autenticada de la compradora. El JWT trae `sub = AccountId`.
class Session {
  const Session({
    required this.token,
    required this.accountId,
    required this.displayName,
    required this.role,
    required this.expiresAt,
    required this.memberships,
    this.activeBusinessId,
    this.refreshToken,
  });

  final String token;
  final int accountId;
  final String displayName;
  final String role;
  final DateTime expiresAt;
  final List<Membership> memberships;

  /// Negocio activo (para el header `X-Business-Id`). Una compradora sin
  /// memberships lo deja en null; con una sola, se autoselecciona.
  final int? activeBusinessId;

  /// Refresh token opaco (90 días) para renovar el JWT sin re-autenticar.
  /// Reemplaza al guardado de contraseña en el dispositivo.
  final String? refreshToken;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get hasMembership => memberships.isNotEmpty;

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
      expiresAt: DateTime.tryParse((j['expiresAt'] ?? '') as String)?.toLocal() ??
          DateTime.now().add(const Duration(days: 7)),
      memberships: memberships,
      activeBusinessId:
          memberships.length == 1 ? memberships.first.businessId : null,
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
        'activeBusinessId': activeBusinessId,
        'refreshToken': refreshToken,
      };

  Session copyWith({int? activeBusinessId, String? refreshToken}) => Session(
        token: token,
        accountId: accountId,
        displayName: displayName,
        role: role,
        expiresAt: expiresAt,
        memberships: memberships,
        activeBusinessId: activeBusinessId ?? this.activeBusinessId,
        refreshToken: refreshToken ?? this.refreshToken,
      );

  String encode() => jsonEncode(toJson());

  static Session decode(String raw) =>
      Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
