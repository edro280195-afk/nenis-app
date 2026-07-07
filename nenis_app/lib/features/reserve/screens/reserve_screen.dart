import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/color_hex.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';
import '../../store/data/store_models.dart';
import '../../store/data/store_repository.dart';
import '../data/reserve_models.dart';
import '../data/reserve_repository.dart';

class ReserveScreen extends ConsumerStatefulWidget {
  const ReserveScreen({
    super.key,
    required this.businessId,
    required this.productId,
  });

  final String businessId;
  final String productId;

  @override
  ConsumerState<ReserveScreen> createState() => _ReserveScreenState();
}

class _ReserveScreenState extends ConsumerState<ReserveScreen> {
  int _quantity = 1;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final id = int.tryParse(widget.businessId);
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(storeBusinessIdProvider.notifier).set(id);
      });
    }
  }

  int? get _productId => int.tryParse(widget.productId);

  Future<void> _confirm(BuyerProduct product) async {
    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(reserveRepositoryProvider)
          .reserve(
            ReserveRequest(
              businessId: int.parse(widget.businessId),
              productId: product.id,
              quantity: _quantity,
            ),
          );
      if (!mounted) return;
      await _showSuccessDialog(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showSuccessDialog(ReserveResult result) async {
    final goTracking = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SuccessDialog(order: result),
    );
    if (!mounted) return;
    if (goTracking == true && result.accessToken != null) {
      context.go('/tracking/${result.orderId}?token=${result.accessToken}');
    } else {
      // Volver a la tienda de la que vinimos.
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/store/${widget.businessId}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(storeControllerProvider);
    final productId = _productId;

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: feed.when(
            loading: () => const _ReserveLoading(),
            error: (e, _) => _ReserveError(
              message: e.toString(),
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
            data: (store) {
              if (store == null || productId == null) {
                return const _ReserveLoading();
              }
              final product = store.products
                  .where((p) => p.id == productId)
                  .cast<BuyerProduct?>()
                  .firstOrNull;
              if (product == null) {
                return _ReserveError(
                  message: 'Este producto ya no está disponible.',
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.go('/store/${widget.businessId}'),
                );
              }
              return Stack(
                children: [
                  _ReserveContent(
                    product: product,
                    store: store,
                    quantity: _quantity,
                    submitting: _submitting,
                    onQuantityChange: (q) => setState(() => _quantity = q),
                    onConfirm: () => _confirm(product),
                    onBack: () => context.canPop()
                        ? context.pop()
                        : context.go('/store/${widget.businessId}'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReserveLoading extends StatelessWidget {
  const _ReserveLoading();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.neni),
    );
  }
}

class _ReserveError extends StatelessWidget {
  const _ReserveError({required this.message, required this.onBack});
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
          PillButton(
            label: 'Volver',
            icon: Symbols.arrow_back,
            onPressed: onBack,
          ),
        ],
      ),
    );
  }
}

class _ReserveContent extends StatelessWidget {
  const _ReserveContent({
    required this.product,
    required this.store,
    required this.quantity,
    required this.submitting,
    required this.onQuantityChange,
    required this.onConfirm,
    required this.onBack,
  });

  final BuyerProduct product;
  final BuyerStoreDetail store;
  final int quantity;
  final bool submitting;
  final ValueChanged<int> onQuantityChange;
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final brand = colorFromHex(store.brandPrimaryColor);
    final money = NumberFormat.currency(
      locale: 'es_MX',
      symbol: r'$',
      decimalDigits: 0,
    );
    final subtotal = product.price * quantity;
    final canConfirm =
        product.inStock &&
        quantity >= 1 &&
        quantity <= product.stock &&
        !submitting;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      children: [
        Row(
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
            Text(
              'Apartar producto',
              style: AppTextStyles.h1.copyWith(fontSize: 22),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Tu tienda lo guarda para ti hasta que confirmes la entrega.',
          style: AppTextStyles.subtitle.copyWith(
            fontSize: 13,
            color: AppColors.ink2,
          ),
        ),
        const SizedBox(height: 22),
        _ProductCard(product: product, brand: brand),
        const SizedBox(height: 18),
        _QuantityStepper(
          value: quantity,
          max: product.stock > 0 ? product.stock : 1,
          onChanged: onQuantityChange,
        ),
        const SizedBox(height: 18),
        _SummaryRow(
          label: 'Subtotal',
          value: money.format(subtotal),
          brand: brand,
        ),
        const SizedBox(height: 6),
        Text(
          'Lo pagas al recoger o recibir.',
          style: AppTextStyles.subtitle.copyWith(
            fontSize: 12,
            color: AppColors.ink3,
          ),
        ),
        const SizedBox(height: 28),
        PillButton(
          label: submitting ? 'Apartando…' : 'Confirmar apartado',
          icon: submitting ? null : Symbols.bookmark,
          variant: PillButtonVariant.brand,
          onPressed: canConfirm ? onConfirm : null,
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

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.brand});
  final BuyerProduct product;
  final Color brand;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [lighten(brand, 0.25), lighten(brand, 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Symbols.image,
              size: 48,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '\$${product.price.toStringAsFixed(0)}',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Symbols.inventory_2,
                      size: 13,
                      color: AppColors.ink3,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      product.stock > 0
                          ? '${product.stock} disponibles'
                          : 'Sin stock',
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 11.5,
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.value,
    required this.max,
    required this.onChanged,
  });
  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        boxShadow: AppShadows.small,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cantidad',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Máximo $max disponibles',
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 11.5,
                    color: AppColors.ink3,
                  ),
                ),
              ],
            ),
          ),
          _StepperButton(
            icon: Symbols.remove,
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 36,
            child: Center(
              child: Text(
                '$value',
                style: AppTextStyles.h2.copyWith(fontSize: 18),
              ),
            ),
          ),
          _StepperButton(
            icon: Symbols.add,
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: Material(
        color: const Color(0xFFFBF3F6),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 18, color: AppColors.neniDeep),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.brand,
  });
  final String label;
  final String value;
  final Color brand;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: AppRadii.softRadius,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.body.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.h2.copyWith(
              fontSize: 18,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog({required this.order});
  final ReserveResult order;
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppColors.statusDeliveredBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Symbols.check_circle,
                color: AppColors.statusDeliveredFg,
                size: 44,
              ),
            ),
            const SizedBox(height: 14),
            Text('¡Apartado!', style: AppTextStyles.h1.copyWith(fontSize: 22)),
            const SizedBox(height: 6),
            Text(
              '${order.businessName} ya está guardando tu pedido. Te avisamos cuando esté listo.',
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              'Pedido #${order.orderId}',
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 12,
                color: AppColors.ink3,
              ),
            ),
            const SizedBox(height: 22),
            PillButton(
              label: 'Ver mi pedido',
              icon: Symbols.local_shipping,
              variant: PillButtonVariant.brand,
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 8),
            PillButton(
              label: 'Seguir comprando',
              variant: PillButtonVariant.ghost,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}
