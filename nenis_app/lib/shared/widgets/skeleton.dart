import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Un cargador de tipo esqueleto (Skeleton screen) con animación de pulso sutil.
/// Se usa para sustituir los indicadores circulares de carga en listas, tarjetas y detalles.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8.0,
  });

  /// Ancho del esqueleto. Si es nulo, se expandirá para llenar el espacio.
  final double? width;

  /// Alto del esqueleto. Si es nulo, se expandirá para llenar el espacio.
  final double? height;

  /// Radio del borde redondeado.
  final double borderRadius;

  /// Constructor para un esqueleto circular (p. ej., avatars, íconos redondos).
  const Skeleton.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = size / 2;

  /// Constructor para una línea de texto de esqueleto.
  const Skeleton.text({
    super.key,
    this.width,
    this.height = 14.0,
    this.borderRadius = 4.0,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}
