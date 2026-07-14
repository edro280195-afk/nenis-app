# Progreso — App Flutter Neni's App (compradora + vendedora)

> Actualizado: 2026-07-09 (sesión de integración con Facebook). Doc para **retomar la construcción** sin re-descubrir.
> Brief original: `PROMPT-APP-FLUTTER.md` (mismo folder) — **ojo:** ese doc describe el arranque de la Fase 2 (jun/2026) y su sección "App = compradora (no la vendedora)" ya **no** refleja la realidad; ver corrección abajo.
> Proyecto Flutter: `C:\Codigos\nenis-app\nenis_app`. Backend: `C:\Codigos\sellgeneral-api`.

## Cómo retomar (resumen de 1 minuto)

- **Ya no es solo la app de la compradora.** Sigue siendo multi-tenant (un `Account` global le compra a muchas tiendas), pero desde julio/2026 la misma app Flutter también sirve a la **vendedora**: hay una familia completa de rutas `/routes`, `/clients`, `/seller/settings` (+ `profile`/`payments`/`team`/`preferences`), `/seller/plan` (+ checkout de suscripción con Mercado Pago), `/seller/updates`, `/seller/vip`, todas gateadas por `session.hasMembership` en `app_router.dart`. La compradora sigue usando el patrón cross-tenant por `AccountId` sin membership; la vendedora usa el patrón estándar de membership + `X-Business-Id` (igual que el panel Angular).
- Método: **full-stack pantalla por pantalla**. Cada bloque: backend → `dotnet build` + `dotnet test` verde; Flutter → `flutter analyze` 0 issues.
- Los **mockups son solo inspiración** (colores/tipografía/layout/componentes). **NUNCA** clonar el chrome del teléfono. Usar `SafeArea` + chrome real del OS.
- Lealtad se llama **"Puntos"**. Logo de la app: **ya existe** (`assets/branding/nenis-app-icon.png`, ya subido también en el dashboard de Meta).
- Login: teléfono+contraseña (con confirmación por WhatsApp) es el camino principal; SMS real vía **Twilio Verify** en producción (código DEV `000000` sigue disponible en `Development`); **Facebook Login** código-completo en backend y Flutter (clientas y vendedoras, incluye "limited login" de iOS con JWKS) — solo le falta el `Facebook:AppSecret` en producción y publicar la app de Meta (ver `live-tiempo-real-facebook` en memoria, o la sección de abajo).

## 🆕 Lo que pasó entre el 2026-06-29 y el 2026-07-09 (no estaba documentado)

Diez días con mucho movimiento en ambos repos (27 commits backend, 26 Flutter) que el resto de este doc — escrito turno a turno hasta el 29 de junio — no alcanzó a registrar. Resumen a nivel de feature (para detalle línea por línea, ver el código directamente; esto no es una relectura exhaustiva commit por commit):

- **Login/registro rediseñado por completo**: teléfono + contraseña como camino principal (ya no solo OTP), confirmación por WhatsApp, unificación de validaciones y mensajes, restablecimiento de contraseña seguro por WhatsApp, **refresh tokens para todas las cuentas** (la sesión ya no fuerza re-autenticación), términos y condiciones aceptados en el registro (`lib/core/legal/legal_config.dart` + `AddAccountLegalAcceptance`). SMS real conectado con **Twilio Verify**.
- **Facebook Login (clientas y vendedoras)**: `AuthController.FacebookLogin` + `CompleteFacebookProfile` en el backend, manejan token clásico *y* el "limited login" de iOS (verificación JWKS), ligan `Account.FacebookUserId`, distinguen `FacebookAccountType.client`/`.seller`. En Flutter, `login_screen.dart` ya llama a `FacebookAuth.instance.login()` de verdad. Pendiente solo config (ver sección de Meta más abajo).
- **Suscripciones de la plataforma**: integración completa de plan de pagos vía Mercado Pago — `MyPlanScreen` (`/seller/plan`) + checkout (`/seller/plan/checkout`, `MpCheckoutWebViewScreen`).
- **Modo vendedora en Flutter** (la corrección grande a este doc): `SellerRoutesScreen`, `SellerClientsScreen`, `SellerSettingsScreen` + sub-pantallas (perfil de tienda, pagos, equipo, preferencias), todas ya enrutadas y gateadas por membership.
- **Comunidad de tienda** (nuevo, backend + Flutter):
  - `LiveAnnouncement` — "estoy en vivo ahora": la vendedora prende una bandera con un toque al empezar a transmitir (TTL 3h), dispara push a sus seguidoras. **Distinto** de `LiveSession` (el pipeline viejo de transcripción, ver abajo).
  - `StoreFollower` — seguir una tienda sin haber comprado nunca; preferencias de aviso (`NotifyOnPost`/`NotifyOnLive`) y marca **VIP** manual (`IsVip`/`VipSince`) — el equivalente adentro de la app a un "grupo VIP" de Facebook. Pantalla de gestión: `/seller/vip`.
  - `StorePost` — novedades tipo muro (texto + foto opcional), con compuerta `IsVipOnly`. Pantalla de gestión: `/seller/updates`.
  - `Business.FacebookUrl` / `Business.MessengerUrl` — enlaces de contacto de la tienda. **Cableados hoy (2026-07-09)** hasta `/api/me/store/{id}` y hasta `store_screen.dart` (el botón "Ver en Facebook" del banner "en vivo ahora" ya abre el link real en vez de un toast).
