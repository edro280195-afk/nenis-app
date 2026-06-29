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
