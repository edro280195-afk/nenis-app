# Fase E (herramientas del pedido) + Fase F (publicación) + login passwordless

**Goal:** Convertir `TrackingScreen` en la experiencia completa del pedido (repartidor real, confirmar, instrucciones, chat en vivo, puntos, pago en revisión) y dejar la app lista para publicar (Install Referrer, Universal Links, Smart App Banner, analítica) + login passwordless general.

**Architecture:**
- **App (Flutter, Riverpod 3, go_router):** extender `OrderTracking` con los campos nuevos del DTO V3; `TrackingRepository` suma confirm/instructions/chat; `TrackingHubClient` se suscribe a `ReceiveClientChatMessage`; `TrackingScreen` reemplaza el placeholder del repartidor y cablea todas las herramientas. MP queda como sección "en revisión" (decisión del dueño: lo maneja después, extra por tenant).
- **Backend (.NET 8):** agregar `CourierPhone` a `ClientOrderView`; Smart App Banner iOS + tabla `LinkEvents` + endpoint anónimo + impresión en `GET /o/{token}`. Backward-compatible (campos opcionales). Migración EF.
- **Publicación:** re-agregar `android_play_install_referrer` con override `compileSdk 34`; cablear `Runner.entitlements` en `project.pbxproj`; env vars de Render documentadas.

**Tech Stack:** Flutter 3.44 / Dart 3.12, Riverpod 3, go_router 17, dio 5, signalr_netcore, app_links, android_play_install_referrer, url_launcher; .NET 8, EF Core, Neon Postgres, SignalR.

**Verificación por paso:** `flutter analyze lib` (limpio) + `flutter build apk --debug`; backend `dotnet build EntregasApi.csproj` + `dotnet test Tests/EntregasApi.Tests/EntregasApi.Tests.csproj`. No se commitea Flutter sin petición; backend se commitea local pero el **push se confirma con el dueño** (deploya a prod).

---

## TAREA 1 — Fase E: herramientas del pedido

### 1.1 Backend: `CourierPhone` en el DTO
- **Modify:** `sellgeneral-api/DTOs/Dtos.cs` `ClientOrderView` → añadir `string? CourierPhone = null` después de `CourierName`.
- **Modify:** `sellgeneral-api/Controllers/ClientViewController.cs` `GetOrder` → la query de la Membership Driver proyecta `(DisplayName, Phone)`; poblar `CourierPhone: driverAccount?.Phone`.
- Backward-compatible (campo opcional al final del record).

### 1.2 App: extender `OrderTracking` + `OrderPayment`
- **Modify:** `lib/features/tracking/data/tracking_models.dart`:
  - Nuevo `class OrderPayment` (id, orderId, amount, method, date, registeredBy, notes) + `fromJson`.
  - `OrderTracking` añade: `courierName`, `courierPhone`, `deliveryInstructions`, `payments`, `evidenceUrls`, `mercadoPagoPublicKey`, `businessName`, `businessLogoUrl` (y opcionales: `expiresAt`, `createdAt`, `signatureSvg`, `signedByName`, `signedAt`, `nonDeliveryEvidenceUrls`, `advancePayment`, `type`, `estimatedArrival`, `clientLatitude`, `clientLongitude`, `rating`). Parseo tolerante (nullables).
  - `copyWith` ampliado para los campos que actualiza SignalR/acciones (status, driverLocation, deliveriesAhead, balanceDue, amountPaid, deliveryInstructions, payments).

### 1.3 App: `TrackingRepository` — acciones token-based
- **Modify:** `lib/features/tracking/data/tracking_repository.dart`:
  - `Future<void> confirmOrder(String token)` → `POST /api/pedido/{token}/confirm`.
  - `Future<void> updateInstructions(String token, String instructions)` → `PATCH /api/pedido/{token}/instructions` body `{ instructions }`.
  - `Future<List<ChatMessage>> getChat(String token)` → `GET /api/pedido/{token}/chat`.
  - `Future<ChatMessage> sendChat(String token, String text)` → `POST /api/pedido/{token}/chat` body `{ text }`.
  - `class ChatMessage` (id, sender, text, timestamp, deliveryId?, deliveryRouteId?) + `fromJson`.
  - (CardPayment request model se deja listo pero **no se usa** — MP en revisión.)

