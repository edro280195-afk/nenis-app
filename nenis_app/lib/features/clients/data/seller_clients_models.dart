import 'package:intl/intl.dart';

String clientMoney(num value) =>
    '\$${NumberFormat('#,##0', 'es_MX').format(value)}';

int _i(dynamic value) => value == null ? 0 : (value as num).toInt();
double _d(dynamic value) => value == null ? 0 : (value as num).toDouble();

enum SellerClientTag {
  none,
  risingStar,
  vip,
  blacklist;

  static SellerClientTag fromApi(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'risingstar':
        return SellerClientTag.risingStar;
      case 'vip':
        return SellerClientTag.vip;
      case 'blacklist':
        return SellerClientTag.blacklist;
      default:
        return SellerClientTag.none;
    }
  }

  String get api => switch (this) {
    SellerClientTag.none => 'None',
    SellerClientTag.risingStar => 'RisingStar',
    SellerClientTag.vip => 'Vip',
    SellerClientTag.blacklist => 'Blacklist',
  };

  String get label => switch (this) {
    SellerClientTag.none => 'Normal',
    SellerClientTag.risingStar => 'En ascenso',
    SellerClientTag.vip => 'Consentida',
    SellerClientTag.blacklist => 'Lista negra',
  };
}

enum SellerClientSegment {
  all,
  newClients,
  frequent,
  vip,
  needsAddress,
  needsLocation;

  String get label => switch (this) {
    SellerClientSegment.all => 'Todas',
    SellerClientSegment.newClients => 'Nuevas',
    SellerClientSegment.frequent => 'Frecuentes',
    SellerClientSegment.vip => 'VIP',
    SellerClientSegment.needsAddress => 'Sin dirección',
    SellerClientSegment.needsLocation => 'Por ubicar',
  };
}

enum SellerClientSort {
  spent,
  orders,
  name,
  location;

  String get label => switch (this) {
    SellerClientSort.spent => 'Mayor compra',
    SellerClientSort.orders => 'Más pedidos',
    SellerClientSort.name => 'Nombre A-Z',
    SellerClientSort.location => 'Pendientes de ubicación',
  };
}

class SellerClientProfile {
  const SellerClientProfile({
    required this.id,
    required this.name,
    required this.tag,
    required this.ordersCount,
    required this.totalSpent,
    required this.type,
    this.phone,
    this.address,
    this.deliveryInstructions,
    this.latitude,
    this.longitude,
    this.aliases = const [],
    this.facebookProfileUrl,
  });

  final int id;
  final String name;
  final SellerClientTag tag;
  final int ordersCount;
  final double totalSpent;
  final String type;
  final String? phone;
  final String? address;
  final String? deliveryInstructions;
  final double? latitude;
  final double? longitude;
  final List<String> aliases;
  final String? facebookProfileUrl;

  bool get isFrequent =>
      ordersCount > 0 || type.trim().toLowerCase() == 'frecuente';
  bool get isVip => tag == SellerClientTag.vip;
  bool get hasPhone => phone?.trim().isNotEmpty ?? false;
  bool get hasAddress => address?.trim().isNotEmpty ?? false;
  bool get hasCoordinates => latitude != null && longitude != null;
  bool get needsAddress => !hasAddress;
  bool get needsLocation => hasAddress && !hasCoordinates;
  String get initial =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
  String get displayType => type.trim().isEmpty ? 'Nueva' : type.trim();

  String get searchableText {
    final parts = [
      name,
      phone,
      address,
      deliveryInstructions,
      displayType,
      tag.label,
      ...aliases,
    ];
    return parts.whereType<String>().join(' ').toLowerCase();
  }

  factory SellerClientProfile.fromJson(Map<String, dynamic> json) {
    return SellerClientProfile(
      id: _i(json['id']),
      name: (json['name'] ?? '') as String,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      tag: SellerClientTag.fromApi(json['tag'] as String?),
      ordersCount: _i(json['ordersCount']),
      totalSpent: _d(json['totalSpent']),
      type: (json['type'] ?? 'Nueva') as String,
      deliveryInstructions: json['deliveryInstructions'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      aliases: ((json['aliases'] as List?) ?? const [])
          .map((value) => value.toString())
          .toList(),
      facebookProfileUrl: json['facebookProfileUrl'] as String?,
    );
  }
}

class UpdateSellerClientRequest {
  const UpdateSellerClientRequest({
    required this.name,
    required this.tag,
    required this.type,
    this.phone,
    this.address,
    this.deliveryInstructions,
    this.facebookProfileUrl,
  });

