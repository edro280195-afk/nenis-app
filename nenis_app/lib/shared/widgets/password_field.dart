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
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? hint;
  final String? label;
  final TextInputAction? textInputAction;
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
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: widget.textInputAction,
      autofillHints: const [AutofillHints.password],
      onSubmitted: widget.onSubmitted,
      suffix: IconButton(
        onPressed: () => setState(() => _obscure = !_obscure),
        tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        padding: EdgeInsets.zero,
        icon: Icon(
          _obscure ? Symbols.visibility : Symbols.visibility_off,
          color: AppColors.ink3,
          size: 22,
        ),
      ),
    );
  }
}
