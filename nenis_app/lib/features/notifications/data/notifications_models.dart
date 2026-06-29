import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

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
        url: j['url'] as String?,
        orderId: (j['orderId'] as num?)?.toInt(),
        createdAt: DateTime.tryParse((j['createdAt'] ?? '') as String) ??
            DateTime.now(),
        readAt: j['readAt'] != null
            ? DateTime.tryParse(j['readAt'] as String)
            : null,
      );
}
