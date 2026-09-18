import 'dart:convert';

import 'label_print_models.dart';

/// Marca de impresora térmica soportada para impresión directa por
/// Bluetooth, sin pasar por la app del fabricante. Cada marca imprime un
/// [LabelMediaSize] fijo (ver docs/impresion-etiquetas.md en regibazarweb).
enum PrinterBrand {
  niimbotB1(mediaSize: LabelMediaSize.square50x50),
  aiyinE40Pro(mediaSize: LabelMediaSize.shipping4x6);

  const PrinterBrand({required this.mediaSize});

  final LabelMediaSize mediaSize;

  static PrinterBrand forMediaSize(LabelMediaSize size) =>
      PrinterBrand.values.firstWhere((brand) => brand.mediaSize == size);
}

/// Impresora emparejada y recordada localmente en este teléfono. El
/// emparejamiento vive por dispositivo, no por cuenta: cada vendedora
/// empareja la impresora física que tiene enfrente.
class PairedPrinter {
  const PairedPrinter({
    required this.brand,
    required this.address,
    required this.name,
    this.bleRemoteId,
  });

  final PrinterBrand brand;

  /// Identificador legado: MAC de Bluetooth clásico en emparejamientos
  /// antiguos o remoteId de BLE en los nuevos.
  final String address;
  final String name;

  /// Identificador que entrega Core Bluetooth/FlutterBluePlus. En Android
  /// normalmente es una MAC; en iOS es un UUID local de ese teléfono. No se
  /// comparte entre teléfonos ni se puede sustituir por la MAC del Pixel.
  final String? bleRemoteId;

  Map<String, dynamic> toJson() => {
    'brand': brand.name,
    'address': address,
    'name': name,
    if (bleRemoteId != null) 'bleRemoteId': bleRemoteId,
  };

  factory PairedPrinter.fromJson(Map<String, dynamic> json) => PairedPrinter(
    brand: PrinterBrand.values.firstWhere(
      (b) => b.name == json['brand'],
      orElse: () => PrinterBrand.niimbotB1,
    ),
    address: (json['address'] ?? '') as String,
    name: (json['name'] ?? '') as String,
    bleRemoteId: (json['bleRemoteId'] as String?)?.trim(),
  );
}

class PairedPrinters {
  const PairedPrinters({this.niimbotB1, this.aiyinE40Pro});

  final PairedPrinter? niimbotB1;
  final PairedPrinter? aiyinE40Pro;

  PairedPrinter? forBrand(PrinterBrand brand) => switch (brand) {
    PrinterBrand.niimbotB1 => niimbotB1,
    PrinterBrand.aiyinE40Pro => aiyinE40Pro,
  };

  PairedPrinter? forMediaSize(LabelMediaSize size) =>
      forBrand(PrinterBrand.forMediaSize(size));

  PairedPrinters copyWith({
    PairedPrinter? Function()? niimbotB1,
    PairedPrinter? Function()? aiyinE40Pro,
  }) {
    return PairedPrinters(
      niimbotB1: niimbotB1 != null ? niimbotB1() : this.niimbotB1,
      aiyinE40Pro: aiyinE40Pro != null ? aiyinE40Pro() : this.aiyinE40Pro,
    );
  }

  String encode() => jsonEncode({
    if (niimbotB1 != null) 'niimbotB1': niimbotB1!.toJson(),
    if (aiyinE40Pro != null) 'aiyinE40Pro': aiyinE40Pro!.toJson(),
  });

  static PairedPrinters decode(String raw) {
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return PairedPrinters(
        niimbotB1: map['niimbotB1'] == null
            ? null
            : PairedPrinter.fromJson(
                (map['niimbotB1'] as Map).cast<String, dynamic>(),
              ),
        aiyinE40Pro: map['aiyinE40Pro'] == null
            ? null
            : PairedPrinter.fromJson(
                (map['aiyinE40Pro'] as Map).cast<String, dynamic>(),
              ),
      );
    } catch (_) {
      return const PairedPrinters();
    }
  }
}
