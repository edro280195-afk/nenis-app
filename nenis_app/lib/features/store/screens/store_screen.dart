import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/color_hex.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';
import '../../../shared/widgets/store_avatar.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/interactive_bounce.dart';
import '../../../shared/widgets/premium_toast.dart';
import '../../raffles/data/raffles_models.dart';
import '../../raffles/data/raffles_repository.dart';
import '../../tandas/data/tandas_models.dart';
import '../../tandas/data/tandas_repository.dart';
import '../data/follow_models.dart';
import '../data/follow_repository.dart';
import '../data/store_models.dart';
import '../data/store_posts_models.dart';
import '../data/store_posts_repository.dart';
import '../data/store_repository.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key, required this.businessId});
  final String businessId;

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
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

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(storeControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: feed.when(
            loading: () => const _StoreLoading(),
            error: (e, _) => _StoreError(
              message: e.toString(),
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
            data: (store) {
              if (store == null) return const _StoreLoading();
              return _StoreContent(store: store);
            },
          ),
        ),
      ),
    );
  }
}

class _StoreLoading extends StatelessWidget {
  const _StoreLoading();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Container(
          height: 132,
          decoration: const BoxDecoration(
            color: Color(0xFFF5EEF2),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Positioned(
                  top: 8,
                  left: 14,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white30,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 14,
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white30,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white30,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Skeleton.circle(size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Skeleton.text(width: 140, height: 18),
                    SizedBox(height: 6),
                    Skeleton.text(width: 180, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Skeleton(height: 48, borderRadius: 14),
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Skeleton(width: 80, height: 32, borderRadius: 16),
              SizedBox(width: 12),
              Skeleton(width: 80, height: 32, borderRadius: 16),
              SizedBox(width: 12),
              Skeleton(width: 80, height: 32, borderRadius: 16),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.78,
            ),
            itemCount: 4,
            itemBuilder: (_, __) => const Skeleton(borderRadius: 20),
          ),
        ),
      ],
    );
  }
}

class _StoreError extends StatelessWidget {
  const _StoreError({required this.message, required this.onBack});
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

class _StoreContent extends ConsumerWidget {
  const _StoreContent({required this.store});
  final BuyerStoreDetail store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(storeSelectedTabProvider);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _StoreHeader(store: store),
        _ProfileRow(store: store),
        _PtsBar(store: store),
        if (store.isLiveNow) _LiveNowBanner(store: store),
        _TabsRow(
          store: store,
          selected: tab,
          onChanged: (t) => ref.read(storeSelectedTabProvider.notifier).set(t),
        ),
        _TabContent(store: store, tab: tab),
      ],
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.store});
  final BuyerStoreDetail store;
  @override
  Widget build(BuildContext context) {
    final brand = colorFromHex(store.brandPrimaryColor);
    return Container(
      height: 132,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [lighten(brand, 0.12), brand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: AppShadows.brandPrimary(brand),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: 8,
              left: 14,
              child: _HeaderIcon(
                icon: Icons.adaptive.arrow_back,
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
              ),
            ),
            Positioned(
              top: 8,
              right: 14,
              child: Row(
                children: [
                  _HeaderIcon(
                    icon: Symbols.favorite,
                    onPressed: () =>
                        _soonToast(context, 'Pronto podrás favoritarla'),
                  ),
                  const SizedBox(width: 8),
                  _HeaderIcon(
                    icon: Symbols.ios_share,
                    onPressed: () => _shareStore(store),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 18,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.liveRed,
                  borderRadius: AppRadii.pillRadius,
                ),
                child: const Text(
                  'TIENDA',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: AppColors.ink),
        ),
      ),
    );
  }
}

