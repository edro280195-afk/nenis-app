# Guía de deploy del backend para pruebas con la app Neni's

Esta guía cubre las dos formas de tener un backend `sellgeneral-api`
vivo al que la app Flutter pueda conectarse. Elige la que prefieras
según tu caso de uso:

| Opción | Para qué sirve | Tiempo de setup |
|---|---|---|
| **A. Puerto en tu laptop** | Iterar rápido, ver logs en vivo, debug en vivo | 5 min |
| **B. Render (recomendada)** | Pruebas reales en el móvil desde cualquier red (4G, WiFi del trabajo) | 15 min |

---

## Prerrequisitos comunes

- Backend funcional: en `C:\Codigos\sellgeneral-api` corre con
  `dotnet test` (190/190 verde) y `dotnet build` (0 errores).
- App móvil: en `C:\Codigos\nenis-app\nenis_app` corre con `flutter analyze`
  (0 issues) y `flutter build apk --debug`.
- **Cadena de BD:** el backend usa Postgres (Neon). Si todavía no tienes,
  créala en https://neon.tech (gratis) y copia la cadena completa
  (host, db, user, password, ssl). La pones en
  `ConnectionStrings__Default`.

---

## Opción A — Puerto en tu laptop (rápido, solo mismo WiFi)

Útil para desarrollo en el día a día. El móvil se conecta a la IP
local de tu laptop.

### 1. Averigua tu IP local

```powershell
ipconfig
# Busca "Dirección IPv4" en la interfaz WiFi (algo tipo 192.168.1.42)
```

### 2. Abre el puerto 5080 en el firewall de Windows

Solo la primera vez, en PowerShell **como administrador**:

```powershell
New-NetFirewallRule -DisplayName "sellgeneral-api" -Direction Inbound -LocalPort 5080 -Protocol TCP -Action Allow
```

### 3. Arranca el backend

```powershell
cd C:\Codigos\sellgeneral-api
ASPNETCORE_ENVIRONMENT=Development dotnet run
```

Elige el perfil `http` (no `https`) — escucha en `http://localhost:5080`
y queda accesible en `http://192.168.1.42:5080` desde tu WiFi.

Verás logs en vivo del backend. Para parar: `Ctrl+C`.

### 4. Verifica que responde

Desde tu laptop o desde el móvil (mismo WiFi), abre en el navegador:
`http://192.168.1.42:5080/swagger`. Si ves la documentación de los
endpoints, está vivo.

### 5. Compila la app con la URL de tu laptop

```powershell
cd C:\Codigos\nenis-app\nenis_app
flutter build apk --debug --no-pub --dart-define=API_BASE_URL=http://192.168.1.42:5080
```

El APK queda en `build\app\outputs\flutter-apk\app-debug.apk`. Instálalo
en tu móvil (USB o descarga).

### Limitaciones

- El móvil **debe estar en la misma WiFi** que tu laptop. Si cambias de
  red (4G, otra WiFi), la app no se conecta.
- Si reinicias el router o la laptop, la IP puede cambiar; tienes que
  re-compilar con la nueva IP.
- HTTP plano (no HTTPS): algunos features del backend (CORS, cookies
  secure, push web) se comportan distinto que en producción.

---

## Opción B — Render (recomendada para móvil)

El backend se deploya en Render con un click. La app se conecta a la
URL pública (HTTPS) desde cualquier red.

### 1. Verifica que el repo esté en GitHub

Render lee el código desde un repo de GitHub. En nuestro caso el backend
está en `https://github.com/edro280195-afk/sellgeneral-api.git`
(ya pusheado en el commit `d62222a`).

### 2. Crea el Web Service en Render

1. Ve a https://dashboard.render.com
2. Click **New + → Web Service**
3. Selecciona **"Build and deploy from a Git repository"** → conecta
   tu cuenta de GitHub si no lo has hecho
4. Selecciona el repo `sellgeneral-api`
5. Click **Connect**

### 3. Configuración del servicio

| Campo | Valor |
|---|---|
| **Name** | `sellgeneral-api` (o el que prefieras; definirá la URL) |
| **Region** | Oregon (US West) — plan Free disponible |
| **Branch** | `main` |
| **Runtime** | Docker |
| **Plan** | Free |
| **Docker Command** | (dejar vacío; usa el `ENTRYPOINT` del Dockerfile) |

Click **Advanced** y verifica:
- **Dockerfile Path:** `./Dockerfile` (default)
- **Docker Build Context:** `./` (default — usa el directorio raíz del repo)

