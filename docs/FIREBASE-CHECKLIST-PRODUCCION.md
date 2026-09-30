# Firebase en producción — checklist y cómo verificarlo

> Creado 2026-09-30 tras validar el token de registro (SMS) y el token de notificaciones push.
> La arquitectura está descrita en `sellgeneral-api/FIREBASE_PHONE_AUTH.md`.

## Qué encontramos (2026-09-30)

| # | Hallazgo | Evidencia |
|---|---|---|
| 1 | **Producción no tiene credencial de Firebase Admin.** El canje SMS→sesión y todos los push están apagados. | `POST /api/auth/firebase` con token falso → `503 firebase_auth_not_configured` (debería ser `401 invalid_firebase_token`). |
| 2 | **El proyecto de la credencial local no coincide con el de la app.** La app usa `nenisapp-60810`; `sellgeneral-api/firebase-service-account.json` es de `regibazarnotify`. Aunque se subiera ese archivo, Firebase rechazaría los tokens de la app. | `google-services.json` → `nenisapp-60810`; el JSON de servicio → `regibazarnotify`. |
| 3 | **Ninguna huella SHA registrada** en `google-services.json` (`oauth_client: []`). Phone Auth en Android necesita SHA-1/SHA-256 o falla / cae a reCAPTCHA. | Ver huellas abajo. |
| 4 | El token push de la app **sí se obtiene y se guarda** en la base. | Log de la app: `[Push] token …EPpYO4 (142 car.) registrado: true`. |
| 5 | El backend enviaba push con el canal `regibazar_channel`, que la app no creaba → Android lo degradaba al canal genérico. | Corregido: la app crea también ese canal. |

## Lo que tienes que hacer tú (no tengo acceso a Firebase ni a Render)

### A. Credencial del backend (proyecto `nenisapp-60810`)
1. Firebase Console → proyecto **nenisapp-60810** → ⚙️ *Configuración del proyecto* → *Cuentas de servicio* → **Generar nueva clave privada**. Se descarga un `.json`.
2. Render → servicio de la API → *Environment* → **Secret Files** → agrega uno llamado exactamente `firebase-service-account.json` y pega el contenido del `.json`. (Render lo monta en `/etc/secrets/`; la API ya lo busca ahí.)
3. Redespliega. En los logs de Render debe aparecer: `🔥 Motor de Firebase conectado con éxito (proyecto: nenisapp-60810)`.
4. **No subas ese archivo a git** (ya está en `.gitignore`).

> ⚠️ Los choferes y el panel web usan el mismo servicio de FCM (`FcmToken`, `regibazar_channel`). Un proceso solo puede tener **una** credencial por defecto. Si tus choferes reciben push con tokens del proyecto `regibazarnotify`, con esta credencial dejarán de recibirlos. Confirma cuál usan antes de cambiar; si hacen falta ambos proyectos hay que agregar una segunda `FirebaseApp` con nombre.

### B. Phone Auth y huellas (Firebase Console → proyecto nenisapp-60810)
1. *Authentication → Sign-in method* → habilita **Teléfono**.
2. *Configuración del proyecto → Tus apps → Android (`com.nenisapp.nenis_app`)* → **Agregar huella digital**:

| Llave | SHA-1 | SHA-256 |
|---|---|---|
| Release (tu `nenis-release.jks`) | `A7:42:19:CE:D9:3A:E4:C5:D7:03:B1:8E:22:BA:6D:0E:CF:84:F8:BE` | `6C:86:55:3D:F8:4F:B5:15:93:CA:23:A5:AB:33:7D:2E:A9:3E:AE:BA:7B:E6:2C:CB:7A:5D:CF:D0:BA:A7:5A:04` |
| Debug (emuladores/desarrollo) | `5D:3B:68:18:F3:53:CB:4F:79:8B:6A:4F:2B:BA:68:5D:B7:D2:5A:29` | `59:57:3A:42:52:47:25:DC:B7:1D:00:71:49:73:2F:BC:7B:73:13:7D:BC:CA:DB:DF:5A:A1:2C:83:02:C6:33:E6` |
| **Play App Signing** (la que re-firma Google) | Play Console → *Integridad de la app* → *Firma de apps* → "Certificado de la clave de firma de la app" | idem (copia SHA-1 **y** SHA-256) |

   **La de Play App Signing es la que importa para los usuarios reales**: las apps instaladas desde Play Store llevan la firma de Google, no la tuya. Sin ella, el SMS falla solo en producción aunque funcione en pruebas.
3. Descarga el `google-services.json` actualizado y reemplaza `nenis_app/android/app/google-services.json` (ahora debe traer `oauth_client` con los hashes).
4. Verifica que *Play Integrity API* esté habilitada en el proyecto de Google Cloud de Firebase.
5. (Opcional, para probar sin gastar SMS) *Phone → Números de teléfono para pruebas*.

## Cómo verificar cada pieza

**1. ¿La API tiene Firebase Admin del proyecto correcto?** (debe dejar de dar 503)
```bash
curl -s -w "\nHTTP %{http_code}\n" -X POST https://app.nenisapp.com/api/auth/firebase \
  -H "Content-Type: application/json" -d '{"idToken":"a.b.c","accountType":"client"}'
```
- `503 firebase_auth_not_configured` → falta la credencial (paso A).
- `401 invalid_firebase_token` → ✅ configurada.

**2. ¿El token del teléfono se registra y las notificaciones llegan?** En la app, sesión iniciada: **Cuenta → Probar notificaciones** (clienta) o **Mi negocio → Probar notificaciones** (vendedora). Mensajes:
- "Las notificaciones están desactivadas…" → permiso del teléfono.
- "Este teléfono no pudo obtener su identificador…" → sin Google Play Services / sin red.
- "El servidor todavía no puede enviar notificaciones" → falta A.
- "El servidor no logró entregar la notificación (SenderIdMismatch…)" → la credencial es de otro proyecto.
- "Listo: te enviamos una notificación de prueba" → ✅ todo el camino funciona; debe llegar al teléfono.

**3. ¿El SMS llega y se canjea por sesión?** En un dispositivo físico, cierra sesión → *Entrar con código* → tu número → llega el SMS → entras. Si el SMS no llega o la app dice "No pudimos validar el dispositivo", revisa las huellas (paso B).

En debug, `adb logcat | grep "\[Push\]"` muestra el registro del token.
