import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AuthMotionColumn extends StatelessWidget {
  const AuthMotionColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.mainAxisSize = MainAxisSize.max,
  });

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final resolvedChildren = reduceMotion
        ? children
        : children
              .animate(interval: 45.ms)
              .fadeIn(duration: 220.ms, curve: Curves.easeOutCubic)
              .slideY(
                begin: 0.035,
                end: 0,
                duration: 260.ms,
                curve: Curves.easeOutCubic,
              );

    return Column(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      children: resolvedChildren,
    );
  }
}
