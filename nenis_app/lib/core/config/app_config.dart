/// Configuración de entorno de la app.
///
/// La app siempre apunta al API publicada en producción. No hay switches de
/// debug/release ni `--dart-define`: cualquier cambio de dominio se hace aquí
/// y se sube. Mientras estemos en desarrollo, este dominio es el de producción
/// y todos los cambios se publican ahí.
class AppConfig {
  AppConfig._();

  /// Base URL del backend `sellgeneral-api` (API publicada).
  static const String apiBaseUrl = 'https://app.nenisapp.com';

  /// Base URL del panel web Angular (`sellgeneral`). Se usa para el checkout
  /// de Mercado Pago (`mp_checkout_webview_screen.dart`), que reusa la página
  /// de pago ya construida ahí. Sin panel web propio todavía: apunta al mismo
  /// dominio de la API. Cuando exista panel separado, cambia esta constante.
  static const String webAdminBaseUrl = 'https://app.nenisapp.com';
}
