/// Configuración de entorno de la app.
///
/// La app siempre apunta al API publicada en producción. No hay switches de
/// debug/release ni `--dart-define`: cualquier cambio de dominio se hace aquí
/// y se sube. Mientras estemos en desarrollo, este dominio es el de producción
/// y todos los cambios se publican ahí.
class AppConfig {
  AppConfig._();

  static const String _productionUrl = 'https://app.nenisapp.com';

  /// Base URL del backend `sellgeneral-api` (API publicada).
  ///
  /// Por defecto usa produccion. Para auditorias locales se puede correr con:
  /// `--dart-define=NENIS_API_BASE_URL=http://10.0.2.2:5080`
  static const String apiBaseUrl = String.fromEnvironment(
    'NENIS_API_BASE_URL',
    defaultValue: _productionUrl,
  );

  /// Base URL del panel web Angular (`sellgeneral`). Se usa para el checkout
  /// de Mercado Pago (`mp_checkout_webview_screen.dart`), que reusa la página
  /// de pago ya construida ahí. Sin panel web propio todavía: apunta al mismo
  /// dominio de la API. Cuando exista panel separado, cambia esta constante.
  static const String webAdminBaseUrl = String.fromEnvironment(
    'NENIS_WEB_ADMIN_BASE_URL',
    defaultValue: _productionUrl,
  );
}
