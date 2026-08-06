import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/interactive_bounce.dart';

/// QR estilizado (placeholder) del rediseño. Replica el SVG aprobado con un
/// CustomPainter para verse nítido a cualquier tamaño.
class LabelQrPlaceholder extends StatelessWidget {
  const LabelQrPlaceholder({
    super.key,
    this.color = AppColors.ink,
    this.size = 44,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _QrPainter(color));
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.color);

  final Color color;

  static const double _grid = 44.0;

  static const List<(double, double)> _modules = [
    (4, 16), (9, 19), (14, 3), (19, 8), (25, 14), (31, 10),
    (16, 2), (11, 24), (16, 29), (22, 25), (29, 29), (34, 25),
    (31, 18), (25, 22), (18, 14), (12, 12), (25, 34), (18, 34),
    (6, 34), (36, 2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _grid;
    final paint = Paint()..color = color;

    void square(double x, double y, double w) {
      canvas.drawRect(Rect.fromLTWH(x * scale, y * scale, w * scale, w * scale), paint);
    }

    // Patrones de esquina.
    square(2, 2, 12);
    square(2, 30, 12);
    square(30, 2, 12);

    // Módulos dispersos.
    for (final module in _modules) {
      square(module.$1, module.$2, 3);
    }

    // Centros blancos de los patrones de esquina.
    final white = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(4.5 * scale, 4.5 * scale, 7 * scale, 7 * scale), white);
    canvas.drawRect(Rect.fromLTWH(4.5 * scale, 32.5 * scale, 7 * scale, 7 * scale), white);
    canvas.drawRect(Rect.fromLTWH(32.5 * scale, 4.5 * scale, 7 * scale, 7 * scale), white);
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) => oldDelegate.color != color;
}

/// Miniatura de la etiqueta que se va a imprimir, tal como se aprobó en el
/// rediseño: fondo blanco, líneas, QR, código de bolsa y barras opcionales.
enum MiniLabelFormat { square50, shipping4x6 }

class MiniLabelPreview extends StatelessWidget {
  const MiniLabelPreview({
    super.key,
    this.format = MiniLabelFormat.square50,
    this.code = 'B-1',
  });

  final MiniLabelFormat format;
  final String code;

  @override
  Widget build(BuildContext context) {
    final ship = format == MiniLabelFormat.shipping4x6;
    return Container(
      width: ship ? 50 : 52,
      height: ship ? 68 : 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x403A2233),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Positioned(
              left: 5,
              top: 7,
              child: Container(
                width: 18,
                height: 2,
                color: AppColors.ink.withValues(alpha: 0.8),
              ),
            ),
            if (!ship)
              Positioned(
                left: 5,
                right: 12,
                top: 13,
                child: Container(
                  height: 2,
                  color: AppColors.ink.withValues(alpha: 0.8),
                ),
              ),
            if (ship)
              const Positioned(
                left: 5,
                right: 5,
                bottom: 14,
                child: _BarcodeBars(
                  widths: [2, 4, 2, 5, 2, 4, 2, 5],
                  barHeight: 6,
                ),
              ),
            Positioned(
              right: 3,
              top: 3,
              child: LabelQrPlaceholder(size: 20),
            ),
            Positioned(
              left: 5,
              bottom: 4,
              child: Text(
                code,
                style: TextStyle(
                  fontSize: 6.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarcodeBars extends StatelessWidget {
  const _BarcodeBars({required this.widths, required this.barHeight});

  final List<double> widths;
  final double barHeight;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (final width in widths) ...[
        Container(width: width, height: barHeight, color: AppColors.ink),
        const SizedBox(width: 1.5),
      ],
    ],
  );
}

/// Pastilla de estado para bolsas y etiquetas: Lista, En ruta o Seleccionada.
enum LabelStatusPillVariant { ready, route, selected }

class LabelStatusPill extends StatelessWidget {
  const LabelStatusPill({
    super.key,
    required this.label,
    required this.variant,
  });

  final String label;
  final LabelStatusPillVariant variant;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (variant) {
      LabelStatusPillVariant.ready => (AppColors.segTrack, AppColors.ink2),
      LabelStatusPillVariant.route => (
        AppColors.statusRouteBg,
        AppColors.statusRouteFg,
      ),
      LabelStatusPillVariant.selected => (
        AppColors.neni.withValues(alpha: 0.12),
        AppColors.neniDeep,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.pillRadius,
      ),
      child: Text(
        label,
        style: AppTextStyles.chip.copyWith(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: foreground,
        ),
      ),
    );
  }
}

/// Check de selección con gradiente rosa, como en el rediseño.
class LabelCheck extends StatelessWidget {
  const LabelCheck({
    super.key,
    required this.selected,
    this.onTap,
    this.size = 23,
  });

  final bool selected;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected ? AppColors.neni : Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: selected ? AppColors.neniDeep : AppColors.ink3,
          width: 1.6,
        ),
        gradient: selected
            ? const LinearGradient(
                colors: [AppColors.neni, AppColors.neniDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: selected
          ? Icon(Symbols.check, size: size * 0.65, color: Colors.white)
          : null,
    );
    if (onTap == null) return child;
    return InteractiveBounce(
      onPressed: onTap,
      scaleFactor: 0.88,
      duration: const Duration(milliseconds: 80),
      child: child,
    );
  }
}

/// Avatar con la inicial del nombre de la clienta para las cabeceras de grupo.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({
    super.key,
    required this.name,
    this.lavender = false,
    this.size = 38,
  });

  final String name;
  final bool lavender;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    final background = lavender
        ? AppColors.lavender.withValues(alpha: 0.14)
        : AppColors.neni.withValues(alpha: 0.14);
    final foreground = lavender ? AppColors.lavender : AppColors.neniDeep;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        initial,
        style: AppTextStyles.h2.copyWith(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}
