import 'dart:convert';
import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/label_print_models.dart';

/// 8 puntos/mm ≈ 203 dpi: resolución estándar de los cabezales térmicos de
/// la NIIMBOT B1 y la AIYIN E40 Pro, usada para imprimir directo por
/// Bluetooth sin pasar por su app de configuración.
const double kThermalPrinterDpi = 8 * 25.4;

class LabelPrintRenderException implements Exception {
  const LabelPrintRenderException(this.message, {required this.code});

  final String message;

  /// Código corto y estable para diagnóstico remoto (se manda al backend
  /// como parte de `failureReason`); la vendedora nunca ve este valor, solo
  /// [message].
  final String code;

  @override
  String toString() => message;
}

/// Convierte el diseño versionado del servidor a un PDF con medidas reales.
/// La medida pertenece a la etiqueta, no a la marca de impresora: Android/iOS
/// muestra después su selector nativo para que la vendedora use la que tenga.
class LabelPdfRenderer {
  const LabelPdfRenderer();

  static Future<_LabelFonts>? _fonts;
  static final Dio _assetClient = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.bytes,
    ),
  );

  PdfPageFormat pageFormatFor(LabelMediaSize size) => PdfPageFormat(
    size.widthMm * PdfPageFormat.mm,
    size.heightMm * PdfPageFormat.mm,
    marginAll: 0,
  );

  Future<Uint8List> render(LabelPrintJob job) async {
    return renderData(
      designJson: job.templateVersion.designJson,
      mediaSize: job.mediaSize,
      assets: job.assets,
      documents: job.items.map((item) => payloadData(item.payload)).toList(),
      copies: job.copies,
    );
  }

  Future<Uint8List> renderData({
    required String designJson,
    required LabelMediaSize mediaSize,
    required List<LabelAssetSnapshot> assets,
    required List<Map<String, String>> documents,
    int copies = 1,
  }) async {
    if (documents.isEmpty || copies < 1) {
      throw const LabelPrintRenderException(
        'No hay etiquetas para imprimir.',
        code: 'no_documents',
      );
    }
    final design = _readDesign(designJson);
    final canvas = _map(design['canvas']);
    final widthMm = _number(canvas['widthMm'], mediaSize.widthMm);
    final heightMm = _number(canvas['heightMm'], mediaSize.heightMm);
    final expected = mediaSize;
    if ((widthMm - expected.widthMm).abs() > 0.01 ||
        (heightMm - expected.heightMm).abs() > 0.01) {
      throw const LabelPrintRenderException(
        'La plantilla no coincide con el formato de etiqueta seleccionado.',
        code: 'template_media_mismatch',
      );
    }

    final format = pageFormatFor(expected);
    final elements =
        ((design['elements'] as List?) ?? const [])
            .map((item) => _map(item))
            .where((element) => element.isNotEmpty)
            .toList()
          ..sort(
            (a, b) =>
                _number(a['zIndex'], 0).compareTo(_number(b['zIndex'], 0)),
          );
    final assetImages = await _loadAssetImages(elements, assets);
    final fonts = await _loadFonts();
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
    );

    for (final data in documents) {
      for (var copy = 0; copy < copies; copy++) {
        document.addPage(
          pw.Page(
            pageFormat: format,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Container(
              color: _pdfColor(canvas['background']) ?? PdfColors.white,
              child: pw.Stack(
                fit: pw.StackFit.expand,
                overflow: pw.Overflow.clip,
                children: elements
                    .where((element) => element['visible'] != false)
                    .map(
                      (element) => _positionedElement(
                        element: element,
                        data: data,
                        assetImages: assetImages,
                        canvasWidthMm: widthMm,
                        canvasHeightMm: heightMm,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );
      }
    }

    return document.save();
  }

  /// Rasteriza una sola etiqueta a PNG monocromo listo para enviar por
  /// Bluetooth a una impresora térmica (NIIMBOT B1 / AIYIN E40 Pro). Reusa
  /// el mismo PDF que ya se valida contra la plantilla, así el diseño que
  /// ve la vendedora en la vista previa es el que sale impreso.
  Future<Uint8List> renderPng({
    required String designJson,
    required LabelMediaSize mediaSize,
    required List<LabelAssetSnapshot> assets,
    required Map<String, String> document,
    double dpi = kThermalPrinterDpi,
  }) async {
    final pdfBytes = await renderData(
      designJson: designJson,
      mediaSize: mediaSize,
      assets: assets,
      documents: [document],
      copies: 1,
    );
    final pages = Printing.raster(pdfBytes, pages: const [0], dpi: dpi);
    final raster = await pages.first;
    return raster.toPng();
  }

  Map<String, dynamic> _readDesign(String json) {
    try {
      return _map(jsonDecode(json));
    } on FormatException {
      throw const LabelPrintRenderException(
        'La plantilla de etiquetas tiene un formato inválido.',
        code: 'invalid_template_json',
      );
    }
  }

  pw.Widget _positionedElement({
    required Map<String, dynamic> element,
    required Map<String, String> data,
    required Map<String, pw.ImageProvider> assetImages,
    required double canvasWidthMm,
    required double canvasHeightMm,
  }) {
    final x = _number(element['x'], 0);
    final y = _number(element['y'], 0);
    final width = _number(element['width'], 0);
    final height = _number(element['height'], 0);
    if (width <= 0 ||
        height <= 0 ||
        x < 0 ||
        y < 0 ||
        x + width > canvasWidthMm ||
        y + height > canvasHeightMm) {
      throw const LabelPrintRenderException(
        'La plantilla contiene un elemento fuera del área imprimible.',
        code: 'element_out_of_bounds',
      );
    }

    return pw.Positioned(
      left: x * PdfPageFormat.mm,
      top: y * PdfPageFormat.mm,
      child: pw.SizedBox(
        width: width * PdfPageFormat.mm,
        height: height * PdfPageFormat.mm,
        child: _elementWidget(element, data, assetImages),
      ),
    );
  }

  pw.Widget _elementWidget(
    Map<String, dynamic> element,
    Map<String, String> data,
    Map<String, pw.ImageProvider> assetImages,
  ) {
    final properties = _map(element['properties']);
    final type = (element['type'] ?? '') as String;
    switch (type) {
      case 'text':
        return _textWidget(
          text: (properties['text'] ?? '') as String,
          properties: properties,
        );
      case 'data':
        final value = _resolveBinding(
          (properties['binding'] ?? '') as String,
          data,
        );
        final prefix = (properties['prefix'] ?? '') as String;
        final suffix = (properties['suffix'] ?? '') as String;
        return _textWidget(
          text: value.isEmpty ? '' : '$prefix$value$suffix',
          properties: properties,
        );
      case 'qr':
        final value = _resolveBinding(
          (properties['binding'] ?? '') as String,
          data,
        );
        if (value.isEmpty) {
          throw const LabelPrintRenderException(
            'Falta el código QR de una bolsa.',
            code: 'missing_qr_data',
          );
        }
        return pw.BarcodeWidget(
          data: value,
          barcode: Barcode.qrCode(),
          color: PdfColors.black,
          backgroundColor: PdfColors.white,
        );
      case 'barcode':
        final value = _resolveBinding(
          (properties['binding'] ?? '') as String,
          data,
        );
        if (value.isEmpty) {
          throw const LabelPrintRenderException(
            'Falta el código de una bolsa.',
            code: 'missing_barcode_data',
          );
        }
        return pw.BarcodeWidget(
          data: value,
          barcode: Barcode.code128(),
          color: PdfColors.black,
          drawText: properties['displayValue'] == true,
        );
      case 'shape':
        return pw.Container(
          decoration: pw.BoxDecoration(
            color: _pdfColor(properties['fill']),
            border: _pdfColor(properties['borderColor']) == null
                ? null
                : pw.Border.all(
                    color: _pdfColor(properties['borderColor'])!,
                    width: _number(properties['borderWidth'], 1),
                  ),
          ),
        );
      case 'line':
        return pw.Container(
          color: _pdfColor(properties['color']) ?? PdfColors.black,
        );
      case 'image':
        final assetId = (properties['assetId'] ?? '') as String;
        final image = assetImages[assetId];
        if (image == null) {
          throw const LabelPrintRenderException(
            'La plantilla usa una imagen que ya no está disponible.',
            code: 'missing_asset',
          );
        }
        return pw.Image(
          image,
          fit: properties['fit'] == 'cover'
              ? pw.BoxFit.cover
              : pw.BoxFit.contain,
        );
      default:
        throw LabelPrintRenderException(
          'La plantilla contiene un elemento no compatible: $type.',
          code: 'unsupported_element',
        );
    }
  }

  pw.Widget _textWidget({
    required String text,
    required Map<String, dynamic> properties,
  }) {
    final alignment = switch (properties['align']) {
      'center' => pw.Alignment.topCenter,
      'right' => pw.Alignment.topRight,
      _ => pw.Alignment.topLeft,
    };
    final weight = _number(properties['fontWeight'], 400);
    final fontSize = _number(properties['fontSize'], 10);
    return pw.Align(
      alignment: alignment,
      child: pw.Text(
        text,
        maxLines: properties['wrap'] == true ? null : 1,
        overflow: pw.TextOverflow.clip,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: weight >= 700 ? pw.FontWeight.bold : pw.FontWeight.normal,
          lineSpacing: 1.08,
        ),
      ),
    );
  }

  Map<String, String> payloadData(LabelPrintPayload payload) => {
    'business.name': payload.businessName,
    'order.clientName': payload.order.clientName,
    'order.phone': payload.order.phone ?? '',
    'order.address': payload.order.address ?? '',
    'order.itemSummary': payload.order.itemSummary,
    'order.deliveryInstructions': payload.order.deliveryInstructions ?? '',
    'package.number': payload.package.number.toString(),
    'package.total': payload.package.total.toString(),
    'package.qrCodeValue': payload.package.qrCodeValue,
  };

  String _resolveBinding(String binding, Map<String, String> data) {
    final value = data[binding];
    if (value != null) return value;
    throw LabelPrintRenderException(
      'La plantilla pide un dato no disponible: $binding.',
      code: 'missing_binding',
    );
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return const {};
  }

  double _number(Object? value, double fallback) {
    return (value as num?)?.toDouble() ?? fallback;
  }

  PdfColor? _pdfColor(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    try {
      return PdfColor.fromHex(value.trim());
    } on FormatException {
      return null;
    }
  }

  Future<_LabelFonts> _loadFonts() {
    return _fonts ??= () async {
      final regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Poppins-Regular.ttf'),
      );
      final bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Poppins-Bold.ttf'),
      );
      return _LabelFonts(regular: regular, bold: bold);
    }();
  }

  Future<Map<String, pw.ImageProvider>> _loadAssetImages(
    List<Map<String, dynamic>> elements,
    List<LabelAssetSnapshot> assets,
  ) async {
    final assetUrls = {for (final asset in assets) asset.id: asset.url};
    final requestedIds = elements
        .where((element) => element['type'] == 'image')
        .map(
          (element) => (_map(element['properties'])['assetId'] ?? '') as String,
        )
        .where((id) => id.isNotEmpty)
        .toSet();
    final images = <String, pw.ImageProvider>{};
    for (final id in requestedIds) {
      final url = assetUrls[id];
      if (url == null || url.isEmpty) {
        throw const LabelPrintRenderException(
          'La plantilla usa una imagen que ya no está disponible.',
          code: 'missing_asset',
        );
      }
      try {
        final response = await _assetClient.get<List<int>>(url);
        final bytes = response.data;
        if (bytes == null || bytes.isEmpty) {
          throw const LabelPrintRenderException(
            'No pudimos cargar una imagen de la etiqueta.',
            code: 'asset_download_empty',
          );
        }
        images[id] = pw.MemoryImage(Uint8List.fromList(bytes));
      } on DioException {
        throw const LabelPrintRenderException(
          'No pudimos cargar una imagen de la etiqueta. Revisa tu conexión e inténtalo de nuevo.',
          code: 'asset_network_error',
        );
      }
    }
    return images;
  }
}

class _LabelFonts {
  const _LabelFonts({required this.regular, required this.bold});

  final pw.Font regular;
  final pw.Font bold;
}
