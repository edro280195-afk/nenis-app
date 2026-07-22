import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/labels/data/label_print_models.dart';

void main() {
  test('reconoce los formatos de impresión sin depender de una impresora', () {
    expect(LabelMediaSize.fromApi('Shipping4x6'), LabelMediaSize.shipping4x6);
    expect(LabelMediaSize.fromApi('Square50x50'), LabelMediaSize.square50x50);
    expect(
      LabelMediaSize.fromApi('formato-desconocido'),
      LabelMediaSize.shipping4x6,
    );
  });

  test('calcula una etiqueta por bolsa y por cada copia solicitada', () {
    final job = LabelPrintJob.fromJson({
      'id': 'job-1',
      'status': 'Prepared',
      'mediaSize': 'Shipping4x6',
      'output': 'SystemPrint',
      'copies': 2,
      'templateVersion': {
        'id': 'template-1',
        'versionNumber': 1,
        'designJson': '{}',
      },
      'items': [
        {
          'id': 'item-1',
          'orderPackageId': 'package-1',
          'sequence': 1,
          'packageQrCodeValue': 'NN-ORD10-PKG1',
          'payload': {
            'businessName': 'Boutique Miel',
            'order': {
              'id': 10,
              'clientName': 'Mariana',
              'itemSummary': '1 × Blusa',
            },
            'package': {
              'id': 'package-1',
              'number': 1,
              'total': 2,
              'qrCodeValue': 'NN-ORD10-PKG1',
            },
          },
        },
        {
          'id': 'item-2',
          'orderPackageId': 'package-2',
          'sequence': 2,
          'packageQrCodeValue': 'NN-ORD10-PKG2',
          'payload': {
            'businessName': 'Boutique Miel',
            'order': {
              'id': 10,
              'clientName': 'Mariana',
              'itemSummary': '1 × Blusa',
            },
            'package': {
              'id': 'package-2',
              'number': 2,
              'total': 2,
              'qrCodeValue': 'NN-ORD10-PKG2',
            },
          },
        },
      ],
    });

    expect(job.totalLabels, 4);
    expect(job.items.first.payload.package.qrCodeValue, 'NN-ORD10-PKG1');
  });
}
