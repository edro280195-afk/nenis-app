import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_bottom_nav.dart';

class SellerHomeScreen extends ConsumerStatefulWidget {
  const SellerHomeScreen({super.key});

  @override
  ConsumerState<SellerHomeScreen> createState() => _SellerHomeScreenState();
}

class _SellerHomeScreenState extends ConsumerState<SellerHomeScreen> with SingleTickerProviderStateMixin {
  bool _isDark = true;
  bool _isFabMenuOpen = false;
  
  // Simulated insight text list
  final List<String> _insights = [
    "\"¡Yazmin! Detecté que el set de sábanas King cuadros es el producto con más apartados en la Tanda #4. Sugiero notificar a tus clientas sobre stock limitado para acelerar cierres de venta. 🌸\"",
    "\"¡Hola Yazmin! Los ingresos de hoy están un 14% arriba del promedio del lunes anterior. Te sugiero asignar a Eduardo la ruta norte hoy, ya que concentra el 75% de las entregas pendientes. 🚗\"",
    "\"¡Yazmin! Tienes \$3,850 por cobrar distribuidos en 7 clientas. Ana Lucía y Karla Gómez representan el 80% de esa cartera pendiente. Envía los recordatorios de pago automáticos desde la sección de cobros. 💳\"",
    "\"¡Excelente día Yazmin! Tu directo de ayer en TikTok generó 3 nuevos registros de clientas. Recuerda lanzar la rifa activa antes de las 6:00 PM para mantener el engagement de Regi Bazar. ✨\""
  ];
  int _currentInsightIndex = 0;
  bool _isRegeneratingInsight = false;

