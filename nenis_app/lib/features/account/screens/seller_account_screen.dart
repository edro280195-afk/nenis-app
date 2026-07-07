import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';

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
        : businessName.substring(0, 1).toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                children: [
                  // Header
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mi Negocio',
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
                        'Configura la información pública y ajustes de tu negocio.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Business profile details card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadii.softRadius,
                      boxShadow: AppShadows.small,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.neni, Color(0xFFF3B341)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
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
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ink,
                                ),
                              ),
                              Text(
                                sellerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: AppColors.ink2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFCECD2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  roleLabel,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.statusPendingFg,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Menu Actions
                  const Text(
                    'HERRAMIENTAS DE VENDEDORA',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink3,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadii.softRadius,
                      boxShadow: AppShadows.small,
                    ),
                    child: Column(
                      children: [
                        _buildMenuRow(
                          Symbols.storefront,
                          'Perfil de la tienda',
                          'Colores, logo, dirección pública',
                          () => context.push('/seller/settings/profile'),
                        ),
                        const Divider(height: 1, color: AppColors.lineSoft),
                        _buildMenuRow(
                          Symbols.payments,
                          'Métodos de pago',
                          'Mercado Pago link, Transferencias',
                          () => context.push('/seller/settings/payments'),
                        ),
                        const Divider(height: 1, color: AppColors.lineSoft),
                        _buildMenuRow(
                          Symbols.groups,
                          'Equipo de reparto',
                          'Administra a tus choferes autorizados',
                          () => context.push('/seller/settings/team'),
                        ),
                        const Divider(height: 1, color: AppColors.lineSoft),
                        _buildMenuRow(
                          Symbols.settings,
                          'Preferencias generales',
                          'Notificaciones de ventas, alertas',
                          () => context.push('/seller/settings/preferences'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Sign Out Button
                  PillButton(
                    label: 'Cerrar Sesión',
                    icon: Symbols.logout,
                    variant: PillButtonVariant.ghost,
                    onPressed: () {
                      ref.read(authControllerProvider.notifier).logout();
                    },
                  ),
                ],
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

  Widget _buildMenuRow(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.neniDeep),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: AppColors.ink2,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Symbols.chevron_right, size: 18, color: AppColors.ink3),
          ],
        ),
      ),
    );
  }
}
