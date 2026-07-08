import 'dart:math' as math;

import 'package:flutter/material.dart';

class ShakeWidget extends StatefulWidget {
  const ShakeWidget({required this.child, super.key});

  final Widget child;

  @override
  State<ShakeWidget> createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void shake() {
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final translation =
            16 *
            math.sin(_controller.value * 4 * math.pi) *
            (1 - _controller.value);

        return Transform.translate(
          offset: Offset(translation.toDouble(), 0),
          child: widget.child,
        );
      },
    );
  }
}
