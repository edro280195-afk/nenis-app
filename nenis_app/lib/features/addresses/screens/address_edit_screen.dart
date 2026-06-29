import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/color_hex.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';
import '../../../shared/widgets/store_avatar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../data/addresses_models.dart';
import '../data/addresses_repository.dart';

class AddressEditScreen extends ConsumerStatefulWidget {
  const AddressEditScreen({super.key, required this.clientId});
  final String clientId;

  @override
  ConsumerState<AddressEditScreen> createState() => _AddressEditScreenState();
}

class _AddressEditScreenState extends ConsumerState<AddressEditScreen> {
  final _addressCtl = TextEditingController();
  final _latCtl = TextEditingController();
  final _lngCtl = TextEditingController();
  final _instrCtl = TextEditingController();

  bool _submitting = false;
  bool _initialized = false;
  BuyerAddress? _original;

  @override
  void dispose() {
    _addressCtl.dispose();
    _latCtl.dispose();
    _lngCtl.dispose();
    _instrCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = int.tryParse(widget.clientId);
    if (id == null) return;
    setState(() => _submitting = true);
    try {
      UpdateAddressRequest req;
      final orig = _original;
      if (orig == null) {
        // Sin original cargado: enviamos lo que esté en el form (puede no
        // actualizar nada si todos los campos son null).
        req = UpdateAddressRequest(
          address: _addressCtl.text.trim().isEmpty
              ? null
              : _addressCtl.text.trim(),
          latitude: double.tryParse(_latCtl.text.trim()),
          longitude: double.tryParse(_lngCtl.text.trim()),
          deliveryInstructions: _instrCtl.text.trim().isEmpty
              ? null
              : _instrCtl.text.trim(),
        );
      } else {
        // Con original: solo enviamos lo que cambió (null = no tocar).
        final newAddr = _addressCtl.text.trim();
        final newInstr = _instrCtl.text.trim();
        final newLat = double.tryParse(_latCtl.text.trim());
        final newLng = double.tryParse(_lngCtl.text.trim());

        req = UpdateAddressRequest(
          address: newAddr == (orig.address?.trim() ?? '')
              ? null
              : (newAddr.isEmpty ? '' : newAddr),
          latitude: newLat == orig.latitude ? null : newLat,
          longitude: newLng == orig.longitude ? null : newLng,
          deliveryInstructions:
              newInstr == (orig.deliveryInstructions?.trim() ?? '')
                  ? null
                  : (newInstr.isEmpty ? '' : newInstr),
        );
      }
      await ref.read(addressesRepositoryProvider).updateAddress(id, req);
      if (!mounted) return;
      ref.invalidate(addressesFeedProvider);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Dirección guardada.')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(addressesFeedProvider);
    final id = int.tryParse(widget.clientId);

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: feed.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.neni),
            ),
            error: (e, _) => _EditError(
              message: e.toString(),
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go('/addresses'),
            ),
            data: (addresses) {
              if (id == null) {
                return _EditError(
                  message: 'Identificador de dirección inválido.',
                  onBack: () => context.pop(),
                );
              }
              final address = addresses
                  .where((a) => a.clientId == id)
                  .cast<BuyerAddress?>()
                  .firstOrNull;
              if (address == null) {
                return _EditError(
                  message: 'Esta dirección no está en tu cuenta.',
                  onBack: () => context.pop(),
                );
              }
              if (!_initialized) {
                _initialized = true;
                _original = address;
                _addressCtl.text = address.address ?? '';
                _latCtl.text = address.latitude?.toString() ?? '';
                _lngCtl.text = address.longitude?.toString() ?? '';
                _instrCtl.text = address.deliveryInstructions ?? '';
              }
              return _EditForm(
                address: address,
                addressCtl: _addressCtl,
                latCtl: _latCtl,
                lngCtl: _lngCtl,
                instrCtl: _instrCtl,
                submitting: _submitting,
                onSave: _save,
                onBack: () => context.canPop()
                    ? context.pop()
                    : context.go('/addresses'),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EditForm extends StatelessWidget {
  const _EditForm({
    required this.address,
    required this.addressCtl,
    required this.latCtl,
    required this.lngCtl,
    required this.instrCtl,
    required this.submitting,
    required this.onSave,
    required this.onBack,
  });

  final BuyerAddress address;
  final TextEditingController addressCtl;
  final TextEditingController latCtl;
  final TextEditingController lngCtl;
  final TextEditingController instrCtl;
  final bool submitting;
  final VoidCallback onSave;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final brand = colorFromHex(address.brandPrimaryColor);
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      children: [
        Material(
          color: AppColors.surface,
          shape: const CircleBorder(),
          elevation: 2,
          shadowColor: Colors.black26,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onBack,
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Symbols.arrow_back, size: 20, color: AppColors.ink),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Editar dirección',
            style: AppTextStyles.h1.copyWith(fontSize: 22)),
        const SizedBox(height: 2),
        Text('Tienda: ${address.businessName}',
            style: AppTextStyles.subtitle
                .copyWith(fontSize: 13, color: AppColors.ink2)),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.softRadius,
            boxShadow: AppShadows.small,
          ),
          child: Row(
            children: [
              StoreAvatarSm(
                label: address.initial,
                gradientStart: lighten(brand, 0.08),
                gradientEnd: brand,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(address.businessName,
                    style: AppTextStyles.body.copyWith(
                        fontSize: 14.5, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AppTextField(
          label: 'Calle y número',
          controller: addressCtl,
          hint: 'Av. Reforma 123, Dep. 4B',
          maxLines: 2,
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: 'Referencias',
          controller: instrCtl,
          hint: 'Casa blanca con portón negro',
          maxLines: 2,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: 'Latitud',
                controller: latCtl,
                hint: '27.4861',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                label: 'Longitud',
                controller: lngCtl,
                hint: '-99.5069',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        PillButton(
          label: submitting ? 'Guardando…' : 'Guardar cambios',
          icon: submitting ? null : Symbols.check,
          variant: PillButtonVariant.brand,
          onPressed: submitting ? null : onSave,
        ),
        const SizedBox(height: 10),
        PillButton(
          label: 'Cancelar',
          variant: PillButtonVariant.ghost,
          onPressed: submitting ? null : onBack,
        ),
      ],
    );
  }
}

class _EditError extends StatelessWidget {
  const _EditError({required this.message, required this.onBack});
  final String message;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Symbols.cloud_off, size: 46, color: AppColors.ink3),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center, style: AppTextStyles.h2),
          const SizedBox(height: 22),
          PillButton(label: 'Volver', icon: Symbols.arrow_back, onPressed: onBack),
        ],
      ),
    );
  }
}
