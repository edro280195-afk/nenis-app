import 'dart:convert';
import 'dart:typed_data';

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
  static Uint8List build({
    required Uint8List png,
    required int widthMm,
    required int heightMm,
    int gapMm = 2,
    int density = 15,
    int copies = 1,
  }) {
    final decoded = img.decodeImage(png);
    if (decoded == null) {
      throw const FormatException('No se pudo decodificar la imagen de la etiqueta.');
    }
    final grayscale = img.grayscale(decoded);
    final bytesPerRow = (grayscale.width + 7) ~/ 8;
    final bitmap = Uint8List(bytesPerRow * grayscale.height);
    // Bit=1 debería significar "quemar/imprimir negro" en TSPL estándar,
    // pero en esta impresora sale al revés (fondo negro, contenido
    // blanco) — así que aquí marcamos bit=1 para los píxeles CLAROS
    // (dejar sin quemar) y dejamos bit=0 en los oscuros (que aquí sí
    // queman negro).
    for (var y = 0; y < grayscale.height; y++) {
      for (var x = 0; x < grayscale.width; x++) {
        final luminance = grayscale.getPixel(x, y).r;
        if (luminance >= 128) {
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
    out.add(ascii.encode('BITMAP 0,0,$bytesPerRow,${grayscale.height},0,'));
    out.add(bitmap);
    out.add(ascii.encode('\r\n'));
    line('PRINT 1,$copies');

    return out.toBytes();
  }
}
