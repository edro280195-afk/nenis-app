import 'package:flutter/material.dart';

/// Colores del gradiente del Hilo Nenis (del prototipo HTML).
const _kThreadGradient = LinearGradient(
  colors: [Color(0xFFC83D74), Color(0xFFE95D92), Color(0xFFF5A9C5)],
  stops: [0.0, 0.52, 1.0],
);

const _kThreadBaseColor = Color(0xFFECDFE6);
const _kThreadWidth = 3.7;

/// CustomPainter que dibuja el "Hilo Nenis": un path bezier animado que
/// representa el recorrido del pedido de la tienda hasta la clienta.
///
/// El path usa coordenadas normalizadas (0.0–1.0) extraídas del prototipo HTML
/// y se escala al tamaño real del canvas en tiempo de ejecución.
///
/// [progress]: 0.0 = sin recorrido, 1.0 = recorrido completo.
/// [shimmerPhase]: 0.0–1.0 para el efecto de shimmer sobre la parte activa.
class NenisThreadPainter extends CustomPainter {
  const NenisThreadPainter({
    required this.progress,
    this.shimmerPhase = 0.0,
  });

  final double progress;
  final double shimmerPhase;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    // ─── Fondo (hilo gris punteado) ───
    final basePaint = Paint()
      ..color = _kThreadBaseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kThreadWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, basePaint);

    if (progress <= 0) return;

    // ─── Progreso (hilo con gradiente) ───
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final progressLength = (metric.length * progress.clamp(0.0, 1.0));
    final progressPath = metric.extractPath(0, progressLength);

    // Gradiente con shimmer: desplazamos ligeramente el inicio del gradiente
    // usando shimmerPhase para crear un efecto sutil de brillo que avanza.
    final shimmerOffset = shimmerPhase * 0.15 * size.width;
    final shader = _kThreadGradient.createShader(
      Rect.fromLTWH(
        -shimmerOffset,
        0,
        size.width + shimmerOffset * 2,
        size.height,
      ),
    );

    final progressPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kThreadWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(progressPath, progressPaint);

    // ─── Punto brillante en la punta del hilo ───
    if (progress > 0.05 && progress < 0.99) {
      final tipTangent = metric.getTangentForOffset(progressLength);
      if (tipTangent != null) {
        final tipPaint = Paint()
          ..color = const Color(0xFFE95D92)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(tipTangent.position, 4.5, tipPaint);
        canvas.drawCircle(
          tipTangent.position,
          3,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  /// Path bezier normalizado extraído del SVG del prototipo HTML.
  /// SVG viewBox: 372×196 → normalizamos a (0,1)×(0,1).
  ///
  /// SVG original: M51 156 C86 129, 104 172, 139 139 S175 77, 215 101
  ///               S262 125, 298 75 S321 52, 337 41
  ///
  /// Expandido a cubicTo (S → C con punto reflejado):
  Path _buildPath(Size size) {
    double x(double nx) => nx * size.width;
    double y(double ny) => ny * size.height;

    final path = Path()
      ..moveTo(x(0.137), y(0.796));

    // C86 129, 104 172, 139 139
    path.cubicTo(
      x(0.231), y(0.658),
      x(0.280), y(0.878),
      x(0.374), y(0.709),
    );

    // S175 77, 215 101 → C(reflected), 175 77, 215 101
    path.cubicTo(
      x(0.468), y(0.541), // reflected ctrl
      x(0.470), y(0.393),
      x(0.578), y(0.515),
    );

    // S262 125, 298 75 → C(reflected), 262 125, 298 75
    path.cubicTo(
      x(0.685), y(0.638), // reflected ctrl
      x(0.704), y(0.638),
      x(0.801), y(0.383),
    );

    // S321 52, 337 41 → C(reflected), 321 52, 337 41
    path.cubicTo(
      x(0.898), y(0.128), // reflected ctrl
      x(0.863), y(0.265),
      x(0.906), y(0.209),
    );

    return path;
  }

  /// Posición normalizada del punto de inicio (tienda).
  static const Offset startNorm = Offset(0.137, 0.796);

  /// Posición normalizada del punto de destino (casa/clienta).
  static const Offset endNorm = Offset(0.906, 0.209);

  @override
  bool shouldRepaint(NenisThreadPainter old) =>
      old.progress != progress || old.shimmerPhase != shimmerPhase;
}
