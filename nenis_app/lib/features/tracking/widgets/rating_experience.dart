import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../data/tracking_models.dart';
import '../data/tracking_repository.dart';

/// Los 4 motivos/stickers disponibles (coinciden con el prototipo HTML).
const kFeedbackReasons = [
  '🎀 El producto',
  '⚡ La entrega',
  '💬 La atención',
  '📦 El empaque',
];

/// Experiencia completa de evaluación del pedido.
///
/// Aparece como sheet que sube desde abajo con scrim blur.
/// Flujo: Stars → Stickers → Comentario (opcional) → Enviar → Éxito
class RatingExperience extends ConsumerStatefulWidget {
  const RatingExperience({
    super.key,
    required this.accessToken,
    required this.existingRating,
    required this.starKeys,
    required this.onDismiss,
    required this.onSubmitted,
  });

  final String accessToken;
  final OrderRating? existingRating;

  /// Keys de las 5 estrellas (para que la flor pueda volar hacia ellas).
  final List<GlobalKey> starKeys;

  final VoidCallback onDismiss;
  final ValueChanged<OrderRating> onSubmitted;

  @override
  ConsumerState<RatingExperience> createState() => _RatingExperienceState();
}

class _RatingExperienceState extends ConsumerState<RatingExperience>
    with TickerProviderStateMixin {
  // ── Controladores de animación ──
  late AnimationController _slideCtrl;
  late AnimationController _scrimCtrl;
  late AnimationController _medalCtrl;

  late Animation<Offset> _slideAnim;
  late Animation<double> _scrimAnim;
  late Animation<double> _medalScaleAnim;
  late Animation<double> _medalRotateAnim;

  // ── Estado del formulario ──
  int _stars = 0;
  final Set<String> _selectedReasons = {};
  final TextEditingController _commentCtrl = TextEditingController();
  bool _submitted = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
    );
    _scrimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _medalCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _slideAnim = Tween(begin: const Offset(0, 1.03), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _slideCtrl,
        curve: const Cubic(0.22, 1.0, 0.36, 1.0),
      ),
    );
    _scrimAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scrimCtrl, curve: Curves.easeOut),
    );
    _medalScaleAnim = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(parent: _medalCtrl, curve: Curves.elasticOut),
    );
    _medalRotateAnim = Tween<double>(begin: -6 * math.pi / 180, end: 0).animate(
      CurvedAnimation(parent: _medalCtrl, curve: Curves.easeOut),
    );

    // Prellenar si ya existe una evaluación
    if (widget.existingRating != null) {
      _stars = widget.existingRating!.stars;
      _selectedReasons.addAll(widget.existingRating!.reasons ?? []);
    }

    // Animar entrada
    _scrimCtrl.forward();
    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted) {
        _slideCtrl.forward();
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) _medalCtrl.forward();
        });
      }
    });
  }

  Future<void> _dismiss() async {
    await Future.wait([_slideCtrl.reverse(), _scrimCtrl.reverse()]);
    if (mounted) widget.onDismiss();
  }

  Future<void> _submit() async {
    if (_stars == 0 || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(trackingRepositoryProvider);
      final rating = await repo.submitRating(
        accessToken: widget.accessToken,
        stars: _stars,
        reasons: _selectedReasons.toList(),
        comment: _commentCtrl.text.trim().isEmpty
            ? null
            : _commentCtrl.text.trim(),
      );

      setState(() {
        _submitted = true;
        _loading = false;
      });
      widget.onSubmitted(rating);
    } on TrackingException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Ocurrió un error. Intenta de nuevo.';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _scrimCtrl.dispose();
    _medalCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Scrim con blur ──
        AnimatedBuilder(
          animation: _scrimAnim,
          builder: (_, _) => GestureDetector(
            onTap: !_submitted ? _dismiss : null,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 5 * _scrimAnim.value,
                sigmaY: 5 * _scrimAnim.value,
              ),
              child: Container(
                color: const Color(0xFF2A2027)
                    .withValues(alpha: 0.45 * _scrimAnim.value),
              ),
            ),
          ),
        ),

        // ── Panel deslizante ──
        Align(
          alignment: Alignment.bottomCenter,
          child: SlideTransition(
            position: _slideAnim,
            child: GestureDetector(
              onTap: () {}, // absorber taps
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFCFD),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x301E0A12),
                      offset: Offset(0, -16),
                      blurRadius: 40,
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: _submitted
                      ? _SuccessView(onClose: _dismiss)
                      : _FormView(
                          stars: _stars,
                          selectedReasons: _selectedReasons,
                          commentCtrl: _commentCtrl,
                          loading: _loading,
                          error: _error,
                          medalScaleAnim: _medalScaleAnim,
                          medalRotateAnim: _medalRotateAnim,
                          starKeys: widget.starKeys,
                          onStarTap: (s) => setState(() => _stars = s),
                          onReasonToggle: (r) => setState(() {
                            if (_selectedReasons.contains(r)) {
                              _selectedReasons.remove(r);
                            } else {
                              _selectedReasons.add(r);
                            }
                          }),
                          onSubmit: _submit,
                          onDismiss: _dismiss,
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Formulario de evaluación ──────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  const _FormView({
    required this.stars,
    required this.selectedReasons,
    required this.commentCtrl,
    required this.loading,
    required this.error,
    required this.medalScaleAnim,
    required this.medalRotateAnim,
    required this.starKeys,
    required this.onStarTap,
    required this.onReasonToggle,
    required this.onSubmit,
    required this.onDismiss,
  });

  final int stars;
  final Set<String> selectedReasons;
  final TextEditingController commentCtrl;
  final bool loading;
  final String? error;
  final Animation<double> medalScaleAnim;
  final Animation<double> medalRotateAnim;
  final List<GlobalKey> starKeys;
  final ValueChanged<int> onStarTap;
  final ValueChanged<String> onReasonToggle;
  final VoidCallback onSubmit;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFECDFE6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Medalla del negocio (Spring animation)
          AnimatedBuilder(
            animation: Listenable.merge([medalScaleAnim, medalRotateAnim]),
            builder: (_, _) => Transform.rotate(
              angle: medalRotateAnim.value,
              child: Transform.scale(
                scale: medalScaleAnim.value,
                child: const _BusinessMedal(),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Título
          const Text(
            '¿Cómo fue tu experiencia?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3A2233),
            ),
          ),
          const Text(
            'Tu opinión ayuda a mejorar el servicio',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              color: Color(0xFF8A6F82),
            ),
          ),
          const SizedBox(height: 22),

          // Estrellas
          _StarRow(
            stars: stars,
            starKeys: starKeys,
            onTap: onStarTap,
          ),
          const SizedBox(height: 20),

          // Stickers / motivos
          if (stars > 0) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: kFeedbackReasons
                  .map((r) => _FeedbackSticker(
                        label: r,
                        selected: selectedReasons.contains(r),
                        onTap: () => onReasonToggle(r),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 18),
          ],

          // Comentario libre
          if (stars > 0) ...[
            TextField(
              controller: commentCtrl,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: 'Algo más que quieras contarnos… (opcional)',
                hintStyle: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  color: Color(0xFFB6A4B1),
                ),
                filled: true,
                fillColor: const Color(0xFFFDF4F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(14),
                counterStyle: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  color: Color(0xFFB6A4B1),
                ),
              ),
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13.5,
                color: Color(0xFF3A2233),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Error
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                error!,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  color: AppColors.neniDeep,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Botón enviar
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: stars > 0
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: loading ? null : onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.neniDeep,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Enviar mi evaluación'),
              ),
            ),
            secondChild: TextButton(
              onPressed: onDismiss,
              child: const Text(
                'Omitir por ahora',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  color: Color(0xFFB6A4B1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Estrellas ─────────────────────────────────────────────────────────────────

class _StarRow extends StatelessWidget {
  const _StarRow({
    required this.stars,
    required this.starKeys,
    required this.onTap,
  });
  final int stars;
  final List<GlobalKey> starKeys;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = i < stars;
        return GestureDetector(
          onTap: () => onTap(i + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: _AnimatedStar(
              key: starKeys[i],
              filled: filled,
              index: i,
              filledCount: stars,
            ),
          ),
        );
      }),
    );
  }
}

