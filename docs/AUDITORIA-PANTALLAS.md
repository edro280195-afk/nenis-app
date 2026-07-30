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

## ✅ Completados (sesión 2026-07-27)

Auditadas y arregladas **todas** las pantallas que quedaban en la lista de
pendientes — vendedora completa, secundarias y las 15 de compradora. 32
archivos tocados (22 Flutter + 10 backend), verificado con `flutter analyze
lib` (0 issues) y `dotnet test` (302/302 verde) al cierre de la sesión.
Metodología: se delegó la lectura/reconocimiento de cada pantalla a
subagentes `explore` en paralelo (varios fallaron una vez por límite de
sesión y se relanzaron); los fixes reales los aplicó la sesión principal.

### SellerRoutesScreen (`features/routes/`)
No estaba tan avanzada como sugería su tamaño (2244 líneas tras el trabajo
reciente de "armado de rutas"). Encontrados y arreglados:
- 🔴 `setState` sin guard `mounted` tras `await`, reintroducido 5 veces
  (`_previewSelected`, `_createRoute`, `_optimizeRoute`, `_saveOrder`,
  `_deleteRoute`) — mismo patrón que B1/B2 de OrderCreateScreen.
- 🔴 `createRoute()` descartaba en silencio los `skipped` que el backend
  rechaza al crear (pedido ya en otra ruta, cancelado, etc.) — ahora
  `CreateRouteResult` los expone y se muestran en el feedback.
- 🔴 `_optimizeRoute` no limpiaba `_draftOrders[routeId]` tras optimizar: la
  tarjeta seguía mostrando el orden viejo y "Guardar orden" podía revertir
  en silencio la optimización recién guardada.
- 🔴 Eliminar ruta era un solo tap sin confirmación, y borra
  permanentemente chat + evidencia de entrega. Ahora pide confirmación
  explícita (`_confirmAndDeleteRoute`) y tiene guard anti doble-tap
  (`_deletingRouteId`).
- 🟡 `_toggleRoute`/`_showRouteMap` sobrescribían el draft local sin
  guardar al colapsar/expandir o ver el mapa — ahora usan `putIfAbsent`.
- 🟢 `SlowLoadHint` agregado a la carga inicial.
- 🟡 `preOptimized` siempre se enviaba en `false`, por lo que crear volvía a
  llamar al optimizador y podía cambiar la ruta que acababa de mostrarse.
  Ahora Flutter manda `preOptimized: true` y la secuencia explícita
  `orderedStopIds`; el backend conserva incluso el intercalado pedido/tanda,
  ignora IDs ajenos/duplicados y agrega al final cualquier parada válida que
  faltara por una previsualización vieja.
- 🟡 Las candidatas se agrupaban por `nombre|teléfono`, lo que podía mezclar
  dos clientas distintas o separar pedidos/tandas de la misma clienta si
  cambió el texto. Ahora pedidos y tandas leen el `clientId` que ya expone el
  API y lo usan como identidad estable.
- **No arreglado (bajo impacto):** el stepper inline de bolsas es código
  muerto (~60 líneas, el bottom sheet real funciona bien).

### SellerClientsScreen (`features/clients/`)
- 🔴 `setState` sin guard tras `await` en el análisis C.A.M.I. (crash si
  cierras el sheet antes de que responda).
- 🔴 Dropdown "Tipo" truena si el valor es `"VIP"` (C.A.M.I. puede fijarlo
  por chat, fuera de las 2 opciones fijas del dropdown) — ahora lo admite
  sin perder el dato.
- Guardar/eliminar clienta y eliminar alias fallaban en silencio (sin
  `catch`) — el backend rechaza el borrado si la clienta tiene pedidos, y
  ese rechazo nunca llegaba a mostrarse.
- Mensaje de error genérico cuando "Fusionar duplicadas" requiere un plan
  que no tienes (402/`feature_locked` no se reconocía) — ahora sí distingue.
- Teléfono/Dirección/Indicaciones: aviso de que dejarlos vacíos no borra el
  dato (el backend los ignora en blanco a propósito) + límite de 20
  caracteres en teléfono.
- Empty state distinto para "directorio realmente vacío" vs. "filtro sin
  resultados". `SlowLoadHint` agregado.

