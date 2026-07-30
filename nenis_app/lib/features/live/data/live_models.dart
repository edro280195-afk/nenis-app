/// Evento que llega por SignalR (`ProductAnnounced`) cuando la vendedora
/// anuncia qué producto está mostrando ahora mismo en su Live.
class LiveProductAnnouncement {
  const LiveProductAnnouncement({
    required this.productId,
    required this.name,
    required this.price,
    required this.announcedAt,
  });

  final int productId;
  final String name;
  final double price;
  final DateTime announcedAt;

  factory LiveProductAnnouncement.fromJson(Map<String, dynamic> j) =>
      LiveProductAnnouncement(
        productId: (j['productId'] as num).toInt(),
        name: (j['name'] ?? '') as String,
        price: (j['price'] as num?)?.toDouble() ?? 0,
        announcedAt: DateTime.tryParse(j['announcedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

/// Producto del catálogo de la vendedora, para el picker de "anunciar".
class SellerProduct {
  const SellerProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
  });

  final int id;
  final String name;
  final double price;
  final int stock;

  factory SellerProduct.fromJson(Map<String, dynamic> j) => SellerProduct(
        id: (j['id'] as num).toInt(),
        name: (j['name'] ?? '') as String,
        price: (j['price'] as num?)?.toDouble() ?? 0,
        stock: (j['stock'] as num?)?.toInt() ?? 0,
      );
}