### 1.4 App: `TrackingHubClient` — chat en vivo
- **Modify:** `lib/features/tracking/data/tracking_repository.dart` `TrackingHubClient`:
  - Nuevo `StreamController<ChatMessage> _chatCtl` + `Stream<ChatMessage> get chatStream`.
  - En `_wireEvents`: `_connection.on('ReceiveClientChatMessage', ...)` → parsea `{id, sender, text, timestamp, deliveryId?}` y emite a `_chatCtl`.
  - `dispose` cierra `_chatCtl`.

### 1.5 App: `TrackingController` — integra chat + acciones
- **Modify:** `lib/features/tracking/data/tracking_controller.dart`:
  - Suscribe a `hub.chatStream` → merge en estado (lista de mensajes). Expone `AsyncValue<List<ChatMessage>>` vía un provider separado `orderChatProvider` (StateNotifier/Notifier) o un field en el controller. **Decisión:** provider aparte `OrderChatNotifier` (carga histórico + merge en vivo + envío) para mantener el controller enfocado en el pedido.
  - Métodos de acción: `confirmOrder()`, `updateInstructions(String)`, `sendChat(String)` que llaman al repo y refrescan/invalian `trackingControllerProvider`.

### 1.6 App: `TrackingScreen` — UI completa
- **Modify:** `lib/features/tracking/screens/tracking_screen.dart`:
  - `_DriverRow`: usa `order.courierName` + `order.courierPhone`. Avatar = inicial del nombre o ícono camión si neutro. Botón chat → abre `_ChatSheet`; botón llamada → `tel:` si `courierPhone` != null (sino oculto). Estado neutro si no hay courier.
  - `_TrackingSheet` añade secciones:
    - **Confirmar pedido** (si status Pending/Postponed): `PillButton` "Confirmar pedido" → `confirmOrder` + snack + refresh.
    - **Instrucciones de entrega**: card editable (modo lectura → tap edita → `AppTextField` multiline → guardar vía `updateInstructions`).
    - **Chat** (FAB o botón en driver row): abre `_ChatSheet` (hoja modal) con histórico + input + envío + recepción en vivo.
    - **RegiPuntos**: card con `order.clientPoints` + botón "Ver mis puntos" → `context.push('/points')`.
    - **Pago**: card "Resumen" (total/abonado/saldo + lista `payments`) y, si `balanceDue > 0`, sub-sección "Pago con tarjeta" marcada "En revisión 🛠️ — próximamente" (sin form). Si `mercadoPagoPublicKey != null` muestra candado "seguro por Mercado Pago".
    - **Evidencia** (si Delivered): gallery de `evidenceUrls` (tap → full-screen).
  - **Create:** `lib/features/tracking/widgets/order_chat_sheet.dart` (`_ChatSheet` reutilizable).
  - **Create:** `lib/features/tracking/widgets/order_payment_section.dart` (resumen + placeholder MP).
  - **Create:** `lib/features/tracking/widgets/order_instructions_card.dart` (editable).
  - **Create:** `lib/features/tracking/widgets/order_confirm_card.dart`.
  - **Create:** `lib/features/tracking/widgets/order_points_card.dart`.

## TAREA 2 — Fase F: publicación

### 2.1 Backend: Smart App Banner iOS + LinkEvents
- **Modify:** `ShareLandingController.BuildLandingHtml` → `<meta name="apple-itunes-app" content="app-id=ID">` cuando `App:IosStoreUrl` tenga un App Store ID (parsear `id...` de la URL). Sin ID → no incluir.
- **Create:** `Models/LinkEvent.cs` (Id, BusinessId?, AccessToken?, EventType, CreatedAt, Meta?) — `ITenantOwned` opcional (BusinessId nullable porque el muro es anónimo).
- **Modify:** `Data/AppDbContext.cs` → `DbSet<LinkEvent> LinkEvents` + índice en (EventType, CreatedAt).
- **Create:** migración `AddLinkEvents` (`dotnet ef migrations add AddLinkEvents`).
- **Create:** `Controllers/LinkEventsController.cs` → `POST /api/link-events` (anónimo, body `{ accessToken?, eventType, meta? }`) registra; `GET /api/link-events/stats` (admin, futuro).
- **Modify:** `ShareLandingController.Landing` → registra impresión `link_opened` (fire-and-forget, no bloquea).
- **Eventos del embudo:** `link_opened` (GET /o), `claimed` (en `ClientClaimService` al reclamar by-token/by-phone), `registered`/`logged_in` (en `AuthController` phone/verify — opcional, mínimo). Se documenta; se implementan los点 clave sin acoplar mucho.

