import 'dart:convert';

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

class MexicanBank {
  const MexicanBank({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.gradientStart,
    required this.gradientEnd,
    this.onPrimaryColor,
  });

  final String id;
  final String name;
  final String primaryColor;
  final String gradientStart;
  final String gradientEnd;
  final String? onPrimaryColor;

  String get onPrimary => onPrimaryColor ?? '#FFFFFF';

  static const List<MexicanBank> all = [
    MexicanBank(
      id: 'bbva',
      name: 'BBVA',
      primaryColor: '#004B93',
      gradientStart: '#004B93',
      gradientEnd: '#0066C0',
    ),
    MexicanBank(
      id: 'banorte',
      name: 'Banorte',
      primaryColor: '#C41230',
      gradientStart: '#C41230',
      gradientEnd: '#EB0029',
    ),
    MexicanBank(
      id: 'santander',
      name: 'Santander',
      primaryColor: '#EC0000',
      gradientStart: '#D40000',
      gradientEnd: '#EC0000',
    ),
    MexicanBank(
      id: 'banamex',
      name: 'Citibanamex',
      primaryColor: '#003B71',
      gradientStart: '#002850',
      gradientEnd: '#004D94',
    ),
    MexicanBank(
      id: 'hsbc',
      name: 'HSBC',
      primaryColor: '#DB0011',
      gradientStart: '#C0000E',
      gradientEnd: '#DB0011',
    ),
    MexicanBank(
      id: 'azteca',
      name: 'Banco Azteca',
      primaryColor: '#00A650',
      gradientStart: '#008040',
      gradientEnd: '#00BF5C',
    ),
    MexicanBank(
      id: 'banregio',
      name: 'BanRegio',
      primaryColor: '#FF6600',
      gradientStart: '#E55D00',
      gradientEnd: '#FF7519',
    ),
    MexicanBank(
      id: 'bancoppel',
      name: 'BanCoppel',
      primaryColor: '#F7B61A',
      gradientStart: '#E5A710',
      gradientEnd: '#FCC939',
      onPrimaryColor: '#3A2233',
    ),
    MexicanBank(
      id: 'scotiabank',
      name: 'Scotiabank',
      primaryColor: '#EE3124',
      gradientStart: '#D42018',
      gradientEnd: '#DC1E14',
    ),
    MexicanBank(
      id: 'inbursa',
      name: 'Inbursa',
      primaryColor: '#003B5C',
      gradientStart: '#002A42',
      gradientEnd: '#004E7A',
    ),
    MexicanBank(
      id: 'bajio',
      name: 'BanBajío',
      primaryColor: '#004B87',
      gradientStart: '#003560',
      gradientEnd: '#0063AC',
    ),
    MexicanBank(
      id: 'nubank',
      name: 'Nu',
      primaryColor: '#820AD1',
      gradientStart: '#6B00B0',
      gradientEnd: '#9A20E8',
    ),
    MexicanBank(
      id: 'hey',
      name: 'Hey Banco',
      primaryColor: '#00E5A1',
      gradientStart: '#00C98A',
      gradientEnd: '#1AFFBB',
      onPrimaryColor: '#3A2233',
    ),
    MexicanBank(
      id: 'spin',
      name: 'Spin (OXXO)',
      primaryColor: '#E31E25',
      gradientStart: '#C41A20',
      gradientEnd: '#F03038',
    ),
    MexicanBank(
      id: 'mercadopago',
      name: 'Mercado Pago',
      primaryColor: '#009EE3',
      gradientStart: '#0085C0',
      gradientEnd: '#20B8FF',
    ),
    MexicanBank(
      id: 'amex',
      name: 'American Express',
      primaryColor: '#006FCF',
      gradientStart: '#0059A8',
      gradientEnd: '#0088EE',
    ),
    MexicanBank(
      id: 'bienestar',
      name: 'Bienestar',
      primaryColor: '#006847',
      gradientStart: '#004D33',
      gradientEnd: '#008A5C',
    ),
    MexicanBank(
      id: 'compartamos',
      name: 'Compartamos',
      primaryColor: '#DA291C',
      gradientStart: '#BA2015',
      gradientEnd: '#E84035',
    ),
    MexicanBank(
      id: 'afirme',
      name: 'Afirme',
      primaryColor: '#003DA5',
      gradientStart: '#002E80',
      gradientEnd: '#0050CC',
    ),
    MexicanBank(
      id: 'uala',
      name: 'Ualá',
      primaryColor: '#7700FF',
      gradientStart: '#5E00CC',
      gradientEnd: '#9030FF',
    ),
    MexicanBank(
      id: 'revolut',
      name: 'Revolut',
      primaryColor: '#000000',
      gradientStart: '#000000',
      gradientEnd: '#333333',
    ),
    MexicanBank(
      id: 'klar',
      name: 'Klar',
      primaryColor: '#1A1A2E',
      gradientStart: '#0F0F1F',
      gradientEnd: '#252545',
    ),
    MexicanBank(
      id: 'cuenca',
      name: 'Cuenca',
      primaryColor: '#3A10E5',
      gradientStart: '#2D0CB8',
      gradientEnd: '#5530FF',
    ),
    MexicanBank(
      id: 'albo',
      name: 'Albo',
      primaryColor: '#6F41E1',
      gradientStart: '#5828C8',
      gradientEnd: '#8A60F0',
    ),
    MexicanBank(
      id: 'fondeadora',
      name: 'Fondeadora',
      primaryColor: '#111111',
      gradientStart: '#000000',
      gradientEnd: '#2A2A2A',
    ),
    MexicanBank(
      id: 'stori',
      name: 'Stori',
      primaryColor: '#643B9F',
      gradientStart: '#4E2E80',
      gradientEnd: '#7B50C0',
    ),
    MexicanBank(
      id: 'rappi',
      name: 'RappiCard',
      primaryColor: '#FF441F',
      gradientStart: '#E03514',
      gradientEnd: '#FF6040',
    ),
    MexicanBank(
      id: 'other',
      name: 'Otro banco',
      primaryColor: '#E8E8EC',
      gradientStart: '#D8D8DE',
      gradientEnd: '#F5F5F8',
      onPrimaryColor: '#3A2233',
    ),
  ];

