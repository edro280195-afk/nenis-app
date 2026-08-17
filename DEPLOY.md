# Despliegue de Neni's App

Esta guía usa exclusivamente el bundle de producción:

- Flutter: `C:\Codigos\nenis-bundle\nenis-app\nenis_app`
- API: `C:\Codigos\nenis-bundle\sellgeneral-api`
- Angular: `C:\Codigos\nenis-bundle\sellgeneral`
- Landing legal: `C:\Codigos\nenis-bundle\nenisapp-landing`

## Estado local antes de publicar

- API: `dotnet test` — 324 pruebas verdes.
- Flutter: `flutter test` — 125 pruebas verdes.
- Angular: `npm run build` — compilación correcta; quedan avisos de tamaño/CommonJS.
- Landing: `npm run build` — compilación correcta.
- El AAB firmado se genera en:
  `C:\Codigos\nenis-bundle\nenis-app\nenis_app\build\app\outputs\bundle\release\app-release.aab`

## API y base de datos

Configura en el proveedor de hosting las variables de producción de
`C:\Codigos\nenis-bundle\sellgeneral-api\appsettings.example.json`.
Como mínimo deben existir:

- `ConnectionStrings__Default`
- `Jwt__Key`, `Jwt__Issuer`, `Jwt__Audience`
- Credenciales reales de Firebase Authentication y `Firebase__ProjectId`
- Configuración de SMS/Firebase, CORS y URLs `App__*`
- Credenciales de pagos, correo, almacenamiento y mapas que realmente se vayan a usar

En producción:

- Usa `ASPNETCORE_ENVIRONMENT=Production`.
- No habilites `Auth__DevOtpEnabled` ni publiques un código fijo.
- Mantén `firebase-service-account.json` fuera del repositorio y fuera de los artefactos públicos.
- Haz un respaldo de PostgreSQL antes de aplicar migraciones.
- Aplica las migraciones pendientes desde el despliegue controlado del API; no las ejecutes manualmente contra producción sin respaldo.

La API ya incluye `DELETE /api/auth/me`. El endpoint requiere sesión autenticada,
elimina la identidad de Firebase, sesiones y tokens personales, y conserva solo
los historiales operativos necesarios de forma anonimizada.

## Angular y páginas legales

Compilar el panel:

```powershell
Set-Location C:\Codigos\nenis-bundle\sellgeneral
npm ci
npm run build
```

Publica `dist\regibazar-store` en `https://app.nenisapp.com`.

Compilar la landing:

```powershell
Set-Location C:\Codigos\nenis-bundle\nenisapp-landing
npm ci
npm run build
```

Publica `dist` en `https://nenisapp.com`. Deben quedar accesibles:

- `https://nenisapp.com/privacy.html`
- `https://nenisapp.com/terms.html`
- `https://nenisapp.com/deletion.html`

## Flutter / Google Play

El proyecto usa `com.nenisapp.nenis_app`, target SDK 36 y firma de release
con el keystore local. `android\key.properties` y `android\nenis-release.jks`
son secretos: no se suben a Git ni se comparten por correo.

Para generar el paquete:

```powershell
Set-Location C:\Codigos\nenis-bundle\nenis-app\nenis_app
flutter clean
flutter pub get
flutter test
flutter build appbundle --release
```

Antes de cada actualización, incrementa `version:` en `pubspec.yaml`, por
ejemplo `1.0.1+2`. Nunca reutilices el mismo `versionCode` en Play Console.

## Firebase y enlaces de aplicación

Después de crear la app en Play Console y activar Play App Signing, registra
en Firebase las huellas SHA-1 y SHA-256 que muestre Play Console para la app
firmada por Google. La huella de la clave local de subida es distinta de la
huella de Play App Signing.

Verifica también que `https://app.nenisapp.com/.well-known/assetlinks.json`
contenga:

- package: `com.nenisapp.nenis_app`
- huella de la clave de firma de aplicación que muestra Play Console

## Pruebas manuales de producción

1. Registro y acceso por SMS en Android real.
2. Cierre y renovación de sesión.
3. Creación de negocio y acceso al panel Angular.
4. Pedido, enlace público, notificación push y deep link.
5. Pagos y suscripciones, si están activados.
6. Eliminación de cuenta desde Flutter y desde Angular.
7. Apertura de privacidad, términos y eliminación desde navegador móvil.

No uses cuentas reales para la prueba de eliminación; usa una cuenta de
prueba dedicada y verifica en Firebase y PostgreSQL que se retiraron los
identificadores personales.
