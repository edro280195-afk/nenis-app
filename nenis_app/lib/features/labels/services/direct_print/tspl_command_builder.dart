import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

/// Arma comandos TSPL (Zebra-compatible) a mano, sin ninguna caja negra de
/// SDK de por medio. La AIYIN E40 Pro no reaccionaba en absoluto al
/// comando que armaba el plugin de terceros (conectaba y aceptaba los
/// bytes sin error, pero nunca imprimía nada) — con esto controlamos byte
/// por byte lo que se manda y sabemos exactamente qué dice.
class TsplCommandBuilder {
  /// [widthMm]/[heightMm]: tamaño físico de la etiqueta.
  /// [gapMm]: separación entre etiquetas en la bobina (0 si es continua).
  /// [density]: 0-15, entre más alto más oscuro/caliente el cabezal.
  ///
  /// Mode 3 is the compressed bitmap extension emitted by AiYin's own
  /// Label Expert SDK. The uncompressed mode remains available for
  /// diagnostics and printers without that extension.
  static Uint8List build({
    required Uint8List png,
    required int widthMm,
    required int heightMm,
    int gapMm = 2,
    int density = 15,
    int copies = 1,
    bool compress = false,
  }) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(png);
    } catch (_) {
      // Con bytes corruptos/demasiado cortos, decodeImage() no siempre
      // devuelve null: el paquete image puede lanzar un error crudo (p.ej.
      // RangeError) al probar formatos candidatos (visto con PSD) antes de
      // descartarlos. Lo normalizamos al mismo error controlado.
      decoded = null;
    }
    if (decoded == null) {
      throw const FormatException(
        'No se pudo decodificar la imagen de la etiqueta.',
      );
    }
    final grayscale = img.grayscale(decoded);
    final bytesPerRow = (grayscale.width + 7) ~/ 8;
    final bitmap = Uint8List(bytesPerRow * grayscale.height);
    // Mode 0 on this E40 interprets the raster polarity opposite to the
    // vendor's compressed mode 3. Preserve the validated mode 0 polarity,
    // while using the standard dark-pixel polarity required by AiYin's
    // compressed encoder.
    for (var y = 0; y < grayscale.height; y++) {
      for (var x = 0; x < grayscale.width; x++) {
        final luminance = grayscale.getPixel(x, y).r;
        final shouldSetBit = compress ? luminance < 128 : luminance >= 128;
        if (shouldSetBit) {
          final byteIndex = y * bytesPerRow + (x >> 3);
          final bitIndex = 7 - (x & 7);
          bitmap[byteIndex] |= 1 << bitIndex;
        }
      }
    }

    final out = BytesBuilder();
    void line(String s) => out.add(ascii.encode('$s\r\n'));

    line('SIZE $widthMm mm,$heightMm mm');
    line(gapMm > 0 ? 'GAP $gapMm mm,0 mm' : 'GAP 0 mm,0 mm');
    line('DENSITY $density');
    line('SPEED 4');
    line('DIRECTION 0');
    line('REFERENCE 0,0');
    line('CLS');
    if (compress) {
      // This matches psdk_fruit_tspl/Pbita: zlib with a 10-bit window,
      // followed by mode 3 and the compressed byte count.
      final compressedBitmap = ZLibEncoder().encode(bitmap, windowBits: 10);
      out.add(
        ascii.encode(
          'BITMAP 0,0,$bytesPerRow,${grayscale.height},3,${compressedBitmap.length},',
        ),
      );
      out.add(compressedBitmap);
    } else {
      out.add(ascii.encode('BITMAP 0,0,$bytesPerRow,${grayscale.height},0,'));
      out.add(bitmap);
    }
    out.add(ascii.encode('\r\n'));
    line('PRINT 1,$copies');

    return out.toBytes();
  }
}
