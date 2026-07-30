/// Estado de "seguir" de la compradora sobre una tienda, tal como lo
/// devuelve el backend (`GET/POST/PUT /api/me/follow/...`).
class FollowState {
  const FollowState({
    required this.businessId,
    required this.isFollowing,
    required this.notifyOnPost,
    required this.notifyOnLive,
    required this.isVip,
  });

  final int businessId;
  final bool isFollowing;
  final bool notifyOnPost;
  final bool notifyOnLive;
  final bool isVip;

  factory FollowState.fromJson(Map<String, dynamic> j) => FollowState(
        businessId: (j['businessId'] as num).toInt(),
        isFollowing: (j['isFollowing'] as bool?) ?? false,
        notifyOnPost: (j['notifyOnPost'] as bool?) ?? true,
        notifyOnLive: (j['notifyOnLive'] as bool?) ?? true,
        isVip: (j['isVip'] as bool?) ?? false,
      );
}
