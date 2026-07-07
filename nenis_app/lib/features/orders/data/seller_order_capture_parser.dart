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
    unitPrice: price / quantity,
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
  var price = 0.0;
  var quantity = 1;
  final productChunks = [...chunks.skip(1)];

  for (var i = productChunks.length - 1; i >= 0; i--) {
    final numbers = RegExp(r'\d+(?:[.,]\d+)?')
        .allMatches(
          productChunks[i].replaceAll(
            RegExp(r'pesos?', caseSensitive: false),
            '',
          ),
        )
        .map((m) => _parseMoney(m.group(0) ?? ''))
        .where((n) => n > 0)
        .toList();
    if (numbers.isNotEmpty) {
      price = numbers.last;
      final qtyMatch = RegExp(r'^(\d+)\s+').firstMatch(productChunks[i]);
      final qty = qtyMatch == null ? null : int.tryParse(qtyMatch.group(1)!);
      if (qty != null && qty > 0 && qty <= 20) quantity = qty;
      productChunks.removeAt(i);
      break;
    }
  }
  if (price <= 0) return null;

  var productName = productChunks.join(' ').trim();
  final productWords = productName
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final productQuantity = productWords.isEmpty
      ? null
      : _parseQuantity(productWords.first);
  if (quantity == 1 && productQuantity != null && productQuantity <= 20) {
    quantity = productQuantity;
    productName = productWords.skip(1).join(' ');
  }
  if (productName.isEmpty) productName = 'Articulo';

  return QuickCaptureDraft(
    clientName: clientName,
    productName: capitalizeWords(productName),
    quantity: quantity,
    unitPrice: price / quantity,
  );
}

double _parseMoney(String value) {
  final clean = value
      .replaceAll(RegExp(r'[\$,]'), '')
      .replaceAll(RegExp(r'pesos?', caseSensitive: false), '')
      .trim();
  return double.tryParse(clean) ?? 0;
}

int? _parseQuantity(String value) {
  final normalized = normalizeCaptureText(value);
  return int.tryParse(normalized) ?? _numberWords[normalized];
}
