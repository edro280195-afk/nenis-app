import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

enum AuthFeedbackTone { error, success, info }

class AuthFeedbackBanner extends StatelessWidget {
  const AuthFeedbackBanner({
    super.key,
    required this.message,
    this.tone = AuthFeedbackTone.error,
  });

  final String message;
  final AuthFeedbackTone tone;

  @override
  Widget build(BuildContext context) {
    final (foreground, background, icon) = switch (tone) {
      AuthFeedbackTone.error => (
        const Color(0xFFA62952),
        const Color(0xFFFFEDF3),
        Symbols.error,
      ),
      AuthFeedbackTone.success => (
        AppColors.statusDeliveredFg,
        AppColors.statusDeliveredBg,
        Symbols.check_circle,
      ),
      AuthFeedbackTone.info => (
        const Color(0xFF6847A0),
        const Color(0xFFF3ECFF),
        Symbols.info,
      ),
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: Border.all(color: foreground.withValues(alpha: 0.16)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground, size: 20, fill: 1),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showAuthNotification(
  BuildContext context,
  String message, {
  AuthFeedbackTone tone = AuthFeedbackTone.info,
}) {
  final icon = switch (tone) {
    AuthFeedbackTone.error => Symbols.error,
    AuthFeedbackTone.success => Symbols.check_circle,
    AuthFeedbackTone.info => Symbols.info,
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        content: Row(
          children: [
            Icon(icon, color: AppColors.surface, size: 20, fill: 1),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.surface,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
