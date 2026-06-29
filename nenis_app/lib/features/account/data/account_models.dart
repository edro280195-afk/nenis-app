import 'package:flutter/widgets.dart';

/// Paleta de avatares por tienda. La usamos para que cada tienda tenga un
/// gradient consistente entre pantallas aunque el endpoint todavía no
/// devuelva `brandPrimaryColor`.
const List<List<Color>> _avatarPalette = [
  [Color(0xFFFF3D8B), Color(0xFFFF0072)],
  [Color(0xFFFF9A6B), Color(0xFFFF7A59)],
  [Color(0xFFA98CF0), Color(0xFF8E6BE6)],
  [Color(0xFF3AD1B8), Color(0xFF16B5A0)],
  [Color(0xFFFFC06F), Color(0xFFF3B341)],
];

/// Devuelve un par (start, end) de gradiente estable para un `businessId`.
({Color start, Color end}) avatarColorsFor(int businessId) {
  if (businessId <= 0) {
    return (start: _avatarPalette[0][0], end: _avatarPalette[0][1]);
  }
  final idx = businessId.abs() % _avatarPalette.length;
  return (start: _avatarPalette[idx][0], end: _avatarPalette[idx][1]);
}

/// Resumen de un Client ya reclamado por la Account actual (cross-tenant).
/// Devuelto por `GET /api/client-claims/mine`.
class ClaimedClientSummary {
  const ClaimedClientSummary({
    required this.clientId,
    required this.businessId,
    required this.businessName,
    required this.clientName,
    required this.linkedBy,
    required this.claimedAt,
  });

  final int clientId;
  final int businessId;
  final String businessName;
  final String clientName;
  final String linkedBy;
  final DateTime claimedAt;

  String get initial => businessName.isNotEmpty
      ? businessName.characters.first.toUpperCase()
      : '?';

  /// Etiqueta humana del mecanismo de vinculación. Sirve como tooltip/hint
  /// en la UI.
  String get linkedByLabel {
    switch (linkedBy) {
      case 'phone-match':
        return 'Vinculada por tu número';
      case 'order-token':
        return 'Vinculada por un pedido';
      case 'idempotent':
        return 'Ya estaba vinculada';
      default:
        return 'Vinculada';
    }
  }

  ({Color start, Color end}) get avatarColors =>
      avatarColorsFor(businessId);

  factory ClaimedClientSummary.fromJson(Map<String, dynamic> j) =>
      ClaimedClientSummary(
        clientId: (j['clientId'] as num).toInt(),
        businessId: (j['businessId'] as num).toInt(),
        businessName: (j['businessName'] ?? '') as String,
        clientName: (j['clientName'] ?? '') as String,
        linkedBy: (j['linkedBy'] ?? '') as String,
        claimedAt:
            DateTime.tryParse((j['claimedAt'] ?? '') as String) ??
                DateTime.now(),
      );
}
