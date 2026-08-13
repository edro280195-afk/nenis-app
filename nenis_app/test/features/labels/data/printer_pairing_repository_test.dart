import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/labels/data/label_print_models.dart';
import 'package:nenis_app/features/labels/data/printer_pairing_models.dart';
import 'package:nenis_app/features/labels/data/printer_pairing_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('empareja una impresora y la persiste en SharedPreferences', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(pairedPrintersProvider.notifier).pair(
      const PairedPrinter(
        brand: PrinterBrand.niimbotB1,
        address: '00:11:22:33:44:55',
        name: 'NIIMBOT bodega',
      ),
    );

    final state = container.read(pairedPrintersProvider);
    expect(state.niimbotB1?.name, 'NIIMBOT bodega');
    expect(state.aiyinE40Pro, isNull);
    expect(
      state.forMediaSize(LabelMediaSize.square50x50)?.name,
      'NIIMBOT bodega',
    );

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('labels.paired_printers.v1');
    expect(raw, isNotNull);
    expect(PairedPrinters.decode(raw!).niimbotB1?.address, '00:11:22:33:44:55');
  });

  test('desemparejar una marca no afecta a la otra', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(pairedPrintersProvider.notifier);
    await notifier.pair(
      const PairedPrinter(brand: PrinterBrand.niimbotB1, address: 'A', name: 'NIIMBOT'),
    );
    await notifier.pair(
      const PairedPrinter(brand: PrinterBrand.aiyinE40Pro, address: 'B', name: 'AIYIN'),
    );

    await notifier.unpair(PrinterBrand.niimbotB1);

    final state = container.read(pairedPrintersProvider);
    expect(state.niimbotB1, isNull);
    expect(state.aiyinE40Pro?.name, 'AIYIN');
  });

  test('carga el emparejamiento ya guardado al construir el provider', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'labels.paired_printers.v1': const PairedPrinters(
        aiyinE40Pro: PairedPrinter(
          brand: PrinterBrand.aiyinE40Pro,
          address: 'C',
          name: 'AIYIN guardada',
        ),
      ).encode(),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final loaded = Completer<PairedPrinters>();
    container.listen<PairedPrinters>(
      pairedPrintersProvider,
      (_, next) {
        if (!loaded.isCompleted && next.aiyinE40Pro != null) {
          loaded.complete(next);
        }
      },
      fireImmediately: true,
    );

    final state = await loaded.future.timeout(const Duration(seconds: 1));
    expect(state.aiyinE40Pro?.name, 'AIYIN guardada');
  });

  test(
    'emparejar una marca justo al abrir la app no borra el emparejamiento '
    'ya guardado de la otra marca (regresión: build() dispara _load() sin '
    'esperarlo, y pair()/unpair() antes solo partían del estado en memoria, '
    'todavía vacío en ese instante)',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'labels.paired_printers.v1': const PairedPrinters(
          niimbotB1: PairedPrinter(
            brand: PrinterBrand.niimbotB1,
            address: 'OLD',
            name: 'NIIMBOT ya emparejada',
          ),
        ).encode(),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Sin ningún await de por medio entre crear el provider y emparejar
      // la otra marca: build() ya disparó _load(), pero todavía no tuvo
      // oportunidad de resolver la lectura async de SharedPreferences.
      await container.read(pairedPrintersProvider.notifier).pair(
        const PairedPrinter(
          brand: PrinterBrand.aiyinE40Pro,
          address: 'NEW',
          name: 'AIYIN recién emparejada',
        ),
      );

      final state = container.read(pairedPrintersProvider);
      expect(
        state.niimbotB1?.address,
        'OLD',
        reason: 'el emparejamiento previo de NIIMBOT no debería perderse',
      );
      expect(state.aiyinE40Pro?.address, 'NEW');

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('labels.paired_printers.v1');
      final persisted = PairedPrinters.decode(raw!);
      expect(
        persisted.niimbotB1?.address,
        'OLD',
        reason: 'tampoco debería perderse en lo que quedó persistido en disco',
      );
      expect(persisted.aiyinE40Pro?.address, 'NEW');
    },
  );
}
