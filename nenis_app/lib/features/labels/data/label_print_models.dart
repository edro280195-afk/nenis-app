enum LabelMediaSize {
  shipping4x6(
    api: 'Shipping4x6',
    label: 'Envío 4 × 6”',
    detail: 'Ideal para bolsas con dirección y contenido',
    widthMm: 101.6,
    heightMm: 152.4,
  ),
  square50x50(
    api: 'Square50x50',
    label: 'Cuadrada 50 × 50 mm',
    detail: 'Compacta para identificar cada bolsa',
    widthMm: 50,
    heightMm: 50,
  );

  const LabelMediaSize({
    required this.api,
    required this.label,
    required this.detail,
    required this.widthMm,
    required this.heightMm,
  });

  final String api;
  final String label;
  final String detail;
  final double widthMm;
  final double heightMm;

  static LabelMediaSize fromApi(String value) {
    return LabelMediaSize.values.firstWhere(
      (size) => size.api == value,
      orElse: () => LabelMediaSize.shipping4x6,
    );
  }
}

class LabelPrintPayload {
  const LabelPrintPayload({
    required this.businessName,
    required this.order,
    required this.package,
  });

  final String businessName;
  final LabelOrderPayload order;
  final LabelPackagePayload package;

  factory LabelPrintPayload.fromJson(Map<String, dynamic> json) {
    return LabelPrintPayload(
      businessName: (json['businessName'] ?? '') as String,
      order: LabelOrderPayload.fromJson(
        (json['order'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      package: LabelPackagePayload.fromJson(
        (json['package'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}

class LabelOrderPayload {
  const LabelOrderPayload({
    required this.id,
    required this.clientName,
    this.phone,
    this.address,
    required this.itemSummary,
    this.deliveryInstructions,
  });

  final int id;
  final String clientName;
  final String? phone;
  final String? address;
  final String itemSummary;
  final String? deliveryInstructions;

  factory LabelOrderPayload.fromJson(Map<String, dynamic> json) {
    return LabelOrderPayload(
      id: (json['id'] as num?)?.toInt() ?? 0,
      clientName: (json['clientName'] ?? '') as String,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      itemSummary: (json['itemSummary'] ?? '') as String,
      deliveryInstructions: json['deliveryInstructions'] as String?,
    );
  }
}

class LabelPackagePayload {
  const LabelPackagePayload({
    required this.id,
    required this.number,
    required this.total,
    required this.qrCodeValue,
  });

  final String id;
  final int number;
  final int total;
  final String qrCodeValue;

  factory LabelPackagePayload.fromJson(Map<String, dynamic> json) {
    return LabelPackagePayload(
      id: (json['id'] ?? '') as String,
      number: (json['number'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      qrCodeValue: (json['qrCodeValue'] ?? '') as String,
    );
  }
}

class LabelTemplateVersionSnapshot {
  const LabelTemplateVersionSnapshot({
    required this.id,
    required this.versionNumber,
    required this.designJson,
  });

  final String id;
  final int versionNumber;
  final String designJson;

  factory LabelTemplateVersionSnapshot.fromJson(Map<String, dynamic> json) {
    return LabelTemplateVersionSnapshot(
      id: (json['id'] ?? '') as String,
      versionNumber: (json['versionNumber'] as num?)?.toInt() ?? 0,
      designJson: (json['designJson'] ?? '') as String,
    );
  }
}

class LabelAssetSnapshot {
  const LabelAssetSnapshot({required this.id, required this.url});

  final String id;
  final String url;

  factory LabelAssetSnapshot.fromJson(Map<String, dynamic> json) {
    return LabelAssetSnapshot(
      id: (json['id'] ?? '') as String,
      url: (json['url'] ?? '') as String,
    );
  }
}

class LabelPrintJobItem {
  const LabelPrintJobItem({
    required this.id,
    required this.orderPackageId,
    required this.sequence,
    required this.packageQrCodeValue,
    required this.payload,
  });

  final String id;
  final String orderPackageId;
  final int sequence;
  final String packageQrCodeValue;
  final LabelPrintPayload payload;

  factory LabelPrintJobItem.fromJson(Map<String, dynamic> json) {
    return LabelPrintJobItem(
      id: (json['id'] ?? '') as String,
      orderPackageId: (json['orderPackageId'] ?? '') as String,
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      packageQrCodeValue: (json['packageQrCodeValue'] ?? '') as String,
      payload: LabelPrintPayload.fromJson(
        (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}

class LabelPrintJob {
  const LabelPrintJob({
    required this.id,
    required this.status,
    required this.mediaSize,
    required this.output,
    required this.copies,
    required this.templateVersion,
    required this.assets,
    required this.items,
  });

  final String id;
  final String status;
  final LabelMediaSize mediaSize;
  final String output;
  final int copies;
  final LabelTemplateVersionSnapshot templateVersion;
  final List<LabelAssetSnapshot> assets;
  final List<LabelPrintJobItem> items;

  int get totalLabels => items.length * copies;

  factory LabelPrintJob.fromJson(Map<String, dynamic> json) {
    return LabelPrintJob(
      id: (json['id'] ?? '') as String,
      status: (json['status'] ?? '') as String,
      mediaSize: LabelMediaSize.fromApi((json['mediaSize'] ?? '') as String),
      output: (json['output'] ?? '') as String,
      copies: (json['copies'] as num?)?.toInt() ?? 1,
      templateVersion: LabelTemplateVersionSnapshot.fromJson(
        (json['templateVersion'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      assets: ((json['assets'] as List?) ?? const [])
          .map(
            (asset) => LabelAssetSnapshot.fromJson(
              (asset as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
      items: ((json['items'] as List?) ?? const [])
          .map(
            (item) => LabelPrintJobItem.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}

class AvailableLabelPackage {
  const AvailableLabelPackage({
    required this.id,
    required this.orderId,
    required this.clientName,
    required this.packageNumber,
    required this.totalPackages,
    required this.status,
  });

  final String id;
  final int orderId;
  final String clientName;
  final int packageNumber;
  final int totalPackages;
  final String status;

  factory AvailableLabelPackage.fromJson(Map<String, dynamic> json) {
    return AvailableLabelPackage(
      id: (json['id'] ?? '') as String,
      orderId: (json['orderId'] as num?)?.toInt() ?? 0,
      clientName: (json['clientName'] ?? '') as String,
      packageNumber: (json['packageNumber'] as num?)?.toInt() ?? 0,
      totalPackages: (json['totalPackages'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? '') as String,
    );
  }
}

class OrderPackageLabel {
  const OrderPackageLabel({
    required this.id,
    required this.packageNumber,
    required this.qrCodeValue,
    required this.status,
  });

  final String id;
  final int packageNumber;
  final String qrCodeValue;
  final String status;

  factory OrderPackageLabel.fromJson(Map<String, dynamic> json) {
    return OrderPackageLabel(
      id: (json['id'] ?? '') as String,
      packageNumber: (json['packageNumber'] as num?)?.toInt() ?? 0,
      qrCodeValue: (json['qrCodeValue'] ?? '') as String,
      status: (json['status'] ?? '') as String,
    );
  }
}
