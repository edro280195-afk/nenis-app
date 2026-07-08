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
import '../data/seller_vip_models.dart';
import '../data/seller_vip_repository.dart';

class SellerVipScreen extends ConsumerWidget {
  const SellerVipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessSettings = ref.watch(sellerBusinessSettingsProvider);
    final hasVipDrops = businessSettings.value?.features.contains('VipDrops') ?? false;
    final followers = ref.watch(sellerVipControllerProvider);

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
                      onTap: () => context.canPop() ? context.pop() : context.go('/account'),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(Icons.adaptive.arrow_back, size: 20, color: AppColors.ink),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Grupo VIP', style: AppTextStyles.h1.copyWith(fontSize: 22)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Marca a tus seguidoras favoritas para que vean tus novedades exclusivas.',
                style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
              ),
              const SizedBox(height: 20),
              if (!hasVipDrops)
                const FeatureLockedCard(
                  title: 'El grupo VIP es una función Pro',
                  body: 'Da acceso anticipado y novedades exclusivas a tus clientas favoritas.',
                )
              else
                followers.when(
                  loading: () => Column(
                    children: List.generate(
                      4,
                      (_) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        height: 64,
                        decoration: BoxDecoration(color: AppColors.segTrack, borderRadius: AppRadii.softRadius),
                      ),
                    ),
                  ),
                  error: (_, _) => Text('No pudimos cargar tus seguidoras.', style: AppTextStyles.subtitle),
                  data: (list) {
                    if (list.isEmpty) {
                      return _EmptyState();
                    }
                    return Column(
                      children: [
                        for (final f in list) ...[
                          _FollowerRow(follower: f),
                          const SizedBox(height: 10),
                        ],
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

class _FollowerRow extends ConsumerWidget {
  const _FollowerRow({required this.follower});
  final SellerFollowerAdmin follower;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        boxShadow: AppShadows.small,
        border: follower.isVip ? Border.all(color: AppColors.gold.withValues(alpha: 0.5)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: follower.isVip ? const Color(0xFFFFF2D4) : AppColors.segTrack,
              shape: BoxShape.circle,
            ),
            child: Text(
              follower.displayName.isNotEmpty ? follower.displayName.characters.first.toUpperCase() : '?',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              follower.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          if (follower.isVip) const Icon(Symbols.workspace_premium, size: 18, color: AppColors.gold),
          Switch(
            value: follower.isVip,
            activeTrackColor: AppColors.neniDeep,
            onChanged: (value) async {
              try {
                await ref.read(sellerVipControllerProvider.notifier).setVip(follower.accountId, value);
              } on SellerVipException catch (e) {
                if (context.mounted) {
                  context.showPremiumToast(e.message, type: PremiumToastType.error);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: const Color(0xFFEFE5EE), borderRadius: BorderRadius.circular(24)),
            child: const Icon(Symbols.group, color: AppColors.ink2, size: 34),
          ),
          const SizedBox(height: 14),
          Text('Aún no tienes seguidoras', textAlign: TextAlign.center, style: AppTextStyles.h2.copyWith(fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            'Cuando alguien siga tu tienda, aparecerá aquí para que la marques VIP.',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
