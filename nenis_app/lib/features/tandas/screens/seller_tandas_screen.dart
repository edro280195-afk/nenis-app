import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/glass_bottom_nav.dart';
import '../../../shared/widgets/segmented.dart';

class SellerTandasScreen extends ConsumerStatefulWidget {
  const SellerTandasScreen({super.key});

  @override
  ConsumerState<SellerTandasScreen> createState() => _SellerTandasScreenState();
}

class _SellerTandasScreenState extends ConsumerState<SellerTandasScreen> {
  int _selectedIndex = 0;

  final List<String> _tandaFilters = ['Activas', 'Completadas'];

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
                          'Administrar Tandas',
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
                          'Controla los números, participantes y pagos de tus tandas.',
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
                      items: _tandaFilters.map((label) => SegmentedItem(label: label)).toList(),
                      selectedIndex: _selectedIndex,
                      onChanged: (i) {
                        setState(() {
                          _selectedIndex = i;
                        });
                      },
                    ),
                  ),

                  // Tandas List
                  Expanded(
                    child: _buildTandasListForTab(_selectedIndex),
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
                  currentRoute: '/tandas',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTandasListForTab(int tabIndex) {
    if (tabIndex == 0) {
      // Activas
      return ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 110),
        children: [
          _buildTandaCard('Tanda #4 - Hogar Premium', 'Semana 6 de 10', '10 participantes', 'Set de Sábanas King / Edredones', '\$200/semanal', true),
          const SizedBox(height: 12),
          _buildTandaCard('Tanda #5 - Belleza Coquette', 'Semana 2 de 8', '8 participantes', 'Set de Maquillaje y Skincare Pro', '\$150/semanal', true),
        ],
      );
    } else {
      // Completadas
      return ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 110),
        children: [
          _buildTandaCard('Tanda #3 - Accesorios Chic', 'Completada', '10 participantes', 'Bolsos y Accesorios de Diseño', '\$250/semanal', false),
          const SizedBox(height: 12),
          _buildTandaCard('Tanda #2 - Calzado Elegante', 'Completada', '6 participantes', 'Zapatos de temporada', '\$300/semanal', false),
        ],
      );
    }
  }

  Widget _buildTandaCard(
    String name,
    String weekInfo,
    String participantsCount,
    String productName,
    String weeklyAmount,
    bool isActive,
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
                  color: isActive ? const Color(0xFFFFE1EC) : const Color(0x0D3A2233),
                  borderRadius: AppRadii.pillRadius,
                ),
                child: Text(
                  isActive ? 'Activa' : 'Finalizada',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isActive ? AppColors.neniDeep : AppColors.ink2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            productName,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetaDetail(Symbols.calendar_today, 'Progreso', weekInfo),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetaDetail(Symbols.groups, 'Grupo', participantsCount),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Cuota:',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink3,
                ),
              ),
              Text(
                weeklyAmount,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neniDeep,
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMetaDetail(IconData icon, String label, String value) {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 9,
                    color: AppColors.ink3,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
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
