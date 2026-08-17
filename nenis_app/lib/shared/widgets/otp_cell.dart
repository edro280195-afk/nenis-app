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
    required this.onChanged,
    this.width = 56,
    this.height = 64,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
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
        onChanged: onChanged,
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
  bool _normalizing = false;
  String? _lastCompletedCode;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
    for (final focusNode in _focusNodes) {
      focusNode.addListener(_refresh);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNodes.isNotEmpty) {
        _focusNodes.first.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final focusNode in _focusNodes) {
      focusNode.removeListener(_refresh);
    }
    for (var i = 0; i < widget.length; i++) {
      _controllers[i].dispose();
      _focusNodes[i].dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onChanged(int index, String text) {
    if (_normalizing) return;

    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      // Permite pegar el código completo desde el SMS y repartirlo en las
      // seis celdas, además de conservar el avance normal al teclear.
      _normalizing = true;
      for (var offset = 0; offset < digits.length; offset++) {
        final targetIndex = index + offset;
        if (targetIndex >= widget.length) break;
        _setCellValue(targetIndex, digits[offset]);
      }
      _normalizing = false;
      final nextIndex = (index + digits.length)
          .clamp(0, widget.length - 1)
          .toInt();
      _focusNodes[nextIndex].requestFocus();
      _refresh();
      _checkCompleted();
      return;
    }

    if (digits.isEmpty) {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    } else {
      _setCellValue(index, digits);
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }
    _refresh();
    _checkCompleted();
  }

  void _setCellValue(int index, String value) {
    _controllers[index].value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _checkCompleted() {
    final code = _controllers.map((c) => c.text).join();
    if (code.length == widget.length) {
      if (_lastCompletedCode == code) return;
      _lastCompletedCode = code;
      widget.onCompleted(code);
    } else {
      _lastCompletedCode = null;
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
            return OtpCell(
              controller: _controllers[i],
              focusNode: _focusNodes[i],
              onChanged: (value) => _onChanged(i, value),
              width: cellWidth,
              height: cellHeight,
            );
          }),
        );
      },
    );
  }
}
