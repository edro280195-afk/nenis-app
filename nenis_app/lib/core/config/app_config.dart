import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Configuración de entorno de la app.
class AppConfig {
  AppConfig._();

  /// Base URL del backend `sellgeneral-api`.
  ///
  /// - Override en build: `--dart-define=API_BASE_URL=http://mi-host:5080`.
  /// - Emulador Android: `10.0.2.2` mapea al `localhost` de la máquina host.
  /// - Simulador iOS / desktop / web: `localhost`.
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    if (kIsWeb) return 'http://localhost:5080';
    if (Platform.isAndroid) return 'http://10.0.2.2:5080';
    return 'http://localhost:5080';
  }
}
