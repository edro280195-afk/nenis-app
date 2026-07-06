import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_text_styles.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.hint,
    this.label,
    this.prefixIcon,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.focusNode,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? hint;
  final String? label;
  final IconData? prefixIcon;
  final String? prefix;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final isMultiline = maxLines > 1;
    final field = Container(
      constraints: isMultiline
          ? BoxConstraints(minHeight: 58)
          : const BoxConstraints(minHeight: 58, maxHeight: 58),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.fieldRadius,
        border: Border.all(color: AppColors.line, width: 1.5),
        boxShadow: AppShadows.small,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMultiline ? 14 : 0,
        vertical: isMultiline ? 10 : 0,
      ),
      alignment: isMultiline ? Alignment.topLeft : Alignment.center,
      child: isMultiline
          ? TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              autofillHints: autofillHints,
              obscureText: obscureText,
              autocorrect: autocorrect,
              enableSuggestions: enableSuggestions,
              maxLines: maxLines,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: AppTextStyles.input,
              cursorColor: AppColors.neni,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTextStyles.fieldPlaceholder,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
            )
          : Row(
              children: [
                if (prefixIcon != null) ...[
                  const SizedBox(width: 18),
                  Icon(prefixIcon, color: AppColors.ink3, size: 22),
                  const SizedBox(width: 10),
                ],
                if (prefix != null) ...[
                  const SizedBox(width: 18),
                  Text(prefix!, style: AppTextStyles.input),
                  const SizedBox(width: 8),
                ] else if (prefixIcon == null)
                  const SizedBox(width: 18),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: keyboardType,
                    textInputAction: textInputAction,
                    autofillHints: autofillHints,
                    obscureText: obscureText,
                    autocorrect: autocorrect,
                    enableSuggestions: enableSuggestions,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    style: AppTextStyles.input,
                    cursorColor: AppColors.neni,
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: AppTextStyles.fieldPlaceholder,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: 12),
                  suffix!,
                  const SizedBox(width: 12),
                ] else
                  const SizedBox(width: 18),
              ],
            ),
    );

    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label!,
          style: AppTextStyles.subtitle.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink2,
          ),
        ),
        const SizedBox(height: 6),
        field,
      ],
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.controller,
    this.hint = 'Busca tu pedido o una tienda',
    this.onChanged,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.fieldRadius,
        boxShadow: AppShadows.small,
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Symbols.search, color: AppColors.ink3, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppTextStyles.input.copyWith(fontSize: 14.5),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTextStyles.fieldPlaceholder,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
