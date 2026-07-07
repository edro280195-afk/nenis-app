import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Orquesta la secuencia de celebración de entrega:
/// 1. Confeti burst (22 piezas, 5 colores)
/// 2. Flor de 5 pétalos florece sobre el pin destino
/// 3. Los pétalos vuelan hacia las estrellas del rating
///
/// El widget recibe [destinationKey] para posicionar la flor,
/// y [starKeys] para calcular a dónde vuelan los pétalos.
///
/// Llama a [onCelebrationEnd] cuando termina la secuencia
/// (momento en que se debe mostrar el sheet de evaluación).
class DeliveryCelebration extends StatefulWidget {
  const DeliveryCelebration({
    super.key,
    required this.destinationKey,
    required this.starKeys,
    required this.onCelebrationEnd,
    this.child,
  });

  final GlobalKey destinationKey;
  final List<GlobalKey> starKeys;
  final VoidCallback onCelebrationEnd;
  final Widget? child;

  @override
  State<DeliveryCelebration> createState() => DeliveryCelebrationState();
}

class DeliveryCelebrationState extends State<DeliveryCelebration>
    with TickerProviderStateMixin {
  late AnimationController _confettiCtrl;
  late AnimationController _flowerCtrl;

  final List<_ConfettiParticle> _particles = [];
  bool _flowerBloomed = false;

  OverlayEntry? _flowerEntry;

  static const _kColors = [
    Color(0xFFE95D92), // rose
    Color(0xFFF3B341), // gold
    Color(0xFF9B7BE0), // lavender
    Color(0xFF4E9B77), // green
    Color(0xFFFB6F9C), // neni
  ];

  @override
  void initState() {
    super.initState();

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _flowerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Generar partículas de confeti
    final rnd = math.Random(42);
    for (int i = 0; i < 22; i++) {
      _particles.add(_ConfettiParticle(
        color: _kColors[i % _kColors.length],
        angle: rnd.nextDouble() * math.pi * 2,
        speed: 180 + rnd.nextDouble() * 200,
        size: 5 + rnd.nextDouble() * 6,
        spin: (rnd.nextDouble() - 0.5) * 6,
        shape: i % 3 == 0 ? _Shape.circle : _Shape.rect,
      ));
    }
  }

  /// Inicia la secuencia de celebración.
  Future<void> start() async {
    // 1. Confeti
    _confettiCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));

    // 2. Flor sobre el pin destino
    if (!mounted) return;
    _showFlowerOverlay();
    _flowerCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _flowerBloomed = true);

    // 3. Notificar al orquestador que puede mostrar el rating sheet
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) widget.onCelebrationEnd();
  }

  void _showFlowerOverlay() {
    final ctx = widget.destinationKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final center = Offset(pos.dx + box.size.width / 2, pos.dy + box.size.height / 2);

    _flowerEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: center.dx - 40,
        top: center.dy - 40,
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _flowerCtrl,
            builder: (_, _) => _NenisFlower(
              progress: _flowerCtrl.value,
              bloomed: _flowerBloomed,
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_flowerEntry!);
  }

  void removeFlower() {
    _flowerEntry?.remove();
    _flowerEntry = null;
  }

  @override
  void dispose() {
    _flowerEntry?.remove();
    _confettiCtrl.dispose();
    _flowerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (widget.child != null) widget.child!,
        // Confeti burst centrado en la pantalla
        if (_confettiCtrl.isAnimating || _confettiCtrl.isCompleted)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiCtrl,
                builder: (_, _) => CustomPaint(
                  painter: _ConfettiPainter(
                    particles: _particles,
                    progress: _confettiCtrl.value,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Flor de 5 pétalos ────────────────────────────────────────────────────────

class _NenisFlower extends StatelessWidget {
  const _NenisFlower({required this.progress, required this.bloomed});
  final double progress;
  final bool bloomed;

  static const _kPetalColors = [
    Color(0xFFE95D92),
    Color(0xFFF5A9C5),
    Color(0xFFE95D92),
    Color(0xFFF5A9C5),
    Color(0xFFE95D92),
  ];

  @override
  Widget build(BuildContext context) {
    final scale = Curves.elasticOut.transform(progress.clamp(0.0, 1.0));
    return SizedBox(
      width: 80,
      height: 80,
      child: Transform.scale(
        scale: scale,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 5 pétalos
            for (int i = 0; i < 5; i++)
              Transform.rotate(
                angle: (i / 5) * math.pi * 2,
                child: Transform.translate(
                  offset: const Offset(0, -18),
                  child: Container(
                    width: 18,
                    height: 26,
                    decoration: BoxDecoration(
                      color: _kPetalColors[i],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(9),
                        topRight: Radius.circular(9),
                        bottomLeft: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
            // Núcleo dorado
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Color(0xFFF3B341),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x60F3B341),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Confeti ───────────────────────────────────────────────────────────────────

enum _Shape { circle, rect }

class _ConfettiParticle {
  _ConfettiParticle({
    required this.color,
    required this.angle,
    required this.speed,
    required this.size,
    required this.spin,
    required this.shape,
  });
  final Color color;
  final double angle;
  final double speed;
  final double size;
  final double spin;
  final _Shape shape;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({
    required this.particles,
    required this.progress,
  });
  final List<_ConfettiParticle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.35);
    final gravity = 200.0;
    final t = progress;

    for (final p in particles) {
      final ease = Curves.easeOut.transform(t);
      final vx = math.cos(p.angle) * p.speed;
      final vy = math.sin(p.angle) * p.speed;
      final x = origin.dx + vx * ease;
      final y = origin.dy + vy * ease + 0.5 * gravity * ease * ease;
      final alpha = (1.0 - t * 0.8).clamp(0.0, 1.0);
      final rot = p.spin * t * math.pi * 2;

      final paint = Paint()
        ..color = p.color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      if (p.shape == _Shape.circle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.6,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) =>
      old.progress != progress;
}
