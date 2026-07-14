import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';
import '../data/seller_settings_models.dart';
import '../data/seller_settings_repository.dart';

class SellerAccountScreen extends ConsumerWidget {
  const SellerAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).value;
    final businessName = _businessNameFor(session);
    final sellerName = _sellerNameFor(session);
    final roleLabel = _roleLabelFor(session);
    final initial = businessName.isEmpty
        ? 'N'
        : businessName.characters.first.toUpperCase();

    final accountsAsync = ref.watch(sellerPayoutAccountsProvider);
    final mercadoPagoAsync = ref.watch(sellerPaymentSettingsProvider);
    final businessSettingsAsync = ref.watch(sellerBusinessSettingsProvider);
    final accountCount = accountsAsync.maybeWhen(
      data: (accounts) => accounts.length,
      orElse: () => 0,
    );
    final mercadoPagoReady =
        mercadoPagoAsync.asData?.value.isConfigured ?? false;
    final paymentReadyCount =
        (accountCount > 0 ? 1 : 0) + (mercadoPagoReady ? 1 : 0);
    final paymentSubtitle = _paymentSubtitle(accountCount, mercadoPagoReady);
    final subscription = businessSettingsAsync.value?.subscription;
    final planSubtitle = _planSubtitle(subscription);

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
            children: [
              _SellerHeader(
                title: 'Mi negocio',
                subtitle: 'Configura tu tienda y lo que ven tus clientas.',
              ),
              const SizedBox(height: 22),
              _SellerHeroCard(
                initial: initial,
                businessName: businessName,
                sellerName: sellerName,
                roleLabel: roleLabel,
                paymentStatus: 'Cobros $paymentReadyCount/2 listos',
              ),
              const SizedBox(height: 22),
              const _SectionLabel(
                title: 'Prioridad de hoy',
                subtitle: 'Lo que más afecta ventas y seguimiento.',
              ),
              const SizedBox(height: 10),
              _SellerMenuTile(
                icon: Symbols.workspace_premium,
                title: 'Mi plan',
                subtitle: planSubtitle,
                badge: subscription?.isLocked == true ? 'Bloqueada' : null,
                highlighted: subscription?.isLocked == true,
                onTap: () => context.push('/seller/plan'),
              ),
              const SizedBox(height: 10),
              _SellerMenuTile(
                icon: Symbols.payments,
                title: 'Cuentas de cobro',
                subtitle: paymentSubtitle,
                badge: accountCount == 0 ? 'Agregar' : 'Revisar',
                highlighted: true,
                onTap: () => context.push('/seller/settings/payments'),
              ),
              const SizedBox(height: 12),
              const _SectionTitle(label: 'Herramientas de vendedora'),
              const SizedBox(height: 10),
              _SellerMenuTile(
                icon: Symbols.storefront,
                title: 'Perfil de tienda',
                subtitle: 'Nombre, colores y enlace público.',
                onTap: () => context.push('/seller/settings/profile'),
              ),
              const SizedBox(height: 10),
              _SellerMenuTile(
                icon: Symbols.campaign,
                title: 'Novedades y vivo',
                subtitle: 'Publica actualizaciones y avisa cuando estés en vivo.',
                onTap: () => context.push('/seller/updates'),
              ),
              const SizedBox(height: 10),
              _SellerMenuTile(
                icon: Symbols.sensors,
                title: 'Anunciar en vivo',
                subtitle: 'Toca un producto mientras transmites y aparece al instante en la app.',
                onTap: () => context.push('/seller/live'),
              ),
              const SizedBox(height: 10),
              _SellerMenuTile(
                icon: Symbols.workspace_premium,
                title: 'Grupo VIP',
                subtitle: 'Elige a tus seguidoras favoritas para novedades exclusivas.',
                onTap: () => context.push('/seller/vip'),
              ),
              const SizedBox(height: 10),
              _SellerMenuTile(
                icon: Symbols.groups,
                title: 'Equipo de reparto',
                subtitle: 'Permisos del chofer y mensajes de ruta.',
                onTap: () => context.push('/seller/settings/team'),
              ),
              const SizedBox(height: 10),
              _SellerMenuTile(
                icon: Symbols.tune,
                title: 'Preferencias',
                subtitle: 'Alertas, mensajes y operación diaria.',
                onTap: () => context.push('/seller/settings/preferences'),
              ),
              const SizedBox(height: 22),
              PillButton(
                label: 'Cerrar sesión',
                icon: Symbols.logout,
                variant: PillButtonVariant.ghost,
                onPressed: () => _confirmLogout(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _businessNameFor(Session? session) {
    if (session == null || session.memberships.isEmpty) return 'Mi negocio';
    final activeBusinessId = session.activeBusinessId;
    for (final membership in session.memberships) {
      if (membership.businessId == activeBusinessId &&
          membership.businessName.trim().isNotEmpty) {
        return membership.businessName.trim();
      }
    }
    final firstName = session.memberships.first.businessName.trim();
    return firstName.isEmpty ? 'Mi negocio' : firstName;
  }

  String _sellerNameFor(Session? session) {
    final name = session?.displayName.trim() ?? '';
    return name.isEmpty ? 'Cuenta vendedora' : name;
  }

  String _roleLabelFor(Session? session) {
    final activeBusinessId = session?.activeBusinessId;
    for (final membership in session?.memberships ?? const <Membership>[]) {
      if (membership.businessId == activeBusinessId &&
          membership.role.trim().isNotEmpty) {
        return membership.role.trim().toUpperCase();
      }
    }
    return 'CUENTA VENDEDORA';
  }

  String _planSubtitle(SellerSubscriptionSettings? subscription) {
    if (subscription == null) return 'Cargando tu plan...';
    if (subscription.isLocked) {
      return 'Elige un plan para seguir usando tu tienda.';
    }
    if (subscription.subscriptionStatus == 'Trialing') {
      return 'Prueba ${subscription.effectivePlan} · ${subscription.daysLeft} días restantes.';
    }
    return 'Plan ${subscription.effectivePlan} activo.';
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tendrás que volver a iniciar sesión para entrar a tu negocio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
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
    await ref.read(authControllerProvider.notifier).logout();
  }
}

class _SellerHeader extends StatelessWidget {
  const _SellerHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.h1.copyWith(fontSize: 26)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
              ),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.line),
            boxShadow: AppShadows.small,
          ),
          child: const Icon(
            Symbols.notifications,
            size: 22,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _SellerHeroCard extends StatelessWidget {
  const _SellerHeroCard({
    required this.initial,
    required this.businessName,
    required this.sellerName,
    required this.roleLabel,
    required this.paymentStatus,
  });

  final String initial;
  final String businessName;
  final String sellerName;
  final String roleLabel;
  final String paymentStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: AppRadii.cardRadius,
        boxShadow: AppShadows.card,
        gradient: const LinearGradient(
          colors: [AppColors.neniDeep, AppColors.neni, AppColors.gold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 2,
                  ),
                ),
                child: Text(
                  initial,
                  style: AppTextStyles.h1.copyWith(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h2.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$sellerName · $roleLabel',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subtitle.copyWith(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const _HeroPill(icon: Symbols.storefront, label: 'Tienda activa'),
              _HeroPill(icon: Symbols.payments, label: paymentStatus),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.chip.copyWith(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.h2.copyWith(fontSize: 17)),
        const SizedBox(height: 2),
        Text(subtitle, style: AppTextStyles.subtitle.copyWith(fontSize: 12.5)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTextStyles.eyebrow(
        AppColors.neniDeep,
      ).copyWith(letterSpacing: 1.0),
    );
  }
}

class _SellerMenuTile extends StatelessWidget {
  const _SellerMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: highlighted ? const Color(0xFFF7FAFF) : AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: highlighted
                  ? AppColors.statusRouteFg.withValues(alpha: 0.2)
                  : AppColors.line,
            ),
            boxShadow: AppShadows.small,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: highlighted
                      ? AppColors.statusRouteBg
                      : AppColors.neni.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: highlighted
                      ? AppColors.statusRouteFg
                      : AppColors.neniDeep,
                  size: 23,
                ),
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.statusDeliveredBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: AppTextStyles.chip.copyWith(
                      color: AppColors.statusDeliveredFg,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                const Icon(
                  Symbols.chevron_right,
                  size: 20,
                  color: AppColors.ink3,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _paymentSubtitle(int accountCount, bool mercadoPagoReady) {
  if (accountCount == 0 && !mercadoPagoReady) {
    return 'Agrega una cuenta para compartir datos de pago.';
  }
  if (accountCount == 0) {
    return 'Mercado Pago listo. Falta una cuenta de respaldo.';
  }
  if (!mercadoPagoReady) {
    return 'Cuenta bancaria lista. Mercado Pago pendiente.';
  }
  return 'Cuenta bancaria y Mercado Pago listos.';
}
