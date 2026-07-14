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
import '../../store/data/store_models.dart';
import '../../store/data/store_repository.dart';
import '../data/live_hub_client.dart';
import '../data/live_models.dart';

/// Visor de la clienta durante el Live de una tienda. No procesa ni
/// reproduce el video de Facebook para nada — solo escucha, por SignalR,
/// qué producto anunció la vendedora, y deja apartarlo en un toque. La
/// clienta sigue viendo el Live de verdad en Facebook, en otra pantalla o
/// pestaña; esta pantalla es la capa de compra en paralelo.
class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key, required this.businessId});
  final String businessId;

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  int? _businessId;
  LiveProductAnnouncement? _liveUpdate;
  bool _joined = false;

  @override
  void initState() {
    super.initState();
    final id = int.tryParse(widget.businessId);
    _businessId = id;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(storeBusinessIdProvider.notifier).set(id);
        _join();
      });
    }
  }

  Future<void> _join() async {
    final id = _businessId;
    if (id == null || _joined) return;
    final hub = ref.read(liveHubProvider);
    hub.productAnnouncedStream.listen((a) {
      if (mounted) setState(() => _liveUpdate = a);
    });
    final ok = await hub.joinLive(id);
    if (mounted) setState(() => _joined = ok);
  }

  @override
  Widget build(BuildContext context) {
    final id = _businessId;
    if (id == null) {
      return const _LiveError(message: 'Tienda no válida.');
    }
    final storeAsync = ref.watch(storeControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          child: storeAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.neniDeep),
            ),
            error: (e, _) => _LiveError(message: e.toString()),
            data: (store) {
              if (store == null) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.neniDeep),
                );
              }
              return _LiveContent(
                store: store,
                businessId: id,
                liveUpdate: _liveUpdate,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LiveContent extends StatelessWidget {
  const _LiveContent({
    required this.store,
    required this.businessId,
    required this.liveUpdate,
  });

  final BuyerStoreDetail store;
  final int businessId;
  final LiveProductAnnouncement? liveUpdate;

  @override
  Widget build(BuildContext context) {
    final brand = colorFromHex(store.brandPrimaryColor);

    // El evento en vivo (si ya llegó uno) manda sobre lo que trajo el GET
    // inicial — así la clienta ve lo último aunque haya entrado tarde.
    final productId = liveUpdate?.productId ?? store.liveCurrentProductId;
    final productName = liveUpdate?.name ?? store.liveCurrentProductName;
    final productPrice = liveUpdate?.price ?? store.liveCurrentProductPrice;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
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
                onTap: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.adaptive.arrow_back, size: 20, color: AppColors.ink),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.liveAnnouncementTitle?.isNotEmpty == true
                        ? store.liveAnnouncementTitle!
                        : store.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h1.copyWith(fontSize: 20),
                  ),
                  Text(
                    'Vivo de ${store.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        if (!store.isLiveNow)
          _NotLiveNow(store: store)
        else if (productId == null || productName == null)
          _WaitingForProduct(brand: brand)
        else
          _CurrentProductCard(
            businessId: businessId,
            productId: productId,
            name: productName,
            price: productPrice ?? 0,
            brand: brand,
          ),
      ],
    );
  }
}

class _NotLiveNow extends StatelessWidget {
  const _NotLiveNow({required this.store});
  final BuyerStoreDetail store;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: Color(0xFFEFE5EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Symbols.sensors, color: AppColors.ink2, size: 44),
            ),
            const SizedBox(height: 20),
            Text('${store.name} no está en vivo ahora', style: AppTextStyles.h1.copyWith(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              'Te avisamos apenas empiece — asegúrate de seguir esta tienda.',
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 22),
            PillButton(
              label: 'Volver a la tienda',
              icon: Symbols.storefront,
              variant: PillButtonVariant.brand,
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingForProduct extends StatelessWidget {
  const _WaitingForProduct({required this.brand});
  final Color brand;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        boxShadow: AppShadows.small,
      ),
      child: Column(
        children: [
          FadeInPulse(color: brand),
          const SizedBox(height: 16),
          Text('En vivo ahora mismo', style: AppTextStyles.h2.copyWith(fontSize: 17)),
          const SizedBox(height: 6),
          Text(
            'En cuanto muestre un producto, aparece aquí para que lo apartes.',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class FadeInPulse extends StatefulWidget {
  const FadeInPulse({super.key, required this.color});
  final Color color;

  @override
  State<FadeInPulse> createState() => _FadeInPulseState();
}

class _FadeInPulseState extends State<FadeInPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
        child: const Icon(Symbols.sensors, color: Colors.white, size: 28),
      ),
    );
  }
}

class _CurrentProductCard extends StatelessWidget {
  const _CurrentProductCard({
    required this.businessId,
    required this.productId,
    required this.name,
    required this.price,
    required this.brand,
  });

  final int businessId;
  final int productId;
  final String name;
  final double price;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: AppColors.liveRed, borderRadius: AppRadii.pillRadius),
          child: const Text(
            'MOSTRANDO AHORA',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [lighten(brand, 0.18), brand],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadii.cardRadius,
            boxShadow: AppShadows.brandPrimary(brand),
          ),
          child: Column(
            children: [
              const Icon(Symbols.shopping_bag, color: Colors.white, size: 40),
              const SizedBox(height: 14),
              Text(
                name,
                textAlign: TextAlign.center,
                style: AppTextStyles.h1.copyWith(color: Colors.white, fontSize: 22),
              ),
              const SizedBox(height: 6),
              Text(
                '\$${price.toStringAsFixed(0)}',
                style: AppTextStyles.h1.copyWith(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => context.push('/reserve/$businessId/$productId'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Symbols.bookmark, color: brand, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Apartar',
                            style: AppTextStyles.button.copyWith(color: brand, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveError extends StatelessWidget {
  const _LiveError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Center(
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
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }
}