  static MexicanBank byId(String? id) {
    if (id == null) return all.last;
    return all.cast<MexicanBank?>().firstWhere(
          (b) => b!.id == id,
          orElse: () => null,
        ) ??
        all.last;
  }

  static MexicanBank? tryMatchName(String? bankName) {
    if (bankName == null || bankName.trim().isEmpty) return null;
    final lower = bankName.toLowerCase().trim();
    for (final bank in all) {
      if (bank.id == 'other') continue;
      if (lower.contains(bank.name.toLowerCase().replaceAll(' ', '')) ||
          lower.contains(bank.id.toLowerCase())) {
        return bank;
      }
    }
    return null;
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

  MexicanBank? get matchedBank => MexicanBank.tryMatchName(bankName);

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

  factory SellerPreferenceSettings.fromJson(Map<String, dynamic> json) {
    return SellerPreferenceSettings(
      notifyNewOrders: json['notifyNewOrders'] as bool? ?? true,
      notifyRouteChanges: json['notifyRouteChanges'] as bool? ?? true,
      autoCopyClientMessage: json['autoCopyClientMessage'] as bool? ?? true,
      requirePaymentBeforeRoute:
          json['requirePaymentBeforeRoute'] as bool? ?? false,
      defaultDeliveryWindow:
          json['defaultDeliveryWindow'] as String? ?? 'Domingos por la tarde',
    );
  }

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

  Map<String, dynamic> toJson() {
    return {
      'notifyNewOrders': notifyNewOrders,
      'notifyRouteChanges': notifyRouteChanges,
      'autoCopyClientMessage': autoCopyClientMessage,
      'requirePaymentBeforeRoute': requirePaymentBeforeRoute,
      'defaultDeliveryWindow': defaultDeliveryWindow,
    };
  }

  String encode() => jsonEncode(toJson());

  static SellerPreferenceSettings decode(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is Map) {
        return SellerPreferenceSettings.fromJson(data.cast<String, dynamic>());
      }
    } on FormatException {
      return const SellerPreferenceSettings();
    }
    return const SellerPreferenceSettings();
  }
}
