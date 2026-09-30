import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// A quién van dirigidas las notificaciones que lista la pantalla. La app pide SOLO las
/// del papel con el que entró la persona: `seller` (dueña/administradora: avisos de su
/// tienda) o `buyer` (clienta: pedidos, en vivo y novedades). Una cuenta con ambos
/// papeles nunca mezcla las dos campanitas. El valor viaja como `?audience=`.
enum NotificationAudience {
  buyer,
  seller;

  String get apiValue => name;
}

/// Filtro de la pantalla "Notificaciones". `all` muestra todo; `unread`
/// solo las que no han sido marcadas como leídas.
enum NotificationsFilter { all, unread }

extension NotificationsFilterX on NotificationsFilter {
  String get label {
    switch (this) {
      case NotificationsFilter.all:
        return 'Todas';
      case NotificationsFilter.unread:
        return 'No leídas';
    }
  }
}

/// Notificación persistida vista por la compradora. `ReadAt == null`
/// significa que aún no la marcó como leída.
class BuyerNotification {
  const BuyerNotification({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.brandPrimaryColor,
    required this.title,
    required this.message,
    required this.tag,
    required this.createdAt,
    this.audience,
    this.url,
    this.orderId,
    this.readAt,
  });

  final String id;
  final int businessId;
  final String businessName;
  final String brandPrimaryColor;
  final String title;
  final String message;
  final String tag;

  /// Destinatario que fijó el backend (`buyer`/`seller`). Es `null` si el backend
  /// todavía no lo manda (versión anterior).
  final NotificationAudience? audience;
  final String? url;
  final int? orderId;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  /// Icono sugerido por tag (mapeo aproximado de los tags que emite el
  /// backend: "delivered", "driver-en-route", "driver-nearby",
  /// "chat-driver", "order-confirmed", "card-payment", "reserve").
  IconData get icon {
    switch (tag) {
      case 'delivered':
        return Symbols.celebration;
      case 'driver-en-route':
        return Symbols.local_shipping;
      case 'driver-nearby':
        return Symbols.location_on;
      case 'chat-driver':
        return Symbols.chat;
      case 'order-confirmed':
        return Symbols.check_circle;
      case 'card-payment':
        return Symbols.credit_card;
      case 'reserve':
        return Symbols.bookmark;
      case 'live-started':
        return Symbols.sensors;
      case 'store-post':
        return Symbols.campaign;
      // Avisos de tienda (vendedora).
      case 'pedidos-por-vencer':
        return Symbols.hourglass_top;
      case 'saldos-sin-cobrar':
      case 'payment-received':
      case 'tanda-payment':
        return Symbols.payments;
      case 'pulso-negocio':
        return Symbols.insights;
      case 'delivery-failed':
        return Symbols.warning;
      case 'packages-returned':
        return Symbols.assignment_return;
      default:
        return Symbols.notifications;
    }
  }

  factory BuyerNotification.fromJson(Map<String, dynamic> j) =>
      BuyerNotification(
        id: (j['id'] ?? '') as String,
        businessId: (j['businessId'] as num).toInt(),
        businessName: (j['businessName'] ?? '') as String,
        brandPrimaryColor: (j['brandPrimaryColor'] ?? '#FB6F9C') as String,
        title: (j['title'] ?? '') as String,
        message: (j['message'] ?? '') as String,
        tag: (j['tag'] ?? 'general') as String,
        audience: switch (j['audience']) {
          'seller' => NotificationAudience.seller,
          'buyer' => NotificationAudience.buyer,
          _ => null,
        },
        url: j['url'] as String?,
        orderId: (j['orderId'] as num?)?.toInt(),
        createdAt:
            DateTime.tryParse((j['createdAt'] ?? '') as String) ??
            DateTime.now(),
        readAt: j['readAt'] != null
            ? DateTime.tryParse(j['readAt'] as String)
            : null,
      );
}
