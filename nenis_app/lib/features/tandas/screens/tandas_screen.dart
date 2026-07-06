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
import '../../../shared/widgets/glass_bottom_nav.dart';
import '../../../shared/widgets/pill_button.dart';
import '../../../shared/widgets/segmented.dart';
import '../../../shared/widgets/store_avatar.dart';
import '../data/tandas_models.dart';
import '../data/tandas_repository.dart';

import '../../../core/auth/auth_controller.dart';
import 'seller_tandas_screen.dart';

class TandasScreen extends ConsumerWidget {
  const TandasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).value;
    final isSeller = session != null && session.hasMembership;
    return isSeller ? const SellerTandasScreen() : const BuyerTandasScreen();
  }
}

class BuyerTandasScreen extends ConsumerWidget {
  const BuyerTandasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(tandasControllerProvider);
    final filter = ref.watch(tandasControllerProvider.notifier).filter;

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              feed.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.neni),
                ),
                error: (e, _) => _TandasError(
                  onRetry: () => ref.invalidate(tandasControllerProvider),
                ),
                data: (tandas) {
                  final filtered = filter == TandasFilter.mine
                      ? tandas.where((t) => t.isMine).toList()
                      : tandas.where((t) => !t.isMine).toList();
                  return Column(
                    children: [
                      const _TandasHeader(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
                        child: SegmentedControl(
                          items: TandasFilter.values
                              .map((f) => SegmentedItem(label: f.label))
                              .toList(),
                          selectedIndex:
                              TandasFilter.values.indexOf(filter),
                          onChanged: (i) => ref
                              .read(tandasControllerProvider.notifier)
                              .setFilter(TandasFilter.values[i]),
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? _TandasEmpty(filter: filter)
                            : _TandasList(tandas: filtered),
                      ),
                    ],
                  );
                },
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GlassBottomNav(
                  items: buildDefaultNavItems(),
                  currentRoute: '/tandas',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TandasHeader extends StatelessWidget {
  const _TandasHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(22, 4, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tus tandas',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                letterSpacing: -0.4,
              )),
          SizedBox(height: 2),
          Text('Avanza semana a semana con tus tiendas.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.ink2,
              )),
        ],
      ),
    );
  }
}

class _TandasList extends ConsumerWidget {
  const _TandasList({required this.tandas});
  final List<BuyerTanda> tandas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppColors.neniDeep,
      onRefresh: () async => ref.invalidate(tandasControllerProvider),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 110),
        itemCount: tandas.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _TandaCard(tanda: tandas[i]),
        ),
      ),
    );
  }
}

class _TandaCard extends ConsumerWidget {
  const _TandaCard({required this.tanda});
  final BuyerTanda tanda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = colorFromHex(tanda.brandPrimaryColor);
    return GestureDetector(
      onTap: () => context.go('/store/${tanda.businessId}'),
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
                  label: tanda.initial,
                  gradientStart: lighten(brand, 0.08),
                  gradientEnd: brand,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tanda.businessName,
                          style: AppTextStyles.subtitle
                              .copyWith(fontSize: 11.5, color: AppColors.ink3)),
                      Text(tanda.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                              fontSize: 15.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                if (tanda.isMine && tanda.amIThisWeekWinner == true)
                  const _WinnerBadge(),
              ],
            ),
            const SizedBox(height: 10),
            Text(tanda.productName,
                style: AppTextStyles.subtitle
                    .copyWith(fontSize: 13, color: AppColors.ink2)),
            const SizedBox(height: 12),
            if (tanda.isMine) _MineFooter(tanda: tanda) else _AvailableFooter(tanda: tanda),
          ],
        ),
      ),
    );
  }
}