class _AnimatedStar extends StatefulWidget {
  const _AnimatedStar({
    super.key,
    required this.filled,
    required this.index,
    required this.filledCount,
  });
  final bool filled;
  final int index;
  final int filledCount;

  @override
  State<_AnimatedStar> createState() => _AnimatedStarState();
}

class _AnimatedStarState extends State<_AnimatedStar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _setupAnimations();
  }

  void _setupAnimations() {
    _scale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.7, end: 1.28)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 55),
      TweenSequenceItem(
          tween: Tween(begin: 1.28, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 45),
    ]).animate(_ctrl);

    _rotate = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: -7 * math.pi / 180, end: 4 * math.pi / 180),
          weight: 55),
      TweenSequenceItem(
          tween: Tween(begin: 4 * math.pi / 180, end: 0.0),
          weight: 45),
    ]).animate(_ctrl);
  }

  @override
  void didUpdateWidget(_AnimatedStar old) {
    super.didUpdateWidget(old);
    if (old.filled != widget.filled && widget.filled) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Transform.scale(
        scale: widget.filled ? _scale.value : 1.0,
        child: Transform.rotate(
          angle: widget.filled ? _rotate.value : 0,
          child: Icon(
            widget.filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 38,
            color: widget.filled
                ? const Color(0xFFF3B341)
                : const Color(0xFFECDFE6),
          ),
        ),
      ),
    );
  }
}

