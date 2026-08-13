import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'printer_pairing_models.dart';

/// Recuerda, por teléfono, qué impresora física corresponde a cada marca.
/// El emparejamiento no viaja al servidor: es un ajuste del dispositivo.
class PairedPrintersController extends Notifier<PairedPrinters> {
  static const _storageKey = 'labels.paired_printers.v1';

  // build() dispara _load() sin esperarlo (fire-and-forget, para no
  // bloquear la construcción del provider). Antes, si pair()/unpair() se
  // llamaban antes de que esa carga terminara, partían de `state` con su
  // valor por defecto (vacío) en vez del ya persistido — copyWith()
  // conservaba "this.<la_otra_marca>" de ese estado vacío, así que emparejar
  // una marca justo al abrir la app podía borrar en silencio, del storage,
  // el emparejamiento ya guardado de la OTRA marca. Guardamos el Future de
  // la carga inicial y lo esperamos al principio de pair()/unpair() para
  // garantizar que siempre parten del estado persistido real.
  late final Future<void> _loading = _load();

  @override
  PairedPrinters build() {
    // Referenciar _loading aquí (en vez de solo en pair()/unpair()) es lo
    // que dispara la carga de inmediato al construir el provider, sin
    // bloquear este build() síncrono.
    unawaited(_loading);
    return const PairedPrinters();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return;
    state = PairedPrinters.decode(raw);
  }

  Future<void> pair(PairedPrinter printer) async {
    await _loading;
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
    await _loading;
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
