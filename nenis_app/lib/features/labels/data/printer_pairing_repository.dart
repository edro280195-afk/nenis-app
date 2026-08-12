import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'printer_pairing_models.dart';

/// Recuerda, por teléfono, qué impresora física corresponde a cada marca.
/// El emparejamiento no viaja al servidor: es un ajuste del dispositivo.
class PairedPrintersController extends Notifier<PairedPrinters> {
  static const _storageKey = 'labels.paired_printers.v1';

  var _version = 0;

  @override
  PairedPrinters build() {
    _load(_version);
    return const PairedPrinters();
  }

  Future<void> _load(int version) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty || _version != version) return;
    state = PairedPrinters.decode(raw);
  }

  Future<void> pair(PairedPrinter printer) async {
    _version++;
    state = state.copyWith(
      niimbotB1: printer.brand == PrinterBrand.niimbotB1
          ? () => printer
          : null,
      aiyinE40Pro: printer.brand == PrinterBrand.aiyinE40Pro
          ? () => printer
          : null,
    );
    await _persist();
  }

  Future<void> unpair(PrinterBrand brand) async {
    _version++;
    state = state.copyWith(
      niimbotB1: brand == PrinterBrand.niimbotB1 ? () => null : null,
      aiyinE40Pro: brand == PrinterBrand.aiyinE40Pro ? () => null : null,
    );
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, state.encode());
  }
}

final pairedPrintersProvider =
    NotifierProvider<PairedPrintersController, PairedPrinters>(
      PairedPrintersController.new,
    );
