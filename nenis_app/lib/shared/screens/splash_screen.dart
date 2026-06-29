import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';

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
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.neni, AppColors.neniDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: AppShadows.brandPrimary(AppColors.neniDeep),
              ),
              child: const Icon(Symbols.shopping_bag,
                  color: Colors.white, size: 48),
            ),
            const SizedBox(height: 18),
            Text("Neni's",
                style: AppTextStyles.h1.copyWith(
                  fontSize: 32,
                  color: AppColors.ink,
                  letterSpacing: -0.5,
                )),
            const SizedBox(height: 2),
            const Text('Compradora',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink2,
                )),
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
