# Kit de arranque — App Flutter de la compradora (Neni's App · Fase 2)

> Pega esto como primer mensaje en una sesión nueva de Claude Code (de preferencia con el directorio en `C:\Codigos\nenis-app`). Es autocontenido.

> **⚠️ Doc histórico (kickoff de la Fase 2, jun/2026).** Para el estado real y actual del proyecto —incluyendo que la app ya NO es solo compradora, ver la corrección en "Decisiones ya tomadas" abajo— usa `PROGRESO-APP-FLUTTER.md` (mismo folder). Este archivo se conserva como registro del arranque original; los Bloques 1–4+, los tokens de diseño y el método de trabajo siguen siendo válidos, pero el contexto de negocio de arriba ya avanzó bastante desde que se escribió.

---

## Contexto (léelo una vez, no asumas)

Vamos a construir la **app nativa de la CLIENTA / compradora** de **Neni's App** en **Flutter** (iOS + Android). Es la **Fase 2** del plan SaaS multi-tenant; el backend y el panel web ya están hechos.

- **Modelo multi-tenant:** un `Account` global (la persona) le compra a **muchas tiendas** (`Business`); el rol vive en `Membership`. La compradora rastrea pedidos, **reclama su perfil** con cada vendedora, junta **Puntos**, y entra a lives, tandas y sorteos. Una sola app, pero **cada tienda viste su espacio con su propia marca**.
- **Repos (NO tocar los originales `regibazar-web` ni `api/EntregasApi`, están congelados):**
  - Backend: `C:\Codigos\sellgeneral-api` (.NET 8 / EF Core 8 / PostgreSQL Neon / SignalR). **Ya en `main`**: Fase 0 (tenancy: Account/Business/Membership, middleware por tenant, hubs aislados), Fase 1 (entitlements, planes, Mercado Pago) y FE-0 (marca por tienda). Detalle en `C:\Codigos\sellgeneral-api\PROGRESO.md` y `ROLYCONTEXTO.md`.
  - Panel web admin (vendedora): `C:\Codigos\sellgeneral` (Angular 21). Ya tiene FE-0..FE-5.
- **Mockups aprobados = SPEC VISUAL EXACTO:** `C:\Codigos\nenis-app\mockups\`. `styles.css` es el sistema de diseño; hay un `.html` por pantalla. **Abre cada `.html` y replícalo fielmente en Flutter** (puedes servir la carpeta con `python -m http.server 4319 --directory C:/Codigos/nenis-app/mockups` y verlos en el navegador).

## Decisiones ya tomadas (no las re-litigues)

- ~~App = **compradora** (no la vendedora, no el conductor)~~ — **superado.** Desde julio/2026 la misma app Flutter también tiene una superficie completa de vendedora (`/routes`, `/clients`, `/seller/settings`, `/seller/plan`, `/seller/updates`, `/seller/vip`, etc.), gateada por `session.hasMembership`. Detalle en `PROGRESO-APP-FLUTTER.md`. Sigue siendo cierto que no hay app de conductor aparte.
- **Estética bloqueada** para toda la app (tokens más abajo). **Tema por tienda** obligatorio.
- Lealtad se llama **"Puntos"** (nunca "RegiPuntos").
- Login **sin ilustración** (versión limpia aprobada). **Logo: ya existe** (`assets/branding/nenis-app-icon.png`).
- Copy de UI en **español** (sentence case, cálido); nombres de código en **inglés**.

---

## Bloque 1 — Arranque del proyecto Flutter

1. Crea el proyecto Flutter en `C:\Codigos\nenis-app` (raíz; deja la carpeta `mockups\` adentro como referencia de diseño). Org sugerida `com.nenisapp`, soporte **iOS + Android**. Inícialo como **repo git nuevo** (`git init`) con `.gitignore` de Flutter; remoto a confirmar con Eduardo.
2. Estructura: `lib/core/` (theme, api, auth, router, utils), `lib/features/` (auth, home, store, live, orders, tracking, points, tandas, raffles, account), `lib/shared/` (widgets reutilizables), `assets/`.
3. Dependencias recomendadas: **flutter_riverpod** (estado), **go_router** (navegación), **dio** (HTTP), **flutter_secure_storage** (JWT), **google_fonts** (Poppins), **material_symbols_icons** (íconos redondeados, = a los mockups), **cached_network_image**, **google_maps_flutter** (rastreo), **signalr_netcore** (tiempo real GPS/live), **intl** (es-MX). Confirma versiones vigentes antes de fijarlas.
4. Configura `MaterialApp.router` con un `ThemeData` base temado (Bloque 2) y una pantalla placeholder.

**── ALTO Y VALIDA ──** `flutter analyze` sin issues; `flutter run` levanta en un emulador iOS o Android y muestra la pantalla placeholder con el tema. Resume y espera OK.

## Bloque 2 — Sistema de diseño en Dart (traduce `styles.css`)

Convierte los tokens del mockup a un design-system Dart reutilizable:

1. `AppColors`, `AppTextStyles` (Poppins, pesos 400/500/600/700), `AppRadii`, `AppShadows` — con los valores de la tabla de tokens de abajo.
2. Widgets compartidos fieles a `styles.css`: botón pill (`btn-primary` / `btn-brand` / `btn-ghost` / `btn-fb`), chip de estado (`chip--pend/route/deliv`), tarjeta glass (`glass`), bottom nav flotante de glass, avatar/badge de tienda, celda OTP, campo de texto, segmented.
3. **Tema por tienda (clave):** un `BrandTheme` (Riverpod provider) que toma el `brandPrimaryColor` de la **tienda activa** y re-tematiza en runtime los elementos "de marca" (igual que el `ThemeService` de FE-5 en Angular). El shell Neni's usa el acento `--neni`; al entrar a una tienda, los acentos cambian a su color (Regi Bazar = `#FF0072`).

