import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nenis_app/features/labels/services/direct_print/tspl_command_builder.dart';

/// PNG de 2×2 en tablero de ajedrez: (0,0) negro, (1,0) blanco,
/// (0,1) blanco, (1,1) negro. Suficiente para verificar el header TSPL y
/// la inversión de bit del bitmap sin depender de assets externos.
Uint8List _checkerboardPng() {
  final image = img.Image(width: 2, height: 2);
  image.setPixelRgb(0, 0, 0, 0, 0);
  image.setPixelRgb(1, 0, 255, 255, 255);
  image.setPixelRgb(0, 1, 255, 255, 255);
  image.setPixelRgb(1, 1, 0, 0, 0);
  return img.encodePng(image);
}

void main() {
  group('TsplCommandBuilder.build', () {
    test('arma el header TSPL con las medidas y parámetros pedidos', () {
      final command = TsplCommandBuilder.build(
        png: _checkerboardPng(),
        widthMm: 102,
        heightMm: 152,
        gapMm: 3,
        density: 9,
        copies: 2,
      );

      final expectedPrefix = ascii.encode(
        'SIZE 102 mm,152 mm\r\n'
        'GAP 3 mm,0 mm\r\n'
        'DENSITY 9\r\n'
        'SPEED 4\r\n'
        'DIRECTION 0\r\n'
        'REFERENCE 0,0\r\n'
        'CLS\r\n',
      );
      expect(command.sublist(0, expectedPrefix.length), expectedPrefix);

      // El bitmap (binario) va entre el header y el pie; buscamos el
      // "PRINT 1,2" del pie para confirmar que copies llegó bien.
      final tail = ascii.encode('\r\nPRINT 1,2\r\n');
      final commandBytes = command.toList();
      final tailStart = commandBytes.length - tail.length;
      expect(command.sublist(tailStart), tail);
    });

    test('sin separación entre etiquetas (gapMm: 0) manda GAP en 0', () {
      final command = TsplCommandBuilder.build(
        png: _checkerboardPng(),
        widthMm: 50,
        heightMm: 50,
        gapMm: 0,
      );
      final expectedPrefix = ascii.encode('SIZE 50 mm,50 mm\r\nGAP 0 mm,0 mm\r\n');
      expect(command.sublist(0, expectedPrefix.length), expectedPrefix);
    });

    test(
      'invierte el bit del bitmap: pixel claro → bit=1 (no quema), pixel '
      'oscuro → bit=0 (sí quema) — esta impresora funciona al revés del '
      'estándar TSPL (ver comentario en tspl_command_builder.dart). Un '
      'cambio accidental aquí produciría etiquetas con los colores '
      'invertidos sin ningún error visible en la app.',
      () {
        final command = TsplCommandBuilder.build(
          png: _checkerboardPng(),
          widthMm: 50,
          heightMm: 50,
        );

        // bytesPerRow = ceil(2px / 8) = 1 byte por fila, 2 filas → 2 bytes.
        final header = ascii.encode(
          'SIZE 50 mm,50 mm\r\n'
          'GAP 2 mm,0 mm\r\n'
          'DENSITY 15\r\n'
          'SPEED 4\r\n'
          'DIRECTION 0\r\n'
          'REFERENCE 0,0\r\n'
          'CLS\r\n',
        );
        final bitmapMarker = ascii.encode('BITMAP 0,0,1,2,0,');
        final prefix = [...header, ...bitmapMarker];
        expect(command.sublist(0, prefix.length), prefix);

        final bitmapBytes = command.sublist(prefix.length, prefix.length + 2);
        // Fila 0: negro(bit7, no marcado), blanco(bit6, marcado) → 0x40.
        expect(bitmapBytes[0], 0x40);
        // Fila 1: blanco(bit7, marcado), negro(bit6, no marcado) → 0x80.
        expect(bitmapBytes[1], 0x80);
      },
    );

    test('rechaza bytes que no son una imagen válida', () {
      expect(
        () => TsplCommandBuilder.build(
          png: Uint8List.fromList([1, 2, 3]),
          widthMm: 50,
          heightMm: 50,
        ),
        throwsFormatException,
      );
    });
  });
}
