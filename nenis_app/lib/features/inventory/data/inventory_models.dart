import '../../labels/data/label_print_models.dart';

class InventoryBoxSummary {
  const InventoryBoxSummary({
    required this.id,
    required this.code,
    required this.name,
    this.location,
    required this.isNfcBound,
    required this.articleTypesCount,
    required this.totalUnits,
  });
  final String id;
  final String code;
  final String name;
  final String? location;
  final bool isNfcBound;
  final int articleTypesCount;
  final int totalUnits;
  factory InventoryBoxSummary.fromJson(Map<String, dynamic> json) =>
      InventoryBoxSummary(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        location: json['location'] as String?,
        isNfcBound: json['isNfcBound'] as bool? ?? false,
        articleTypesCount: (json['articleTypesCount'] as num?)?.toInt() ?? 0,
        totalUnits: (json['totalUnits'] as num?)?.toInt() ?? 0,
      );
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    this.variant,
    this.barcode,
    required this.labelCode,
    required this.quantity,
  });
  final String id;
  final String name;
  final String? variant;
  final String? barcode;
  final String labelCode;
  final int quantity;
  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
    id: json['id'] as String,
    name: json['name'] as String,
    variant: json['variant'] as String?,
    barcode: json['barcode'] as String?,
    labelCode: json['labelCode'] as String,
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
  );
}

class InventoryMovement {
  const InventoryMovement({
    required this.id,
    this.itemName,
    required this.type,
    required this.quantityDelta,
    required this.quantityAfter,
    this.note,
    required this.performedBy,
    required this.occurredAt,
  });
  final String id;
  final String? itemName;
  final String type;
  final int quantityDelta;
  final int quantityAfter;
  final String? note;
  final String performedBy;
  final DateTime occurredAt;
  factory InventoryMovement.fromJson(Map<String, dynamic> json) =>
      InventoryMovement(
        id: json['id'] as String,
        itemName: json['itemName'] as String?,
        type: json['type'] as String,
        quantityDelta: (json['quantityDelta'] as num?)?.toInt() ?? 0,
        quantityAfter: (json['quantityAfter'] as num?)?.toInt() ?? 0,
        note: json['note'] as String?,
        performedBy: json['performedBy'] as String? ?? 'Sistema',
        occurredAt:
            DateTime.tryParse(json['occurredAt'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );
}

class InventoryBox extends InventoryBoxSummary {
  const InventoryBox({
    required super.id,
    required super.code,
    required super.name,
    super.location,
    required super.isNfcBound,
    required super.articleTypesCount,
    required super.totalUnits,
    required this.nfcUrl,
    required this.items,
    required this.movements,
  });
  final String nfcUrl;
  final List<InventoryItem> items;
  final List<InventoryMovement> movements;
  factory InventoryBox.fromJson(Map<String, dynamic> json) => InventoryBox(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    location: json['location'] as String?,
    isNfcBound: json['isNfcBound'] as bool? ?? false,
    articleTypesCount: (json['articleTypesCount'] as num?)?.toInt() ?? 0,
    totalUnits: (json['totalUnits'] as num?)?.toInt() ?? 0,
    nfcUrl: json['nfcUrl'] as String,
    items: ((json['items'] as List?) ?? const [])
        .map(
          (item) =>
              InventoryItem.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList(),
    movements: ((json['movements'] as List?) ?? const [])
        .map(
          (item) =>
              InventoryMovement.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList(),
  );
}

class InventoryLabelPrint {
  const InventoryLabelPrint({
    required this.id,
    required this.status,
    required this.mediaSize,
    required this.copies,
    required this.templateVersion,
    required this.assets,
    required this.data,
  });

  final String id;
  final String status;
  final LabelMediaSize mediaSize;
  final int copies;
  final LabelTemplateVersionSnapshot templateVersion;
  final List<LabelAssetSnapshot> assets;
  final Map<String, String> data;

  factory InventoryLabelPrint.fromJson(Map<String, dynamic> json) {
    final rawData = (json['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return InventoryLabelPrint(
      id: (json['id'] ?? '') as String,
      status: (json['status'] ?? '') as String,
      mediaSize: LabelMediaSize.fromApi((json['mediaSize'] ?? '') as String),
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
      data: rawData.map((key, value) => MapEntry(key, value.toString())),
    );
  }
}
