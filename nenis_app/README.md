# nenis_app

App nativa (Flutter · iOS + Android) de la compradora de **Neni's App** (Fase 2 del SaaS multi-tenant).

## Stack

- Flutter 3.44 / Dart 3.12
- Riverpod (estado) · go_router (navegación) · dio (HTTP)
- flutter_secure_storage (JWT) · google_fonts (Poppins) · material_symbols_icons
- cached_network_image · google_maps_flutter · signalr_netcore · intl

## Arranque

```bash
flutter pub get
flutter run -d <device>
```

`mockups/` contiene los HTML/CSS de referencia visual de cada pantalla. El sistema de diseño en Dart vive en `lib/core/theme/`.

## Estructura

```
lib/
  core/        tema, router, api, auth, utils
  features/    auth, home, store, live, orders, tracking, points, tandas, raffles, account
  shared/      widgets reutilizables, screens comunes
  main.dart
```

## Backend

Por defecto `http://localhost:5080` (configurable en `lib/core/api/` cuando se implemente el cliente HTTP). Repo backend: `sellgeneral-api`.

## Facebook Login

La app usa el mismo Facebook App ID en Android, iOS y el backend. El SDK móvil
ya está configurado para:

- Android: `com.nenisapp.nenis_app`
- iOS: `com.nenisapp.nenisApp`

En Meta for Developers deben existir ambas plataformas. Android también requiere
los hashes de la llave de debug y de la llave de release; sin el hash de release
el acceso funciona localmente pero falla al instalar la versión publicada.

El `AppSecret` nunca va dentro de la app móvil. Se configura únicamente en el
servidor, preferentemente con variables de entorno:

```text
Facebook__AppId=1427323549158529
Facebook__AppSecret=<APP_SECRET>
Facebook__GraphApiVersion=v25.0
```

La aplicación de Meta debe estar en modo Live para usuarias externas y tener
habilitados `public_profile` y `email`.

La guía completa, con el hash debug verificado y las instrucciones para obtener
los hashes de release y Google Play, está en
[`FACEBOOK_LOGIN_CONFIGURACION.md`](FACEBOOK_LOGIN_CONFIGURACION.md).

## Firma de Android para release

Los builds de producción no usan la llave de debug. La configuración admite
`android/key.properties` o variables de entorno y falla con un mensaje claro si
faltan credenciales.

Genera una llave de carga una sola vez:

```powershell
keytool -genkeypair -v `
  -keystore android/app/upload-keystore.jks `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias upload
```

Copia la plantilla y reemplaza las dos contraseñas:

```powershell
Copy-Item android/key.properties.example android/key.properties
```

`key.properties` y los archivos `.jks` están ignorados por Git. Después puedes
generar el artefacto publicable:

```powershell
flutter build appbundle --release
```

En CI también se aceptan `NENIS_KEYSTORE_PATH`,
`NENIS_KEYSTORE_PASSWORD`, `NENIS_KEY_ALIAS` y `NENIS_KEY_PASSWORD`.