**── ALTO Y VALIDA ──** Una pantalla de catálogo de componentes (style gallery) que muestre botones, chips, cards y el cambio de tema por tienda en vivo. Compara contra `mockups/home.html` y `mockups/tienda.html`.

## Bloque 3 — Capa de datos + autenticación

1. Cliente API (`dio`) hacia `sellgeneral-api`, base URL configurable (dev: el backend corre en `http://localhost:5080`; prod: la URL de Render). Interceptor que añade `Authorization: Bearer <jwt>` y `X-Business-Id: <activeBusinessId>` en `/api/**`, y que **omite** las rutas públicas por token.
2. Auth sobre `Account`: teléfono **OTP** (camino principal; **modo DEV acepta código `000000`** mientras no haya SMS real), **Facebook**, y correo legacy ("acceso de equipo"). Guarda en secure storage: JWT (`sub = AccountId`), `displayName`, `memberships [{businessId, businessName, role}]`, `activeBusinessId`.
3. **Reclamar perfil** (backend 0.3, `ClientClaimController`): fan-out por teléfono y/o por token de pedido. Nunca enlazar sin prueba.
4. **Patrón repositorio mockable:** cada feature consume un repository con interfaz; implementación real contra la API donde el endpoint exista, y un **mock con datos de ejemplo** donde el endpoint de comprador **aún no exista** (ver caveat de endpoints abajo). Así la UI avanza sin bloquearse; luego cableamos lo real.

**── ALTO Y VALIDA ──** Flujo real contra el backend dev: OTP modo DEV deja entrar; `GET /api/business/me` responde; si el Account no tiene memberships → a Reclamar/Home según corresponda. Resume y espera OK.

## Bloques 4+ — Pantallas (una por bloque, fieles al mockup)

Construye en este orden. **Cada pantalla = abre su `.html` y replícala** (las 7 con ✓ ya tienen mockup exacto; las demás, derívalas del mismo lenguaje).

**A · Identidad** ① Splash · ② Bienvenida · ③ Acceso ✓`acceso.html` · ④ OTP ✓`otp.html` · ⑤ Reclamar perfil ✓`reclamar.html`
**B · Núcleo** ⑥ Home ✓`home.html` · ⑦ Tienda ✓`tienda.html` · ⑧ Live shopping ✓`live.html`
**C · Pedidos** ⑨ Mis pedidos (cross-tienda) · ⑩ Rastreo ✓`rastreo.html` · ⑪ Confirmación de pedido apartado
**D · Comunidad** ⑫ Puntos · ⑬ Tandas · ⑭ Sorteos
**E · Cuenta** ⑮ Mi cuenta (tiendas enlazadas) · ⑯ Notificaciones · ⑰ Pagos y direcciones · ⑱ Cambiar a "modo vendedora" + ajustes

