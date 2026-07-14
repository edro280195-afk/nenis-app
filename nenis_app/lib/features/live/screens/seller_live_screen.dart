import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/feature_locked_card.dart';
import '../../../shared/widgets/premium_toast.dart';
import '../../account/data/seller_settings_repository.dart';
import '../../seller_updates/data/seller_updates_repository.dart';
import '../data/live_hub_client.dart';
import '../data/live_models.dart';
import '../data/seller_products_repository.dart';

/// Control de la vendedora durante su Live: no toca el video de Facebook
/// para nada — solo anuncia con un toque qué producto está mostrando, y eso
/// llega al instante a las compradoras conectadas (LiveHub). Requiere que
/// ya haya un "Estoy en vivo" activo (se inicia desde Novedades).
class SellerLiveScreen extends ConsumerStatefulWidget {
  const SellerLiveScreen({super.key});

  @override
  ConsumerState<SellerLiveScreen> createState() => _SellerLiveScreenState();
}

class _SellerLiveScreenState extends ConsumerState<SellerLiveScreen> {
  bool _joined = false;
  bool _joining = false;
  int? _announcingId;
  LiveProductAnnouncement? _lastAnnounced;

  Future<void> _ensureJoined() async {
    if (_joined || _joining) return;
    setState(() => _joining = true);
    final hub = ref.read(liveHubProvider);
    hub.productAnnouncedStream.listen((a) {
      if (mounted) setState(() => _lastAnnounced = a);
    });
    final ok = await hub.joinAdminLive();
    if (mounted) {
      setState(() {
        _joined = ok;
        _joining = false;
      });
    }
  }

  Future<void> _announce(SellerProduct product) async {
    setState(() => _announcingId = product.id);
    final hub = ref.read(liveHubProvider);
    final ok = await hub.announceProduct(product.id);
    if (!mounted) return;
    setState(() => _announcingId = null);
    if (ok) {
      setState(() => _lastAnnounced = LiveProductAnnouncement(
            productId: product.id,
            name: product.name,
            price: product.price,
            announcedAt: DateTime.now(),
          ));
    } else {
      context.showPremiumToast(
        'No pudimos anunciarlo. Revisa tu conexión.',
        type: PremiumToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessSettings = ref.watch(sellerBusinessSettingsProvider);
    final hasLivePush =
        businessSettings.value?.features.contains('LivePush') ?? false;
    final activeLive = ref.watch(activeLiveAnnouncementProvider);

    ref.listen(activeLiveAnnouncementProvider, (previous, next) {
      if (next.value?.isActive == true) _ensureJoined();
    });

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          child: ListView(
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
                          context.canPop() ? context.pop() : context.go('/account'),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(Icons.adaptive.arrow_back, size: 20, color: AppColors.ink),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Anunciar en vivo', style: AppTextStyles.h1.copyWith(fontSize: 22)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Toca un producto cada vez que lo muestres en tu Live — tus '
                'clientas lo ven aparecer al instante en la app.',
                style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
              ),
              const SizedBox(height: 20),
              if (!hasLivePush)
                const FeatureLockedCard(
                  title: 'Anunciar en vivo es una función Pro',
                  body: 'Avisa a tus seguidoras qué producto estás mostrando, en tiempo real.',
                )
              else
                activeLive.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(child: CircularProgressIndicator(color: AppColors.neniDeep)),
                  ),
                  error: (_, _) => Text('No pudimos revisar tu vivo.', style: AppTextStyles.subtitle),
                  data: (active) {
                    if (active == null || !active.isActive) {
                      return _NotLiveYetCard(
                        onStart: () => context.push('/seller/updates'),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LiveStatusBanner(
                          title: active.title,
                          connecting: _joining && !_joined,
                          lastAnnounced: _lastAnnounced,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'TU CATÁLOGO',
                          style: AppTextStyles.eyebrow(AppColors.neniDeep).copyWith(letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 10),
                        Consumer(
                          builder: (context, ref, _) {
                            final products = ref.watch(sellerProductsProvider);
                            return products.when(
                              loading: () => const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.neni),
                                  ),
                                ),
                              ),
                              error: (_, _) =>
                                  Text('No pudimos cargar tu catálogo.', style: AppTextStyles.subtitle),
                              data: (list) {
                                if (list.isEmpty) {
                                  return Text(
                                    'Todavía no tienes productos activos en tu catálogo.',
                                    style: AppTextStyles.subtitle,
                                  );
                                }
                                return Column(
                                  children: [
                                    for (final p in list) ...[
                                      _ProductAnnounceRow(
                                        product: p,
                                        busy: _announcingId == p.id,
                                        isCurrent: _lastAnnounced?.productId == p.id,
                                        onTap: () => _announce(p),
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotLiveYetCard extends StatelessWidget {
  const _NotLiveYetCard({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEFE5EE),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Symbols.sensors, color: AppColors.ink2, size: 26),
          ),
          const SizedBox(height: 14),
          Text('Primero avisa que estás en vivo', style: AppTextStyles.h2.copyWith(fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            'Desde Novedades puedes prender "Estoy en vivo ahora". En cuanto '
            'lo hagas, vuelve aquí para empezar a anunciar productos.',
            style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          Material(
            color: AppColors.neniDeep,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onStart,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Text(
                  'Ir a Novedades',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveStatusBanner extends StatelessWidget {
  const _LiveStatusBanner({
    required this.title,
    required this.connecting,
    required this.lastAnnounced,
  });

  final String? title;
  final bool connecting;
  final LiveProductAnnouncement? lastAnnounced;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF3D8B), Color(0xFFFF0072)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.softRadius,
        boxShadow: AppShadows.brandPrimary(const Color(0xFFFF0072)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(Symbols.sensors, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title?.isNotEmpty == true ? title! : 'Estás en vivo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(fontSize: 14.5, color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 1),
                Text(
                  connecting
                      ? 'Conectando…'
                      : lastAnnounced != null
                          ? 'Mostrando: ${lastAnnounced!.name}'
                          : 'Toca un producto de abajo para anunciarlo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductAnnounceRow extends StatelessWidget {
  const _ProductAnnounceRow({
    required this.product,
    required this.busy,
    required this.isCurrent,
    required this.onTap,
  });

  final SellerProduct product;
  final bool busy;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: AppRadii.softRadius,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.softRadius,
            boxShadow: AppShadows.small,
            border: isCurrent ? Border.all(color: AppColors.neniDeep, width: 1.4) : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${product.price.toStringAsFixed(0)} · ${product.stock} disponibles',
                      style: AppTextStyles.subtitle.copyWith(fontSize: 11.5, color: AppColors.ink2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.neniDeep),
                )
              else if (isCurrent)
                const Icon(Symbols.check_circle, color: AppColors.neniDeep, size: 22)
              else
                Material(
                  color: AppColors.neniDeep,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onTap,
                    child: const SizedBox(
                      width: 34,
                      height: 34,
                      child: Icon(Symbols.campaign, color: Colors.white, size: 18),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