### 4. Variables de entorno (Environment → Environment Variables)

Crea las env vars. Render usa la convención de ASP.NET Core: `__`
(doble guion bajo) para jerarquía. **Las que SÍ importan** para que la
app funcione end-to-end (el resto puede quedar vacío hasta que actives
features específicas):

| Env var | Requerida? | Valor de ejemplo | Notas |
|---|---|---|---|
| `ASPNETCORE_ENVIRONMENT` | Sí | `Production` | `Production` NO corre el seeder de demo. Si quieres datos demo, usa `Development`. |
| `ConnectionStrings__Default` | Sí | `Host=ep-xxxx.us-east-1.aws.neon.tech;Database=neondb;Username=neondb_owner;Password=TU_PASSWORD;SSL Mode=Require;Trust Server Certificate=true` | Cadena completa de Neon. La sacas del dashboard de Neon → Connection Details. |
| `Jwt__Key` | Sí | una cadena aleatoria de 64+ chars | Genera con `openssl rand -base64 48`. Si usas la misma entre deploys, los tokens viejos siguen siendo válidos. |
| `Auth__DevOtpCode` | Recomendada | `000000` | El código OTP que acepta la app sin Twilio. Default ya es 000000. |

**Las que puedes dejar vacías** (la app funciona, pero algunos features
no будут disponibles):

| Env var | Servicio | Qué pasa si falta |
|---|---|---|
| `VapidDetails__PublicKey` + `PrivateKey` + `Subject` | Web Push (notificaciones en el navegador) | Las push web no se envían. La app móvil usa FCM, no VAPID. |
| `Gemini__ApiKey` | Cami (asistente IA) | Cami no responde. |
| `Google__GeocodingApiKey` | Geocodificación de direcciones | Las direcciones se guardan sin geocodificar. |
| `Cloudinary__CloudName` + `ApiKey` + `ApiSecret` | Upload de imágenes | Los productos y avatares no suben imágenes. |
| `OpenAI__ApiKey` | Transcripción de lives | Los lives no se transcriben. |
| `CloudflareR2__*` | Almacenamiento de videos de live | Los videos no se guardan. |
| `MercadoPago__AccessToken` + `PublicKey` | Pagos con tarjeta del cliente | El endpoint `/api/pedido/{token}/payment/card` falla. La app usa `Method="Efectivo"` por default. |
| `Platform__MercadoPago__*` | Pagos de suscripción | El panel admin no puede cobrar. |
| `App__FrontendUrl` | CORS / links en emails | Default `https://regibazar.com`. Cámbialo si tu frontend está en otro dominio. |

### 5. Crear el servicio

Click **Create Web Service**. Render:
1. Hace `git clone` del repo
2. Compila el Dockerfile (instala .NET SDK, restaura paquetes, hace
   `dotnet publish`, instala ffmpeg + tesseract + yt-dlp)
3. Arranca el contenedor
4. Te asigna una URL tipo `https://sellgeneral-api-xxxx.onrender.com`

**Tiempo:** ~5-10 min en el primer build. Builds subsecuentes son
más rápidos.

### 6. Verifica que está vivo

Desde tu navegador:
- `https://sellgeneral-api-xxxx.onrender.com/swagger` → ves los
  endpoints
- `https://sellgeneral-api-xxxx.onrender.com/api/me/home` → ves 401
  (esperado, sin token)

### 7. Compila la app con la URL de Render

```powershell
cd C:\Codigos\nenis-app\nenis_app
flutter build apk --debug --no-pub --dart-define=API_BASE_URL=https://sellgeneral-api-xxxx.onrender.com
```

APK en `build\app\outputs\flutter-apk\app-debug.apk`. Instala en tu
móvil.

### Notas sobre Render Free

- **Cold start:** si nadie usa la app por 15 min, Render apaga el
  contenedor. El próximo hit tarda ~30-60s en despertar (verás el
  splash con spinner mientras arranca).
- **750 horas/mes de uptime** — suficiente para desarrollo, no para
  producción.
- **Logs:** visibles en el dashboard de Render (Logs → Logs).
- **Redeploy:** automático con cada push a `main` del repo del backend.

---

## Smoke test end-to-end

Una vez que el backend está vivo (laptop o Render), valida este flujo:

