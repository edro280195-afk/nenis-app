import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class NenisMark extends StatelessWidget {
  const NenisMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Image.asset(
        'assets/branding/nenis-mark.png',
        fit: BoxFit.contain,
        semanticLabel: "Logo de Neni's",
      ),
    );
  }
}

class NenisLogo extends StatelessWidget {
  const NenisLogo({
    super.key,
    this.markSize = 56,
    this.wordmarkSize = 28,
    this.subtitle,
  });

  final double markSize;
  final double wordmarkSize;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NenisMark(size: markSize),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                text: "Neni's",
                style: AppTextStyles.h1.copyWith(
                  fontSize: wordmarkSize,
                  height: 1,
                ),
                children: const [
                  TextSpan(
                    text: '.',
                    style: TextStyle(color: AppColors.neniDeep),
                  ),
                ],
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink2,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
