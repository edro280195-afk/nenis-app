import 'package:flutter/material.dart';
import 'nenis_thread_painter.dart';

/// Widget del "Hilo Nenis" con animación de progreso y shimmer.
///
/// Cuando [progress] cambia, anima suavemente hacia el nuevo valor.
/// El shimmer pulse es continuo mientras el hilo no esté completo.
class NenisThreadWidget extends StatefulWidget {
  const NenisThreadWidget({
    super.key,
    required this.progress,
    this.width = double.infinity,
    this.height = 120,
    this.startKey,
    this.endKey,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  /// Progreso del hilo (0.0 – 1.0). Anima cuando cambia.
  final double progress;
  final double width;
  final double height;

  /// GlobalKey colocado sobre el pin de inicio (tienda).
  final GlobalKey? startKey;

  /// GlobalKey colocado sobre el pin de destino (clienta / casa).
  final GlobalKey? endKey;

  final Duration animationDuration;

  @override
  State<NenisThreadWidget> createState() => _NenisThreadWidgetState();
}

class _NenisThreadWidgetState extends State<NenisThreadWidget>
    with TickerProviderStateMixin {
  late AnimationController _progressCtrl;
  late AnimationController _shimmerCtrl;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();

    _progressCtrl = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _progressAnim = Tween<double>(
      begin: 0,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _progressCtrl,
      curve: Curves.easeInOutCubic,
    ));
    _progressCtrl.forward();

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void didUpdateWidget(NenisThreadWidget old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      _progressAnim = Tween<double>(
        begin: _progressAnim.value,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _progressCtrl,
        curve: Curves.easeInOutCubic,
      ));
      _progressCtrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rawW = widget.width.isFinite ? widget.width : constraints.maxWidth;
        final rawH = widget.height.isFinite ? widget.height : constraints.maxHeight;

        final safeW = (rawW.isNaN || !rawW.isFinite || rawW <= 0) ? 300.0 : rawW;
        final safeH = (rawH.isNaN || !rawH.isFinite || rawH <= 0) ? 120.0 : rawH;

        final startLeft = (NenisThreadPainter.startNorm.dx * safeW - 14).clamp(0.0, safeW - 28);
        final startTop = (NenisThreadPainter.startNorm.dy * safeH - 14).clamp(0.0, safeH - 28);

        final endLeft = (NenisThreadPainter.endNorm.dx * safeW - 14).clamp(0.0, safeW - 28);
        final endTop = (NenisThreadPainter.endNorm.dy * safeH - 14).clamp(0.0, safeH - 28);

        return SizedBox(
          width: safeW,
          height: safeH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Hilo animado ──
              AnimatedBuilder(
                animation: Listenable.merge([_progressCtrl, _shimmerCtrl]),
                builder: (_, _) => CustomPaint(
                  size: Size(safeW, safeH),
                  painter: NenisThreadPainter(
                    progress: _progressAnim.value.isNaN ? 0.0 : _progressAnim.value,
                    shimmerPhase: _shimmerCtrl.value.isNaN ? 0.0 : _shimmerCtrl.value,
                  ),
                ),
              ),

              // ── Pin tienda (inicio) ──
              Positioned(
                left: startLeft,
                top: startTop,
                child: _StorePinDot(key: widget.startKey),
              ),

              // ── Pin casa (destino) ──
              Positioned(
                left: endLeft,
                top: endTop,
                child: _HomePinDot(key: widget.endKey, isActive: widget.progress >= 0.99),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StorePinDot extends StatelessWidget {
  const _StorePinDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF3D8B), Color(0xFFFF0072)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(9),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40E84E83),
            offset: Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 14),
    );
  }
}

class _HomePinDot extends StatefulWidget {
  const _HomePinDot({super.key, required this.isActive});
  final bool isActive;

  @override
  State<_HomePinDot> createState() => _HomePinDotState();
}

class _HomePinDotState extends State<_HomePinDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ripple;

  @override
  void initState() {
    super.initState();
    _ripple = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isActive) _ripple.repeat();
  }

  @override
  void didUpdateWidget(_HomePinDot old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !_ripple.isAnimating) {
      _ripple.repeat();
    } else if (!widget.isActive && _ripple.isAnimating) {
      _ripple.stop();
    }
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.isActive)
            AnimatedBuilder(
              animation: _ripple,
              builder: (_, _) => Container(
                width: 28 * (1 + _ripple.value * 0.6),
                height: 28 * (1 + _ripple.value * 0.6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE95D92)
                      .withValues(alpha: 0.25 * (1 - _ripple.value)),
                ),
              ),
            ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: widget.isActive
                  ? const Color(0xFF3A2233)
                  : const Color(0xFFECDFE6),
              shape: BoxShape.circle,
              boxShadow: widget.isActive
                  ? const [
                      BoxShadow(
                        color: Color(0x403A2233),
                        offset: Offset(0, 3),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.home_rounded,
              color: widget.isActive ? Colors.white : const Color(0xFFB6A4B1),
              size: 14,
            ),
          ),
        ],
      ),
    );
  }
}
