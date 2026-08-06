import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/maps/google_address_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class GoogleAddressField extends ConsumerStatefulWidget {
  const GoogleAddressField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText = 'Busca calle, colonia o lugar',
    this.labelText,
    this.onChanged,
    this.onSelected,
    this.textInputAction = TextInputAction.next,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final String? labelText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<GoogleAddressSelection>? onSelected;
  final TextInputAction textInputAction;

  @override
  ConsumerState<GoogleAddressField> createState() => _GoogleAddressFieldState();
}

class _GoogleAddressFieldState extends ConsumerState<GoogleAddressField> {
  Timer? _debounce;
  List<GoogleAddressSuggestion> _suggestions = const [];
  bool _searching = false;
  String _lastQuery = '';
  String? _sessionToken;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.onChanged?.call(value);
    _debounce?.cancel();
    final query = value.trim();
    _lastQuery = query;
    if (query.length < 3) {
      _sessionToken = null;
      setState(() {
        _suggestions = const [];
        _searching = false;
      });
      return;
    }

    _sessionToken ??= _createSessionToken();
    final sessionToken = _sessionToken;
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 320), () async {
      final suggestions = await ref
          .read(googleAddressRepositoryProvider)
          .autocomplete(query, sessionToken: sessionToken);
      if (!mounted || _lastQuery != query) return;
      setState(() {
        _suggestions = suggestions;
        _searching = false;
      });
    });
  }

  Future<void> _select(GoogleAddressSuggestion suggestion) async {
    _debounce?.cancel();
    final fallback = suggestion.description.isNotEmpty
        ? suggestion.description
        : suggestion.mainText;
    widget.controller.value = TextEditingValue(
      text: fallback,
      selection: TextSelection.collapsed(offset: fallback.length),
    );
    setState(() {
      _suggestions = const [];
      _searching = true;
    });

    final details = await ref
        .read(googleAddressRepositoryProvider)
        .getDetails(suggestion.placeId, sessionToken: _sessionToken);
    if (!mounted) return;
    final selection = details ?? GoogleAddressSelection(address: fallback);
    final address = selection.address.trim().isEmpty
        ? fallback
        : selection.address;
    widget.controller.value = TextEditingValue(
      text: address,
      selection: TextSelection.collapsed(offset: address.length),
    );
    setState(() => _searching = false);
    _sessionToken = null;
    widget.onSelected?.call(
      GoogleAddressSelection(
        address: address,
        latitude: selection.latitude,
        longitude: selection.longitude,
      ),
    );
  }

  String _createSessionToken() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          onChanged: _onChanged,
          textInputAction: widget.textInputAction,
          maxLines: 2,
          minLines: 1,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: const Icon(Symbols.location_searching),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                for (final suggestion in _suggestions)
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Symbols.location_on,
                      color: AppColors.neniDeep,
                    ),
                    title: Text(
                      suggestion.mainText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      suggestion.secondaryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _select(suggestion),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Powered by Google',
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 10,
                        color: AppColors.ink3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
