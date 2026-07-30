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
import '../../../shared/widgets/segmented.dart';
import '../../../shared/widgets/skeleton.dart';
import '../data/raffles_models.dart';
import '../data/raffles_repository.dart';

class RafflesScreen extends ConsumerWidget {
  const RafflesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(rafflesControllerProvider);
    final filter = ref.watch(rafflesControllerProvider.notifier).filter;

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: feed.when(
            loading: () => const _RafflesLoading(),
            error: (e, _) => _RafflesError(
              onRetry: () => ref.invalidate(rafflesControllerProvider),
            ),
            data: (raffles) {
              final filtered = _applyFilter(raffles, filter);
              return Column(
                children: [
                  const _RafflesHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
                    child: SegmentedControl(
                      items: RafflesFilter.values
                          .map((f) => SegmentedItem(label: f.label))
                          .toList(),
                      selectedIndex: RafflesFilter.values.indexOf(filter),
                      onChanged: (i) => ref
                          .read(rafflesControllerProvider.notifier)
                          .setFilter(RafflesFilter.values[i]),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? _RafflesEmpty(filter: filter)
                        : _RafflesList(raffles: filtered),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<BuyerRaffle> _applyFilter(List<BuyerRaffle> all, RafflesFilter f) {
    switch (f) {
      case RafflesFilter.active:
        return all.where((r) => r.isActive).toList();
      case RafflesFilter.mine:
        return all.where((r) => r.isMineEntered).toList();
      case RafflesFilter.history:
        return all.where((r) => r.isCompleted || r.isCancelled).toList();
    }
  }
}

class _RafflesHeader extends StatelessWidget {
  const _RafflesHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(22, 4, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sorteos',
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
            'Participa y gana con tus tiendas favoritas.',
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

class _RafflesList extends ConsumerWidget {
  const _RafflesList({required this.raffles});
  final List<BuyerRaffle> raffles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppColors.neniDeep,
      onRefresh: () async => ref.invalidate(rafflesControllerProvider),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        itemCount: raffles.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _RaffleCard(raffle: raffles[i]),
        ),
      ),
    );
  }
}

class _RaffleCard extends StatelessWidget {
  const _RaffleCard({required this.raffle});
  final BuyerRaffle raffle;

  @override
  Widget build(BuildContext context) {
    final brand = colorFromHex(raffle.brandPrimaryColor);
    final isWinner = raffle.amIWinner;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        boxShadow: AppShadows.small,
        border: isWinner
            ? Border.all(color: AppColors.statusDeliveredFg, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (raffle.imageUrl != null && raffle.imageUrl!.isNotEmpty)
                _RaffleImage(url: raffle.imageUrl!, brand: brand)
              else
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [lighten(brand, 0.18), lighten(brand, 0.02)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Symbols.celebration,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      raffle.businessName,
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 11.5,
                        color: AppColors.ink3,
                      ),
                    ),
                    Text(
                      raffle.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (isWinner) const _WinnerBadge(),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Symbols.card_giftcard,
                size: 14,
                color: AppColors.neniDeep,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  raffle.prizeDescription ??
                      '${raffle.prizeLabel}${raffle.prizeValue != null ? ' · \$${raffle.prizeValue!.toStringAsFixed(0)}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 12.5,
                    color: AppColors.ink2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Symbols.calendar_today,
                size: 14,
                color: AppColors.ink3,
              ),
              const SizedBox(width: 5),
              Text(
                'Sorteo: ${_formatDate(raffle.raffleDate)}',
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: 12,
                  color: AppColors.ink3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (raffle.isMineEntered)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E6),
                    borderRadius: AppRadii.pillRadius,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Symbols.confirmation_number,
                        size: 14,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        raffle.myEntryCount == 1
                            ? '1 boleto'
                            : '${raffle.myEntryCount} boletos',
                        style: AppTextStyles.chip.copyWith(
                          color: const Color(0xFF8A5A0E),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.segTrack,
                    borderRadius: AppRadii.pillRadius,
                  ),
                  child: Text(
                    'Aún sin boletos',
                    style: AppTextStyles.chip.copyWith(
                      color: AppColors.ink3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              _StatusChip(raffle: raffle),
            ],
          ),
        ],
      ),
    );
  }
}