Empieza por la **columna vertebral**: ③ → ④ → ⑤ → ⑥, luego ⑦ ⑧ ⑩, luego ⑨ ⑫ ⑮ (completar el bottom nav), luego el resto.

**── ALTO Y VALIDA ── por pantalla:** `flutter analyze` limpio; corre en emulador; **se ve como el mockup**. Resume y espera OK antes de la siguiente.

---

## Tokens de diseño (de `mockups/styles.css`)

- **Texto:** primario `#3a2233`, secundario `#8a6f82`, tenue `#b6a4b1`. Superficie `#ffffff`. Línea `rgba(58,34,51,.08)`.
- **Acento Neni's (plataforma):** `#fb6f9c` (rosa-coral), profundo `#e84e83`. Lavanda `#9b7be0`. Dorado (Puntos) `#f3b341`.
- **Estados:** pendiente texto `#b5730a` / fondo `#fcecd2`; en ruta `#2e6bd6` / `#e4ecff`; entregado `#1f9a6a` / `#d9f3e6`.
- **Marca por tienda (`--brand`):** default = acento Neni's; **Regi Bazar = `#FF0072`**. Otras demo: Luna Bella `#ff7a59`, Aurora `#8e6be6`, Mía Joya `#16b5a0`.
- **Radios:** card 28, suave 20, pill 999. **Sombras** rosadas suaves (ver `--shadow` en styles.css). **Fondo** crema `#fdf4f7` con blobs radiales rosa/lavanda.
- **Tipografía:** Poppins. **Íconos:** Material Symbols Rounded.
- **Patrones:** Home en bento; glass solo en capas flotantes (nav, drawers, overlays del live); esquinas redondeadas; microinteracciones cálidas.

## Endpoints backend relevantes (y caveat importante)

Existen (admin/identidad/públicos): auth sobre Account + JWT con memberships; `GET /api/business/me` (marca+plan+features del negocio activo); `ClientClaimController` (reclamar perfil); vistas **públicas por token sin login**: `/api/pedido/{accessToken}`, `/api/driver/{driverToken}`, `/api/public-tanda/{token}`, live por `LiveSession.Id`; controllers de Orders, Loyalty, Tandas, Raffles (tenant-scoped). SignalR: 5 hubs aislados por tenant (tracking GPS, pedidos, etc.).

> **Caveat:** el backend se construyó para la **vendedora** y las **vistas públicas**. Varias agregaciones **del lado comprador** (mis tiendas seguidas, mis pedidos cross-tenant por `AccountId`, mis Puntos por tienda, feed de lives) **probablemente aún no tienen endpoint**. Plan: construir la UI con repos **mockables**, y **agregar esos endpoints a `sellgeneral-api`** (filtrados por `AccountId`, patrón `IgnoreQueryFilters` cross-tenant del plan 0.1/0.2) conforme cada pantalla los necesite. Esto puede intercalar trabajo backend.

## Método de trabajo

- **Un bloque a la vez**, terminando en `── ALTO Y VALIDA ──`: `flutter analyze` 0 issues, corre en emulador, y la pantalla **se ve como el mockup**. Resume qué cambió y espera el OK.
- Implementaciones **completas** (sin `TODO`/stubs silenciosos). UI en español, código en inglés. No `dynamic` salvo necesario.
- No toques `regibazar-web` ni `api/EntregasApi`.

## A confirmar al inicio con Eduardo

1. **Ubicación del proyecto** Flutter (sugerido `C:\Codigos\nenis-app`) y **remoto git** nuevo.
2. **Estado:** Riverpod (sugerido) u otro.
3. **API base URL** de dev (¿`localhost:5080`? ¿URL de Render?) y cómo correr el backend dev.
4. **Logo:** sigue pendiente de generar → placeholder por ahora.