  void _regenerateInsight() async {
    if (_isRegeneratingInsight) return;
    setState(() {
      _isRegeneratingInsight = true;
    });
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _currentInsightIndex = (_currentInsightIndex + 1) % _insights.length;
        _isRegeneratingInsight = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Colors depending on local dual-theme mode
    final Color phoneBg = _isDark ? const Color(0xFF09070F) : const Color(0xFFFAF6F8);
    final Color cardBg = _isDark ? const Color(0xFF130F22) : Colors.white;
    final Color borderColor = _isDark ? const Color(0x1F8B5CF6) : const Color(0x28FF85B3);
    final Color textPrimary = _isDark ? Colors.white : const Color(0xFF1E1B29);
    final Color textSecondary = _isDark ? const Color(0xFF94A3B8) : const Color(0xFF5E5A75);
    final Color textMuted = _isDark ? const Color(0xFF64748B) : const Color(0xFF8E8A9F);
    
    final List<Color> corteGradients = _isDark 
        ? [const Color(0xFF191430), const Color(0xFF0D0A19)] 
        : [const Color(0xFFFFF0F5), const Color(0xFFF2ECFF)];
    final List<Color> camiGradients = _isDark 
        ? [const Color(0xFF1E103B), const Color(0xFF140A28)] 
        : [const Color(0xFFF2ECFF), const Color(0xFFFFF0F5)];

    return Scaffold(
      backgroundColor: phoneBg,
      body: Stack(
        children: [
          // Scrollable content
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: AppColors.neni,
              onRefresh: () async {
                await Future.delayed(const Duration(milliseconds: 1000));
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                children: [
                  
                  // App Bar / Top header info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.neni, Color(0xFFF3B341)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.neni.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'R',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Regi Bazar',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Premium',
                                    style: TextStyle(
                                      fontFamily: 'Playfair Display',
                                      color: AppColors.neni,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  )
                                ],
                              ),
                              const Text(
                                'SOCIO ELITE 💎',
                                style: TextStyle(
                                  color: Color(0xFF9B7BE0),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 8,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Theme Switcher Button
                          _buildHeaderButton(
                            icon: _isDark ? Symbols.light_mode : Symbols.dark_mode,
                            color: textPrimary,
                            cardBg: cardBg,
                            borderColor: borderColor,
                            onTap: () {
                              setState(() {
                                _isDark = !_isDark;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          // Notifications Bell
                          Stack(
                            children: [
                              _buildHeaderButton(
                                icon: Symbols.notifications,
                                color: textPrimary,
                                cardBg: cardBg,
                                borderColor: borderColor,
                                onTap: () {
                                  context.go('/notifications');
                                },
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.neni,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Greeting Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡Hola Yazmin!',
                            style: TextStyle(
                              color: textSecondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                'Tu Dashboard',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'Resumen',
                                style: TextStyle(
                                  fontFamily: 'Playfair Display',
                                  color: AppColors.neni,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              )
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9F3E6),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: const Color(0x331F9A6A)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1F9A6A),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'CORTE ABIERTO',
                              style: TextStyle(
                                color: Color(0xFF1F9A6A),
                                fontWeight: FontWeight.w800,
                                fontSize: 8,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Active Period Bento Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: corteGradients,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neni.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Symbols.calendar_today, color: AppColors.neni, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Corte: Fin de Mes Junio',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                'ACTIVO',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 8,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _buildCorteStat('Ventas', '\$34,850', const Color(0xFF1F9A6A), textPrimary, cardBg, borderColor),
                            const SizedBox(width: 8),
                            _buildCorteStat('Invertido', '\$12,300', const Color(0xFFFF2D55), textPrimary, cardBg, borderColor),
                            const SizedBox(width: 8),
                            _buildCorteStat('Utilidad', '\$22,550', AppColors.neni, textPrimary, cardBg, borderColor),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // KPI Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _buildKpiCard('Ventas Hoy', '\$12,450', '+14% hoy', Symbols.payments, const Color(0xFF1F9A6A), cardBg, textPrimary, textSecondary, borderColor),
                      _buildKpiCard('Pendientes', '24', '6 en ruta', Symbols.shopping_bag, AppColors.neni, cardBg, textPrimary, textSecondary, borderColor),
                      _buildKpiCard('Por Cobrar', '\$3,850', 'De 7 clientas', Symbols.account_balance_wallet, const Color(0xFFF3B341), cardBg, textPrimary, textSecondary, borderColor),
                      _buildKpiCard('Repartos', '3', 'Activos', Symbols.map, const Color(0xFF9B7BE0), cardBg, textPrimary, textSecondary, borderColor),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // C.A.M.I Assistant Card
                  GestureDetector(
                    onTap: () {
                      _showCamiDialog(context, textPrimary, textSecondary, cardBg, borderColor);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: camiGradients,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(Symbols.psychology, color: Colors.white, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'C.A.M.I. Smart Insights',
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Text(
                                        'ASISTENTE VIRTUAL IA',
                                        style: TextStyle(
                                          color: AppColors.neni,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 7,
                                          letterSpacing: 1.0,
                                        ),
                                      )
                                    ],
                                  )
                                ],
                              ),
                              GestureDetector(
                                onTap: _regenerateInsight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.neni,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.neni.withValues(alpha: 0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  ),
                                  child: Row(
                                    children: [
                                      if (_isRegeneratingInsight)
                                        const SizedBox(
                                          width: 8,
                                          height: 8,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 1.5,
                                          ),
                                        )
                                      else
                                        const Icon(Symbols.refresh, color: Colors.white, size: 10),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Regenerar',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: _isDark ? 0.25 : 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: Text(
                              _insights[_currentInsightIndex],
                              style: TextStyle(
                                color: textSecondary,
                                fontStyle: FontStyle.italic,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Sales Chart Bento Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Symbols.query_stats, color: AppColors.neni, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'VENTAS SEMANALES',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                )
                              ],
                            ),
                            const Text(
                              'Ver Detalle',
                              style: TextStyle(
                                color: AppColors.neni,
                                fontWeight: FontWeight.bold,
                                fontSize: 8,
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 140,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _LineChartPainter(isDark: _isDark),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Recent Activity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ACTIVIDAD RECIENTE',
                        style: TextStyle(
                          color: textMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Text(
                        'VER TODO',
                        style: TextStyle(
                          color: AppColors.neni,
                          fontWeight: FontWeight.bold,
                          fontSize: 8,
                          letterSpacing: 0.5,
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Order items list
                  _buildRecentOrderRow('Gar Cia', '9:15 AM • 💵 Efectivo', '\$410', 'Entregado', const Color(0xFF1F9A6A), cardBg, textPrimary, textSecondary, borderColor),
                  const SizedBox(height: 8),
                  _buildRecentOrderRow('Ana Lucía', 'Ayer • 🏦 Transferencia', '\$1,200', 'Tanda #4', const Color(0xFF9B7BE0), cardBg, textPrimary, textSecondary, borderColor),

                ],
              ),
            ),
          ),

          // Floating Action Button Operations Morph Menu
          if (_isFabMenuOpen)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isFabMenuOpen = false;
                });
              },
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                width: double.infinity,
                height: double.infinity,
              ),
            ),

          // Morph Menu Content
          if (_isFabMenuOpen)
            Positioned(
              bottom: 100,
              right: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    )
                  ]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'NUEVA OPERACIÓN',
                      style: TextStyle(
                        color: textMuted,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.2,
                      children: [
                        _buildFabMenuItem('Capturar Pedido', Symbols.add_shopping_cart, textPrimary, cardBg, borderColor),
                        _buildFabMenuItem('Enviar Link', Symbols.link, textPrimary, cardBg, borderColor),
                        _buildFabMenuItem('Registrar Tanda', Symbols.groups, textPrimary, cardBg, borderColor),
                        _buildFabMenuItem('Crear Reparto', Symbols.directions_car, textPrimary, cardBg, borderColor),
                      ],
                    )
                  ],
                ),
              ),
            ),

          // Floating Action Button
          Positioned(
            bottom: 84,
            right: 16,
            child: FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isFabMenuOpen = !_isFabMenuOpen;
                });
              },
              backgroundColor: AppColors.neni,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              child: AnimatedRotation(
                turns: _isFabMenuOpen ? 0.375 : 0.0, // Rotate + into an X
                duration: const Duration(milliseconds: 300),
                child: const Icon(Symbols.add, size: 28),
              ),
            ),
          ),

          // Bottom Navigation Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GlassBottomNav(
              items: buildSellerNavItems(),
              currentRoute: '/home',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required Color color,
    required Color cardBg,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildCorteStat(String title, String value, Color color, Color textPrimary, Color cardBg, Color borderColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: cardBg.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.bold,
                fontSize: 8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color accentColor,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accentColor, size: 16),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 8,
                ),
              )
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                  fontSize: 8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFabMenuItem(String label, IconData icon, Color textPrimary, Color cardBg, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.neni.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.neni, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRecentOrderRow(
    String clientName,
    String timeInfo,
    String amount,
    String status,
    Color statusColor,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.neni.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text('🛍️', style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clientName,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    timeInfo,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  color: AppColors.neni,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 7,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  void _showCamiDialog(BuildContext context, Color textPrimary, Color textSecondary, Color cardBg, Color borderColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: _isDark ? const Color(0xFF0F0A1F) : const Color(0xFFFAF6F8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: borderColor),
          ),
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Indicator handle
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 14),
              // Dialog Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Symbols.psychology, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Asistente C.A.M.I.',
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          const Text(
                            'CHAT DE ANÁLISIS ACTIVO',
                            style: TextStyle(
                              color: AppColors.neni,
                              fontWeight: FontWeight.bold,
                              fontSize: 7,
                              letterSpacing: 0.8,
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: cardBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Symbols.close, size: 14, color: Color(0xFF64748B)),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 18),
              
              // Chat conversation history simulation
              Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Color(0xFFECE0FF),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text('C', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            '¡Hola de nuevo Yazmin! He analizado las finanzas del corte "Fin de Mes Junio". Tu margen de utilidad neta actual es del 64%, superando la meta. Sin embargo, tenemos \$3,850 por cobrar. ¿Quieres que redacte un mensaje de cobranza por WhatsApp para las clientas con saldos vencidos?',
                            style: TextStyle(color: textPrimary, fontSize: 11, height: 1.4),
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: AppColors.neni,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Sí, por favor, ayúdame a generar el texto.',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, height: 1.4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: AppColors.neni,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text('Y', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Color(0xFFECE0FF),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text('C', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: const [
                            _TypingDot(delayMs: 100),
                            SizedBox(width: 4),
                            _TypingDot(delayMs: 200),
                            SizedBox(width: 4),
                            _TypingDot(delayMs: 300),
                          ],
                        ),
                      )
                    ],
                  )
                ],
              ),
              const SizedBox(height: 16),

              // Chat Input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: TextStyle(color: textPrimary, fontSize: 11),
                      decoration: InputDecoration(
                        hintText: 'Pregúntale algo a C.A.M.I...',
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        filled: true,
                        fillColor: cardBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.neni, width: 1.2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.neni,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Symbols.send, color: Colors.white, size: 18),
                  )
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

