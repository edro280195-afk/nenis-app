import 'package:flutter/widgets.dart';

/// Premio canjeable de lealtad visto por la compradora. El backend usa
/// `LoyaltyRewardType` (FixedDiscount | FreeShipping | Gift) y lo manda como
/// string en `type`.
class BuyerReward {
  const BuyerReward({
    required this.id,
    required this.name,
    required this.pointsCost,
    required this.type,
    required this.value,
    this.description,
    this.icon,
  });

  final int id;
  final String name;
  final String? description;
  final int pointsCost;
  final String type;
  final double value;
  final String? icon;

  /// Categoría visual simplificada para iconografía y copy.
  String get kind {
    switch (type) {
      case 'FreeShipping':
        return 'shipping';
      case 'Gift':
        return 'gift';
      default:
        return 'discount';
    }
  }

  String get costLabel => '$pointsCost pts';

  factory BuyerReward.fromJson(Map<String, dynamic> j) => BuyerReward(
        id: (j['id'] as num).toInt(),
        name: (j['name'] ?? '') as String,
        description: j['description'] as String?,
        pointsCost: (j['pointsCost'] as num?)?.toInt() ?? 0,
        type: (j['type'] ?? 'FixedDiscount') as String,
        value: (j['value'] as num?)?.toDouble() ?? 0,
        icon: j['icon'] as String?,
      );
}

/// Catálogo de premios activos de una tienda de la compradora, junto con los
/// puntos que ella tiene acumulados ahí. `rewards` puede ser vacío si la
/// tienda aún no configuró su catálogo.
class RewardsByBusiness {
  const RewardsByBusiness({
    required this.businessId,
    required this.businessName,
    required this.brandPrimaryColor,
    required this.storePoints,
    this.logoUrl,
    this.rewards = const [],
  });

  final int businessId;
  final String businessName;
  final String brandPrimaryColor;
  final String? logoUrl;
  final int storePoints;
  final List<BuyerReward> rewards;

  String get initial => businessName.isNotEmpty
      ? businessName.characters.first.toUpperCase()
      : '?';

  bool get hasRewards => rewards.isNotEmpty;

  factory RewardsByBusiness.fromJson(Map<String, dynamic> j) => RewardsByBusiness(
        businessId: (j['businessId'] as num).toInt(),
        businessName: (j['businessName'] ?? '') as String,
        brandPrimaryColor: (j['brandPrimaryColor'] ?? '#FB6F9C') as String,
        logoUrl: j['logoUrl'] as String?,
        storePoints: (j['storePoints'] as num?)?.toInt() ?? 0,
        rewards: ((j['rewards'] as List?) ?? const [])
            .map((e) => BuyerReward.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
