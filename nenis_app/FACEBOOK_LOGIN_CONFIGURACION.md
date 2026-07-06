# Configuración de Facebook Login

Este documento contiene los valores verificados en los proyectos:

- App móvil: `C:\Codigos\nenis-app\nenis_app`
- API: `C:\Codigos\sellgeneral-api`

## 1. Valores encontrados

| Valor | Estado | Dónde se usa |
|---|---|---|
| Facebook App ID | `1427323549158529` | Android, iOS, Meta y API |
| Facebook Client Token | `e2e76b65a8e71ba9771ae4c07fcd9590` | Android e iOS |
| Facebook AppSecret | No está configurado | Solamente en la API |
| Paquete Android | `com.nenisapp.nenis_app` | Plataforma Android en Meta |
| Activity Android | `com.nenisapp.nenis_app.MainActivity` | Plataforma Android en Meta |
| Bundle ID iOS | `com.nenisapp.nenisApp` | Plataforma iOS en Meta |
| Hash de llave debug | `XTtoGPNTy095i2pPK7poXbfSWik=` | Key Hashes de Android en Meta |

El hash debug fue calculado desde:

```text
C:\Users\eduardo.rdz\.android\debug.keystore
Alias: androiddebugkey
SHA-1: 5D:3B:68:18:F3:53:CB:4F:79:8B:6A:4F:2B:BA:68:5D:B7:D2:5A:29
```

## 2. AppSecret y Client Token no son lo mismo

El `Client Token` ya estaba dentro de Android. Eso es correcto porque forma
parte de la configuración pública del SDK y termina incluido en el APK.

El `AppSecret` es una credencial privada del servidor:

- No debe colocarse en `strings.xml`.
- No debe colocarse en `AndroidManifest.xml`.
- No debe colocarse en `Info.plist`.
- No debe guardarse en Git.
- No debe compartirse en capturas, logs o documentación.

Actualmente, `C:\Codigos\sellgeneral-api\appsettings.json` contiene la propiedad
`Facebook:AppSecret`, pero su valor está vacío. Tampoco existe una variable de
entorno configurada en esta computadora.

## 3. Obtener el AppSecret en Meta

1. Abre [Meta for Developers](https://developers.facebook.com/apps/).
2. Selecciona la aplicación con ID `1427323549158529`.
3. Entra a **App settings > Basic**.
4. Busca **App secret** y presiona **Show**.
5. Confirma tu contraseña de Facebook.
6. Copia el valor directamente al almacén seguro del backend.

No copies el AppSecret a este archivo.

### Desarrollo local

El proyecto de la API ya admite `.NET User Secrets`. Ejecuta:

```powershell
Set-Location C:\Codigos\sellgeneral-api

dotnet user-secrets set "Facebook:AppId" "1427323549158529"
dotnet user-secrets set "Facebook:AppSecret" "PEGA_AQUI_EL_APP_SECRET"
dotnet user-secrets set "Facebook:GraphApiVersion" "v25.0"
```

Los valores se guardan fuera del repositorio y se cargan automáticamente cuando
la API corre con ambiente `Development`.

### Producción

Configura estas variables en el panel del proveedor donde corre la API:

```text
Facebook__AppId=1427323549158529
Facebook__AppSecret=<APP_SECRET_REAL>
Facebook__GraphApiVersion=v25.0
```

En variables de entorno de .NET, el doble guion bajo `__` representa la sección
`Facebook:`. Reinicia o vuelve a desplegar la API después de guardarlas.

## 4. Configurar Android en Meta

Dentro de la aplicación de Meta:

1. Entra a **App settings > Basic**.
2. En **Add platform**, selecciona **Android**.
3. Captura:

```text
Google Play package name:
com.nenisapp.nenis_app

Class name:
com.nenisapp.nenis_app.MainActivity
```

4. En **Key hashes**, agrega este hash de desarrollo:

```text
XTtoGPNTy095i2pPK7poXbfSWik=
```

5. Guarda los cambios.

El App ID, Client Token, manifest y esquema `fb1427323549158529` ya están
configurados en el proyecto Android.

## 5. Hashes que aún faltan

No se encontró ninguno de estos archivos:

```text
C:\Codigos\nenis-app\nenis_app\android\key.properties
C:\Codigos\nenis-app\nenis_app\android\*.jks
```

Por eso todavía no existe un hash de la llave de release que pueda entregarse.
Cuando se genere la llave descrita en el `README.md`, calcula el hash con:

```powershell
$keytool = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
$output = & $keytool -list -v `
  -alias upload `
  -keystore "C:\Codigos\nenis-app\nenis_app\android\app\upload-keystore.jks"

$sha1 = (
  $output |
    Select-String '^\s*SHA1:\s*([0-9A-Fa-f:]+)\s*$' |
    Select-Object -First 1
).Matches[0].Groups[1].Value

$hex = $sha1 -replace ':', ''
$bytes = [byte[]]::new($hex.Length / 2)
for ($i = 0; $i -lt $bytes.Length; $i++) {
  $bytes[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16)
}

[Convert]::ToBase64String($bytes)
```

El comando solicita la contraseña de la llave sin escribirla en el archivo.
El resultado también debe agregarse en **Key hashes** de Meta.

### Google Play App Signing

Si Google Play firma la aplicación, también debes registrar el hash del
certificado de **App signing**, no solamente el de la llave `upload`.

1. Abre Google Play Console.
2. Entra a **Setup > App integrity > App signing**.
3. Copia el SHA-1 del certificado de firma.
4. Sustituye el valor de `$sha1` en este bloque:

```powershell
$sha1 = "PEGA_AQUI_EL_SHA1_DE_GOOGLE_PLAY"
$hex = $sha1 -replace ':', ''
$bytes = [byte[]]::new($hex.Length / 2)
for ($i = 0; $i -lt $bytes.Length; $i++) {
  $bytes[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16)
}
[Convert]::ToBase64String($bytes)
```

Agrega el resultado a **Key hashes** en Meta. En producción normalmente deben
quedar registrados:

1. Hash de debug.
2. Hash de la llave upload/release.
3. Hash de App Signing de Google Play.

## 6. Configurar iOS en Meta

En **App settings > Basic > Add platform > iOS**, registra:

```text
Bundle ID:
com.nenisapp.nenisApp
```

El App ID, Client Token y esquema de retorno ya están agregados a
`ios\Runner\Info.plist`.

## 7. Lista de verificación

- [ ] AppSecret guardado en User Secrets para desarrollo.
- [ ] AppSecret guardado como variable del servidor en producción.
- [ ] Paquete y Activity Android registrados en Meta.
- [ ] Hash debug registrado.
- [ ] Hash upload/release registrado cuando exista la llave.
- [ ] Hash de Google Play App Signing registrado al publicar.
- [ ] Bundle ID de iOS registrado.
- [ ] Aplicación de Meta en modo Live o cuentas de prueba agregadas como roles.
- [ ] Permisos `public_profile` y `email` disponibles.

Sin el AppSecret, Android puede abrir el diálogo de Facebook, pero la API
rechazará el token clásico porque no puede validarlo de forma segura.
