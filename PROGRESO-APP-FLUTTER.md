# Progreso — App Flutter Neni's App (compradora + vendedora)

> Actualizado: 2026-07-27 (auditoría + Tandas + autenticación + orden estable de Rutas). Doc para **retomar la construcción** sin re-descubrir.
> Brief original: `PROMPT-APP-FLUTTER.md` (mismo folder) — **ojo:** ese doc describe el arranque de la Fase 2 (jun/2026) y su sección "App = compradora (no la vendedora)" ya **no** refleja la realidad; ver corrección abajo.
> Proyecto Flutter: `nenis-app\nenis_app` dentro del bundle (hoy `C:\Codigos\nenis-bundle\nenis-app\nenis_app`). Backend: `nenis-bundle\sellgeneral-api`. Las rutas viejas `C:\Codigos\nenis-app\` / `C:\Codigos\sellgeneral-api\` (sin `nenis-bundle`) que aparecen más abajo en este doc son de antes del bundle — ajustar mentalmente si ya no existen sueltas.
> **Antes de confiar en las tablas de "Pendiente" de este doc, cruzar contra `git log --oneline --stat` desde la fecha de arriba** — se ha encontrado más de una vez trabajo real ya hecho (a veces semanas) que este doc seguía listando como pendiente. Ver nota en `docs/AUDITORIA-PANTALLAS.md`.

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

## 🆕 Sesión 2026-07-27 — auditoría completa + Live Nivel 2 ya estaba construido

Se pidió "qué falta y arréglalo todo, sin dejar nada a medias". Antes de
arrancar se cruzó este doc contra `git log` y aparecieron dos sorpresas:

- **El "Nivel 2" de Live (línea 47 vieja, "sin construir todavía") ya
  estaba completo de punta a punta** desde el mismo 2026-07-09 — backend
  (`Hubs/LiveHub.cs`: `JoinAdminLive`/`AnnounceProduct`/`JoinLive`, mapeado
  en `/hubs/live`) y Flutter (`SellerLiveScreen`, `live_screen.dart` ya
  NO era placeholder). Este doc simplemente no se actualizó ese mismo día.
  Se auditó lo ya construido y se arreglaron bugs reales (ver
  `docs/AUDITORIA-PANTALLAS.md`, sección SellerLiveScreen).
- Un módulo completo de **Etiquetas + Inventario con NFC**
  (`features/inventory/`, `features/labels/`, ~6,200 líneas, commit
  `472c322` "Integracion de etiquetas", 2026-07-22) no aparecía en este doc
  ni como hecho ni como pendiente. No se auditó a fondo esta sesión — es
  candidato a auditoría propia si hace falta.

Trabajo de esta sesión (detalle completo en `docs/AUDITORIA-PANTALLAS.md`,
sección "✅ Completados (sesión 2026-07-27)"): auditadas y arregladas
**todas** las pantallas que quedaban pendientes en ese doc — Rutas,
Clientas, Live (vendedora+compradora), Cuenta+Settings, las 4 secundarias
de vendedora, y las 15 de compradora. 32 archivos (22 Flutter + 10
backend). Highlights de lo encontrado y arreglado:

- 🔴 **Doble cobro real en Tandas** — "Registrar pago" sin guard anti
  doble-tap en ninguna capa; arreglado en Flutter y backend.
- 🔴 **Resorteo peligroso en Tandas** — ya no permite cambiar aleatoriamente
  todos los turnos después de registrar el primer pago o entrega. Flutter
  deshabilita la acción y el backend aplica la regla aunque se llame directo.
- 🟡 **Recuperación/Facebook** — el OTP usa códigos de error estructurados y
  limpia banners obsoletos; los conflictos 409 terminales de Facebook ya no
  dejan a la usuaria atrapada en un formulario que nunca puede resolverlos.
- 🔴 **Fuga de chat entre clientas** en `TrackingScreen` (backend, endpoint
  anónimo) — el filtro devolvía también chat de otras clientas en la misma
  ruta y chat interno chofer↔admin a cualquiera con un solo token de pedido.
- 🔴 **Direcciones: no se podía borrar el pin GPS guardado** — mostraba
  éxito falso mientras el chofer seguía navegando al lugar viejo.
- 🔴 `DeliveryUpdate` de SignalR nunca llegaba a `TrackingScreen` (mismatch
  de argumentos) — los cambios de estado en vivo solo se veían con
  pull-to-refresh manual.
- 🔴 Condición de carrera real en cuentas de cobro (dos cuentas podían
  quedar marcadas "principal" a la vez) — candado en proceso por
  `BusinessId`, mismo patrón que `BuyerReserveService`.
- Varios `setState`/`ref.invalidate` sin guard `mounted` tras `await`
  (mismo patrón B1/B2 ya conocido) repetidos en Rutas, Clientas, Novedades.
- Lista completa de lo NO arreglado a propósito (ambigüedad de producto o
  bajo impacto) en `docs/AUDITORIA-PANTALLAS.md`, sección "🔲 Pendientes".

Verificado al cierre: `flutter analyze lib` → 0 issues. `dotnet test` →
302/302 verde.

**Lección de la sesión:** un primer intento de arreglar la condición de
carrera de cuentas de cobro usó una transacción real +
`pg_advisory_xact_lock` de Postgres — rompió 3 tests existentes porque la
suite corre contra `UseInMemoryDatabase`, que no soporta transacciones. Se
corrigió al patrón que ya usa `BuyerReserveService` (candado `SemaphoreSlim`
en proceso). Para este tipo de fix, correr `dotnet test` (no solo
`dotnet build`) antes de darlo por bueno.

## ✅ Hecho y validado — histórico hasta 2026-06-29 (turno 10)

> Detalle técnico línea por línea de los bloques ①–⑱ originales de la Fase 2 (home, pedidos, puntos, tandas, sorteos, tienda, apartado, notificaciones, pagos, direcciones). Sigue siendo preciso para esas pantallas; no se repite aquí, ver el historial de este archivo o el código directamente en `lib/features/{home,orders,points,tandas,raffles,store,reserve,notifications,payments,addresses}/`.

## ⛏️ Pendiente (lo que falta)

Lista corta a propósito — el detalle completo (con `file:line`) de todo lo
encontrado-pero-no-arreglado el 2026-07-27 vive en
`docs/AUDITORIA-PANTALLAS.md`, sección "🔲 Pendientes".

| Pantalla / pieza | Estado |
|---|---|
| **Publicar la app de Meta** | Genuinamente pendiente, requiere acción manual de Eduardo — ver sección abajo, sin cambios desde 2026-07-09. |
| **StoreScreen: storefront público** | El link de "compartir tienda" es un callejón sin salida (404) para quien no es ya clienta/seguidora — ¿es intencional o falta un flujo de "seguir desde cero"? Decisión de producto, no bug. |
| **Points/RafflesScreen sin guard `isSeller`** | Únicas pantallas compartidas compradora/vendedora sin el guard que sí tienen Home/Tandas/Account — alcanzable si una vendedora abre el link público de su propia tienda. Confirmar si falta o es a propósito. |
| **Multi-dirección (`ClientAddress` con FK a `Client`)** | Confirmado (2026-07-27): es decisión deliberada, documentada en el propio código (`BuyerAddressService.cs`) — 1 dirección por `Client` a propósito, con comentario explícito de cómo extenderlo si algún día se necesita. No es un pendiente real salvo que se decida que sí se quiere la feature. |
| **Pipeline de Live Capture (`LiveSession`/`LiveCaptureService`)** | **Ya no existe** — se borró de raíz en la migración `DropLiveCapturePipeline` (2026-07-09), junto con el `ViewerCount` hardcodeado que dependía de él. Nada que hacer aquí. |

### Live en tiempo real ("Nivel 2") — YA CONSTRUIDO, no es un pendiente

Corrección 2026-07-27: esta sección decía "diseño acordado, sin construir
todavía". **Ya estaba construido desde el 2026-07-09**, el mismo día que se
escribió esa frase — nunca se tachó. Lo que describía como plan ya es
código real y auditado:

1. La vendedora transmite en Facebook como siempre — la app no toca el video para nada. ✅
2. `/seller/live` (`SellerLiveScreen`) anuncia con un toque qué producto está mostrando. ✅
3. `Hubs/LiveHub.cs` (`AnnounceProduct`) empuja el evento `ProductAnnounced` a las compradoras conectadas que siguen la tienda. ✅
4. `live_screen.dart` (ya NO es placeholder) muestra el producto y aparta con un toque vía `POST /api/me/reserve`. ✅
5. El candado de stock (`BuyerReserveService.ReserveAsync`) **ya tenía** un `SemaphoreSlim` por producto + conteo de "apartado" pendiente desde el mismo commit de seguridad del 2026-07-08 (`5afb82a`) — cubre bien el despliegue de una sola instancia (Render hoy). Si algún día se corre en varias instancias a la vez, ese candado deja de alcanzar por sí solo y sí haría falta el update atómico en BD (ver reporte crítico en la sesión 2026-07-27).

Bugs reales encontrados el 2026-07-27 en lo ya construido (arreglados):
`isLiveNow` no se refrescaba con el evento SignalR (la clienta se quedaba
viendo "no está en vivo" aunque llegaran productos reales), la vendedora
perdía de vista el último producto anunciado al reentrar a la pantalla, y
`JoinAdminLive`/`AnnounceProduct` fallaban en silencio para vendedoras con
más de una tienda. Detalle en `docs/AUDITORIA-PANTALLAS.md`.

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
La auditoría base del 2026-07-27 quedó publicada en `main`: app `1ec8acf` y
backend `18d7ea4`. Después se publicaron la protección del sorteo de Tandas,
el endurecimiento de autenticación y la creación de Rutas respetando
exactamente el orden previsualizado. La agrupación visual de candidatas usa
ahora `clientId`, no texto mutable. Verificación actual:
`flutter analyze lib test` sin hallazgos, 84/84 pruebas Flutter, 308/308
pruebas de API y 18/18 pruebas del migrador.
