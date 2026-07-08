/// Aviso "en vivo ahora" del lado vendedora (`LiveAnnouncementDto`).
class SellerLiveAnnouncement {
  const SellerLiveAnnouncement({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.isActive,
  });

  final int id;
  final String? title;
  final DateTime startedAt;
  final bool isActive;

  factory SellerLiveAnnouncement.fromJson(Map<String, dynamic> j) => SellerLiveAnnouncement(
        id: (j['id'] as num).toInt(),
        title: j['title'] as String?,
        startedAt: DateTime.tryParse(j['startedAt']?.toString() ?? '') ?? DateTime.now(),
        isActive: (j['isActive'] as bool?) ?? false,
      );
}

/// Novedad publicada por la vendedora (`StorePostDto`).
class SellerStorePost {
  const SellerStorePost({
    required this.id,
    required this.body,
    required this.imageUrl,
    required this.isVipOnly,
    required this.createdAt,
  });

  final int id;
  final String body;
  final String? imageUrl;
  final bool isVipOnly;
  final DateTime createdAt;

  factory SellerStorePost.fromJson(Map<String, dynamic> j) => SellerStorePost(
        id: (j['id'] as num).toInt(),
        body: (j['body'] ?? '') as String,
        imageUrl: j['imageUrl'] as String?,
        isVipOnly: (j['isVipOnly'] as bool?) ?? false,
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );
}