  final String name;
  final SellerClientTag tag;
  final String type;
  final String? phone;
  final String? address;
  final String? deliveryInstructions;
  final String? facebookProfileUrl;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'phone': phone?.trim(),
    'address': address?.trim(),
    'tag': tag.api,
    'type': type.trim().isEmpty ? 'Nueva' : type.trim(),
    'deliveryInstructions': deliveryInstructions?.trim(),
    if (facebookProfileUrl != null) 'facebookProfileUrl': facebookProfileUrl,
  };
}

class SellerClientAlias {
  const SellerClientAlias({
    required this.id,
    required this.alias,
    required this.source,
    required this.timesSeen,
    required this.createdAt,
  });

  final int id;
  final String alias;
  final String source;
  final int timesSeen;
  final DateTime createdAt;

  factory SellerClientAlias.fromJson(Map<String, dynamic> json) {
    return SellerClientAlias(
      id: _i(json['id']),
      alias: (json['alias'] ?? '') as String,
      source: (json['source'] ?? '') as String,
      timesSeen: _i(json['timesSeen']),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '') as String)?.toLocal() ??
          DateTime.now(),
    );
  }
}

class SellerClientLoyaltySummary {
  const SellerClientLoyaltySummary({
    required this.clientId,
    required this.clientName,
    required this.currentPoints,
    required this.lifetimePoints,
    required this.tier,
    required this.tierKey,
    this.lastAccrual,
  });

  final int clientId;
  final String clientName;
  final int currentPoints;
  final int lifetimePoints;
  final String tier;
  final String tierKey;
  final DateTime? lastAccrual;

  double get tierProgress {
    if (lifetimePoints >= 300) return 1;
    if (lifetimePoints >= 100) return (lifetimePoints - 100) / 200;
    return lifetimePoints / 100;
  }

  String get nextTierLabel {
    if (lifetimePoints >= 300) return 'Nivel máximo';
    if (lifetimePoints >= 100) {
      return '${300 - lifetimePoints} pts para Diamante';
    }
    return '${100 - lifetimePoints} pts para Rose Gold';
  }

  factory SellerClientLoyaltySummary.fromJson(Map<String, dynamic> json) {
    return SellerClientLoyaltySummary(
      clientId: _i(json['clientId']),
      clientName: (json['clientName'] ?? '') as String,
      currentPoints: _i(json['currentPoints']),
      lifetimePoints: _i(json['lifetimePoints']),
      tier: (json['tier'] ?? 'Clienta Pink') as String,
      tierKey: (json['tierKey'] ?? 'pink') as String,
      lastAccrual: json['lastAccrual'] == null
          ? null
          : DateTime.tryParse(json['lastAccrual'] as String)?.toLocal(),
    );
  }
}

class SellerClientLoyaltyTransaction {
  const SellerClientLoyaltyTransaction({
    required this.id,
    required this.points,
    required this.reason,
    required this.date,
  });

  final int id;
  final int points;
  final String reason;
  final DateTime date;

  factory SellerClientLoyaltyTransaction.fromJson(Map<String, dynamic> json) {
    return SellerClientLoyaltyTransaction(
      id: _i(json['id']),
      points: _i(json['points']),
      reason: (json['reason'] ?? '') as String,
      date:
          DateTime.tryParse((json['date'] ?? '') as String)?.toLocal() ??
          DateTime.now(),
    );
  }
}

class SellerClientInsight {
  const SellerClientInsight({required this.text});
  final String text;

  factory SellerClientInsight.fromJson(Map<String, dynamic> json) {
    return SellerClientInsight(text: (json['text'] ?? '') as String);
  }
}

class BulkGeocodeResult {
  const BulkGeocodeResult({
    required this.clientId,
    required this.success,
    this.latitude,
    this.longitude,
    this.formattedAddress,
    this.error,
  });

  final int clientId;
  final bool success;
  final double? latitude;
  final double? longitude;
  final String? formattedAddress;
  final String? error;

  factory BulkGeocodeResult.fromJson(Map<String, dynamic> json) {
    return BulkGeocodeResult(
      clientId: _i(json['clientId']),
      success: json['success'] == true,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      formattedAddress: json['formattedAddress'] as String?,
      error: json['error'] as String?,
    );
  }
}
