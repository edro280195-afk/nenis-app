import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class NeniBackground extends StatelessWidget {
  const NeniBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // El fondo debe cubrir siempre toda el área disponible. El cuerpo de un
    // Scaffold da restricciones sueltas, y un SingleChildScrollView corto se
    // encoge a su contenido: sin esto el degradado terminaba en una línea
    // recta donde acababa el contenido y debajo se veía el color liso.
    return LayoutBuilder(
      builder: (context, constraints) {
        final background = _buildBackground();
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return background;
        }
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: background,
        );
      },
    );
  }

  Widget _buildBackground() {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.surfaceCream),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.7, -0.9),
                  radius: 0.9,
                  colors: [Color(0xFFFFE1EE), Color(0x00FFE1EE)],
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.85, -0.85),
                  radius: 0.85,
                  colors: [Color(0x24E9DEFB), Color(0x00E9DEFB)],
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.75, 1.05),
                  radius: 0.95,
                  colors: [Color(0xFFFFE7D8), Color(0x00FFE7D8)],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
