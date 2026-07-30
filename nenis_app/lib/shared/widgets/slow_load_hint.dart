import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';

/// Aviso sutil que aparece si una carga tarda más de lo normal (p. ej. el
/// backend de pruebas en Render despertando de un cold start). Sin esto, una
/// espera larga pero normal se siente igual que la app congelada o rota.
/// Se coloca flotando sobre un skeleton (ver `_BuyerHomeSkeleton` en
/// `home_screen.dart` para el patrón de uso con `Stack`).
class SlowLoadHint extends StatefulWidget {
  const SlowLoadHint({super.key, this.delay = const Duration(seconds: 6)});

  final Duration delay;

  @override
  State<SlowLoadHint> createState() => _SlowLoadHintState();
}

class _SlowLoadHintState extends State<SlowLoadHint> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 500),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(99),
              boxShadow: AppShadows.small,
            ),
            child: Text(
              'Esto está tardando un poco más de lo normal…',
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 12,
                color: AppColors.ink3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
