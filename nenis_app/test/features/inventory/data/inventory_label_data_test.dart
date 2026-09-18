import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/inventory/data/inventory_models.dart';

void main() {
  test('completa totalUnits para plantillas de caja con respuesta parcial', () {
    final box = InventoryBox(
      id: 'box-1',
      code: 'B-01',
      name: 'Blusas',
      location: 'Estante A',
      isNfcBound: false,
      articleTypesCount: 2,
      totalUnits: 14,
      updatedAt: DateTime(2026, 8, 26),
      nfcUrl: 'https://app.nenisapp.com/caja/box-1',
      movementCount: 0,
      items: const [],
      movements: const [],
      createdAt: DateTime(2026, 8, 1),
    );

    final data = enrichInventoryLabelData(
      box: box,
      data: const {'box.code': 'servidor-B-01'},
    );

    expect(data['box.code'], 'servidor-B-01');
    expect(data['box.totalUnits'], '14');
    expect(data['box.totalunits'], '14');
  });
}
