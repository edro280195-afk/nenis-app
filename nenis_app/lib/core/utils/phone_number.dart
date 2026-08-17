/// Utilidades de normalización para teléfonos usados por Firebase Phone Auth.
class PhoneNumberNormalizer {
  static const String _mexicoCountryCode = '52';

  const PhoneNumberNormalizer._();

  /// Convierte un teléfono nacional mexicano o un número internacional a E.164.
  static String? toE164(String? input) {
    if (input == null || input.trim().isEmpty) return null;

    final trimmed = input.trim();
    var digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (trimmed.startsWith('00') && digits.length > 2) {
      digits = digits.substring(2);
    }

    if (digits.length == 10) return '+$_mexicoCountryCode$digits';
    if (digits.length == 12 && digits.startsWith(_mexicoCountryCode)) {
      return '+$digits';
    }

    return digits.length >= 8 && digits.length <= 15 ? '+$digits' : null;
  }

  static bool isValidE164(String? value) {
    return value != null && RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(value);
  }
}
