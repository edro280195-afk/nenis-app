import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/nenis_logo.dart';

/// Splash inicial. Muestra el logo + un spinner mientras el
/// `authControllerProvider` carga la sesión persistida. La navegación
/// al destino correcto (login o home) la hace el `redirect` del
/// router cuando el `refreshListenable` dispara, así que este screen
/// no necesita hacer `context.go` explícito.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NenisLogo(
              markSize: 88,
              wordmarkSize: 32,
              subtitle: 'Compradora',
              crossAxisAlignment: CrossAxisAlignment.center,
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.neni,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
