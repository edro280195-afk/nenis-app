# Notificaciones: quién recibe qué (y por qué nunca se mezclan)

> Creado 2026-09-30 tras auditar de punta a punta el envío de avisos (backend `sellgeneral-api`, app `nenis-app`, panel `sellgeneral`).
> Regla de oro: **cada aviso tiene UN destinatario declarado**. Las clientas, las seguidoras de una tienda y las vendedoras nunca reciben lo del otro.

## Los 4 destinatarios

Todo sale de `IPushNotificationService` (`Services/PushNotificationService.cs`). Ningún otro código manda push ni crea `Notification`
(lo vigilan las pruebas de `NotificationArchitectureTests`).

| Destinatario | Método | Quién recibe EXACTAMENTE | Canales |
|---|---|---|---|
| **Una clienta** (por pedido) | `SendNotificationToClientAsync(clientId, …)` | Los teléfonos de la **cuenta enlazada a esa ficha** (`Client.AccountId`) + quien abrió el enlace público de ese pedido. Nunca otra clienta, ni la dueña. | FCM (app) · Web Push (enlace público) · historial |
| **Las clientas** (seguidoras de una tienda) | `SendNotificationToFollowersAsync(businessId, …)` | Cuentas con `StoreFollower` activo en ESE negocio (filtros VIP / avisos de en vivo / novedades). | FCM · historial |
| **Las vendedoras** | `SendNotificationToBusinessOwnersAsync(businessId, …)` | Cuentas con membresía **Owner o Admin** de ESE negocio. No choferes, no escaneadores, no otro negocio. | FCM · historial · Web Push de los paneles web de ese negocio |
| **El chofer de una ruta** | `NotifyDriverFcmAsync(routeToken, …)` / `NotifyDriversNewRouteAsync` | Dispositivos registrados con el token de ESA ruta. Solo si nadie ha abierto la ruta aún, una *nueva ruta* avisa a los choferes del negocio (no hay cuenta con la que identificarlos). | FCM |

