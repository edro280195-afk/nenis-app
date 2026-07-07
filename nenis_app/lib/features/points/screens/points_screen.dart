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
import '../data/points_models.dart';
import '../data/points_repository.dart';

class PointsScreen extends ConsumerWidget {
  const PointsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(pointsFeedProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: feed.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.neni),
            ),
            error: (e, _) =>
                _PointsError(onRetry: () => ref.invalidate(pointsFeedProvider)),
            data: (stores) => _PointsContent(stores: stores),
          ),
        ),
      ),
    );
  }
}

class _PointsContent extends ConsumerWidget {
  const _PointsContent({required this.stores});
  final List<RewardsByBusiness> stores;

  int get _total => stores.fold(0, (sum, s) => sum + s.storePoints);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stores.isEmpty) {
      return RefreshIndicator(
        color: AppColors.neniDeep,
        onRefresh: () async => ref.invalidate(pointsFeedProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: const [
            SizedBox(height: 12),
            _PointsHeader(),
            SizedBox(height: 16),
            _TotalHero(total: 0, storeCount: 0),
            SizedBox(height: 24),
            _PointsEmpty(),
          ],
        ),
      );
    }

    final hasAnyRewards = stores.any((s) => s.hasRewards);

    return RefreshIndicator(
      color: AppColors.neniDeep,
      onRefresh: () async => ref.invalidate(pointsFeedProvider),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const _PointsHeader(),
          const SizedBox(height: 16),
          _TotalHero(total: _total, storeCount: stores.length),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'Tus tiendas'),
          const SizedBox(height: 12),
          ...stores.map(
            (s) => Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 11),
              child: _StorePointsRow(store: s),
            ),
          ),
          if (hasAnyRewards) ...[
            const SizedBox(height: 12),
            const _SectionTitle(title: 'Premios que puedes canjear'),
            const SizedBox(height: 12),
            ...stores
                .where((s) => s.hasRewards)
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: _RewardsByStore(store: s),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _PointsHeader extends StatelessWidget {
  const _PointsHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(22, 4, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tus puntos',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              letterSpacing: -0.4,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Tu lealtad con todas tus tiendas.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.ink2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalHero extends StatelessWidget {
  const _TotalHero({required this.total, required this.storeCount});
  final int total;
  final int storeCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: AppRadii.cardRadius,
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF7E6), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: AppShadows.small,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2D4),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Symbols.stars,
                size: 30,
                color: AppColors.gold,
                fill: 1,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Puntos acumulados',
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$total',
                    style: AppTextStyles.display.copyWith(
                      fontSize: 38,
                      letterSpacing: -0.8,
                    ),
                  ),
                  Text(
                    storeCount == 1 ? 'en 1 tienda' : 'en $storeCount tiendas',
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 12,
                      color: AppColors.ink3,
                    ),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Text(title, style: AppTextStyles.h2.copyWith(fontSize: 17)),
    );
  }
}

class _StorePointsRow extends StatelessWidget {
  const _StorePointsRow({required this.store});
  final RewardsByBusiness store;

  @override
  Widget build(BuildContext context) {
    final brand = colorFromHex(store.brandPrimaryColor);
    final pointsLabel = store.storePoints == 1
        ? '1 punto'
        : '${store.storePoints} puntos';
    final canjea = store.hasRewards
        ? ' · canjea desde ${store.rewards.first.pointsCost} pts'
        : '';
    return GestureDetector(
      onTap: () => context.go('/store/${store.businessId}'),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.softRadius,
          boxShadow: AppShadows.small,
        ),
        child: Row(
          children: [
            StoreAvatarSm(
              label: store.initial,
              gradientStart: lighten(brand, 0.08),
              gradientEnd: brand,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.businessName,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$pointsLabel acumulados aquí$canjea',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const Icon(Symbols.chevron_right, color: AppColors.ink3, size: 22),
          ],
        ),
      ),
    );
  }
}

class _RewardsByStore extends StatelessWidget {
  const _RewardsByStore({required this.store});
  final RewardsByBusiness store;

  @override
  Widget build(BuildContext context) {
    final brand = colorFromHex(store.brandPrimaryColor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: brand,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  store.businessName,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${store.rewards.length} premios',
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: 11.5,
                  color: AppColors.ink3,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 172,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            itemCount: store.rewards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final reward = store.rewards[i];
              return _RewardCard(reward: reward, brand: brand);
            },
          ),
        ),
      ],
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.reward, required this.brand});
  final BuyerReward reward;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.softRadius,
          boxShadow: AppShadows.small,
          border: Border.all(color: AppColors.lineSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [lighten(brand, 0.18), lighten(brand, 0.02)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                reward.icon ?? _defaultIcon(reward.kind),
                style: const TextStyle(fontSize: 24, height: 1.1),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              reward.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: AppRadii.pillRadius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Symbols.stars, size: 12, color: AppColors.gold),
                  const SizedBox(width: 3),
                  Text(
                    reward.costLabel,
                    style: AppTextStyles.chip.copyWith(
                      color: const Color(0xFF8A5A0E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _RedeemButton(brand: brand),
          ],
        ),
      ),
    );
  }

  String _defaultIcon(String kind) {
    switch (kind) {
      case 'shipping':
        return '🚚';
      case 'gift':
        return '🎁';
      default:
        return '💸';
    }
  }
}

class _RedeemButton extends StatelessWidget {
  const _RedeemButton({required this.brand});
  final Color brand;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 32,
      child: TextButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El canje se aplica al pagar en tu pedido.'),
              duration: Duration(seconds: 3),
            ),
          );
        },
        style: TextButton.styleFrom(
          foregroundColor: brand,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.pillRadius,
            side: BorderSide(color: brand.withValues(alpha: 0.5)),
          ),
        ),
        child: const Text(
          'Canjear',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PointsEmpty extends StatelessWidget {
  const _PointsEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2D4),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Symbols.stars,
              color: AppColors.gold,
              size: 40,
              fill: 1,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Aún no tienes puntos',
            textAlign: TextAlign.center,
            style: AppTextStyles.h2.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Reclama tu perfil para juntar puntos con tus tiendas y desbloquear premios.',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 22),
          PillButton(
            label: 'Reclamar mi perfil',
            icon: Symbols.favorite,
            variant: PillButtonVariant.brand,
            onPressed: () => context.go('/claim'),
          ),
        ],
      ),
    );
  }
}

class _PointsError extends StatelessWidget {
  const _PointsError({required this.onRetry});
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
            'No pudimos cargar tus puntos',
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
