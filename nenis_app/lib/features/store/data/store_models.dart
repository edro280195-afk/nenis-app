import 'package:flutter/widgets.dart';

/// Tabs de la pantalla de tienda. El contenido de "Tandas" y "Sorteos"
/// se hidrata reusando los providers existentes (`tandasControllerProvider`
/// y `rafflesControllerProvider`) y filtrando client-side por `businessId`.
enum StoreTab { products, lives, novedades, tandas, sorteos }

extension StoreTabX on StoreTab {
  String get label {
    switch (this) {
      case StoreTab.products:
        return 'Productos';
      case StoreTab.lives:
        return 'En vivo';
      case StoreTab.novedades:
        return 'Novedades';
      case StoreTab.tandas:
        return 'Tandas';
      case StoreTab.sorteos:
        return 'Sorteos';
    }
  }
}

/// Detalle de una tienda visto por la compradora.
class BuyerStoreDetail {
  const BuyerStoreDetail({
    required this.businessId,
    required this.name,
    required this.brandPrimaryColor,
    required this.clientCount,
    required this.isVerified,
    required this.points,
    required this.products,
    required this.activeTandasCount,
    required this.activeRafflesCount,
    required this.followerCount,
    required this.isFollowing,
    required this.isVip,
    required this.isLiveNow,
    required this.ratingsCount,
    this.liveAnnouncementTitle,
    this.averageRating,
    this.slug,
    this.city,
    this.logoUrl,
    this.brandAccentColor,
    this.live,
  });

  final int businessId;
  final String name;
  final String? slug;
  final String? city;
  final String? logoUrl;
  final String brandPrimaryColor;
  final String? brandAccentColor;
  final int clientCount;
  final bool isVerified;
  final StorePoints points;
  final BuyerLiveSummary? live;
  final List<BuyerProduct> products;
  final int activeTandasCount;
  final int activeRafflesCount;
  final int followerCount;
  final bool isFollowing;
  final bool isVip;
  final bool isLiveNow;
  final String? liveAnnouncementTitle;
  final double? averageRating;
  final int ratingsCount;

  bool get hasRatings => ratingsCount > 0 && averageRating != null;

  String get initial => name.isNotEmpty
      ? name.characters.first.toUpperCase()
      : '?';

  factory BuyerStoreDetail.fromJson(Map<String, dynamic> j) => BuyerStoreDetail(
        businessId: (j['businessId'] as num).toInt(),
        name: (j['name'] ?? '') as String,
        slug: j['slug'] as String?,
        city: j['city'] as String?,
        logoUrl: j['logoUrl'] as String?,
        brandPrimaryColor: (j['brandPrimaryColor'] ?? '#FB6F9C') as String,
        brandAccentColor: j['brandAccentColor'] as String?,
        clientCount: (j['clientCount'] as num?)?.toInt() ?? 0,
        isVerified: (j['isVerified'] as bool?) ?? false,
        points: StorePoints.fromJson(
            (j['points'] as Map<String, dynamic>?) ?? const {}),
        live: j['live'] != null
            ? BuyerLiveSummary.fromJson(j['live'] as Map<String, dynamic>)
            : null,
        products: ((j['products'] as List?) ?? const [])
            .map((e) => BuyerProduct.fromJson(e as Map<String, dynamic>))
            .toList(),
        activeTandasCount: (j['activeTandasCount'] as num?)?.toInt() ?? 0,
        activeRafflesCount: (j['activeRafflesCount'] as num?)?.toInt() ?? 0,
        followerCount: (j['followerCount'] as num?)?.toInt() ?? 0,
        isFollowing: (j['isFollowing'] as bool?) ?? false,
        isVip: (j['isVip'] as bool?) ?? false,
        isLiveNow: (j['isLiveNow'] as bool?) ?? false,
        liveAnnouncementTitle: j['liveAnnouncementTitle'] as String?,
        averageRating: (j['averageRating'] as num?)?.toDouble(),
        ratingsCount: (j['ratingsCount'] as num?)?.toInt() ?? 0,
      );

  BuyerStoreDetail copyWith({
    int? followerCount,
    bool? isFollowing,
    bool? isVip,
  }) => BuyerStoreDetail(
        businessId: businessId,
        name: name,
        slug: slug,
        city: city,
        logoUrl: logoUrl,
        brandPrimaryColor: brandPrimaryColor,
        brandAccentColor: brandAccentColor,
        clientCount: clientCount,
        isVerified: isVerified,
        points: points,
        live: live,
        products: products,
        activeTandasCount: activeTandasCount,
        activeRafflesCount: activeRafflesCount,
        followerCount: followerCount ?? this.followerCount,
        isFollowing: isFollowing ?? this.isFollowing,
        isVip: isVip ?? this.isVip,
        isLiveNow: isLiveNow,
        liveAnnouncementTitle: liveAnnouncementTitle,
        averageRating: averageRating,
        ratingsCount: ratingsCount,
      );
}

/// Puntos que la compradora tiene acumulados en esta tienda, y el costo
/// de la próxima reward que podría alcanzar (null si la tienda no tiene
/// rewards configuradas).
class StorePoints {
  const StorePoints({required this.currentPoints, this.nextRewardAt});
  final int currentPoints;
  final int? nextRewardAt;

  factory StorePoints.fromJson(Map<String, dynamic> j) => StorePoints(
        currentPoints: (j['currentPoints'] as num?)?.toInt() ?? 0,
        nextRewardAt: (j['nextRewardAt'] as num?)?.toInt(),
      );
}

/// Resumen del live activo de la tienda (si hay).
class BuyerLiveSummary {
  const BuyerLiveSummary({
    required this.sessionId,
    required this.title,
    required this.viewerCount,
    this.topics,
    this.processedAt,
  });

  final int sessionId;
  final String title;
  final int viewerCount;
  final String? topics;
  final DateTime? processedAt;

  factory BuyerLiveSummary.fromJson(Map<String, dynamic> j) => BuyerLiveSummary(
        sessionId: (j['sessionId'] as num).toInt(),
        title: (j['title'] ?? 'Live') as String,
        viewerCount: (j['viewerCount'] as num?)?.toInt() ?? 0,
        topics: j['topics'] as String?,
        processedAt: j['processedAt'] != null
            ? DateTime.tryParse(j['processedAt'] as String)
            : null,
      );
}

/// Producto del catálogo público de la tienda. (El backend todavía no
/// expone imágenes, así que la app muestra placeholders con gradient.)
class BuyerProduct {
  const BuyerProduct({
    required this.id,
    required this.sku,
    required this.name,
    required this.price,
    required this.stock,
  });

  final int id;
  final String sku;
  final String name;
  final double price;
  final int stock;

  bool get inStock => stock > 0;

  factory BuyerProduct.fromJson(Map<String, dynamic> j) => BuyerProduct(
        id: (j['id'] as num).toInt(),
        sku: (j['sku'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        price: (j['price'] as num?)?.toDouble() ?? 0,
        stock: (j['stock'] as num?)?.toInt() ?? 0,
      );
}