// ── Sticker de motivo ─────────────────────────────────────────────────────────

class _FeedbackSticker extends StatefulWidget {
  const _FeedbackSticker({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_FeedbackSticker> createState() => _FeedbackStickerState();
}

class _FeedbackStickerState extends State<_FeedbackSticker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(_FeedbackSticker old) {
    super.didUpdateWidget(old);
    if (!old.selected && widget.selected) {
      _ctrl.forward().then((_) => _ctrl.reverse());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(0xFFFFE8F0)
                : const Color(0xFFF5EEF2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.selected
                  ? const Color(0xFFE84E83)
                  : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: widget.selected
                ? const [
                    BoxShadow(
                      color: Color(0x20E84E83),
                      offset: Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13.5,
              fontWeight:
                  widget.selected ? FontWeight.w700 : FontWeight.w500,
              color: widget.selected
                  ? const Color(0xFFE84E83)
                  : const Color(0xFF8A6F82),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Medalla del negocio ───────────────────────────────────────────────────────

class _BusinessMedal extends StatelessWidget {
  const _BusinessMedal();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF3D8B), Color(0xFFE84E83)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x40E84E83),
            offset: Offset(0, 6),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 32),
    );
  }
}

// ── Vista de éxito ────────────────────────────────────────────────────────────

class _SuccessView extends StatefulWidget {
  const _SuccessView({required this.onClose});
  final VoidCallback onClose;

  @override
  State<_SuccessView> createState() => _SuccessViewState();
}

class _SuccessViewState extends State<_SuccessView>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _scale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) => Transform.scale(
              scale: _scale.value,
              child: FadeTransition(opacity: _fade, child: child),
            ),
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFD9F3E6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Color(0xFF1F9A6A),
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '¡Gracias por tu evaluación!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3A2233),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tu opinión nos ayuda a mejorar cada día 💖',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              color: Color(0xFF8A6F82),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.onClose,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.neniDeep,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Cerrar'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
