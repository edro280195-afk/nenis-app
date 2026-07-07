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
import '../data/addresses_models.dart';
import '../data/addresses_repository.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(addressesFeedProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: feed.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.neni),
            ),
            error: (e, _) => _AddressesError(
              onRetry: () => ref.invalidate(addressesFeedProvider),
            ),
            data: (addresses) {
              if (addresses.isEmpty) {
                return _EmptyAddresses(
                  onBack: () =>
                      context.canPop() ? context.pop() : context.go('/account'),
                );
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _Header(
                    onBack: () => context.canPop()
                        ? context.pop()
                        : context.go('/account'),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                    child: Text(
                      'Edita la dirección de cada tienda. Cuando hagas un pedido, te preguntaremos cuál usar.',
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 12.5,
                        color: AppColors.ink2,
                      ),
                    ),
                  ),
                  for (final a in addresses) ...[
                    _AddressRow(address: a),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
      child: Row(
        children: [
          Material(
            color: AppColors.surface,
            shape: const CircleBorder(),
            elevation: 2,
            shadowColor: Colors.black26,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onBack,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.adaptive.arrow_back,
                  size: 20,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mis direcciones',
                style: AppTextStyles.h1.copyWith(fontSize: 24),
              ),
              Text(
                'Las direcciones que tus tiendas tienen guardadas.',
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: 12.5,
                  color: AppColors.ink2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address});
  final BuyerAddress address;
  @override
  Widget build(BuildContext context) {
    final brand = colorFromHex(address.brandPrimaryColor);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.softRadius,
          boxShadow: AppShadows.small,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StoreAvatarSm(
                  label: address.initial,
                  gradientStart: lighten(brand, 0.08),
                  gradientEnd: brand,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    address.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                PillButton(
                  label: 'Editar',
                  icon: Symbols.edit,
                  expand: false,
                  onPressed: () =>
                      context.push('/addresses/${address.clientId}'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _AddressLine(
              icon: Symbols.location_on,
              text: address.address?.trim().isNotEmpty == true
                  ? address.address!
                  : 'Sin dirección',
              empty: address.address == null || address.address!.trim().isEmpty,
            ),
            if (address.latitude != null && address.longitude != null)
              _AddressLine(
                icon: Symbols.my_location,
                text:
                    '${address.latitude!.toStringAsFixed(4)}, ${address.longitude!.toStringAsFixed(4)}',
              ),
            if (address.deliveryInstructions?.trim().isNotEmpty == true)
              _AddressLine(
                icon: Symbols.info,
                text: address.deliveryInstructions!,
              ),
          ],
        ),
      ),
    );
  }
}

class _AddressLine extends StatelessWidget {
  const _AddressLine({
    required this.icon,
    required this.text,
    this.empty = false,
  });
  final IconData icon;
  final String text;
  final bool empty;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AppColors.ink3),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 12.5,
                color: empty ? AppColors.ink3 : AppColors.ink2,
                fontStyle: empty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAddresses extends StatelessWidget {
  const _EmptyAddresses({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
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
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                Icons.adaptive.arrow_back,
                size: 20,
                color: AppColors.ink,
              ),
            ),
          ),
        ),
        const SizedBox(height: 60),
        Center(
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE1EC),
                  borderRadius: BorderRadius.all(Radius.circular(28)),
                ),
                child: const Icon(
                  Symbols.location_on,
                  color: AppColors.neniDeep,
                  size: 40,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Aún no tienes tiendas con dirección',
                textAlign: TextAlign.center,
                style: AppTextStyles.h2.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Cuando una tienda registre tu número, su dirección aparecerá aquí para que la mantengas actualizada.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddressesError extends StatelessWidget {
  const _AddressesError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Symbols.cloud_off, size: 46, color: AppColors.ink3),
          const SizedBox(height: 14),
          Text(
            'No pudimos cargar tus direcciones',
            textAlign: TextAlign.center,
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 8),
          Text(
            'Revisa tu conexión e intenta de nuevo.',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 22),
          PillButton(
            label: 'Reintentar',
            icon: Symbols.refresh,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
