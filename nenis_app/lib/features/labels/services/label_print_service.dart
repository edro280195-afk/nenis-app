import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';

import '../data/label_print_models.dart';
import '../data/printer_pairing_models.dart';
import 'direct_print/aiyin_e40_print_service.dart';
import 'direct_print/niimbot_b1_print_service.dart';
import 'label_pdf_renderer.dart';

/// Envía el PDF al selector de impresión del sistema operativo. El resultado
/// confirma que Android/iOS recibió el trabajo; no afirma que una impresora
/// física haya terminado de imprimirlo.
class LabelPrintService {
  const LabelPrintService({
    this.renderer = const LabelPdfRenderer(),
    this.niimbot = const NiimbotB1PrintService(),
    this.aiyin = const AiyinE40PrintService(),
  });

  final LabelPdfRenderer renderer;
  final NiimbotB1PrintService niimbot;
  final AiyinE40PrintService aiyin;

  /// Imprime directo por Bluetooth a la impresora emparejada para este
  /// tamaño de etiqueta, sin pasar por el selector del sistema ni la app
  /// del fabricante (NIIMBOT B1 para 50×50mm, AIYIN E40 Pro para 4×6").
  ///
  /// Renderiza todos los documentos primero y los envía en un solo
  /// [NiimbotB1PrintService.printBatch]/[AiyinE40PrintService.printBatch]:
  /// antes cada documento del lote conectaba y desconectaba la impresora
  /// por separado, multiplicando los puntos de fallo por cada etiqueta.
  Future<void> printDirect({
    required PairedPrinter printer,
    required String designJson,
    required LabelMediaSize mediaSize,
    required List<LabelAssetSnapshot> assets,
    required List<Map<String, String>> documents,
    required int copies,
  }) async {
    final pngs = <Uint8List>[];
    for (final document in documents) {
      final png = await renderer.renderPng(
        designJson: designJson,
        mediaSize: mediaSize,
        assets: assets,
        document: document,
      );
      _debugLogPngContent(png);
      pngs.add(png);
    }
    if (pngs.isEmpty) return;

    switch (printer.brand) {
      case PrinterBrand.niimbotB1:
        await niimbot.printBatch(
          address: printer.address,
          name: printer.name,
          bleRemoteId: printer.bleRemoteId,
          pngs: pngs,
          copies: copies,
        );
      case PrinterBrand.aiyinE40Pro:
        await aiyin.printBatch(
          address: printer.address,
          name: printer.name,
          bleRemoteId: printer.bleRemoteId,
          pngs: pngs,
          copies: copies,
        );
    }
  }

  /// Igual que [printDirect], pero a partir de un [LabelPrintJob] ya armado
  /// (usado por el flujo de bolsas de pedido).
  Future<void> printDirectJob(PairedPrinter printer, LabelPrintJob job) {
    return printDirect(
      printer: printer,
      designJson: job.templateVersion.designJson,
      mediaSize: job.mediaSize,
      assets: job.assets,
      documents: job.items
          .map((item) => renderer.payloadData(item.payload))
          .toList(),
      copies: job.copies,
    );
  }

  void _debugLogPngContent(Uint8List png) {
    if (!kDebugMode) return;
    final decoded = img.decodeImage(png);
    if (decoded == null) {
      debugPrint(
        '[LabelPrintService] renderPng: no se pudo decodificar el PNG (${png.length} bytes)',
      );
      return;
    }
    debugPrint(
      '[LabelPrintService] renderPng: ${decoded.width}x${decoded.height}, '
      '${png.length} bytes',
    );
  }

  Future<bool> handOffToSystem(LabelPrintJob job) async {
    final bytes = await renderer.render(job);
    return Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Etiquetas de bolsas · ${job.totalLabels}',
      format: renderer.pageFormatFor(job.mediaSize),
      dynamicLayout: false,
      usePrinterSettings: false,
    );
  }

  Future<bool> handOffData({
    required String designJson,
    required LabelMediaSize mediaSize,
    required List<LabelAssetSnapshot> assets,
    required List<Map<String, String>> documents,
    required int copies,
    required String name,
  }) async {
    final bytes = await renderer.renderData(
      designJson: designJson,
      mediaSize: mediaSize,
      assets: assets,
      documents: documents,
      copies: copies,
    );
    return Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: name,
      format: renderer.pageFormatFor(mediaSize),
      dynamicLayout: false,
      usePrinterSettings: false,
    );
  }
}
