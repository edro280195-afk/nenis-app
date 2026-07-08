import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';

class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: AppColors.surface,
                  shape: const CircleBorder(),
                  elevation: 2,
                  shadowColor: Colors.black26,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.adaptive.arrow_back,
                        size: 20,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 60),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF3D8B), Color(0xFFFF0072)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Symbols.sensors,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Live #$sessionId',
                      style: AppTextStyles.h1.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'La experiencia de live shopping está en construcción. Tu tienda te avisará cuando empiece un live nuevo.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 13,
                        color: AppColors.ink2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    PillButton(
                      label: 'Volver al inicio',
                      icon: Symbols.home,
                      variant: PillButtonVariant.brand,
                      onPressed: () => context.go('/home'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
