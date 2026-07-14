class QuickCaptureDraft {
  const QuickCaptureDraft({
    required this.clientName,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final String clientName;
  final String productName;
  final int quantity;
  final double unitPrice;

  double get total => quantity * unitPrice;
}

const _numberWords = <String, int>{
  'un': 1,
  'una': 1,
  'uno': 1,
  'dos': 2,
  'tres': 3,
  'cuatro': 4,
  'cinco': 5,
  'seis': 6,
  'siete': 7,
  'ocho': 8,
  'nueve': 9,
  'diez': 10,
  'once': 11,
  'doce': 12,
  'quince': 15,
  'veinte': 20,
};

QuickCaptureDraft? parseQuickCapture(String text) {
  final raw = text.trim();
  if (raw.isEmpty) return null;

  final chunks = raw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (chunks.length >= 2) {
    return _parseCommaCapture(chunks);
  }

  return parseQuickProductCapture(clientName: null, productText: raw);
}

QuickCaptureDraft? parseQuickProductCapture({
  required String? clientName,
  required String productText,
}) {
  final words = productText.trim().split(RegExp(r'\s+'));
  if (words.length < 2) return null;

  var priceIndex = -1;
  var price = 0.0;
  for (var i = words.length - 1; i >= 0; i--) {
    final parsedPrice = _parseMoney(words[i]);
    if (parsedPrice > 0) {
      price = parsedPrice;
      priceIndex = i;
      break;
    }
  }
  if (priceIndex < 1 || price <= 0) return null;

  final resolvedClientName = clientName ?? capitalizeWords(words.first);
  var productWords = clientName == null
      ? words.sublist(1, priceIndex)
      : words.sublist(0, priceIndex);
  if (productWords.isEmpty) return null;

  var quantity = _parseQuantity(productWords.first);
  if (quantity != null && quantity <= 20) {
    productWords = productWords.sublist(1);
  } else {
    quantity = 1;
  }
  if (productWords.isEmpty) productWords = ['Articulo'];

  return QuickCaptureDraft(
    clientName: resolvedClientName,
    productName: capitalizeWords(productWords.join(' ')),
    quantity: quantity,
    // U13: el precio que escribe la vendedora es el UNITARIO (lo más natural:
    // "blusa 100" = $100 c/u). Antes se dividía entre la cantidad, así que
    // "2 blusas 100" daba $50 c/u aunque ella pensara $100.
    unitPrice: price,
  );
}

String normalizeCaptureText(String text) {
  const accents = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  return text
      .trim()
      .toLowerCase()
      .split('')
      .map((c) => accents[c] ?? c)
      .join()
      .replaceAll(RegExp(r'\s+'), ' ');
}

String capitalizeWords(String text) {
  return text
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map(
        (w) => w.length == 1
            ? w.toUpperCase()
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
      )
      .join(' ');
}

QuickCaptureDraft? _parseCommaCapture(List<String> chunks) {
  final clientName = capitalizeWords(chunks.first);
  // B6: antes, si un chunk tenía el precio pegado al producto (ej. "blusa 100"
  // en "Maria, blusa 100"), se eliminaba el chunk entero y se perdía "blusa".
  // Ahora unimos todo el texto de producto y extraemos solo el número.
  final productText = chunks.skip(1).join(' ').trim();
  if (productText.isEmpty) return null;

  // Quitamos la palabra "peso/pesos" para que no la confunda con un número.
  final cleaned = productText.replaceAll(
    RegExp(r'pesos?', caseSensitive: false),
    '',
  );

  // Buscamos todos los números (incluye separadores MXN) y nos quedamos con
  // el último como precio.
  final priceRegex = RegExp(r'\d[\d.,]*\d|\d');
  final matches = priceRegex.allMatches(cleaned).toList();
  if (matches.isEmpty) return null;
  final lastMatch = matches.last;
  final price = _parseMoney(lastMatch.group(0)!);
  if (price <= 0) return null;

  // El nombre del producto es el texto sin el número del precio.
  var productName = (cleaned.substring(0, lastMatch.start) +
          cleaned.substring(lastMatch.end))
      .trim();

  // Cantidad al inicio del producto (ej. "2 blusas" → qty=2, "blusas").
  final words = productName
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  var quantity = 1;
  if (words.isNotEmpty) {
    final firstQty = _parseQuantity(words.first);
    if (firstQty != null && firstQty > 0 && firstQty <= 20) {
      quantity = firstQty;
      words.removeAt(0);
      productName = words.join(' ');
    }
  }
  if (productName.isEmpty) productName = 'Articulo';

  return QuickCaptureDraft(
    clientName: clientName,
    productName: capitalizeWords(productName),
    quantity: quantity,
    // U13: precio unitario, no total/cantidad.
    unitPrice: price,
  );
}

double _parseMoney(String value) {
  var clean = value
      .replaceAll(RegExp(r'\$'), '')
      .replaceAll(RegExp(r'pesos?', caseSensitive: false), '')
      .trim();
  // U12: convención mexicana — "." separa miles, "," separa decimales.
  //   "1.000"      → 1000
  //   "10.500"     → 10500
  //   "1.000.000"  → 1000000
  //   "1,5"        → 1.5
  //   "1,50"       → 1.50
  //   "1.50"       → 1.50 (2 decimales → decimal, no miles)
  //   "1.234,5"    → 1234.5 (formato completo MXN)
  if (clean.contains(',') && clean.contains('.')) {
    clean = clean.replaceAll('.', '').replaceAll(',', '.');
  } else if (clean.contains(',')) {
    clean = clean.replaceAll(',', '.');
  } else if (clean.contains('.')) {
    final parts = clean.split('.');
    if (parts.length > 2) {
      // "1.000.000" → miles múltiples.
      clean = parts.join('');
    } else if (parts.length == 2 && parts[1].length == 3) {
      // "1.000" → 1000 (3 dígitos tras el punto = miles).
      clean = parts.join('');
    }
    // else: "1.5" / "1.50" / "1.99" → decimal, double.tryParse lo resuelve.
  }
  return double.tryParse(clean) ?? 0;
}

int? _parseQuantity(String value) {
  final normalized = normalizeCaptureText(value);
  return int.tryParse(normalized) ?? _numberWords[normalized];
}