class _RaffleImage extends StatelessWidget {
  const _RaffleImage({required this.url, required this.brand});
  final String url;
  final Color brand;
  @override
  Widget build(BuildContext context) {
    // Imagen segura: por ahora un placeholder con gradient. La app
    // probablemente use cached_network_image cuando llegue el feature.
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [lighten(brand, 0.18), lighten(brand, 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Icon(Symbols.celebration, color: Colors.white, size: 26),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.raffle});
  final BuyerRaffle raffle;
  @override
  Widget build(BuildContext context) {
    if (raffle.isCompleted) {
      return _Pill(
        icon: Symbols.celebration,
        label: 'Finalizado',
        fg: AppColors.statusDeliveredFg,
        bg: AppColors.statusDeliveredBg,
      );
    }
    if (raffle.isCancelled) {
      return _Pill(
        icon: Symbols.block,
        label: 'Cancelado',
        fg: AppColors.ink2,
        bg: const Color(0xFFEFE5EE),
      );
    }
    return _Pill(
      icon: Symbols.fiber_manual_record,
      label: 'Activo',
      fg: AppColors.statusRouteFg,
      bg: AppColors.statusRouteBg,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
  });
  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadii.pillRadius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.chip.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WinnerBadge extends StatelessWidget {
  const _WinnerBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD9F3E6), Color(0xFFFFE1EC)],
        ),
        borderRadius: AppRadii.pillRadius,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.celebration,
            size: 14,
            color: AppColors.statusDeliveredFg,
          ),
          SizedBox(width: 4),
          Text(
            '¡Ganaste!',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.statusDeliveredFg,
            ),
          ),
        ],
      ),
    );
  }
}

class _RafflesEmpty extends StatelessWidget {
  const _RafflesEmpty({required this.filter});
  final RafflesFilter filter;
  @override
  Widget build(BuildContext context) {
    final isActive = filter == RafflesFilter.active;
    final isMine = filter == RafflesFilter.mine;
    final (icon, title, body) = switch (filter) {
      RafflesFilter.active => (
        Symbols.celebration,
        'No hay sorteos activos por ahora',
        'Cuando tu tienda abra un sorteo aparecerá aquí.',
      ),
      RafflesFilter.mine => (
        Symbols.confirmation_number,
        'Aún no tienes boletos',
        'Tus compras con tiendas en promoción se convierten en boletos.',
      ),
      RafflesFilter.history => (
        Symbols.history,
        'Aún no hay sorteos finalizados',
        'Cuando se cierre un sorteo lo verás aquí.',
      ),
    };
    return RefreshIndicator(
      color: AppColors.neniDeep,
      onRefresh: () async {},
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 30, bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFFFE1EC)
                        : (isMine
                              ? const Color(0xFFFFF2D4)
                              : const Color(0xFFD9F3E6)),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(
                    icon,
                    color: isActive
                        ? AppColors.neniDeep
                        : (isMine
                              ? AppColors.gold
                              : AppColors.statusDeliveredFg),
                    size: 40,
                  ),
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
                const SizedBox(height: 22),
                PillButton(
                  label: 'Explorar tiendas',
                  icon: Symbols.storefront,
                  variant: PillButtonVariant.brand,
                  onPressed: () => context.go('/home'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RafflesError extends StatelessWidget {
  const _RafflesError({required this.onRetry});
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
            'No pudimos cargar tus sorteos',
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

String _formatDate(DateTime date) {
  return DateFormat("d 'de' MMM, yyyy", 'es').format(date.toLocal());
}

class _RafflesLoading extends StatelessWidget {
  const _RafflesLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
          child: Row(
            children: const [
              Skeleton.circle(size: 32),
              SizedBox(width: 16),
              Skeleton.text(width: 120, height: 20),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22),
          child: Skeleton(height: 48, borderRadius: 14),
        ),
        const SizedBox(height: 20),
        ...List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.fromLTRB(22, 0, 22, 14),
            child: Skeleton(height: 150, borderRadius: 24),
          ),
        ),
      ],
    );
  }
}
