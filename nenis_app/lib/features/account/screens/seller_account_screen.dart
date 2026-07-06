import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/glass_bottom_nav.dart';
import '../../../shared/widgets/pill_button.dart';

class SellerAccountScreen extends ConsumerWidget {
  const SellerAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).value;

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 110),
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
                          child: const Text(
                            'R',
                            style: TextStyle(
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
                              const Text(
                                'Regi Bazar',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ink,
                                ),
                              ),
                              Text(
                                session != null
                                    ? '${session.displayName.toLowerCase().replaceAll(' ', '')}@hotmail.com'
                                    : 'yazmin_vara@hotmail.com',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: AppColors.ink2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFCECD2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'PLAN ELITE 💎',
                                  style: TextStyle(
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
                        _buildMenuRow(Symbols.storefront, 'Perfil de la tienda', 'Colores, logo, dirección pública'),
                        const Divider(height: 1, color: AppColors.lineSoft),
                        _buildMenuRow(Symbols.payments, 'Métodos de pago', 'Mercado Pago link, Transferencias'),
                        const Divider(height: 1, color: AppColors.lineSoft),
                        _buildMenuRow(Symbols.groups, 'Equipo de reparto', 'Administra a tus choferes autorizados'),
                        const Divider(height: 1, color: AppColors.lineSoft),
                        _buildMenuRow(Symbols.settings, 'Preferencias generales', 'Notificaciones de ventas, alertas'),
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
              
              // Bottom Nav
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GlassBottomNav(
                  items: buildSellerNavItems(),
                  currentRoute: '/account',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuRow(IconData icon, String title, String subtitle) {
    return InkWell(
      onTap: () {},
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
