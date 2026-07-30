import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/labels/data/label_print_models.dart';
import 'package:nenis_app/features/labels/services/label_pdf_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('genera un PDF con QR y datos versionados de la bolsa', () async {
    const design = '''
      {
        "schemaVersion": 1,
        "canvas": {"widthMm": 101.6, "heightMm": 152.4, "background": "#FFFFFF"},
        "elements": [
          {"id":"business","type":"data","x":6,"y":6,"width":89.6,"height":8,"visible":true,"zIndex":1,"properties":{"binding":"business.name","fontSize":24,"fontWeight":800,"align":"center"}},
          {"id":"recipient","type":"text","x":6,"y":20,"width":54,"height":4,"visible":true,"zIndex":1,"properties":{"text":"ENTREGAR A","fontSize":9,"fontWeight":700,"align":"left"}},
          {"id":"client","type":"data","x":6,"y":26,"width":54,"height":12,"visible":true,"zIndex":1,"properties":{"binding":"order.clientName","fontSize":21,"fontWeight":800,"align":"left","wrap":true}},
          {"id":"phone","type":"data","x":6,"y":40,"width":54,"height":5,"visible":true,"zIndex":1,"properties":{"binding":"order.phone","prefix":"Tel. ","fontSize":10,"fontWeight":600,"align":"left"}},
          {"id":"address","type":"data","x":6,"y":49,"width":54,"height":28,"visible":true,"zIndex":1,"properties":{"binding":"order.address","fontSize":12,"fontWeight":600,"align":"left","wrap":true}},
          {"id":"package-kicker","type":"text","x":67,"y":20,"width":28.6,"height":4,"visible":true,"zIndex":1,"properties":{"text":"BOLSA","fontSize":9,"fontWeight":700,"align":"center"}},
          {"id":"package-number","type":"data","x":67,"y":26,"width":28.6,"height":14,"visible":true,"zIndex":1,"properties":{"binding":"package.number","prefix":"#","fontSize":36,"fontWeight":800,"align":"center"}},
          {"id":"qr","type":"qr","x":67,"y":48,"width":28,"height":28,"visible":true,"zIndex":2,"properties":{"binding":"package.qrCodeValue"}},
          {"id":"total","type":"data","x":67,"y":79,"width":28.6,"height":4,"visible":true,"zIndex":1,"properties":{"binding":"package.total","suffix":" BOLSAS","fontSize":8,"fontWeight":600,"align":"center"}},
          {"id":"content","type":"text","x":6,"y":86,"width":54,"height":4,"visible":true,"zIndex":1,"properties":{"text":"CONTENIDO","fontSize":9,"fontWeight":700,"align":"left"}},
          {"id":"items","type":"data","x":6,"y":92,"width":54,"height":34,"visible":true,"zIndex":1,"properties":{"binding":"order.itemSummary","fontSize":10,"fontWeight":500,"align":"left","wrap":true}},
          {"id":"note","type":"data","x":6,"y":130,"width":89.6,"height":9,"visible":true,"zIndex":1,"properties":{"binding":"order.deliveryInstructions","prefix":"Nota: ","fontSize":8,"fontWeight":600,"align":"left","wrap":true}}
        ]
      }
    ''';
    final job = LabelPrintJob(
      id: 'job-1',
      status: 'Prepared',
      mediaSize: LabelMediaSize.shipping4x6,
      output: 'SystemPrint',
      copies: 1,
      templateVersion: const LabelTemplateVersionSnapshot(
        id: 'template-1',
        versionNumber: 1,
        designJson: design,
      ),
      assets: const [],
      items: const [
        LabelPrintJobItem(
          id: 'item-1',
          orderPackageId: 'package-1',
          sequence: 1,
          packageQrCodeValue: 'NN-ORD10-PKG1',
          payload: LabelPrintPayload(
            businessName: 'Boutique Miel',
            order: LabelOrderPayload(
              id: 10,
              clientName: 'Mar\u00eda L\u00f3pez',
              phone: '868 000 0000',
              address: 'Calle Rosas 12\nCol. Centro, Nuevo Laredo',
              itemSummary: '1 x Blusa lila\n2 x Scrunchie rosa',
              deliveryInstructions: 'Tocar antes de entrar',
            ),
            package: LabelPackagePayload(
              id: 'package-1',
              number: 1,
              total: 1,
              qrCodeValue: 'NN-ORD10-PKG1',
            ),
          ),
        ),
      ],
    );

    final bytes = await const LabelPdfRenderer().render(job);
    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test(
    'rechaza una plantilla que no coincide con el papel seleccionado',
    () async {
      const design =
          '''{"canvas":{"widthMm":50,"heightMm":50},"elements":[]}''';
      final job = LabelPrintJob(
        id: 'job-1',
        status: 'Prepared',
        mediaSize: LabelMediaSize.shipping4x6,
        output: 'SystemPrint',
        copies: 1,
        templateVersion: const LabelTemplateVersionSnapshot(
          id: 'template-1',
        versionNumber: 1,
        designJson: design,
      ),
        assets: const [],
        items: const [],
      );

      expect(
        () => const LabelPdfRenderer().render(job),
        throwsA(isA<LabelPrintRenderException>()),
      );
    },
  );

  test('genera una etiqueta de caja desde datos inmutables de inventario', () async {
    const design = '''
      {
        "canvas":{"widthMm":50,"heightMm":50,"background":"#FFFFFF"},
        "elements":[
          {"id":"code","type":"data","x":3,"y":3,"width":44,"height":7,"visible":true,"zIndex":1,"properties":{"binding":"box.code","fontSize":18,"fontWeight":800,"align":"center"}},
          {"id":"name","type":"data","x":3,"y":12,"width":44,"height":8,"visible":true,"zIndex":1,"properties":{"binding":"box.name","fontSize":12,"fontWeight":700,"align":"center","wrap":true}},
          {"id":"qr","type":"qr","x":13,"y":22,"width":24,"height":24,"visible":true,"zIndex":2,"properties":{"binding":"box.nfcUrl"}}
        ]
      }
    ''';

    final bytes = await const LabelPdfRenderer().renderData(
      designJson: design,
      mediaSize: LabelMediaSize.square50x50,
      assets: const [],
      documents: const [
        {
          'business.name': 'Boutique Miel',
          'box.code': 'B-01',
          'box.name': 'Blusas',
          'box.nfcUrl': 'https://app.nenisapp.com/caja/1/token-seguro',
        },
      ],
    );

    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
