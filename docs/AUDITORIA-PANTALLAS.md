# Auditoría pantalla por pantalla — app compradora (Neni's)

Seguimiento del análisis control por control de la app Flutter, empezando por
la vendedora. Retomar aquí la próxima sesión.

## Cómo retomar

1. Leer este archivo completo.
2. Empezar por el primer item en **Pendientes** (no analizados aún).
3. Para cada pantalla: leer el `.dart` + su `data/` + verificar el endpoint del
   backend en `C:\Codigos\sellgeneral-api`. Reportar hallazgos con
   `file:line`, severidad (🔴/🟡/🟢) y causa raíz.
4. Regla del dueño: **arreglar los hallazgos antes de avanzar** a la siguiente
   pantalla (salvo los marcados como "decisión de producto").
5. Verificar con `dart analyze` tras cada fix.
6. Al final de la sesión: commit+push y actualizar este archivo.

---

## ✅ Completados (sesión 2026-07-14)

Commit `9013710` en `main`. Resumen de lo arreglado:

### SellerHomeScreen (dashboard) + AuthController
- Badge de notificaciones condicional (antes siempre rojo).
- `SlowLoadHint` en la carga del dashboard.
- Selector de negocio multi-tienda (botón + sheet).
- `AuthController._withDefaultBusiness`: autoselecciona el primer negocio si
  una vendedora multi-tienda entra sin activo. Arregla el bug de raíz donde el
  dashboard usaba `DefaultBusinessId=1` del backend (datos ajenos).
- Dead code del `_ChartPainter` (rama `== 1` inalcanzable).

### SellerOrdersScreen (lista de pedidos)
- Filtros completos (9 estados con `TabChip` scrollable). Antes solo 4 y los
  pedidos Confirmed/Shipped/NotDelivered/Canceled/Postponed quedaban huérfanos.
- `SlowLoadHint` en el loading.
- Botón de limpiar en el campo de búsqueda (`_SearchField` ahora StatefulWidget).

### OrderCreateScreen (captura) — `order_create_screen.dart`
Crashes / pérdida de datos:
- B1/B2: `setState` después de `dispose` (crash si sales durante envío rápido
  o tras crear). Guards `mounted` en `_submitQuickQueue` y `_afterOrderCreated`.
- B3: la cola rápida ya no se limpia con fallos parciales; los items del grupo
  que falló se quedan para reintentar.
- B4: doble tap en "Crear pedido" ya no apila dos diálogos/creaciones (el
  guard `_creatingManual` se setea antes del `await` del diálogo).
- B5: fuga de datos entre clientas al romperse el match exacto (teléfono/
  dirección de "Ana" pegados a "Ana López"). El autorellenado ahora solo
  ocurre al seleccionar explícitamente una sugerencia.

UX:
- U6: input formatters en campos de precio/cantidad.
- U7: **focus chain** en el form de agregar artículo (Nombre → Precio → Cant.
  → Agregar). `TextInputAction.next` + FocusNodes `_manualPriceFocus`/`_manualQtyFocus`.
- U8: stepper no elimina items al llegar a 0 (botón X lo hace).
- U14: chips de "Producto fijo" ahora filtran al teclear (`ValueListenableBuilder`).
- U17: modo rápido = `forceNew: true` (cada captura es pedido nuevo, sin
  auto-merge silencioso).
- U19: `_OpenOrderSheet` muestra "Vas a agregar N artículos · $X".
- `SlowLoadHint` en `_CaptureLoading`.

Parser (`seller_order_capture_parser.dart`):
- B6: "Maria, blusa 100" ya no pierde "blusa" (extrae solo el número, deja
  el nombre).
- U12: formato MXN: "1.000" = $1000 (puntos=miles, coma=decimal).
- U13: el precio es **unitario**, no total/cantidad.

