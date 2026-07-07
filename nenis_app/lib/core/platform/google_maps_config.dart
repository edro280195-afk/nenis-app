import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GoogleMapsConfig {
  const GoogleMapsConfig._();

  static const _channel = MethodChannel('nenis_app/google_maps');

  static Future<bool> isConfigured() async {
    if (kIsWeb) return true;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return true;
    }

    try {
      return await _channel.invokeMethod<bool>('hasApiKey') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

final googleMapsConfiguredProvider = FutureProvider<bool>((ref) {
  return GoogleMapsConfig.isConfigured();
});
