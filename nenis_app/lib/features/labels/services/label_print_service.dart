import 'package:printing/printing.dart';

import '../data/label_print_models.dart';
import 'label_pdf_renderer.dart';

/// Envía el PDF al selector de impresión del sistema operativo. El resultado
/// confirma que Android/iOS recibió el trabajo; no afirma que una impresora
/// física haya terminado de imprimirlo.
class LabelPrintService {
  const LabelPrintService({this.renderer = const LabelPdfRenderer()});

  final LabelPdfRenderer renderer;

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
