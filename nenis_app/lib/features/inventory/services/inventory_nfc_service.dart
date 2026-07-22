import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:nfc_manager/ndef_record.dart';

class InventoryNfcException implements Exception {
  const InventoryNfcException(this.message);
  final String message;
  @override
  String toString() => message;
}

class InventoryNfcService {
  Future<String> writeBoxLink(String link) async {
    if (!Platform.isAndroid) {
      throw const InventoryNfcException(
        'Vincula la tarjeta desde Android para confirmar su identificador físico.',
      );
    }
    if (await NfcManager.instance.checkAvailability() !=
        NfcAvailability.enabled) {
      throw const InventoryNfcException(
        'Activa NFC en este teléfono para continuar.',
      );
    }
    final result = Completer<String>();
    await NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443},
      onDiscovered: (tag) async {
        try {
          final ndef = Ndef.from(tag);
          final uid = NfcTagAndroid.from(tag)?.id;
          if (uid == null || uid.isEmpty) {
            throw const InventoryNfcException(
              'No pudimos leer el identificador físico de esta tarjeta.',
            );
          }
          final message = NdefMessage(
            records: [
              NdefRecord(
                typeNameFormat: TypeNameFormat.wellKnown,
                type: Uint8List.fromList([0x55]),
                identifier: Uint8List(0),
                payload: Uint8List.fromList([0, ...utf8.encode(link)]),
              ),
            ],
          );
          if (ndef != null && !ndef.isWritable) {
            throw const InventoryNfcException(
              'Esta tarjeta está bloqueada y no se puede vincular.',
            );
          }
          if (ndef != null) {
            await ndef.write(message: message);
          } else {
            final formatable = NdefFormatableAndroid.from(tag);
            if (formatable == null) {
              throw const InventoryNfcException(
                'Esta tarjeta no admite formato NFC NDEF.',
              );
            }
            await formatable.format(message);
          }
          await NfcManager.instance.stopSession(
            alertMessageIos: 'Tarjeta vinculada',
          );
          if (!result.isCompleted) {
            result.complete(
              uid
                  .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
                  .join()
                  .toUpperCase(),
            );
          }
        } catch (error) {
          await NfcManager.instance.stopSession(
            errorMessageIos: 'No se pudo vincular',
          );
          if (!result.isCompleted) {
            result.completeError(
              error is InventoryNfcException
                  ? error
                  : InventoryNfcException(
                      'No pudimos escribir esta tarjeta NFC.',
                    ),
            );
          }
        }
      },
    );
    try {
      return await result.future.timeout(const Duration(seconds: 45));
    } on TimeoutException {
      await NfcManager.instance.stopSession(
        errorMessageIos: 'Tiempo de lectura agotado',
      );
      throw const InventoryNfcException(
        'No detectamos una tarjeta NFC. Acércala e inténtalo de nuevo.',
      );
    }
  }
}
