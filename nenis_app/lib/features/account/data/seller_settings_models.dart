class SellerBusinessSettings {
  const SellerBusinessSettings({
    required this.id,
    required this.name,
    required this.slug,
    required this.brand,
    required this.subscription,
    required this.features,
    this.city,
  });

  final int id;
  final String name;
  final String slug;
  final String? city;
  final SellerBrandSettings brand;
  final SellerSubscriptionSettings subscription;
  final List<String> features;

  factory SellerBusinessSettings.fromJson(Map<String, dynamic> json) {
    return SellerBusinessSettings(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      city: json['city'] as String?,
      brand: SellerBrandSettings.fromJson(
        (json['brand'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      subscription: SellerSubscriptionSettings.fromJson(
        (json['subscription'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      features: ((json['features'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class SellerBrandSettings {
  const SellerBrandSettings({
    required this.primaryColor,
    this.logoUrl,
    this.bannerUrl,
    this.accentColor,
  });

  final String? logoUrl;
  final String? bannerUrl;
  final String primaryColor;
  final String? accentColor;

  factory SellerBrandSettings.fromJson(Map<String, dynamic> json) {
    return SellerBrandSettings(
      logoUrl: json['logoUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      primaryColor: json['brandPrimaryColor'] as String? ?? '#FB6F9C',
      accentColor: json['brandAccentColor'] as String?,
    );
  }
}

class SellerSubscriptionSettings {
  const SellerSubscriptionSettings({
    required this.effectivePlan,
    required this.subscriptionStatus,
    required this.isLocked,
    required this.daysLeft,
  });

  final String effectivePlan;
  final String subscriptionStatus;
  final bool isLocked;
  final int daysLeft;

  factory SellerSubscriptionSettings.fromJson(Map<String, dynamic> json) {
    return SellerSubscriptionSettings(
      effectivePlan: json['effectivePlan'] as String? ?? 'Entrada',
      subscriptionStatus: json['subscriptionStatus'] as String? ?? 'Active',
      isLocked: json['isLocked'] as bool? ?? false,
      daysLeft: (json['daysLeft'] as num?)?.toInt() ?? 0,
    );
  }
}

class MercadoPagoSettings {
  const MercadoPagoSettings({
    this.publicKey,
    required this.hasAccessToken,
    required this.isConfigured,
  });

  final String? publicKey;
  final bool hasAccessToken;
  final bool isConfigured;

  factory MercadoPagoSettings.fromJson(Map<String, dynamic> json) {
    return MercadoPagoSettings(
      publicKey: json['publicKey'] as String?,
      hasAccessToken: json['hasAccessToken'] as bool? ?? false,
      isConfigured: json['isConfigured'] as bool? ?? false,
    );
  }
}

enum SellerPayoutAccountKind {
  clabe,
  debitCard,
  bankAccount,
  phone;

  String get apiValue => switch (this) {
    SellerPayoutAccountKind.clabe => 'clabe',
    SellerPayoutAccountKind.debitCard => 'debitCard',
    SellerPayoutAccountKind.bankAccount => 'bankAccount',
    SellerPayoutAccountKind.phone => 'phone',
  };

  String get label => switch (this) {
    SellerPayoutAccountKind.clabe => 'CLABE',
    SellerPayoutAccountKind.debitCard => 'Tarjeta',
    SellerPayoutAccountKind.bankAccount => 'Cuenta',
    SellerPayoutAccountKind.phone => 'Celular SPEI',
  };

  String get helper => switch (this) {
    SellerPayoutAccountKind.clabe => '18 dígitos con validación bancaria',
    SellerPayoutAccountKind.debitCard => '16 dígitos, sin CVV ni vencimiento',
    SellerPayoutAccountKind.bankAccount => 'Número de cuenta del banco',
    SellerPayoutAccountKind.phone => 'Celular vinculado a SPEI',
  };

  int? get exactLength => switch (this) {
    SellerPayoutAccountKind.clabe => 18,
    SellerPayoutAccountKind.debitCard => 16,
    SellerPayoutAccountKind.phone => 10,
    SellerPayoutAccountKind.bankAccount => null,
  };

  static SellerPayoutAccountKind fromApi(String? value) {
    return switch ((value ?? '').trim()) {
      'debitCard' => SellerPayoutAccountKind.debitCard,
      'bankAccount' => SellerPayoutAccountKind.bankAccount,
      'phone' => SellerPayoutAccountKind.phone,
      _ => SellerPayoutAccountKind.clabe,
    };
  }
}

class SellerPayoutAccount {
  const SellerPayoutAccount({
    required this.id,
    required this.kind,
    required this.kindLabel,
    required this.holderName,
    required this.maskedNumber,
    required this.numberLength,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
    this.bankName,
    this.alias,
    this.notes,
  });

  final int id;
  final SellerPayoutAccountKind kind;
  final String kindLabel;
  final String holderName;
  final String? bankName;
  final String? alias;
  final String maskedNumber;
  final int numberLength;
  final String? notes;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName {
    final cleanAlias = alias?.trim();
    if (cleanAlias != null && cleanAlias.isNotEmpty) return cleanAlias;
    final cleanBank = bankName?.trim();
    if (cleanBank != null && cleanBank.isNotEmpty) return cleanBank;
    return kindLabel;
  }

  factory SellerPayoutAccount.fromJson(Map<String, dynamic> json) {
    return SellerPayoutAccount(
      id: (json['id'] as num).toInt(),
      kind: SellerPayoutAccountKind.fromApi(json['kind'] as String?),
      kindLabel: json['kindLabel'] as String? ?? 'Cuenta',
      holderName: json['holderName'] as String? ?? '',
      bankName: json['bankName'] as String?,
      alias: json['alias'] as String?,
      maskedNumber: json['maskedNumber'] as String? ?? '',
      numberLength: (json['numberLength'] as num?)?.toInt() ?? 0,
      notes: json['notes'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class SellerPreferenceSettings {
  const SellerPreferenceSettings({
    this.notifyNewOrders = true,
    this.notifyRouteChanges = true,
    this.autoCopyClientMessage = true,
    this.requirePaymentBeforeRoute = false,
    this.defaultDeliveryWindow = 'Domingos por la tarde',
  });

  final bool notifyNewOrders;
  final bool notifyRouteChanges;
  final bool autoCopyClientMessage;
  final bool requirePaymentBeforeRoute;
  final String defaultDeliveryWindow;

  SellerPreferenceSettings copyWith({
    bool? notifyNewOrders,
    bool? notifyRouteChanges,
    bool? autoCopyClientMessage,
    bool? requirePaymentBeforeRoute,
    String? defaultDeliveryWindow,
  }) {
    return SellerPreferenceSettings(
      notifyNewOrders: notifyNewOrders ?? this.notifyNewOrders,
      notifyRouteChanges: notifyRouteChanges ?? this.notifyRouteChanges,
      autoCopyClientMessage:
          autoCopyClientMessage ?? this.autoCopyClientMessage,
      requirePaymentBeforeRoute:
          requirePaymentBeforeRoute ?? this.requirePaymentBeforeRoute,
      defaultDeliveryWindow:
          defaultDeliveryWindow ?? this.defaultDeliveryWindow,
    );
  }
}