### OrderDetailScreen — `order_detail_screen.dart`
- D1: stepper que eliminaba artículos sin confirmar al llegar a 0 (diálogo).
- D2: `SlowLoadHint` en el loading.
- D3: confirmación si el cobro excede el restante.
- D4: `setNotified` ahora es transparente (avisa que copiar marca notificado).
- D5: input formatters en `_AddItemForm` (`_MiniField`).
- D6: confirma rebajas de estatus (ej. Entregado → Pendiente) con
  `_isStatusDowngrade` + `_deliveryFlow`.

---

## 🔲 Pendientes — pantallas NO analizadas aún (en orden)

1. **SellerRoutesScreen** — `features/routes/screens/seller_routes_screen.dart`
2. **SellerClientsScreen** — `features/clients/screens/seller_clients_screen.dart`
3. **SellerLiveScreen** — `features/live/screens/seller_live_screen.dart`
   (nueva; data en `features/live/data/`)
4. **SellerAccountScreen** + settings —
   `features/account/screens/seller_account_screen.dart`,
   `seller_settings_screens.dart`, `seller_payment_settings_screen.dart`
5. **Pantallas secundarias** (prioridad baja):
   - SellerVipScreen — `features/seller_vip/screens/seller_vip_screen.dart`
   - SellerUpdatesScreen — `features/seller_updates/screens/seller_updates_screen.dart`
   - SellerTandasCommandScreen — `features/tandas/screens/seller_tandas_command_screen.dart`
   - PointsScreen — `features/points/screens/points_screen.dart`
6. **Pantallas de compradora** (después de terminar la vendedora):
   - BuyerHomeScreen, StoreScreen, LiveScreen, TrackingScreen, OrderLinkScreen,
     PointsScreen, TandasScreen, RafflesScreen, AccountScreen, Addresses,
     Notifications, Payments, Reserve, Claim, Auth (welcome/login/otp/register/
     confirm/forgot).

---

## 🟡 Backlog UX de orders (decisión de producto — NO arreglados)

Quedaron fuera por ser decisiones de producto, no bugs. Revisar con el dueño:

- **U7 ya hecho** ✅ (estaba en el backlog, se completó).
- **U9**: "Copiar mensajes" copia todos los creados pero el panel muestra solo
  4. `order_create_screen.dart` — `_copyCreatedMessages` copia
  `_createdOrders` (todos) vs el panel `orders.take(4)`.
- **U10/U11**: modo rápido no envía dirección y usa un solo tipo de entrega
  para toda la cola. **Decisión del dueño**: modo rápido = sin dirección
  (la dirección se captura por clienta, no es obligatoria). → **Confirmado
  que así debe quedar**. No arreglar.
- **U18**: `createManual` envía `status: 'Pending'` incluso al agregar a un
  pedido existente. Verificar si el backend respeta este campo al mergear
  contra un pedido "Confirmed" (podría rebajar el estatus). Revisar
  `OrdersController.CreateManual` en `sellgeneral-api`.

---

## 📝 Notas para la próxima sesión

- La app **siempre apunta a `https://app.nenisapp.com`** (commit anterior
  `88646d5`). Sin `dart-define` ni switches de plataforma.
- Para verificar el backend: `curl` directo a `app.nenisapp.com` (ej.
  `/api/me/home` devuelve 401 sin token, confirma que está vivo).
- El backend filtra por `BusinessId` vía `HasQueryFilter` global en
  `AppDbContext.cs:585` — los KPIs del dashboard ya están aislados por tenant.
- Patrón de `SlowLoadHint`: ya está en home (buyer), seller home, seller
  orders, order create, order detail, orders. Toda pantalla con carga de red
  larga debe usarlo (cold-start de Render Free hasta 60s).
- `_withDefaultBusiness` en `AuthController` ya normaliza el negocio activo;
  las pantallas nuevas no deben preocuparse por `activeBusinessId == null`.
- Cuando se delegue análisis a subagente (Task tool), especificar
  `subagent_type: explore` y pedir reporte con `file:line` + severidad.
