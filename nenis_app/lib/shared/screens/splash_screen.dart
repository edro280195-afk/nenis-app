import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Neni's", style: AppTextStyles.display),
            const SizedBox(height: 8),
            const Text(
              'Compradora',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.ink2,
              ),
            ),
            const SizedBox(height: 32),
            Material(
              color: AppColors.surface,
              borderRadius: AppRadii.pillRadius,
              child: InkWell(
                onTap: () => context.push('/style-gallery'),
                borderRadius: AppRadii.pillRadius,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Text(
                    'Ver style gallery',
                    style: TextStyle(
                      color: AppColors.neniDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
