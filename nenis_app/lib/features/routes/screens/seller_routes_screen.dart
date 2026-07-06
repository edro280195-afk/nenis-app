import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/glass_bottom_nav.dart';
import '../../../shared/widgets/segmented.dart';

class SellerRoutesScreen extends ConsumerStatefulWidget {
  const SellerRoutesScreen({super.key});

  @override
  ConsumerState<SellerRoutesScreen> createState() => _SellerRoutesScreenState();
}

class _SellerRoutesScreenState extends ConsumerState<SellerRoutesScreen> {
  int _selectedIndex = 0;

  final List<String> _routeFilters = ['Pendientes', 'En Reparto', 'Historial'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Padding(
                    padding: EdgeInsets.fromLTRB(22, 4, 22, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rutas de Reparto',
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
                          'Optimiza y monitorea los recorridos de tus repartidores.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Filter Control
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
                    child: SegmentedControl(
                      items: _routeFilters.map((label) => SegmentedItem(label: label)).toList(),
                      selectedIndex: _selectedIndex,
                      onChanged: (i) {
                        setState(() {
                          _selectedIndex = i;
                        });
                      },
                    ),
                  ),

                  // Routes List
                  Expanded(
                    child: _buildRoutesListForTab(_selectedIndex),
                  )
                ],
              ),
              
              // Bottom Nav
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GlassBottomNav(
                  items: buildSellerNavItems(),
                  currentRoute: '/routes',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoutesListForTab(int tabIndex) {
    if (tabIndex == 0) {
      // Pendientes
      return ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 110),
        children: [
          _buildRouteCard('Ruta Norte - Laredo', 'Eduardo Rodriguez', '5 entregas pendientes', 'Por optimizar', AppColors.statusPendingFg, AppColors.statusPendingBg, false),
          const SizedBox(height: 12),
          _buildRouteCard('Ruta Oriente', 'Sin Repartidor', '3 entregas pendientes', 'Borrador', AppColors.ink2, const Color(0x0D3A2233), false),
        ],
      );
    } else if (tabIndex == 1) {
      // En Reparto
      return ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 110),
        children: [
          _buildRouteCard('Ruta Poniente Express', 'Jesús Martínez', '6 paradas • 3 entregadas', 'En Reparto', AppColors.statusRouteFg, AppColors.statusRouteBg, true),
        ],
      );
    } else {
      // Historial
      return ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 110),
        children: [
          _buildRouteCard('Ruta Centro - Histórico', 'Eduardo Rodriguez', '8 entregas exitosas', 'Completada', AppColors.statusDeliveredFg, AppColors.statusDeliveredBg, false),
          const SizedBox(height: 12),
          _buildRouteCard('Ruta Sur Laredo', 'Jesús Martínez', '4 entregas exitosas', 'Completada', AppColors.statusDeliveredFg, AppColors.statusDeliveredBg, false),
        ],
      );
    }
  }

  Widget _buildRouteCard(
    String name,
    String driverName,
    String description,
    String status,
    Color statusFg,
    Color statusBg,
    bool isLive,
  ) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: AppRadii.pillRadius,
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Symbols.person, size: 16, color: AppColors.ink2),
              const SizedBox(width: 8),
              Text(
                'Repartidor: $driverName',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: AppColors.ink3,
            ),
          ),
          const SizedBox(height: 12),
          if (isLive)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Symbols.sensors, size: 16, color: AppColors.liveRed),
                    SizedBox(width: 6),
                    Text(
                      'Ubicación en tiempo real activa',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.liveRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.neniDeep,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Ver Mapa',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF3F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.segTrack),
                  ),
                  child: const Text(
                    'Detalles de Ruta',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            )
        ],
      ),
    );
  }
}