### 2.2 App: Install Referrer Android (deferred deep link)
- **Modify:** `pubspec.yaml` → `android_play_install_referrer: ^1.2.0` (pin compatible).
- **Modify:** `android/build.gradle.kts` (root) → `subprojects { afterEvaluate { ... } }` que suba `compileSdk` a 34 (override) para el plugin.
- **Modify:** `lib/core/deeplinks/pending_claim_store.dart` → re-añadir `_referrerKey`, `isReferrerConsumed()`, `markReferrerConsumed()`.
- **Modify:** `lib/core/deeplinks/deep_link_service.dart` → re-añadir `_readInstallReferrer()` (patrón del commit `212ca04`, recuperado del git history) + llamada `unawaited(_readInstallReferrer())` en `start()` + imports.

### 2.3 App: iOS Universal Links
- **Modify:** `ios/Runner.xcodeproj/project.pbxproj` → `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` en las 3 build configs (Debug/Release/Profile) del target Runner. (El archivo `Runner.entitlements` ya existe con `applinks:app.nenisapp.com`.)
- **Doc/env vars:** `App__AppleAppId = TEAMID.com.nenisapp.nenis_app` en Render; verificar `/.well-known/apple-app-site-association`.

### 2.4 Env vars de Render (documentación, no código)
- `App__AndroidCertFingerprints` = SHA-256 de Play App Signing (Play Console → App Integrity).
- `App__AppleAppId` = `TEAMID.com.nenisapp.nenis_app`.
- `App__AndroidStoreUrl` / `App__IosStoreUrl` (activa los botones de descarga + Smart App Banner).
- Verificar `/.well-known/assetlinks.json` y `apple-app-site-association`.

## TAREA 3 — Login passwordless general

### 3.1 App: `AuthController` flag de rescate
- **Modify:** `lib/core/auth/auth_controller.dart` → `bool _needsOrderRescue = false; bool get needsOrderRescue`; set `true` al final de `verifyPasswordlessOtp`; método `clearOrderRescue()`.

### 3.2 App: pantalla OTP de login
- **Create:** `lib/features/auth/screens/login_otp_screen.dart` → lee `pendingPhone` (del `requestPasswordlessOtp` previo), `OtpInput` length 6, `verifyPasswordlessOtp(code)`, countdown + reenvío (`resendCode`), back a `/login`. Reusa estilos/widgets de `confirm_screen.dart`.

### 3.3 App: `LoginScreen` — opción "Entrar con código"
- **Modify:** `lib/features/auth/screens/login_screen.dart` `_ClientLoginForm` → añadir botón "Entrar con código" (debajo del de contraseña). Flow: valida teléfono → `requestPasswordlessOtp(phone)` → `context.go('/login-otp')`. Conserva login por contraseña y vendedora correo+contraseña.

### 3.4 App: router — redirect rescate + nueva ruta
- **Modify:** `lib/core/router/app_router.dart`:
  - Nueva ruta `/login-otp` → `LoginOtpScreen`.
  - Redirect: `if (session != null && !hasPending && ref.read(authControllerProvider.notifier).needsOrderRescue && loc != '/claim') return '/claim';` y al estar en `/claim` limpiar el flag.

## Verificación final
- `flutter analyze lib` → 0 issues.
- `flutter build apk --debug` → éxito.
- `dotnet build EntregasApi.csproj` → éxito; `dotnet test Tests/EntregasApi.Tests/EntregasApi.Tests.csproj` → verde.
- Actualizar memoria: `enlace-pedido-deeplink.md`, `auth-passwordless-refresh.md`, `deploy-render-envvars.md`.
- **Confirmar con el dueño antes de `git push` al backend.** Flutter no se commitea salvo petición.
