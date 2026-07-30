import 'dart:convert';

import 'label_print_models.dart';

enum LabelTemplateKind {
  inventoryBox,
  inventoryItem,
  orderPackage;

  String get api => switch (this) {
    LabelTemplateKind.inventoryBox => 'InventoryBox',
    LabelTemplateKind.inventoryItem => 'InventoryItem',
    LabelTemplateKind.orderPackage => 'OrderPackage',
  };

  String get label => switch (this) {
    LabelTemplateKind.inventoryBox => 'caja de bodega',
    LabelTemplateKind.inventoryItem => 'artículo de bodega',
    LabelTemplateKind.orderPackage => 'bolsa de pedido',
  };

  static LabelTemplateKind fromApi(String value) => switch (value) {
    'InventoryBox' => LabelTemplateKind.inventoryBox,
    'InventoryItem' => LabelTemplateKind.inventoryItem,
    _ => LabelTemplateKind.orderPackage,
  };
}

class LabelTemplateVersion {
  const LabelTemplateVersion({
    required this.id,
    required this.versionNumber,
    required this.status,
    required this.revision,
    required this.designJson,
  });

  final String id;
  final int versionNumber;
  final String status;
  final int revision;
  final String designJson;

  factory LabelTemplateVersion.fromJson(Map<String, dynamic> json) {
    return LabelTemplateVersion(
      id: (json['id'] ?? '') as String,
      versionNumber: (json['versionNumber'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? '') as String,
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      designJson: (json['designJson'] ?? '') as String,
    );
  }
}

class LabelTemplateHistoryVersion {
  const LabelTemplateHistoryVersion({
    required this.id,
    required this.versionNumber,
    required this.status,
  });

  final String id;
  final int versionNumber;
  final String status;

  factory LabelTemplateHistoryVersion.fromJson(Map<String, dynamic> json) {
    return LabelTemplateHistoryVersion(
      id: (json['id'] ?? '') as String,
      versionNumber: (json['versionNumber'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? '') as String,
    );
  }
}

class LabelTemplateEditor {
  const LabelTemplateEditor({
    required this.id,
    required this.name,
    required this.kind,
    required this.mediaSize,
    this.publishedVersion,
    required this.draftVersion,
    required this.history,
  });

  final String id;
  final String name;
  final LabelTemplateKind kind;
  final LabelMediaSize mediaSize;
  final LabelTemplateVersion? publishedVersion;
  final LabelTemplateVersion draftVersion;
  final List<LabelTemplateHistoryVersion> history;

  factory LabelTemplateEditor.fromJson(Map<String, dynamic> json) {
    return LabelTemplateEditor(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      kind: LabelTemplateKind.fromApi((json['kind'] ?? '') as String),
      mediaSize: LabelMediaSize.fromApi((json['mediaSize'] ?? '') as String),
      publishedVersion: json['publishedVersion'] is Map
          ? LabelTemplateVersion.fromJson(
              (json['publishedVersion'] as Map).cast<String, dynamic>(),
            )
          : null,
      draftVersion: LabelTemplateVersion.fromJson(
        (json['draftVersion'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      history: ((json['history'] as List?) ?? const [])
          .map(
            (item) => LabelTemplateHistoryVersion.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}

class LabelAsset {
  const LabelAsset({
    required this.id,
    required this.name,
    required this.url,
    required this.contentType,
  });

  final String id;
  final String name;
  final String url;
  final String contentType;

  factory LabelAsset.fromJson(Map<String, dynamic> json) {
    return LabelAsset(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      url: (json['url'] ?? '') as String,
      contentType: (json['contentType'] ?? '') as String,
    );
  }
}

class LabelDesign {
  const LabelDesign({
    required this.widthMm,
    required this.heightMm,
    required this.background,
    required this.elements,
  });

  final double widthMm;
  final double heightMm;
  final String background;
  final List<LabelDesignElement> elements;

  factory LabelDesign.fromJson(String source, LabelMediaSize fallbackSize) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) throw const FormatException('El diseño no es válido.');
    final canvas =
        (decoded['canvas'] as Map?)?.cast<String, dynamic>() ?? const {};
    return LabelDesign(
      widthMm: (canvas['widthMm'] as num?)?.toDouble() ?? fallbackSize.widthMm,
      heightMm:
          (canvas['heightMm'] as num?)?.toDouble() ?? fallbackSize.heightMm,
      background: (canvas['background'] ?? '#FFFFFF') as String,
      elements: ((decoded['elements'] as List?) ?? const [])
          .map(
            (item) => LabelDesignElement.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }

  String toJson() => jsonEncode({
    'schemaVersion': 1,
    'canvas': {
      'widthMm': widthMm,
      'heightMm': heightMm,
      'background': background,
    },
    'elements': elements.map((element) => element.toJson()).toList(),
  });

  LabelDesign copyWith({
    List<LabelDesignElement>? elements,
    String? background,
  }) {
    return LabelDesign(
      widthMm: widthMm,
      heightMm: heightMm,
      background: background ?? this.background,
      elements: elements ?? this.elements,
    );
  }
}

class LabelDesignElement {
  const LabelDesignElement({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.zIndex,
    this.rotation = 0,
    this.visible = true,
    this.properties = const {},
  });

  final String id;
  final String type;
  final double x;
  final double y;
  final double width;
  final double height;
  final int zIndex;
  final double rotation;
  final bool visible;
  final Map<String, dynamic> properties;

  String? get binding => properties['binding'] as String?;
  bool get isRequired =>
      binding == 'order.clientName' ||
      binding == 'package.number' ||
      binding == 'package.qrCodeValue' ||
      binding == 'box.code' ||
      binding == 'box.nfcUrl' ||
      binding == 'item.name' ||
      binding == 'item.scannableCode';

  LabelDesignElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    int? zIndex,
    bool? visible,
    Map<String, dynamic>? properties,
  }) {
    return LabelDesignElement(
      id: id,
      type: type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      zIndex: zIndex ?? this.zIndex,
      rotation: rotation,
      visible: visible ?? this.visible,
      properties: properties ?? this.properties,
    );
  }

  factory LabelDesignElement.fromJson(Map<String, dynamic> json) {
    return LabelDesignElement(
      id: (json['id'] ?? '') as String,
      type: (json['type'] ?? 'text') as String,
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 10,
      height: (json['height'] as num?)?.toDouble() ?? 5,
      zIndex: (json['zIndex'] as num?)?.toInt() ?? 1,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      visible: (json['visible'] as bool?) ?? true,
      properties:
          (json['properties'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'rotation': rotation,
    'visible': visible,
    'zIndex': zIndex,
    'properties': properties,
  };
}