- **Compartir tienda + reseñas**: universal link `/store/{id}` para compartir, `OrderRating` (promedio + conteo) como señal de confianza en la ficha de tienda.
- **Cliente ↔ Facebook**: `Client.FacebookProfileUrl` + importación masiva (`FacebookImportRow`/`FacebookImportPreviewResponse`) con matching difuso contra clientas existentes, para cuando la vendedora pega su lista de contactos de Facebook.
- **Fase E + F + login passwordless general**: herramientas completas de la clienta sobre `TrackingScreen` (confirmar pedido, chat con repartidor en vivo vía SignalR, instrucciones de entrega editables, sección de Puntos, resumen de pago con tarjeta "en revisión"), más lo necesario para publicar (Install Referrer, Universal Links/App Links, Smart App Banner, tabla `LinkEvents`) y login passwordless general fuera del flujo de reclamar pedido. Detalle completo en `docs/superpowers/plans/2026-07-07-fase-e-f-passwordless.md`.
- **Correcciones severas a vulnerabilidad y malas prácticas** (commit `5afb82a` en el backend) — revisar ese commit si hace falta contexto de seguridad específico; no se detalla aquí porque no se re-auditó en esta sesión.
- Todo esto **ya está commiteado en `main` en ambos repos** — ver "Estado git" abajo (la sección vieja que decía "sin commitear" quedó obsoleta).

## ✅ Hecho y validado — histórico hasta 2026-06-29 (turno 10)

> Detalle técnico línea por línea de los bloques ①–⑱ originales de la Fase 2 (home, pedidos, puntos, tandas, sorteos, tienda, apartado, notificaciones, pagos, direcciones). Sigue siendo preciso para esas pantallas; no se repite aquí, ver el historial de este archivo o el código directamente en `lib/features/{home,orders,points,tandas,raffles,store,reserve,notifications,payments,addresses}/`.

## ⛏️ Pendiente (lo que falta)

| Pantalla / pieza | Estado |
|---|---|
| **⑧ Live shopping (viewer real de la clienta)** | Sigue en placeholder honesto ("en construcción") en `live_screen.dart`. **Ahora tiene plan concreto** — ver "Nivel 2" abajo: no va a ser el viewer que procesa video de Facebook, va a ser un feed en tiempo real de "producto anunciado ahora" vía SignalR. |
| **Multi-dirección (`ClientAddress` con FK a `Client`)** | No confirmado si sigue pendiente — el modelo de direcciones que vi sigue siendo 1 dirección por `Client`. Verificar antes de asumir. |
| **`LiveSession.Live.ViewerCount`** | Sigue hardcodeado a `0` en `BuyerStoreService` (comentario propio en el código: "no hay modelo de viewerCount todavía"). Distinto de `IsLiveNow`, que sí es real desde `LiveAnnouncement`. |
| **Pipeline de Live Capture (`LiveSession`/`LiveCaptureService`, transcripción con Whisper + Gemini + OCR de comentarios vía `yt-dlp`)** | **Descartado.** Eduardo lo probó en producción con Regi Bazar y no funciona en la práctica (flujo inconsistente de las vendedoras al transmitir, nombres de clientas casi imposibles de transcribir bien). Sale del proyecto **junto con** el build del Nivel 2 (no antes, no aparte). Ver memoria `live-capture-transcripcion-descartada`. |

