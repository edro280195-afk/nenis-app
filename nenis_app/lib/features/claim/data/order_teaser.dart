import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';

/// Vista previa mínima del pedido (`GET /api/pedido/{token}/teaser`, pública por
/// token). Da contexto de confianza y pre-llena el registro passwordless.
class OrderTeaser {
  const OrderTeaser({
    required this.businessName,
    required this.clientName,
    required this.total,
    required this.itemsCount,
    required this.statusLabel,
    required this.isExpired,
    this.businessLogoUrl,
    this.clientPhone,
    this.scheduledDeliveryDate,
  });

  final String businessName;
  final String? businessLogoUrl;
  final String clientName;
  final double total;
  final int itemsCount;
  final String statusLabel;
  final bool isExpired;
  final String? clientPhone;
  final DateTime? scheduledDeliveryDate;

  /// Teléfono en formato local de 10 dígitos (para pre-llenar el campo).
  String? get localPhone {
    final digits = clientPhone?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (digits.isEmpty) return null;
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  /// Nombre de pila (primera palabra) para el saludo y el alta.
  String? get firstName {
    final parts = clientName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? null : parts.first;
  }

  /// Apellido(s): el resto del nombre después de la primera palabra.
  String? get lastName {
    final parts = clientName.trim().split(RegExp(r'\s+'));
    return parts.length > 1 ? parts.sublist(1).join(' ') : null;
  }

  factory OrderTeaser.fromJson(Map<String, dynamic> j) => OrderTeaser(
        businessName: (j['businessName'] ?? 'Tu tienda') as String,
        businessLogoUrl: j['businessLogoUrl'] as String?,
        clientName: (j['clientName'] ?? 'bonita') as String,
        total: (j['total'] as num?)?.toDouble() ?? 0,
        itemsCount: (j['itemsCount'] as num?)?.toInt() ?? 0,
        statusLabel: (j['statusLabel'] ?? '') as String,
        isExpired: (j['isExpired'] as bool?) ?? false,
        clientPhone: j['clientPhone'] as String?,
        scheduledDeliveryDate: j['scheduledDeliveryDate'] != null
            ? DateTime.tryParse(j['scheduledDeliveryDate'] as String)
            : null,
      );
}

/// Carga el teaser del pedido por token (endpoint público).
final orderTeaserProvider =
    FutureProvider.autoDispose.family<OrderTeaser, String>((ref, token) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/api/pedido/$token/teaser');
  return OrderTeaser.fromJson((res.data as Map).cast<String, dynamic>());
});
