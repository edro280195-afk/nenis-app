import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../shared/widgets/nenis_logo.dart';

/// Ilustración ligera y nativa para la entrada de Neni's.
///
/// Se dibuja con Flutter para no depender de una imagen de mockup completa:
/// así la escena se adapta a cualquier tamaño de teléfono y conserva el logo
/// oficial como asset de la aplicación.
class BoutiqueHeroScene extends StatefulWidget {
  const BoutiqueHeroScene({super.key, this.reduceMotion = false});

  final bool reduceMotion;

  @override
  State<BoutiqueHeroScene> createState() => _BoutiqueHeroSceneState();
}

class _BoutiqueHeroSceneState extends State<BoutiqueHeroScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    if (!widget.reduceMotion) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant BoutiqueHeroScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion && !oldWidget.reduceMotion) {
      _controller.stop();
      _controller.value = 0;
    } else if (!widget.reduceMotion && oldWidget.reduceMotion) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final lift = widget.reduceMotion
              ? 0.0
              : math.sin(_controller.value * math.pi) * 3;
          return Transform.translate(offset: Offset(0, -lift), child: child);
        },
        child: Container(
          height: 270,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD7E4),
            borderRadius: const BorderRadius.all(Radius.circular(30)),
            border: Border.all(color: AppColors.surface),
            boxShadow: AppShadows.card,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _BoutiqueScenePainter()),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: _SceneChip(
                  icon: Icons.location_on_rounded,
                  label: 'Nuevo Laredo',
                  color: AppColors.ink,
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.88),
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.small,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.neniDeep,
                    size: 20,
                  ),
                ),
              ),
              Positioned(
                left: 20,
                bottom: 18,
                child: _SceneCaption(
                  icon: Icons.storefront_rounded,
                  label: 'Vendedora local',
                ),
              ),
              Positioned(
                right: 20,
                bottom: 18,
                child: _SceneCaption(
                  icon: Icons.shopping_bag_rounded,
                  label: 'Consiente tu estilo',
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                top: 104,
                child: Center(child: _NenisBagMark()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NenisBagMark extends StatelessWidget {
  const _NenisBagMark();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.04,
      child: Container(
        width: 74,
        height: 68,
        decoration: BoxDecoration(
          color: AppColors.neniDeep,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
          boxShadow: AppShadows.small,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: -13,
              child: Container(
                width: 34,
                height: 26,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.neniDeep, width: 4),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                ),
              ),
            ),
            const NenisMark(size: 31),
          ],
        ),
      ),
    );
  }
}

class _SceneChip extends StatelessWidget {
  const _SceneChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.86),
        borderRadius: const BorderRadius.all(Radius.circular(99)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneCaption extends StatelessWidget {
  const _SceneCaption({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.82),
        borderRadius: const BorderRadius.all(Radius.circular(99)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.surface),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.surface,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoutiqueScenePainter extends CustomPainter {
  const _BoutiqueScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final background = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFB6CB), Color(0xFFFFE6ED)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final sun = Paint()..color = const Color(0xFFFFF0B8).withValues(alpha: 0.8);
    canvas.drawCircle(Offset(width * 0.77, height * 0.22), 34, sun);

    _drawBridge(canvas, size);
    _drawRack(canvas, size);
    _drawSeller(canvas, Offset(width * 0.29, height * 0.61));
    _drawClient(canvas, Offset(width * 0.71, height * 0.63));
  }

  void _drawBridge(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final bridgePaint = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final bridgeY = height * 0.35;
    canvas.drawLine(
      Offset(width * 0.56, bridgeY),
      Offset(width * 0.94, bridgeY),
      bridgePaint,
    );
    for (final x in [0.61, 0.72, 0.83, 0.92]) {
      canvas.drawLine(
        Offset(width * x, bridgeY),
        Offset(width * x, height * 0.48),
        bridgePaint,
      );
    }
    final arch = Path()
      ..moveTo(width * 0.56, height * 0.48)
      ..quadraticBezierTo(
        width * 0.75,
        height * 0.20,
        width * 0.94,
        height * 0.48,
      );
    canvas.drawPath(arch, bridgePaint);

    final riverPaint = Paint()
      ..color = const Color(0xFFB66D9D).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final river = Path()
      ..moveTo(width * 0.46, height * 0.53)
      ..cubicTo(
        width * 0.60,
        height * 0.49,
        width * 0.75,
        height * 0.58,
        width,
        height * 0.52,
      );
    canvas.drawPath(river, riverPaint);
  }

  void _drawRack(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final rackPaint = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final left = width * 0.08;
    final right = width * 0.39;
    final top = height * 0.27;
    final bottom = height * 0.71;
    canvas.drawLine(Offset(left, top), Offset(right, top), rackPaint);
    canvas.drawLine(Offset(left + 8, top), Offset(left, bottom), rackPaint);
    canvas.drawLine(Offset(right - 8, top), Offset(right, bottom), rackPaint);

    final clothes = <Color>[
      const Color(0xFFE84E83),
      const Color(0xFFF783A9),
      const Color(0xFFFFC6D9),
      const Color(0xFFB65F91),
    ];
    for (var i = 0; i < clothes.length; i++) {
      final x = left + 33 + i * 27.0;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(x, top + 12), width: 15, height: 17),
        math.pi,
        math.pi,
        false,
        rackPaint,
      );
      final dress = Path()
        ..moveTo(x - 9, top + 23)
        ..lineTo(x + 9, top + 23)
        ..lineTo(x + 16, bottom - 17)
        ..lineTo(x - 16, bottom - 17)
        ..close();
      canvas.drawPath(dress, Paint()..color = clothes[i]);
    }
  }

  void _drawSeller(Canvas canvas, Offset center) {
    final skin = Paint()..color = const Color(0xFFE7A17F);
    final hair = Paint()..color = const Color(0xFF4B2B38);
    final shirt = Paint()..color = AppColors.neniDeep;
    canvas.drawCircle(center.translate(0, -40), 18, skin);
    canvas.drawCircle(center.translate(0, -47), 19, hair);
    canvas.drawCircle(center.translate(0, -36), 14, skin);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center.translate(0, 18), width: 57, height: 87),
      const Radius.circular(22),
    );
    canvas.drawRRect(body, shirt);
    final armPaint = Paint()
      ..color = skin.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center.translate(20, 4),
      center.translate(42, 28),
      armPaint,
    );
  }

  void _drawClient(Canvas canvas, Offset center) {
    final skin = Paint()..color = const Color(0xFFF0B18E);
    final hair = Paint()..color = const Color(0xFF5B3540);
    final shirt = Paint()..color = const Color(0xFFFFF7F4);
    canvas.drawCircle(center.translate(0, -40), 18, skin);
    canvas.drawCircle(center.translate(0, -46), 20, hair);
    canvas.drawCircle(center.translate(0, -36), 14, skin);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center.translate(0, 20), width: 59, height: 91),
      const Radius.circular(22),
    );
    canvas.drawRRect(body, shirt);
    final armPaint = Paint()
      ..color = skin.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center.translate(-19, 3),
      center.translate(-41, 31),
      armPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
