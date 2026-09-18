import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';
import '../data/printer_pairing_models.dart';
import '../data/printer_pairing_repository.dart';
import '../services/direct_print/aiyin_e40_print_service.dart';
import '../services/direct_print/niimbot_b1_print_service.dart';

/// FlutterBluePlus mantiene una sola sesión de escaneo BLE por proceso: si
/// ambas tarjetas llaman startScan() a la vez, una búsqueda corta a la otra.
/// Este lock evita que las dos tarjetas escaneen simultáneamente.
class _BluetoothScanLock extends Notifier<bool> {
  @override
  bool build() => false;

  void setBusy(bool value) => state = value;
}

final _bluetoothScanBusyProvider = NotifierProvider<_BluetoothScanLock, bool>(
  _BluetoothScanLock.new,
);

/// Empareja, por teléfono, la impresora física de cada marca para poder
/// imprimir directo por Bluetooth (sin la app del fabricante).
class PrinterPairingScreen extends ConsumerWidget {
  const PrinterPairingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paired = ref.watch(pairedPrintersProvider);
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
                child: Row(
                  children: [
                    BackIconButton(
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Impresoras',
                      style: AppTextStyles.h1.copyWith(fontSize: 22),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  children: [
                    Text(
                      'Empareja aquí la impresora física que tienes en bodega. '
                      'Nenis imprime directo por Bluetooth, sin abrir la app '
                      'del fabricante.',
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _PrinterCard(
                      brand: PrinterBrand.niimbotB1,
                      title: 'NIIMBOT B1',
                      subtitle: 'Etiquetas de caja y artículo · 50 × 50 mm',
                      paired: paired.niimbotB1,
                    ),
                    const SizedBox(height: 14),
                    _PrinterCard(
                      brand: PrinterBrand.aiyinE40Pro,
                      title: 'AIYIN E40 Pro',
                      subtitle: 'Etiquetas de bolsa de pedido · 4 × 6"',
                      paired: paired.aiyinE40Pro,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrinterCard extends ConsumerStatefulWidget {
  const _PrinterCard({
    required this.brand,
    required this.title,
    required this.subtitle,
    required this.paired,
  });

  final PrinterBrand brand;
  final String title;
  final String subtitle;
  final PairedPrinter? paired;

  @override
  ConsumerState<_PrinterCard> createState() => _PrinterCardState();
}

class _PrinterCardState extends ConsumerState<_PrinterCard> {
  bool _scanning = false;
  String? _error;
  List<({String name, String address})> _found = const [];

  Future<void> _scan() async {
    // Guard contra la carrera entre las dos tarjetas: si la otra marca ya
    // está escaneando, no arrancamos un segundo scan que la cortaría.
    if (ref.read(_bluetoothScanBusyProvider)) return;
    ref.read(_bluetoothScanBusyProvider.notifier).setBusy(true);
    setState(() {
      _scanning = true;
      _error = null;
      _found = const [];
    });
    try {
      const niimbot = NiimbotB1PrintService();
      const aiyin = AiyinE40PrintService();
      _found = widget.brand == PrinterBrand.niimbotB1
          ? await niimbot.scan()
          : await aiyin.scan();
      if (_found.isEmpty) {
        _error =
            'No encontramos ninguna impresora encendida cerca. '
            'Enciéndela, acércala al teléfono e inténtalo de nuevo.';
      }
    } on NiimbotPrintException catch (e) {
      // Ya trae un mensaje orientado a la vendedora (p.ej. permiso de
      // Bluetooth denegado) — mostrarlo tal cual, sin envolverlo.
      _error = e.message;
    } on AiyinPrintException catch (e) {
      _error = e.message;
    } catch (e) {
      // Antes se interpolaba $e crudo aquí, exponiendo texto técnico del
      // SDK nativo (a veces en inglés) directo a la vendedora. El detalle
      // real solo queda en el log de debug.
      debugPrint('[PrinterPairing] scan failed: $e');
      _error =
          'No pudimos buscar impresoras. Revisa que el Bluetooth del '
          'teléfono esté encendido e inténtalo de nuevo.';
    } finally {
      ref.read(_bluetoothScanBusyProvider.notifier).setBusy(false);
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _pair(({String name, String address}) device) async {
    final name = device.name.isEmpty ? widget.title : device.name;
    await ref
        .read(pairedPrintersProvider.notifier)
        .pair(
          PairedPrinter(
            brand: widget.brand,
            address: device.address,
            name: name,
            // En esta pantalla address ya es el remoteId BLE descubierto por
            // este teléfono. Guardarlo explícitamente permite conservar
            // compatibilidad con los emparejamientos clásicos antiguos.
            bleRemoteId: device.address,
          ),
        );
    if (!mounted) return;
    setState(() => _found = const []);
    // Antes no había ninguna señal de éxito aquí — la única pista era que
    // la lista de dispositivos encontrados desaparecía.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$name emparejada. Ya puedes imprimir directo desde aquí.',
        ),
        backgroundColor: AppColors.lavender,
      ),
    );
  }

  Future<void> _unpair() async {
    final pairedName = widget.paired?.name ?? widget.title;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Quitar impresora emparejada?'),
        content: Text(
          'Dejarás de poder imprimir directo en $pairedName hasta que la '
          'vuelvas a emparejar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(pairedPrintersProvider.notifier).unpair(widget.brand);
  }

  @override
  Widget build(BuildContext context) {
    final paired = widget.paired;
    final anyScanning = ref.watch(_bluetoothScanBusyProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.neni.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Symbols.print,
                  color: AppColors.neniDeep,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTextStyles.h2.copyWith(fontSize: 15),
                    ),
                    Text(
                      widget.subtitle,
                      style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (paired != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.neni.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Symbols.bluetooth_connected,
                    size: 18,
                    color: AppColors.neniDeep,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Emparejada: ${paired.name}',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(onPressed: _unpair, child: const Text('Quitar')),
                ],
              ),
            ),
          const SizedBox(height: 10),
          PillButton(
            label: _scanning ? 'Buscando…' : 'Buscar impresoras',
            icon: Symbols.bluetooth_searching,
            // Deshabilitado también si la OTRA tarjeta está escaneando:
            // FlutterBluePlus serializa la sesión de radio global.
            onPressed: anyScanning ? null : _scan,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 11.5,
                color: Colors.red,
              ),
            ),
          ],
          for (final device in _found) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _pair(device),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.lineSoft),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        device.name.isEmpty ? device.address : device.name,
                        style: AppTextStyles.body.copyWith(fontSize: 12.5),
                      ),
                    ),
                    const Icon(Symbols.chevron_right, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
