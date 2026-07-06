import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import 'app_text_field.dart';

/// Campo de contraseña con botón para mostrar/ocultar el texto.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.hint = 'Contraseña',
    this.label,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? hint;
  final String? label;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint,
      prefixIcon: Symbols.lock,
      obscureText: _obscure,
      onSubmitted: widget.onSubmitted,
      suffix: GestureDetector(
        onTap: () => setState(() => _obscure = !_obscure),
        child: Icon(
          _obscure ? Symbols.visibility : Symbols.visibility_off,
          color: AppColors.ink3,
          size: 22,
        ),
      ),
    );
  }
}