### SellerLiveScreen + LiveScreen (compradora) — "Nivel 2" ya estaba construido
Hallazgo grande: el plan de Live en tiempo real que `PROGRESO-APP-FLUTTER.md`
describía como "sin construir todavía" **ya estaba completo de punta a
punta** (backend `LiveHub` + Flutter, commits del 2026-07-09) — el doc
simplemente no se actualizó. Bugs reales encontrados en lo ya construido:
- 🔴 `live_screen.dart`: `isLiveNow` viene del GET inicial y nunca se
  actualizaba con el evento SignalR `ProductAnnounced` — si la clienta
  entraba justo antes de que la vendedora arrancara el vivo, se quedaba
  viendo "no está en vivo" para siempre aunque llegaran productos reales.
- 🟡 `LiveAnnouncementDto` no exponía `CurrentProduct*` — si la vendedora
  salía de `/seller/live` y volvía a media transmisión, perdía de vista
  qué fue lo último anunciado (el dato sí estaba en BD).
- 🟡 `JoinAdminLive`/`AnnounceProduct` no mandaban `businessId` — fallaban
  en silencio para vendedoras con más de una tienda.
- 🟢 Comentarios fósiles referenciando `LiveSession` (clase ya borrada).

### SellerAccountScreen + settings (`features/account/`)
- 🟡→arreglado de raíz: dos cuentas de cobro podían quedar marcadas
  "principal" a la vez (condición de carrera real: `ClearDefaultAsync` lee-
  y-limpia sin serializar entre requests). Candado en proceso por
  `BusinessId` (`BusinessPayoutAccountsController.DefaultGates`, mismo
  patrón que `BuyerReserveService`) + guard global en el front.
- Formatters de longitud en Titular/Banco/Alias/Nota, `SlowLoadHint`,
  mensaje honesto cuando el guardado falla por cold-start de Render
  (antes decía "revisa tu internet"), disclaimer en Preferencias dejando
  claro que hoy no cambian nada real (mismo patrón que ya usaba Equipo).
- 🟢 `_StorePreviewCard` sin guard de nombre vacío (crash potencial, no
  disparado hoy) — alineado con `_BusinessSummaryCard`.
- **No arreglado:** hub `/seller/settings` es código muerto confirmado
  (nadie navega ahí, `SellerAccountScreen` enlaza directo a las
  sub-rutas) — seguro de borrar, no se tocó por no ser urgente.

### Pantallas secundarias de vendedora
- **SellerVipScreen**: sin retry en error de carga — arreglado.
- **SellerUpdatesScreen**: 🔴 `setState`/`ref.invalidate` sin guard
  `mounted` en `_publish` (crash real) + mismo patrón en `_startLive`,
  `_endLive`, `_deletePost`, `_pickImage` — todos arreglados. Error de
  carga que renderizaba nada (`SizedBox.shrink()`) ahora muestra mensaje +
  reintentar.
- **VIP/Updates (continuación 2026-07-27)**: el backend ya limitaba ambos
  módulos a Owner/Admin, pero `SellerAccountScreen` los ofrecía a todo el
  staff. Ahora `Session.canManageStoreEngagement` replica esa política; para
  Driver/Scaner los tiles muestran `Sin permiso` y quedan deshabilitados.
  Un enlace directo abre una explicación clara sin llamar a los providers
  protegidos, y un 403 tardío también se traduce a un mensaje de rol.
  Cubierto con 7 pruebas nuevas de sesión, UI y repositorios.
- **SellerTandasCommandScreen**: 🔴 **doble cobro real** — "Registrar pago"
  sin guard anti doble-tap en ninguna capa (ni Flutter ni backend), y
  `collectedAmount` suma pagos duplicados sin dedup. Arreglado en ambos
  lados: guard global `_actionInFlight` en el helper `_run` (Flutter) +
  chequeo de pago ya existente antes de insertar
  (`TandaService.RegisterPaymentAsync`, backend). También: regresión de
  layout ancho (≥900px) que dejaba "Sortear turnos" deshabilitado y
  "WhatsApp" sin renderizar (faltaban `onDrawTurns`/`onWhatsApp` en la
  rama wide de `_DetailPanel`); 4 bottom sheets sin `catch` (fallos
  silenciosos); `SlowLoadHint` agregado.
