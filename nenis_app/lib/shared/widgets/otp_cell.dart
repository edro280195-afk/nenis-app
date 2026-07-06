import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';

class OtpCell extends StatelessWidget {
  const OtpCell({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.autoSubmit,
    this.width = 56,
    this.height = 64,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autoSubmit;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        border: Border.all(
          color: focusNode.hasFocus
              ? AppColors.neni
              : controller.text.isNotEmpty
              ? AppColors.neni
              : AppColors.line,
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14D6336C),
            offset: Offset(0, 8),
            blurRadius: 20,
            spreadRadius: -10,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: AppTextStyles.display.copyWith(
          fontSize: 24,
          color: AppColors.ink,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        onChanged: (value) {
          if (autoSubmit && value.isNotEmpty) {
            FocusScope.of(context).nextFocus();
          }
        },
      ),
    );
  }
}

class OtpInput extends StatefulWidget {
  const OtpInput({super.key, required this.length, required this.onCompleted})
    : assert(length > 0);

  final int length;
  final ValueChanged<String> onCompleted;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late final List<VoidCallback> _listeners;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
    _listeners = [];
    for (var i = 0; i < widget.length; i++) {
      final focusNode = _focusNodes[i];
      focusNode.addListener(() => setState(() {}));
      final controller = _controllers[i];
      void onChange() => _onControllerChanged(i, controller.text);
      _listeners.add(onChange);
      controller.addListener(onChange);
    }
  }

  @override
  void dispose() {
    for (var i = 0; i < widget.length; i++) {
      _controllers[i].removeListener(_listeners[i]);
      _controllers[i].dispose();
      _focusNodes[i].dispose();
    }
    super.dispose();
  }

  void _onControllerChanged(int index, String text) {
    if (text.length > 1) {
      final newText = text.characters.last;
      _controllers[index].text = newText;
      _controllers[index].selection = TextSelection.collapsed(offset: 1);
      return;
    }
    if (text.isEmpty && _controllers[index].text.isEmpty) {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
    setState(() {});
    _checkCompleted();
  }

  void _checkCompleted() {
    final code = _controllers.map((c) => c.text).join();
    if (code.length == widget.length) {
      widget.onCompleted(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minimumGap = 8.0;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : widget.length * 56.0 + (widget.length - 1) * minimumGap;
        final cellWidth =
            ((availableWidth - (widget.length - 1) * minimumGap) /
                    widget.length)
                .clamp(36.0, 56.0)
                .toDouble();
        final cellHeight = (cellWidth + 8).clamp(50.0, 64.0).toDouble();

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(widget.length, (i) {
            final isLast = i == widget.length - 1;
            return OtpCell(
              controller: _controllers[i],
              focusNode: _focusNodes[i],
              autoSubmit: !isLast,
              width: cellWidth,
              height: cellHeight,
            );
          }),
        );
      },
    );
  }
}
