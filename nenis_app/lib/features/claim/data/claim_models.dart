/// Un `Client` que una vendedora ya tiene de esta persona y que la compradora
/// puede reclamar (camino de fan-out por teléfono, backend 0.3).
class ClaimCandidate {
  const ClaimCandidate({
    required this.clientId,
    required this.businessId,
    required this.businessName,
    required this.clientName,
    required this.ordersCount,
    required this.matchedBy,
    this.city,
    this.lastOrderAt,
  });

  final int clientId;
  final int businessId;
  final String businessName;
  final String clientName;
  final int ordersCount;
  final String matchedBy; // "phone" | "order-token"
  final String? city;
  final DateTime? lastOrderAt;

  factory ClaimCandidate.fromJson(Map<String, dynamic> j) => ClaimCandidate(
        clientId: (j['clientId'] as num).toInt(),
        businessId: (j['businessId'] as num).toInt(),
        businessName: (j['businessName'] ?? '') as String,
        clientName: (j['clientName'] ?? '') as String,
        ordersCount: (j['ordersCount'] as num?)?.toInt() ?? 0,
        matchedBy: (j['matchedBy'] ?? 'phone') as String,
        city: j['city'] as String?,
        lastOrderAt: j['lastOrderAt'] != null
            ? DateTime.tryParse(j['lastOrderAt'] as String)
            : null,
      );
}

/// Desenlace de reclamar un pedido por su token de acceso (camino principal del
/// deep link). Refleja los estados que el backend devuelve en
/// `POST /api/client-claims/by-order-token/{token}`.
enum ClaimByTokenStatus {
  /// Enlazado (o ya estaba enlazado a esta cuenta: idempotente).
  linked,

  /// El perfil ya lo reclamó otra cuenta (409).
  alreadyClaimedByOther,

  /// El pedido/token no existe (404).
  notFound,

  /// Falta la prueba o la cuenta no puede reclamar (403).
  noProof,
  forbidden,

  /// Error transitorio (red / 5xx). Conviene reintentar.
  error,
}

/// Resultado tipado de `claimByOrderToken`. `businessName`/`clientName` vienen
/// del backend cuando el enlace fue exitoso.
class ClaimByTokenResult {
  const ClaimByTokenResult({
    required this.status,
    this.businessName,
    this.clientName,
    this.message,
  });

  final ClaimByTokenStatus status;
  final String? businessName;
  final String? clientName;
  final String? message;

  bool get isLinked => status == ClaimByTokenStatus.linked;

  /// `true` salvo en errores transitorios: indica que no vale la pena
  /// reintentar y que el token pendiente ya puede descartarse.
  bool get isTerminal => status != ClaimByTokenStatus.error;
}
