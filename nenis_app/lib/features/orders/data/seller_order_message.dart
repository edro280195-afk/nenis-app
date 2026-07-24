import 'seller_orders_models.dart';

const _weekdays = [
  'domingo',
  'lunes',
  'martes',
  'mi\u00E9rcoles',
  'jueves',
  'viernes',
  's\u00E1bado',
];

const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String publicOrderLink(String link) => link.replaceFirst('/o/', '/pedido/');

String buildSellerOrderMessage(SellerOrder order) {
  final name = order.clientName.trim().isEmpty
      ? 'bonita'
      : order.clientName.trim();
  // Preferimos el enlace corto compartible (dominio compartido, /o/{token}),
  // que orilla a instalar la app. Si el backend no lo mandó (ShareLinkBaseUrl
  // sin configurar), caemos al enlace público legacy (/pedido/{token}).
  final link = (order.shareUrl?.trim().isNotEmpty ?? false)
      ? order.shareUrl!.trim()
      : publicOrderLink(order.link ?? '');
  final deliveryDate =
      order.scheduledDeliveryDate ??
      order.expiresAt?.subtract(const Duration(days: 1));
  final pickupLimit = deliveryDate?.subtract(const Duration(days: 1));
  final deliveryLabel = _formatSpanishDate(deliveryDate);
  final pickupLimitLabel = _formatSpanishDate(pickupLimit);

  final lines = <String>[
    'Hola $name, aqu\u00ED te dejo tu total de compras \u{2705}\u{1F6CD}\u{FE0F}',
    link,
    '',
  ];

  if (deliveryLabel != null) {
    lines.add('Fecha de entrega es el $deliveryLabel.');
  }
  if (pickupLimitLabel != null) {
    lines.add(
      'Fecha l\u00EDmite para pasar a recoger tu pedido: $pickupLimitLabel.',
    );
  }

  lines
    ..add('')
    ..add('📲 *Rastrea tu paquete y descarga la App de Clientas:*')
    ..add(link)
    ..add('')
    ..add('Cualquier duda quedamos al pendiente. ❤️✨');

  return lines.join('\n');
}


String? _formatSpanishDate(DateTime? date) {
  if (date == null) return null;
  final local = date.toLocal();
  return '${_weekdays[local.weekday % 7]} ${local.day} de ${_months[local.month - 1]}';
}
