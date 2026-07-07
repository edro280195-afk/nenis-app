import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';
import '../../../shared/widgets/store_avatar.dart';
import '../data/account_models.dart';
import '../data/account_repository.dart';

import 'seller_account_screen.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).value;
    final isSeller = session != null && session.hasMembership;
    return isSeller ? const SellerAccountScreen() : const BuyerAccountScreen();
  }
}

class BuyerAccountScreen extends ConsumerWidget {
  const BuyerAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).asData?.value;
    final claimed = ref.watch(myClaimedClientsProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              RefreshIndicator(
                color: AppColors.neniDeep,
                onRefresh: () async => ref.invalidate(myClaimedClientsProvider),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                  children: [
                    const _AccountHeader(),
                    const SizedBox(height: 22),
                    _ProfileCard(displayName: session?.displayName ?? ''),
                    const SizedBox(height: 22),
                    const _SectionTitle(label: 'TUS TIENDAS'),
                    const SizedBox(height: 10),
                    claimed.when(
                      loading: () => const _StoresLoading(),
                      error: (e, _) => _StoresError(
                        onRetry: () => ref.invalidate(myClaimedClientsProvider),
                      ),
                      data: (stores) => stores.isEmpty
                          ? const _StoresEmpty()
                          : _StoresList(stores: stores),
                    ),
                    const SizedBox(height: 26),
                    _AccountMenuCard(
                      icon: Symbols.payments,
                      title: 'Mis pagos',
                      subtitle: 'Tu historial con todas tus tiendas',
                      onTap: () => context.push('/payments'),
                    ),
                    _AccountMenuCard(
                      icon: Symbols.location_on,
                      title: 'Mis direcciones',
                      subtitle: 'Edita dónde quieres recibir tus pedidos',
                      onTap: () => context.push('/addresses'),
                    ),
                    _AccountMenuCard(
                      icon: Symbols.notifications,
                      title: 'Notificaciones',
                      subtitle: 'Avisos de pedidos, entregas y mensajes',
                      onTap: () => context.push('/notifications'),
                    ),
                    const SizedBox(height: 18),
                    _LogoutButton(
                      onConfirm: () async {
                        await ref
                            .read(authControllerProvider.notifier)
                            .logout();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mi cuenta',
                  style: AppTextStyles.h1.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 2),
                Text(
                  'Gestiona tu perfil y las tiendas donde compras.',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.eyebrow(
        AppColors.neniDeep,
      ).copyWith(letterSpacing: 1.0),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.displayName});
  final String displayName;

  String get _firstName {
    final n = displayName.trim();
    if (n.isEmpty || n == 'Clienta') return 'Clienta';
    return n;
  }

  bool get _hasRealName =>
      displayName.trim().isNotEmpty && displayName.trim() != 'Clienta';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        boxShadow: AppShadows.small,
      ),
      child: Row(
        children: [
          UserAvatar(
            label: _firstName.characters.first.toUpperCase(),
            size: 54,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasRealName ? displayName : 'Agrega tu nombre',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Symbols.call, size: 13, color: AppColors.ink2),
                    const SizedBox(width: 5),
                    Text(
                      '+52 ··· XX',
                      style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppColors.ink3,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Symbols.verified,
                      size: 14,
                      color: AppColors.statusDeliveredFg,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Verificado',
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 12.5,
                        color: AppColors.statusDeliveredFg,
                        fontWeight: FontWeight.w600,
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

class _StoresList extends StatelessWidget {
  const _StoresList({required this.stores});
  final List<ClaimedClientSummary> stores;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        boxShadow: AppShadows.small,
      ),
      child: Column(
        children: [
          for (var i = 0; i < stores.length; i++) ...[
            _ClaimedStoreRow(store: stores[i]),
            if (i < stores.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.lineSoft,
                indent: 16,
                endIndent: 16,
              ),
          ],
        ],
      ),
    );
  }
}

class _ClaimedStoreRow extends StatelessWidget {
  const _ClaimedStoreRow({required this.store});
  final ClaimedClientSummary store;

  @override
  Widget build(BuildContext context) {
    final colors = store.avatarColors;
    final fecha = _formatDate(store.claimedAt);
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
      child: Row(
        children: [
          StoreAvatarSm(
            label: store.initial,
            gradientStart: colors.start,
            gradientEnd: colors.end,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.businessName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  store.linkedByLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 11.5,
                    color: AppColors.ink2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Vinculada el $fecha',
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 11,
                    color: AppColors.ink3,
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

class _StoresEmpty extends StatelessWidget {
  const _StoresEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        boxShadow: AppShadows.small,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE1EC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Symbols.storefront,
              color: AppColors.neniDeep,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aún no tienes tiendas',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cuando abras un pedido desde el link de una tienda o ella registre tu número, aparecerá aquí.',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoresLoading extends StatelessWidget {
  const _StoresLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        boxShadow: AppShadows.small,
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: AppColors.neni,
        ),
      ),
    );
  }
}

class _StoresError extends StatelessWidget {
  const _StoresError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              const Icon(Symbols.cloud_off, size: 22, color: AppColors.ink3),
              const SizedBox(width: 10),
              Text(
                'No pudimos cargar tus tiendas',
                style: AppTextStyles.body.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Revisa tu conexión e intenta de nuevo.',
            style: AppTextStyles.subtitle.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 12),
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

class _AccountMenuCard extends StatelessWidget {
  const _AccountMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.softRadius,
            border: Border.all(color: AppColors.lineSoft),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE1EC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.neniDeep, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 11.5,
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Symbols.chevron_right, color: AppColors.ink3),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onConfirm});
  final Future<void> Function() onConfirm;

  Future<void> _handleTap(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tendrás que volver a verificar tu número para entrar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Cerrar sesión',
              style: TextStyle(
                color: AppColors.neniDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: PillButton(
        label: 'Cerrar sesión',
        icon: Symbols.logout,
        variant: PillButtonVariant.ghost,
        onPressed: () => _handleTap(context),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return DateFormat("d 'de' MMM, yyyy", 'es').format(local);
}