- **SellerTandasCommandScreen (continuación 2026-07-27)**: resorteo bloqueado
  en Flutter y backend desde el primer pago o entrega. La validación cubre
  `Payments`, `IsDelivered` y `DeliveryDate` porque una entrega hecha desde
  Rutas puede registrar la fecha sin activar la otra bandera. El botón se
  deshabilita con explicación y el endpoint rechaza llamadas directas.
  Verificado con 3 pruebas .NET y 4 pruebas de modelo Flutter nuevas.
- **PointsScreen**: sin hallazgos — la más sólida de las 4. Nota: no
  distingue compradora/vendedora (ver Pendientes).

### Autenticación (continuación 2026-07-27)
- **Recuperación de contraseña**: los errores de OTP ahora se clasifican con
  `error=invalid_code|invalid_code_format` del backend, sin buscar palabras
  dentro del mensaje traducido. Al completar un nuevo código se limpia el
  banner anterior antes de volver a "Nueva contraseña".
- **Facebook Login**: los 409 recuperables
  (`facebook_profile_required`/`facebook_account_link_required`) conservan el
  formulario; `identity_conflict` y `verified_phone_change_not_allowed`
  muestran un estado terminal con explicación y botón para volver al inicio.
  También se descarta la credencial pendiente y se cierra la sesión del SDK de
  Facebook. Cubierto con pruebas de contrato y widget.

### Pantallas de compradora (15 pantallas/áreas, 3 grupos)
- **BuyerHomeScreen**: 🔴 tile "Lives en vivo" navegaba a `/live` sin
  `:businessId` (ruta inválida, pantalla de error de go_router en cada
  tap) — ahora va directo a la tienda en vivo si hay exactamente una.
- **StoreScreen**: 🔴 el link de "compartir tienda" es un callejón sin
  salida para quien lo recibe por primera vez (backend 404 si la cuenta no
  tiene ya Client/Follower ahí) — **no arreglado, es ambigüedad de
  producto** (¿debería haber storefront público? ver Pendientes).
- **TrackingScreen**: 🔴 **`DeliveryUpdate` de SignalR nunca llegaba** — el
  handler esperaba 2 argumentos posicionales pero el backend manda un solo
  objeto `{Status, Message}`; los cambios de estado en vivo
  (Confirmed→Shipped→InRoute→Delivered) solo se veían con pull-to-refresh
  manual. 🔴 **fuga de chat entre clientas** (backend, endpoint anónimo): el
  filtro de `GetChat` devolvía también el chat de otras clientas en la
  misma ruta y el chat interno chofer↔admin a cualquiera con el token de
  un solo pedido — ahora acota estrictamente a `DeliveryId` de esa entrega.
  🟡 "Confirmar pedido" causaba un flash de loading que desmontaba el
  widget antes de mostrar el snack de éxito — ahora actualiza el estado
  local en vez de recargar todo (mismo patrón que ya usaba
  `saveInstructions`).
- **TrackingScreen (continuación 2026-07-27)**: token, controller, chat y
  cliente SignalR ahora son `autoDispose`. El hub se conserva mientras
  Tracking o el chat tengan un consumidor y se cierra al salir del último.
  El cierre también cubre una conexión todavía en curso, evita emitir sobre
  streams cerrados y fuerza reconexión limpia si cambia el pedido. Cubierto
  con 3 pruebas nuevas de ciclo de vida.
- **OrderLinkScreen**: sin hallazgos reales, solo código muerto inofensivo.
- **Addresses**: 🔴 **no se podía borrar el pin GPS guardado** — un `null`
  explícito en JSON para lat/lng deserializa igual que el campo ausente en
  un `double?`, así que el backend nunca lo tocaba aunque la UI mostrara
  "Dirección guardada." El pin viejo podía seguir dirigiendo al chofer al
  lugar equivocado. Arreglado con una bandera explícita `ClearLocation` en
  el contrato (+ 2 tests nuevos en `BuyerAddressServiceTests`).
- **Account**: 🟡 `LinkedBy` nunca coincidía ("Vinculada por tu número" /
  "por un pedido" nunca se mostraba, siempre caía al genérico) — el
  backend mandaba el enum en PascalCase (`a.Mode.ToString()`) en vez de las
  mismas constantes kebab-case que sí usan los endpoints de reclamar.
