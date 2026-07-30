/// Fila de la lista de seguidoras que gestiona la vendedora
/// (`StoreFollowerAdminDto`).
class SellerFollowerAdmin {
  const SellerFollowerAdmin({
    required this.accountId,
    required this.displayName,
    required this.followedAt,
    required this.isVip,
    this.vipSince,
  });

  final int accountId;
  final String displayName;
  final DateTime followedAt;
  final bool isVip;
  final DateTime? vipSince;

  SellerFollowerAdmin copyWith({bool? isVip, DateTime? vipSince}) => SellerFollowerAdmin(
        accountId: accountId,
        displayName: displayName,
        followedAt: followedAt,
        isVip: isVip ?? this.isVip,
        vipSince: vipSince ?? this.vipSince,
      );

  factory SellerFollowerAdmin.fromJson(Map<String, dynamic> j) => SellerFollowerAdmin(
        accountId: (j['accountId'] as num).toInt(),
        displayName: (j['displayName'] ?? 'Clienta') as String,
        followedAt: DateTime.tryParse(j['followedAt']?.toString() ?? '') ?? DateTime.now(),
        isVip: (j['isVip'] as bool?) ?? false,
        vipSince: j['vipSince'] != null ? DateTime.tryParse(j['vipSince'].toString()) : null,
      );
}
