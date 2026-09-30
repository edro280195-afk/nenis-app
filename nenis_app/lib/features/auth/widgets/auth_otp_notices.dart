import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';

/// Explica en lenguaje simple qué es el código que llega por SMS y por qué a
/// veces se abre el navegador. Existe porque Firebase, cuando Google no puede
/// verificar el dispositivo en silencio, abre una comprobación reCAPTCHA en el
/// navegador y luego regresa a la app: sin aviso eso parece una falla o una
/// estafa. Se muestra ANTES de pedir el código.
///
/// - `compact: false` (antes de enviar el SMS): explica ambas cosas.
/// - `compact: true` (ya con el código en camino): solo el recordatorio de
///   seguridad de no compartirlo.
class OtpExplainer extends StatelessWidget {
  const OtpExplainer({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Container(
        key: const Key('otp-explainer'),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.72),
          borderRadius: AppRadii.softRadius,
          border: Border.all(color: AppColors.line),
        ),
        child: compact
            ? const _NoticeRow(
                icon: Symbols.shield_lock,
                text:
                    'No compartas este código con nadie. Neni\'s nunca te lo '
                    'pedirá por llamada, WhatsApp ni mensaje.',
              )
            : const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NoticeRow(
                    icon: Symbols.sms,
                    title: '¿Qué es el código?',
                    text:
                        'Es una clave de 6 dígitos que te mandamos por SMS. '
                        'Sirve una sola vez y confirma que este número es tuyo. '
                        'No la compartas: nadie de Neni\'s te la va a pedir.',
                  ),
                  SizedBox(height: 14),
                  _NoticeRow(
                    icon: Symbols.verified_user,
                    title: 'Verificación de seguridad',
                    text:
                        'A veces se abre tu navegador unos segundos para '
                        'comprobar que eres tú y no un robot. Es de Google, es '
                        'normal y seguro: al terminar regresas a Neni\'s.',
                  ),
                ],
              ),
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.icon, required this.text, this.title});

  final IconData icon;
  final String text;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.neni.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 19, color: AppColors.neniDeep),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                text,
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: 12.5,
                  height: 1.45,
                  color: AppColors.textAa,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Aviso corto que se muestra MIENTRAS se prepara el código, que es justo
/// cuando Android puede abrir el navegador con la verificación de Google.
class BrowserCheckHint extends StatelessWidget {
  const BrowserCheckHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        key: const Key('browser-check-hint'),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Symbols.info, size: 17, color: AppColors.textAa),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Si se abre tu navegador, completa la verificación y regresa '
                'a Neni\'s: aquí seguiremos con tu código.',
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textAa,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Encabezado funcional de las pantallas de acceso: título y explicación corta,
/// sin foto. La foto editorial queda solo en la bienvenida.
class AuthTitleBlock extends StatelessWidget {
  const AuthTitleBlock({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: AppTextStyles.display.copyWith(
              fontSize: 27,
              height: 1.12,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: AppTextStyles.subtitle.copyWith(
            fontSize: 14,
            height: 1.45,
            color: AppColors.textAa,
          ),
        ),
      ],
    );
  }
}
