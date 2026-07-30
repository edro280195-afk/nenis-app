import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

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
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final double markSize;
  final double wordmarkSize;
  final String? subtitle;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final preferredHeight = wordmarkSize * 1.45;
    final logoHeight = markSize > preferredHeight ? markSize : preferredHeight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Image.asset(
          'assets/branding/nenis-logo.png',
          height: logoHeight,
          fit: BoxFit.contain,
          semanticLabel: "Logo de Neni's",
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
    );
  }
}
