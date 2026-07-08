/// Novedad de una tienda vista por la compradora, tal como la devuelve
/// `GET /api/me/store/{businessId}/posts` (`StorePostFeedItemDto`).
class StorePostFeedItem {
  const StorePostFeedItem({
    required this.id,
    required this.businessId,
    required this.body,
    required this.imageUrl,
    required this.isVipOnly,
    required this.isLocked,
    required this.createdAt,
  });

  final int id;
  final int businessId;
  final String body;
  final String? imageUrl;
  final bool isVipOnly;
  final bool isLocked;
  final DateTime createdAt;

  factory StorePostFeedItem.fromJson(Map<String, dynamic> j) => StorePostFeedItem(
        id: (j['id'] as num).toInt(),
        businessId: (j['businessId'] as num).toInt(),
        body: (j['body'] ?? '') as String,
        imageUrl: j['imageUrl'] as String?,
        isVipOnly: (j['isVipOnly'] as bool?) ?? false,
        isLocked: (j['isLocked'] as bool?) ?? false,
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );
}