### Nivel 2 acordado — Live en tiempo real (reemplaza el pipeline de arriba)

Diseño ya acordado con Eduardo (2026-07-09), sin construir todavía:
1. La vendedora transmite en Facebook como siempre — la app no toca el video para nada.
2. Desde una pantalla nueva en la familia `/seller/*` (ej. `/seller/live`, mismo patrón que `/seller/vip` o `/seller/updates`), anuncia con un toque qué producto está mostrando ahora.
3. Eso dispara un evento por un `LiveHub` nuevo (mismo molde que `DeliveryHub`/`TrackingHub`/`OrderHub`/`LogisticsHub`/`PosHub`, todos `TenantAwareHubBase`) a las compradoras conectadas que siguen la tienda.
4. La clienta ve el producto anunciado en `live_screen.dart` (hoy placeholder) y aparta con un toque — reusa `POST /api/me/reserve`, que **ya existe completo**, no hay que crear nada nuevo ahí.
5. Antes de exponer esto a ráfagas reales de "apartar" simultáneo: `BuyerReserveService.ReserveAsync` hoy valida stock con una lectura `AsNoTracking` sin bloqueo — no decrementa nada hasta el pago en POS. Hay que endurecerlo (update atómico de stock) para que no se sobrevenda cuando varias clientas tocan "Apartar" sobre el mismo producto casi al mismo tiempo.

### Publicar la app de Meta (en progreso, 2026-07-09)

App `1427323549158529`, sigue en modo Desarrollo ("Sin publicar"). Ya confirmado en el dashboard: dominio `nenisapp.com`, ícono, categoría "Compras", y las 3 URLs legales (privacy/terms/deletion, todas verificadas cargando de verdad). Falta:
- Copiar el **App Secret** (visible en el dashboard, "Mostrar") al backend — **no vive ahí solo por estar en el dashboard**, hay que ponerlo en `sellgeneral-api`: local vía `dotnet user-secrets set "Facebook:AppSecret" "..."`, producción vía variable de entorno `Facebook__AppSecret` en Render.
- Confirmar si Meta pide **Business Verification** al intentar activar el switch (el dashboard lo dice explícitamente si aplica).
- Solo se piden permisos `public_profile` + `email` (default de Meta) → no hay cola de App Review manual.

## Cómo correr / validar
- Backend dev: en `C:\Codigos\sellgeneral-api` → `ASPNETCORE_ENVIRONMENT=Development dotnet run` (escucha en `:5080`). Requiere `appsettings.Development.json` (gitignored, connection string real).
- Tests backend: `dotnet test Tests\EntregasApi.Tests\EntregasApi.Tests.csproj` (si falla la copia de `runtimeconfig`, primero `dotnet build` del test project y luego `dotnet test --no-build`). Se puede acotar con `--filter "FullyQualifiedName~NombreDeLaClase"`.
- Flutter: en `C:\Codigos\nenis-app\nenis_app` → `flutter analyze lib` y `flutter run` (emulador). Override de URL: `--dart-define=API_BASE_URL=http://host:puerto`.

## Decisiones tomadas (no re-litigar)
- Estética bloqueada (tema por tienda; tokens en `mockups/styles.css`); "Puntos"; login sin ilustración.
- **Corregido 2026-07-09:** la app Flutter ya NO es solo compradora. La compradora sigue siendo cross-tenant por `AccountId` con `IgnoreQueryFilters` + scoping explícito (patrón `BuyerFeedService`/`ClientClaimService`), auth `[Authorize]` con JWT (sub=AccountId), sin membership ni `X-Business-Id` — **eso sigue siendo cierto solo para las pantallas de compradora** (`/home`, `/store`, `/orders`, `/points`, etc.). La vendedora, dentro de la misma app, usa el patrón estándar de membership + `X-Business-Id`, igual que el panel Angular.
- El "Live shopping" **no** va a basarse en procesar el video de Facebook (transcripción/OCR) — ver Nivel 2 arriba y memoria `live-tiempo-real-facebook`.
- Mockups = inspiración, NO clonar chrome de teléfono.

## Estado git
Todo commiteado en `main` en ambos repos al 2026-07-09 (últimos: `071db75`/`Compartir tienda y reseñas...` en backend, `Compartir tienda, preferencias de notificación y calificación` en Flutter). La sección vieja de este doc que listaba archivos "sin commitear" del turno 10 quedó obsoleta — todo ese trabajo ya está en `main` desde hace días.