class _MineFooter extends StatelessWidget {
  const _MineFooter({required this.tanda});
  final BuyerTanda tanda;
  @override
  Widget build(BuildContext context) {
    final paid = tanda.hasPaidThisWeek ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetaItem(
                icon: Symbols.flag,
                label: 'Tu turno',
                value: tanda.myTurn?.toString() ?? '—',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetaItem(
                icon: Symbols.calendar_today,
                label: 'Semana',
                value: '${tanda.currentWeek} de ${tanda.totalWeeks}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _PaymentStrip(
          totalWeeks: tanda.totalWeeks,
          paidWeeks: tanda.paidWeeks,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: paid
                    ? AppColors.statusDeliveredBg
                    : AppColors.statusPendingBg,
                borderRadius: AppRadii.pillRadius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    paid ? Symbols.check_circle : Symbols.schedule,
                    size: 14,
                    color: paid
                        ? AppColors.statusDeliveredFg
                        : AppColors.statusPendingFg,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    paid ? 'Pagada esta semana' : 'Pendiente esta semana',
                    style: AppTextStyles.chip.copyWith(
                      color: paid
                          ? AppColors.statusDeliveredFg
                          : AppColors.statusPendingFg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(tanda.weeklyAmountLabel,
                style: AppTextStyles.subtitle.copyWith(
                    fontSize: 12, color: AppColors.ink3)),
          ],
        ),
      ],
    );
  }
}

class _AvailableFooter extends StatelessWidget {
  const _AvailableFooter({required this.tanda});
  final BuyerTanda tanda;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE1EC),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Symbols.groups,
              size: 18, color: AppColors.neniDeep),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${tanda.currentWeek} de ${tanda.totalWeeks} semanas',
                  style: AppTextStyles.body
                      .copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
              Text('Pregunta en tu tienda para inscribirte',
                  style: AppTextStyles.subtitle
                      .copyWith(fontSize: 11.5, color: AppColors.ink3)),
            ],
          ),
        ),
        Text(tanda.weeklyAmountLabel,
            style: AppTextStyles.subtitle.copyWith(
                fontSize: 12, color: AppColors.ink3)),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF3F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.neniDeep),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: AppTextStyles.subtitle
                      .copyWith(fontSize: 10, color: AppColors.ink3)),
              Text(value,
                  style: AppTextStyles.body.copyWith(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentStrip extends StatelessWidget {
  const _PaymentStrip({required this.totalWeeks, required this.paidWeeks});
  final int totalWeeks;
  final List<int> paidWeeks;
  @override
  Widget build(BuildContext context) {
    final paid = paidWeeks.toSet();
    return SizedBox(
      height: 14,
      child: Row(
        children: List.generate(totalWeeks, (i) {
          final week = i + 1;
          final isPaid = paid.contains(week);
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == totalWeeks - 1 ? 0 : 3),
              child: Container(
                decoration: BoxDecoration(
                  color: isPaid
                      ? AppColors.statusDeliveredFg
                      : AppColors.segTrack,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          );
        }),
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
          colors: [Color(0xFFFFD2E3), Color(0xFFFFE7B3)],
        ),
        borderRadius: AppRadii.pillRadius,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.celebration,
              size: 14, color: AppColors.neniDeep),
          SizedBox(width: 4),
          Text('¡Te toca!',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.neniDeep,
              )),
        ],
      ),
    );
  }
}

class _TandasEmpty extends StatelessWidget {
  const _TandasEmpty({required this.filter});
  final TandasFilter filter;
  @override
  Widget build(BuildContext context) {
    final isMine = filter == TandasFilter.mine;
    return RefreshIndicator(
      color: AppColors.neniDeep,
      onRefresh: () async {},
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 30, bottom: 110),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE1EC),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Symbols.groups,
                      color: AppColors.neniDeep, size: 40),
                ),
                const SizedBox(height: 18),
                Text(
                  isMine
                      ? 'Aún no estás en ninguna tanda'
                      : 'No hay tandas abiertas por ahora',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h2.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  isMine
                      ? 'Cuando la administradora te inscriba a una tanda aparecerá aquí.'
                      : 'Si tu tienda abre una tanda nueva, la verás aquí.',
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

class _TandasError extends StatelessWidget {
  const _TandasError({required this.onRetry});
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
          Text('No pudimos cargar tus tandas',
              textAlign: TextAlign.center, style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text('Revisa tu conexión e intenta de nuevo.',
              textAlign: TextAlign.center, style: AppTextStyles.subtitle),
          const SizedBox(height: 22),
          PillButton(
              label: 'Reintentar',
              icon: Symbols.refresh,
              onPressed: onRetry),
        ],
      ),
    );
  }
}
