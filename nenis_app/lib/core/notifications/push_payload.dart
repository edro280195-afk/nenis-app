import 'dart:convert';

import '../auth/session.dart';

/// A quién va dirigido un push. Lo fija el backend en `data.audience`
/// (`PushNotificationService`): `buyer` = la persona como clienta/seguidora,
/// `seller` = la persona como dueña/administradora de un negocio.
enum PushAudience {
  buyer,
  seller;

  static PushAudience? parse(Object? raw) {
    switch (raw) {
      case 'buyer':
        return PushAudience.buyer;
      case 'seller':
        return PushAudience.seller;
    }
    return null;
  }
}

/// Datos que trae un push (`RemoteMessage.data`):
///
/// - `type`: etiqueta del aviso (p. ej. `delivered`, `pedidos-por-vencer`).
/// - `audience`: a quién va dirigido ([PushAudience]).
/// - `businessId`: negocio del que viene.
/// - `url`: ruta interna de la app a la que lleva.
/// - `accountId`: solo cuando el aviso es para UNA cuenta concreta (un pedido).
///
/// Antes de mostrar un push o de navegar con él se valida con [isFor]: así un aviso
/// de la tienda nunca se abre en una sesión de clienta, ni el de una cuenta en la
/// sesión de otra que entró después en el mismo teléfono.
class PushPayload {
  const PushPayload({
    this.type,
    this.audience,
    this.businessId,
    this.accountId,
    this.url,
  });

  final String? type;
  final PushAudience? audience;
  final int? businessId;
  final int? accountId;
  final String? url;

  /// Desde `RemoteMessage.data` (los valores de FCM siempre llegan como texto).
  factory PushPayload.fromData(Map<String, dynamic> data) {
    String? text(String key) {
      final value = data[key];
      if (value == null) return null;
      final s = value.toString().trim();
      return s.isEmpty ? null : s;
    }

    return PushPayload(
      type: text('type'),
      audience: PushAudience.parse(text('audience')),
      businessId: int.tryParse(text('businessId') ?? ''),
      accountId: int.tryParse(text('accountId') ?? ''),
      url: text('url'),
    );
  }

  /// Desde el `payload` de una notificación local. Acepta el formato actual
  /// (JSON de [encode]) y el anterior (solo la URL).
  factory PushPayload.decode(String? raw) {
    if (raw == null || raw.isEmpty) return const PushPayload();
    if (!raw.startsWith('{')) return PushPayload(url: raw);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return PushPayload.fromData(decoded.cast());
    } catch (_) {
      // JSON roto: se trata como si no trajera datos.
    }
    return const PushPayload();
  }

  /// Texto para el `payload` de una notificación local.
  String encode() => jsonEncode({
    'type': type,
    'audience': audience?.name,
    'businessId': businessId,
    'accountId': accountId,
    'url': url,
  });

  /// ¿Este aviso es para quien tiene la sesión [session]?
  ///
  /// - Si trae `accountId`, tiene que ser el de la sesión.
  /// - Si es de tienda (`seller`), la sesión tiene que ser dueña o administradora de
  ///   ese negocio.
  /// - Un aviso de clienta (`buyer`) sin cuenta concreta (en vivo, novedades) es válido
  ///   para cualquier sesión: lo fija el backend por seguidoras.
  bool isFor(Session session) {
    final recipient = accountId;
    if (recipient != null && recipient != session.accountId) return false;
    if (audience == PushAudience.seller) {
      return session.managesBusiness(businessId);
    }
    return true;
  }

  /// `true` si la URL es una ruta interna de la app (nunca se navega a una externa).
  bool get hasInternalUrl {
    final value = url;
    return value != null && value.startsWith('/');
  }
}