// Custom Painter for the line chart drawing (Premium custom vector curve)
class _LineChartPainter extends CustomPainter {
  final bool isDark;
  _LineChartPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.neni.withValues(alpha: 0.05)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw horizontal grid lines
    const int gridRows = 4;
    for (int i = 0; i <= gridRows; i++) {
      double y = size.height * i / gridRows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = [
      Offset(0, size.height * 0.8),
      Offset(size.width * 0.16, size.height * 0.55),
      Offset(size.width * 0.33, size.height * 0.65),
      Offset(size.width * 0.5, size.height * 0.4),
      Offset(size.width * 0.66, size.height * 0.3),
      Offset(size.width * 0.83, size.height * 0.1),
      Offset(size.width, size.height * 0.25),
    ];

    // Build the cubic curve path
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p1.dx, p1.dy);
    }

    // Draw gradient area below path
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillShader = ui.Gradient.linear(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      [
        AppColors.neni.withValues(alpha: 0.35),
        AppColors.neni.withValues(alpha: 0.0),
      ],
    );

    final fillPaint = Paint()
      ..shader = fillShader
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Draw curve line
    final linePaint = Paint()
      ..color = AppColors.neni
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Draw points dots
    final dotOuterPaint = Paint()
      ..color = isDark ? const Color(0xFF09070F) : Colors.white
      ..style = PaintingStyle.fill;

    final dotInnerPaint = Paint()
      ..color = AppColors.neni
      ..style = PaintingStyle.fill;

    for (var p in points) {
      canvas.drawCircle(p, 5.0, dotOuterPaint);
      canvas.drawCircle(p, 3.0, dotInnerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Typing dots bubble animation indicator
class _TypingDot extends StatefulWidget {
  final int delayMs;
  const _TypingDot({required this.delayMs});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0.0, end: -6.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppColors.neni,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