- **Reserve**: doble-tap y mensaje de stock ya estaban bien. 🟡 al
  rechazarse por stock insuficiente, el stepper seguía ofreciendo el
  máximo viejo y el botón se re-habilitaba listo para fallar de nuevo con
  la misma cantidad — ahora reclampea a 1 e invalida el store para traer
  stock fresco.
- **Payments**: 🟡 sin `RefreshIndicator` (única pantalla de compradora sin
  ese patrón) — agregado.
- **Points/Tandas/Raffles/Notifications/Claim/Auth**: sin hallazgos 🔴.
  Varios 🟡/🟢 documentados pero no arreglados por ser ambiguos o de bajo
  impacto — ver Pendientes.

---

## 🔲 Pendientes — hallazgos con decisión de producto o de bajo impacto

Todo lo de arriba ya se auditó; esto es lo que quedó fuera a propósito,
por ser ambiguo o necesitar una decisión que no es mía tomar sola:

- **StoreScreen**: ¿debe existir un storefront público para quien recibe un
  link de "compartir tienda" sin ser ya clienta/seguidora? Hoy es un
  callejón sin salida (404). Confirmar si es intencional.
- **Points/RafflesScreen**: únicas pantallas compartidas compradora/
  vendedora sin el guard `isSeller` que sí tienen Home/Tandas/Account.
  Alcanzable si una vendedora abre el link público de su propia tienda.
  ¿Falta el guard, o Puntos/Sorteos de vendedora se administran fuera del
  app a propósito?
- `AddParticipantAsync` (chip de clienta standalone en Tandas) resuelve
  por nombre normalizado — mismo patrón de match implícito que causó B5 en
  OrderCreateScreen. Puede ser dedup intencional, confirmar con la dueña.
- `BuyerHomeScreen`: `SearchField` ("Busca tu pedido o una tienda") es
  100% decorativo, no filtra nada.
- Cuentas admin/conductor creadas fuera de la app (sin teléfono) no
  tendrían ruta de recuperación de contraseña — no confirmado contra
  producción, valdría un query rápido de `Accounts` antes de asumir.
- Código muerto de bajo riesgo, seguro de borrar cuando convenga: hub
  `/seller/settings`, stepper inline de bolsas en Rutas, `_EmptyState` en
  `claim_profile_screen.dart`, flag `needsOrderRescue` en `AuthController`.

---

## 🟡 Backlog UX de orders (decisión de producto — NO arreglados)

- **U7, U9 ya hechos** ✅ (U9: el panel ahora dice "Copiar mensajes (N)" y
  avisa "+N más ya creados" cuando hay más de 4).
- **U10/U11**: modo rápido no envía dirección. **Confirmado que así debe
  quedar** por el dueño. No arreglar.
- **U18**: verificado, **no es bug**. `CreateManual` nunca toca `Status` en
  la rama de fusión (merge) — el `status: 'Pending'` que manda Flutter se
  ignora ahí, no puede rebajar un pedido "Confirmed".

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
- **Los docs de progreso se desactualizan rápido — cruzar contra `git log`
  antes de confiar en ellos.** El 2026-07-27 se encontró que este mismo doc
  y `PROGRESO-APP-FLUTTER.md` llevaban 11-16 días sin reflejar trabajo real
  ya hecho: un módulo completo de Etiquetas/Inventario con NFC
  (`features/inventory/`, `features/labels/`, ~6,200 líneas, commit
  `472c322`, "Integracion de etiquetas") que no aparecía como hecho ni
  como pendiente en ningún lado, y el "Live Nivel 2" que este mismo doc y
  el de progreso describían como "sin construir todavía" cuando ya estaba
  completo de punta a punta. Antes de reportar "qué falta", correr
  `git log --oneline --stat` desde la fecha de la última actualización.
- Al aplicar un fix de concurrencia en el backend (candado/transacción),
  correr `dotnet test` (no solo `dotnet build`) — la suite usa el proveedor
  `InMemoryDatabase`, que no soporta transacciones reales y tira excepción
  en cualquier `BeginTransactionAsync()`. Para este tipo de carrera, seguir
  el patrón ya usado en `BuyerReserveService` (candado `SemaphoreSlim` en
  proceso, `ConcurrentDictionary` por llave), no una transacción +
  `pg_advisory_xact_lock` — eso rompió 3 tests existentes la primera vez.