| Paso | Endpoint / Acción | Resultado esperado |
|---|---|---|
| 1 | Abre la app | Splash → Login |
| 2 | Login con tu teléfono real | Te manda OTP (código `000000` en dev) |
| 3 | `POST /api/auth/phone/verify` con código `000000` | Devuelve token JWT + accountId |
| 4 | El router te manda a `/claim` (porque no tienes Client asociado) | Ves la pantalla de selección de tiendas |
| 5 | Selecciona una tienda | Te crea el Client y te manda a `/home` |
| 6 | Ves el home con datos | Si la BD tiene datos, ves pedidos/tandas/sorteos. Si no, ves empty states. |
| 7 | Tap en una tienda → `/store/{id}` | Ves los 4 tabs (Productos/Lives/Tandas/Sorteos) |
| 8 | Tap en `+` de un producto → `/reserve/{businessId}/{productId}` | Modal de éxito + navega a `/tracking/{id}?token=...` |
| 9 | Ves el rastreo con mapa | El placeholder muestra tienda/driver/casa |

Si algo falla, abre los logs del backend (consola en laptop, o
dashboard de Render) y revisa qué excepción tira.

---

## Comandos útiles

### Generar una `Jwt__Key` segura (PowerShell)

```powershell
$bytes = New-Object byte[] 48
(New-Object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes($bytes)
[Convert]::ToBase64String($bytes)
```

### Ver las env vars cargadas por el backend (debug)

Agrega este endpoint temporal al `BuyerController` para debug:

```csharp
[HttpGet("/api/me/_debug-env")]
public IActionResult DebugEnv()
{
    var jwt = HttpContext.RequestServices
        .GetRequiredService<IConfiguration>()["Jwt:Key"];
    var conn = HttpContext.RequestServices
        .GetRequiredService<IConfiguration>()["ConnectionStrings:Default"];
    return Ok(new { jwtLength = jwt?.Length ?? 0, conn = conn });
}
```

(Recuérdalo quitar después.)

### Probar el backend desde PowerShell con curl

```powershell
# Health check:
curl https://sellgeneral-api-xxxx.onrender.com/swagger/v1/swagger.json

# Login:
curl -X POST https://sellgeneral-api-xxxx.onrender.com/api/auth/phone/verify `
  -H "Content-Type: application/json" `
  -d '{"phone":"8681452290","code":"000000"}'
```

---

## Troubleshooting

| Síntoma | Causa probable | Fix |
|---|---|---|
| App muestra "No pudimos cargar..." en todas las pantallas | `API_BASE_URL` mal configurado o backend no reachable | Verifica con `curl` desde el navegador. |
| 404 al login con un teléfono real | El endpoint requiere `Content-Type: application/json` | Verifica con `curl` que devuelve 200 con un teléfono válido. |
| Login funciona pero `/home` devuelve 401 | El token JWT no se está enviando | El interceptor de Dio en `lib/core/api/dio_provider.dart` lo inyecta automáticamente. Verifica que `authControllerProvider` tenga la sesión. |
| Cold start de Render tarda mucho (>30s) | Plan Free duerme tras 15 min sin uso | Es normal, espera. El primer hit lo despierta. |
| Backend crashea con "Unable to connect to the database" | `ConnectionStrings__Default` mal copiada | Verifica que el string sea exactamente el de Neon. |
| `JWT__Key` cambia en cada deploy y los tokens viejos dejan de ser válidos | Normal | Usa la misma key en todos los deploys (o avisa a los usuarios que vuelvan a login). |
| 401 desde el backend con `WWW-Authenticate: Bearer error="invalid_token"` | El token expiró (default 7 días) o la `Jwt__Key` cambió | Cierra sesión y vuelve a login. |

---

## Resumen rápido

**Si quieres probar YA (5 min):**

```powershell
# Terminal 1: backend
cd C:\Codigos\sellgeneral-api
ASPNETCORE_ENVIRONMENT=Development dotnet run

# Terminal 2: app con la IP de tu laptop
cd C:\Codigos\nenis-app\nenis_app
flutter build apk --debug --no-pub --dart-define=API_BASE_URL=http://<tu-ip-local>:5080
```

**Si quieres probar de verdad en el móvil (15 min):**

1. Sube el backend a Render con el `Dockerfile` del repo
2. Ponle `ASPNETCORE_ENVIRONMENT=Development` + `ConnectionStrings__Default` + `Jwt__Key` + `Auth__DevOtpCode=000000`
3. Espera a que Render te dé la URL `https://sellgeneral-api-xxxx.onrender.com`
4. Compila la app con `--dart-define=API_BASE_URL=https://sellgeneral-api-xxxx.onrender.com`
5. Instala el APK en tu móvil
6. Login con tu teléfono real + código `000000` → claim una tienda → home