El negocio o la clienta **siempre se pasan y se filtran de forma explícita**: ningún envío usa el "negocio activo" de la petición
(que, sin token reconocible, cae al negocio #1 — Regi Bazar).

## Matriz de eventos

| Evento | Se dispara en | Destinatario | Etiqueta (`tag`) | Enlace |
|---|---|---|---|---|
| Pedido empacado / en ruta / entregado (cambio de estatus) | `OrdersController.UpdateStatus` | Clienta | — | `/o/{token}` |
| "Tu pedido va en camino" — **solo a la clienta a la que le toca** (la siguiente de la lista) | `DriverController`: iniciar ruta (la primera), avanzar a la siguiente parada, reordenar, marcar en tránsito (no se repite si ya era la actual). **No** al crear la ruta | Clienta | `driver-en-route` | — |
| "Pedido entregado" (chofer) | `DriverController.MarkDelivered` | Clienta | `delivered` | — |
| Nuevo apartado | `BuyerReserveService` | Vendedoras | `reserve` | `/orders/detail/{id}` |
| Pedido confirmado por la clienta | `ClientViewController.ConfirmOrder` | Vendedoras | `order-confirmed` | `/orders/detail/{id}` |
| Pago con tarjeta | `ClientViewController` | Vendedoras | `card-payment` | `/orders/detail/{id}` |
| Pago de tanda | `PublicTandaController` | Vendedoras | `tanda-payment` | `/tandas` |
| Cobro registrado por el chofer | `DriverController.MarkDelivered` | Vendedoras | `payment-received` | `/orders/detail/{id}` |
| Entrega fallida | `DriverController.MarkFailed` | Vendedoras | `delivery-failed` | `/orders/detail/{id}` |
| Bolsas devueltas al terminar ruta | `DriverController.CheckRouteCompletion` | Vendedoras | `packages-returned` | `/seller/inventory` |
| Pedidos por vencer · Saldos sin cobrar · Pulso del negocio | `AdminNotificationsService` (cada mañana) | Vendedoras | `pedidos-por-vencer` · `saldos-sin-cobrar` · `pulso-negocio` | `/orders` · `/home` |
| ¡Estamos en vivo! | `LiveAnnouncementService` | Clientas (seguidoras con avisos de en vivo) | `live-started` | `/store/{id}` |
| Nueva novedad (normal o VIP) | `StorePostsService` | Clientas (seguidoras; VIP solo VIP) | `store-post` | `/store/{id}` |
| Nueva ruta · reordenada · cambios · cancelada | `RoutesController` | Chofer de esa ruta (por el token de su ruta) | `new_route` / acciones | — |

## Contrato del push (FCM `data`)

La app valida esto antes de **mostrar** el aviso o **navegar** con él (`core/notifications/push_payload.dart`, `push_navigation.dart`).

| Campo | Valor |
|---|---|
| `type` | Etiqueta del aviso |
| `audience` | `buyer` (la persona como clienta) · `seller` (como dueña/administradora) |
| `businessId` | Negocio del que viene |
| `url` | Ruta interna de la app (`""` si no hay); solo se navega si empieza con `/` |
| `accountId` | **Solo** si es para UNA cuenta concreta (aviso de pedido). Si no coincide con la sesión abierta, se descarta |

Reglas en la app: un aviso `seller` solo se abre con una sesión Owner/Admin de ese negocio (y cambia el negocio activo si es de otra de sus tiendas);
un aviso con `accountId` ajeno no se muestra ni se abre; sin sesión no se navega.

## Historial, campanita y "marcar todas"

`Notification.Audience` (`buyer`/`seller`) se guarda en cada fila. La API acepta `?audience=` en
`GET /api/me/notifications`, `…/unread-count` y `POST …/read-all`:

- La app pide solo el del papel con el que entró (`notificationAudienceProvider`: con membresía → `seller`; sin ella → `buyer`).
- Los avisos de tienda **solo se ven mientras la cuenta siga siendo Owner/Admin de ese negocio** (si la sacan del equipo, desaparecen de su historial).
- Sin `audience` se devuelve todo (compatibilidad con la app ya publicada).
- Una cuenta con ambos papeles (dueña de una tienda y clienta de otra) **nunca mezcla** las dos campanitas.
  Consecuencia de producto: en modo vendedora no ve en la campanita los avisos de sus compras (le llegan como push, pero el historial es solo de la tienda).

## Seguridad de la suscripción

| Endpoint | Regla |
|---|---|
| `POST /api/push/subscribe` (Web Push, anónimo) | `admin` exige sesión Owner/Admin del negocio (`X-Business-Id` si tiene varios) · `client` exige el **token del pedido** (la clienta y el negocio salen del pedido; el `clientId` del cuerpo se ignora) · `driver` exige el token de una ruta que existe. El negocio sale del recurso validado. Un navegador de administración no se convierte en clienta/chofer por una llamada anónima. |
| `POST /api/push/subscribe-fcm` (choferes, anónimo) | `admin` exige sesión · el token de ruta debe existir y fija el negocio (uno inventado se descarta). |
| `POST /api/push/test` y `send/*` | Solo Owner/Admin. La prueba solo llega a las suscripciones de **administración** de ese negocio. |
| `POST /api/me/devices` | Sesión. Token ≤ 512 y plataforma ≤ 20 (antes un valor largo daba 500). Un token que cambia de cuenta se **reasigna** (sale de la anterior). |
| `DELETE /api/me/devices/{token}` | **Anónimo a propósito** (el token es un secreto del dispositivo): así el cierre de sesión siempre puede quitarlo aunque la sesión ya expiró. |

## Bugs que había y ya no (auditoría 2026-09-30)

1. Los avisos a vendedoras (apartado, confirmado, pago, entrega fallida…) iban por Web Push "admin", un canal que la app nunca llena → **no llegaban**; y cualquiera podía suscribirse como "admin" del negocio #1 y leerlos.
2. Los avisos de pedido a una clienta con la app **solo se guardaban en el historial** (nunca salían por FCM a su teléfono).
3. `logout()` borraba la sesión antes de quitar el token de push → el `DELETE` salía sin credenciales, daba 401 y el token seguía atado a la cuenta que salió.
4. Historial/contador/"marcar todas" mezclaban avisos de tienda y de clienta para una cuenta con ambos papeles.
5. Cambios de una ruta avisaban a **todos** los choferes del negocio.
6. El panel web mandaba `clientId: ord.id` (campo inexistente) → la suscripción de la clienta quedaba vacía y nunca recibía nada.
7. En "Pedido confirmado" el nombre de la clienta salía vacío y el número era el id interno, no el consecutivo del negocio.

## Candados (pruebas)

- Backend (`sellgeneral-api/Tests/EntregasApi.Tests`): `NotificationRecipientsTests`, `NotificationEmittersTests`, `PushControllerSecurityTests`,
  `BuyerDeviceControllerTests`, `NotificationArchitectureTests`.
- App (`nenis_app/test`): `core/notifications/push_payload_test.dart`, `core/auth/logout_push_token_test.dart`,
  `features/notifications/data/notifications_repository_test.dart`, `features/devices/device_repository_test.dart`.

## Decisiones tomadas (2026-09-30)

- **"Va en camino"**: solo cuando de verdad es la siguiente de la lista (ver matriz). Quitado de `RoutesController.Create`; `NotificationArchitectureTests` impide que vuelva.
- **Tiempo real (SignalR)**: los grupos de vendedora (`JoinAdminGroup` de los hubs de entregas, logística, pedidos y rastreo, y el vivo: `JoinAdminLive`/`AnnounceProduct`) son **solo para dueña o administradora**. Choferes y escaneadores ya no entran: la app de Flutter es solo de clientas y vendedoras; los choferes tendrán su propia app. (`PosHub` no cambia: el escaneador lo usa en el punto de venta.) Prueba: `SellerHubAccessTests`.
- **Firebase de choferes**: los avisos a choferes salen por `IDriverFcmService`, que usa una **segunda FirebaseApp ("drivers")** si hay credencial aparte y, si no, el mismo proyecto de la app. Un token FCM solo lo acepta el proyecto con el que se registró; con una sola credencial en Render (`nenisapp-60810`) los dispositivos de la app de choferes anterior (proyecto `regibazarnotify`) fallaban con `SenderIdMismatch`. Para activarlo: subir a Render un **Secret File** `firebase-drivers-service-account.json` (la credencial de `regibazarnotify`, la misma que está local como `firebase-service-account.json`). Al arrancar, el log dice `🔥 Firebase de choferes conectado (proyecto: …)`. Si la app de choferes nueva vive en `nenisapp-60810`, basta con **no** subir ese archivo.
- **Colores AA**: `ink2`, `ink3` y `neniDeep` ahora cumplen 4.5:1 sobre todos los fondos (ver `QA-HALLAZGOS-EMULADOR-2026-08-05.md`).

## Abierto

- **Despliegue**: el backend debe subir **antes** que la app nueva (las dos son compatibles hacia atrás, pero el logout de la app ya publicada solo mejora cuando el backend permite la baja anónima). La migración `AddNotificationAudience` se aplica sola al arrancar.
- **Tokens de choferes de dos proyectos a la vez**: si la tabla `FcmTokens` mezclara dispositivos de la app de choferes anterior y de la nueva (proyectos distintos), un solo canal no cubre ambos. Hoy se asume uno solo; cuando llegue la app nueva conviene quitar la segunda credencial o reiniciar los registros.
- **Tokens vencidos**: FCM rechaza los tokens de teléfonos desinstalados pero no se podan (solo se registran en el log).
- **Botones con degradado**: el texto blanco sobre el rosa claro inicial del degradado (`neni`, #FB6F9C) sigue por debajo de 4.5:1; este cambio de paleta no toca `neni`.
- Sin usar hoy: `SendNotificationToDriverAsync` (Web Push a chofer) y `NotifyClientDriverNearbyAsync`.