class _ProfileRow extends ConsumerWidget {
  const _ProfileRow({required this.store});
  final BuyerStoreDetail store;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBusy = ref.watch(followControllerProvider);
    return Transform.translate(
      offset: const Offset(0, -34),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                boxShadow: AppShadows.card,
              ),
              padding: const EdgeInsets.all(4),
              child: StoreAvatarXl(label: store.initial),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            store.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.h1.copyWith(fontSize: 20),
                          ),
                        ),
                        if (store.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Symbols.verified,
                            size: 16,
                            color: AppColors.statusDeliveredFg,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (store.hasRatings) ...[
                      Row(
                        children: [
                          const Icon(Symbols.star, size: 14, color: AppColors.gold, fill: 1),
                          const SizedBox(width: 3),
                          Text(
                            store.averageRating!.toStringAsFixed(1),
                            style: AppTextStyles.body.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '(${store.ratingsCount})',
                            style: AppTextStyles.subtitle.copyWith(fontSize: 11.5, color: AppColors.ink3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      _subtitle(store),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 12,
                        color: AppColors.ink2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (store.isFollowing) ...[
              _HeaderIcon(
                icon: Symbols.tune,
                onPressed: () => _openFollowPreferences(context, store.businessId),
              ),
              const SizedBox(width: 8),
            ],
            PillButton(
              label: store.isFollowing ? 'Siguiendo' : 'Seguir',
              icon: store.isFollowing ? Symbols.check : Symbols.add,
              expand: false,
              variant: store.isFollowing
                  ? PillButtonVariant.ghost
                  : PillButtonVariant.brand,
              onPressed: isBusy
                  ? null
                  : () async {
                      try {
                        await ref.read(followControllerProvider.notifier).toggle();
                      } on FollowException catch (e) {
                        if (context.mounted) {
                          context.showPremiumToast(
                            e.message,
                            type: PremiumToastType.error,
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _openFollowPreferences(BuildContext context, int businessId) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FollowPreferencesSheet(businessId: businessId),
    );
  }

  String _subtitle(BuyerStoreDetail s) {
    final parts = <String>[];
    if (s.city != null && s.city!.isNotEmpty) parts.add(s.city!);
    if (s.clientCount > 0) {
      parts.add('${s.clientCount} clientas');
    }
    if (s.followerCount > 0) {
      parts.add('${s.followerCount} siguen');
    }
    return parts.isEmpty ? 'Tienda en Neni\'s' : parts.join(' · ');
  }
}

/// Hoja modal para ajustar qué avisos manda una tienda que ya sigues.
/// Carga el estado fresco al abrir (el `FollowState` completo — con los
/// flags granulares — no viaja en `BuyerStoreDetail`, solo `isFollowing`).
class _FollowPreferencesSheet extends ConsumerStatefulWidget {
  const _FollowPreferencesSheet({required this.businessId});
  final int businessId;

  @override
  ConsumerState<_FollowPreferencesSheet> createState() => _FollowPreferencesSheetState();
}

class _FollowPreferencesSheetState extends ConsumerState<_FollowPreferencesSheet> {
  FollowState? _state;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final state = await ref.read(followRepositoryProvider).getState(widget.businessId);
      if (mounted) setState(() { _state = state; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update({bool? notifyOnPost, bool? notifyOnLive}) async {
    final current = _state;
    if (current == null || _saving) return;
    final next = FollowState(
      businessId: current.businessId,
      isFollowing: current.isFollowing,
      notifyOnPost: notifyOnPost ?? current.notifyOnPost,
      notifyOnLive: notifyOnLive ?? current.notifyOnLive,
      isVip: current.isVip,
    );
    setState(() { _state = next; _saving = true; });
    try {
      final saved = await ref.read(followRepositoryProvider).updatePreferences(
            widget.businessId,
            notifyOnPost: next.notifyOnPost,
            notifyOnLive: next.notifyOnLive,
          );
      if (mounted) setState(() { _state = saved; _saving = false; });
    } on FollowException catch (e) {
      if (mounted) {
        setState(() { _state = current; _saving = false; });
        context.showPremiumToast(e.message, type: PremiumToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(22, 14, 22, 22 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Tus avisos de esta tienda', style: AppTextStyles.h2.copyWith(fontSize: 17)),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(color: AppColors.neniDeep)),
            )
          else if (_state == null)
            Text('No pudimos cargar tus preferencias.', style: AppTextStyles.subtitle)
          else ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Novedades'),
              subtitle: const Text('Cuando publique fotos o textos nuevos.'),
              value: _state!.notifyOnPost,
              activeTrackColor: AppColors.neniDeep,
              onChanged: _saving ? null : (v) => _update(notifyOnPost: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('En vivo'),
              subtitle: const Text('Cuando empiece a transmitir.'),
              value: _state!.notifyOnLive,
              activeTrackColor: AppColors.neniDeep,
              onChanged: _saving ? null : (v) => _update(notifyOnLive: v),
            ),
          ],
        ],
      ),
    );
  }
}

class _PtsBar extends StatelessWidget {
  const _PtsBar({required this.store});
  final BuyerStoreDetail store;
  @override
  Widget build(BuildContext context) {
    final brand = colorFromHex(store.brandPrimaryColor);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
      child: GestureDetector(
        onTap: () => context.go('/points'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF6E6), Color(0xFFFFFFFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadii.cardRadius,
            boxShadow: AppShadows.small,
            border: Border.all(color: AppColors.lineSoft),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2D4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Symbols.stars,
                  color: AppColors.gold,
                  size: 20,
                  fill: 1,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${store.points.currentPoints} puntos',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _caption(store.points.nextRewardAt),
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 11.5,
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Symbols.chevron_right, size: 20, color: lighten(brand, 0.1)),
            ],
          ),
        ),
      ),
    );
  }

  String _caption(int? nextRewardAt) {
    if (nextRewardAt == null) {
      return 'Acumula puntos con cada compra';
    }
    return 'acumulados aquí · canjea desde $nextRewardAt pts';
  }
}

/// Aviso en tiempo real de "está en vivo ahora" (`LiveAnnouncement`). Tocar
/// el banner entra al visor en vivo dentro de la app (feed de productos
/// anunciados + apartar); el botón "Ver en Facebook" abre el video real —
/// las dos cosas coexisten a propósito, una no reemplaza a la otra.
class _LiveNowBanner extends StatefulWidget {
  const _LiveNowBanner({required this.store});
  final BuyerStoreDetail store;

  @override
  State<_LiveNowBanner> createState() => _LiveNowBannerState();
}

class _LiveNowBannerState extends State<_LiveNowBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
      child: GestureDetector(
        onTap: () => context.push('/live/${widget.store.businessId}'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.liveRed,
            borderRadius: AppRadii.softRadius,
            boxShadow: AppShadows.brandPrimary(AppColors.liveRed),
          ),
          child: Row(
            children: [
              FadeTransition(
                opacity: _controller,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.store.liveAnnouncementTitle != null
                      ? '¡En vivo! ${widget.store.liveAnnouncementTitle}'
                      : '¡Está en vivo ahora mismo!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PillButton(
                label: 'Ver en Facebook',
                icon: Symbols.open_in_new,
                expand: false,
                variant: PillButtonVariant.ghost,
                onPressed: () =>
                    _openStoreFacebook(context, widget.store.facebookUrl),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabsRow extends StatelessWidget {
  const _TabsRow({
    required this.store,
    required this.selected,
    required this.onChanged,
  });
  final BuyerStoreDetail store;
  final StoreTab selected;
  final ValueChanged<StoreTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
      child: SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final t in StoreTab.values) ...[
              _TabPill(
                label: _label(t, store),
                isActive: t == selected,
                onTap: () => onChanged(t),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  String _label(StoreTab t, BuyerStoreDetail s) {
    switch (t) {
      case StoreTab.products:
        return 'Productos${s.products.isNotEmpty ? ' · ${s.products.length}' : ''}';
      case StoreTab.lives:
        return 'En vivo${s.isLiveNow ? ' · 1' : ''}';
      case StoreTab.novedades:
        return 'Novedades';
      case StoreTab.tandas:
        return s.activeTandasCount > 0
            ? 'Tandas · ${s.activeTandasCount}'
            : 'Tandas';
      case StoreTab.sorteos:
        return s.activeRafflesCount > 0
            ? 'Sorteos · ${s.activeRafflesCount}'
            : 'Sorteos';
    }
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? AppColors.ink : AppColors.segTrack,
          borderRadius: AppRadii.pillRadius,
        ),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: isActive ? AppColors.surface : AppColors.ink2,
          ),
        ),
      ),
    );
  }
}

class _TabContent extends ConsumerWidget {
  const _TabContent({required this.store, required this.tab});
  final BuyerStoreDetail store;
  final StoreTab tab;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (tab) {
      case StoreTab.products:
        return _ProductsGrid(store: store);
      case StoreTab.lives:
        return _LiveTabContent(store: store);
      case StoreTab.novedades:
        return _NovedadesTabContent(businessId: store.businessId);
      case StoreTab.tandas:
        return _TandasTabContent(businessId: store.businessId);
      case StoreTab.sorteos:
        return _SorteosTabContent(businessId: store.businessId);
    }
  }
}

class _ProductsGrid extends StatelessWidget {
  const _ProductsGrid({required this.store});
  final BuyerStoreDetail store;
  @override
  Widget build(BuildContext context) {
    if (store.products.isEmpty) {
      return const _EmptyTab(
        icon: Symbols.inventory_2,
        iconColor: AppColors.ink2,
        iconBg: Color(0xFFEFE5EE),
        title: 'Pronto verás el catálogo aquí',
        body: 'Esta tienda aún no subió sus productos a la app.',
      );
    }
    final brand = colorFromHex(store.brandPrimaryColor);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemCount: store.products.length,
        itemBuilder: (context, i) => _ProductCard(
          product: store.products[i],
          brand: brand,
          onTap: () => context.push(
            '/reserve/${store.businessId}/${store.products[i].id}',
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.brand,
    required this.onTap,
  });
  final BuyerProduct product;
  final Color brand;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InteractiveBounce(
      onPressed: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.softRadius,
          boxShadow: AppShadows.small,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Placeholder con gradient (el backend no expone imágenes todavía).
            Expanded(
              child: Container(
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
                  size: 36,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12.5,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '\$${product.price.toStringAsFixed(0)}',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Material(
                        color: brand,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(11),
                          onTap: onTap,
                          child: const SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(
                              Symbols.add,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveTabContent extends StatelessWidget {
  const _LiveTabContent({required this.store});
  final BuyerStoreDetail store;
  @override
  Widget build(BuildContext context) {
    if (!store.isLiveNow) {
      return _EmptyTab(
        icon: Symbols.sensors,
        iconColor: AppColors.ink2,
        iconBg: const Color(0xFFEFE5EE),
        title: 'No hay lives en este momento',
        body: '${store.name} avisará por aquí cuando empiece un live.',
      );
    }
    final subtitle = store.hasCurrentLiveProduct
        ? 'Mostrando: ${store.liveCurrentProductName}'
        : 'Toca para ver qué está mostrando';
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
      child: GestureDetector(
        onTap: () => context.push('/live/${store.businessId}'),
        child: Container(
          padding: const EdgeInsets.all(16),
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
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF3D8B), Color(0xFFFF0072)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Symbols.sensors,
                      color: Colors.white,
                      size: 24,
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
                              : 'En vivo ahora',
                          style: AppTextStyles.body.copyWith(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 12,
                            color: AppColors.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.liveRed,
                      borderRadius: AppRadii.pillRadius,
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Toca para ver el live →',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.ink3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TandasTabContent extends ConsumerWidget {
  const _TandasTabContent({required this.businessId});
  final int businessId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(tandasControllerProvider);
    return feed.when(
      loading: () => const SizedBox(
        height: 60,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.neni,
            ),
          ),
        ),
      ),
      error: (e, _) => _EmptyTab(
        icon: Symbols.cloud_off,
        iconColor: AppColors.ink3,
        iconBg: AppColors.segTrack,
        title: 'No pudimos cargar las tandas',
        body: 'Revisa tu conexión e intenta de nuevo.',
      ),
      data: (all) {
        final filtered = all.where((t) => t.businessId == businessId).toList();
        if (filtered.isEmpty) {
          return const _EmptyTab(
            icon: Symbols.groups,
            iconColor: AppColors.neniDeep,
            iconBg: Color(0xFFFFE1EC),
            title: 'Esta tienda no tiene tandas abiertas',
            body: 'Vuelve más tarde para ver si abre una tanda nueva.',
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
          child: Column(
            children: [
              for (final t in filtered) ...[
                _TandaCompactRow(tanda: t),
                const SizedBox(height: 11),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TandaCompactRow extends StatelessWidget {
  const _TandaCompactRow({required this.tanda});
  final BuyerTanda tanda;
  @override
  Widget build(BuildContext context) {
    final brand = colorFromHex(tanda.brandPrimaryColor);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        boxShadow: AppShadows.small,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE1EC),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Symbols.groups,
              color: AppColors.neniDeep,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tanda.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  tanda.isMine
                      ? 'Tu turno ${tanda.myTurn ?? '—'} · ${tanda.weeklyAmountLabel}'
                      : 'Disponible · ${tanda.weeklyAmountLabel}',
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 11.5,
                    color: AppColors.ink2,
                  ),
                ),
              ],
            ),
          ),
          Icon(Symbols.chevron_right, color: lighten(brand, 0.1), size: 20),
        ],
      ),
    );
  }
}

class _NovedadesTabContent extends ConsumerWidget {
  const _NovedadesTabContent({required this.businessId});
  final int businessId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(storePostsControllerProvider);
    return feed.when(
      loading: () => const SizedBox(
        height: 60,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.neni),
          ),
        ),
      ),
      error: (e, _) => _EmptyTab(
        icon: Symbols.cloud_off,
        iconColor: AppColors.ink3,
        iconBg: AppColors.segTrack,
        title: 'No pudimos cargar las novedades',
        body: 'Revisa tu conexión e intenta de nuevo.',
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return const _EmptyTab(
            icon: Symbols.campaign,
            iconColor: AppColors.neniDeep,
            iconBg: Color(0xFFFFE1EC),
            title: 'Aún no hay novedades',
            body: 'Esta tienda avisará por aquí cuando publique algo nuevo.',
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
          child: Column(
            children: [
              for (final p in posts) ...[
                _PostCard(post: p),
                const SizedBox(height: 11),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});
  final StorePostFeedItem post;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        boxShadow: AppShadows.small,
        border: post.isVipOnly
            ? Border.all(color: AppColors.gold.withValues(alpha: 0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.isVipOnly) ...[
            Row(
              children: [
                const Icon(Symbols.workspace_premium, size: 15, color: AppColors.gold),
                const SizedBox(width: 5),
                Text(
                  'SOLO VIP',
                  style: AppTextStyles.chip.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (post.isLocked)
            Row(
              children: [
                const Icon(Symbols.lock, size: 18, color: AppColors.ink3),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Únete al grupo VIP de esta tienda para ver esta novedad.',
                    style: AppTextStyles.subtitle.copyWith(fontSize: 12.5, color: AppColors.ink2),
                  ),
                ),
              ],
            )
          else
            Text(
              post.body,
              style: AppTextStyles.body.copyWith(fontSize: 13.5, height: 1.35),
            ),
          const SizedBox(height: 8),
          Text(
            _relativeTime(post.createdAt),
            style: AppTextStyles.subtitle.copyWith(fontSize: 11, color: AppColors.ink3),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'hace ${diff.inDays} d';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _SorteosTabContent extends ConsumerWidget {
  const _SorteosTabContent({required this.businessId});
  final int businessId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(rafflesControllerProvider);
    return feed.when(
      loading: () => const SizedBox(
        height: 60,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.neni,
            ),
          ),
        ),
      ),
      error: (e, _) => _EmptyTab(
        icon: Symbols.cloud_off,
        iconColor: AppColors.ink3,
        iconBg: AppColors.segTrack,
        title: 'No pudimos cargar los sorteos',
        body: 'Revisa tu conexión e intenta de nuevo.',
      ),
      data: (all) {
        final filtered = all.where((r) => r.businessId == businessId).toList();
        if (filtered.isEmpty) {
          return const _EmptyTab(
            icon: Symbols.celebration,
            iconColor: AppColors.neniDeep,
            iconBg: Color(0xFFFFE1EC),
            title: 'Aún no hay sorteos',
            body: 'Esta tienda suele anunciar sorteos en fechas especiales.',
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
          child: Column(
            children: [
              for (final r in filtered) ...[
                _RaffleCompactRow(raffle: r),
                const SizedBox(height: 11),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RaffleCompactRow extends StatelessWidget {
  const _RaffleCompactRow({required this.raffle});
  final BuyerRaffle raffle;
  @override
  Widget build(BuildContext context) {
    final brand = colorFromHex(raffle.brandPrimaryColor);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        boxShadow: AppShadows.small,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [lighten(brand, 0.18), lighten(brand, 0.02)],
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Symbols.celebration,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  raffle.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  raffle.prizeDescription ?? raffle.prizeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 11.5,
                    color: AppColors.ink2,
                  ),
                ),
              ],
            ),
          ),
          if (raffle.isMineEntered)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: AppRadii.pillRadius,
              ),
              child: Text(
                '${raffle.myEntryCount} boleto${raffle.myEntryCount == 1 ? '' : 's'}',
                style: AppTextStyles.chip.copyWith(
                  color: const Color(0xFF8A5A0E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 30, 30, 20),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(icon, color: iconColor, size: 40),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.h2.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

void _soonToast(BuildContext context, String message) {
  context.showPremiumToast(message, type: PremiumToastType.info);
}

/// Abre el Facebook de la tienda (`Business.FacebookUrl`) en el navegador o
/// la app de Facebook. Si la vendedora todavía no lo configuró, avisa en
/// vez de fingir que existe.
Future<void> _openStoreFacebook(BuildContext context, String? facebookUrl) async {
  if (facebookUrl == null || facebookUrl.isEmpty) {
    _soonToast(context, 'Esta tienda aún no agregó su Facebook.');
    return;
  }
  final uri = Uri.tryParse(facebookUrl);
  final opened = uri != null &&
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    context.showPremiumToast(
      'No pudimos abrir Facebook.',
      type: PremiumToastType.error,
    );
  }
}

/// Comparte un link a la tienda. Si quien lo recibe ya tiene la app
/// instalada y la abre con sesión, `deep_link_service.dart` la navega ahí
/// directo; si no, el mensaje incluye el nombre de la tienda como respaldo.
Future<void> _shareStore(BuyerStoreDetail store) async {
  await SharePlus.instance.share(
    ShareParams(
      text: '¡Sígueme en Neni\'s App! Soy ${store.name} 💕\n'
          'https://app.nenisapp.com/store/${store.businessId}',
      subject: store.name,
    ),
  );
}
