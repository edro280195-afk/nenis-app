import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/legal/legal_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';

class LegalAcceptanceCheckbox extends StatelessWidget {
  const LegalAcceptanceCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: AppColors.line),
      ),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        onTap: enabled ? () => onChanged(!value) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 9, 12, 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: value,
                onChanged: enabled
                    ? (checked) => onChanged(checked ?? false)
                    : null,
                activeColor: AppColors.neniDeep,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: LegalLinksText(
                    prefix: 'Acepto los ',
                    middle: ' y el ',
                    suffix: '.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LegalLinksCaption extends StatelessWidget {
  const LegalLinksCaption({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalLinksText(
      prefix: 'Al continuar aceptas los ',
      middle: ' y el ',
      suffix: '.',
      textAlign: TextAlign.center,
      fontSize: 10.5,
    );
  }
}

class LegalLinksText extends StatelessWidget {
  const LegalLinksText({
    super.key,
    required this.prefix,
    required this.middle,
    required this.suffix,
    this.textAlign = TextAlign.start,
    this.fontSize = 12,
  });

  final String prefix;
  final String middle;
  final String suffix;
  final TextAlign textAlign;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final base = AppTextStyles.subtitle.copyWith(
      color: AppColors.ink3,
      fontSize: fontSize,
      height: 1.35,
    );
    final link = base.copyWith(
      color: AppColors.neniDeep,
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.neniDeep.withValues(alpha: 0.45),
    );

    return Wrap(
      alignment: textAlign == TextAlign.center
          ? WrapAlignment.center
          : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prefix, style: base, textAlign: textAlign),
        _LegalLink(label: 'Términos', url: LegalConfig.termsUrl, style: link),
        Text(middle, style: base, textAlign: textAlign),
        _LegalLink(
          label: 'Aviso de privacidad',
          url: LegalConfig.privacyUrl,
          style: link,
        ),
        Text(suffix, style: base, textAlign: textAlign),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({
    required this.label,
    required this.url,
    required this.style,
  });

  final String label;
  final String url;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadii.pillRadius,
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Text(label, style: style),
      ),
    );
  }
}
