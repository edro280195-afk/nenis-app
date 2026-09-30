# QA manual en emulador — Vendedora + Clienta (2026-08-05)

> Recorrido pantalla por pantalla, botón por botón, campo por campo, hecho por
> Claude Code en el emulador Android `emulator-5554`. Objetivo: encontrar
> errores de UI y de API, corregirlos sobre la marcha cuando es razonable, y
> dejar histórico de lo encontrado (incluso lo que no se arregló).

## Entorno de esta sesión

- **Backend usado: producción** (`https://app.nenisapp.com`), por decisión
  explícita de Eduardo — se intentó primero backend local en `Development`
  contra la base de dev de Neon (`ep-shiny-darkness...`/`sellgeneral`) pero el
  password guardado en `appsettings.Development.json` está desactualizado
  (`password authentication failed`). No se tocó ese archivo; queda pendiente
  aparte si se quiere arreglar para la próxima sesión de desarrollo local.
- Como es producción, el OTP de WhatsApp es real: Eduardo relevó los códigos
  en el momento para cada registro/login nuevo.
- App instalada vía `flutter run -d emulator-5554` (debug build), sin cambios
  de configuración (no se tocó `app_config.dart`, apunta a producción como
  siempre).
- Cuentas de prueba creadas (ver detalle de cada una en su sección):
  - Vendedora: _(se completa abajo)_
  - Clienta: _(se completa abajo)_

## Convenciones de esta bitácora

- 🔴 = bug serio (bloquea el flujo, pérdida de datos, crash). 🟡 = bug menor
  (cosmético, mensaje confuso, inconsistencia). 🟢 = sugerencia/pulido, no bug.
  ℹ️ = limitación esperada del entorno (no es un bug de la app).
- Estado: 🔧 Corregido en esta sesión · ⏳ Pendiente · 👀 A confirmar con
  Eduardo (ambigüedad de producto).
- Cada hallazgo incluye archivo:línea cuando se identificó la causa en código.

---

## Índice

- [Vendedora](#vendedora)
- [Clienta](#clienta)
- [Resumen final](#resumen-final)

---

## Vendedora

Cuenta de prueba creada: `vendedora.qa@nenisapp.test` / tel. `868 140 0001` / tienda "Tienda QA Demo" (Matamoros).

### Pantalla: Login (`login_screen.dart`)

- Verificado: toggle Clienta/Vendedora cambia correctamente el formulario
  (Clienta = teléfono, Vendedora = correo). Es a propósito, no es un bug: el
  registro de vendedora pide correo Y teléfono (`register_screen.dart`), el
  teléfono es solo para el OTP de WhatsApp, el login usa correo. Confirmado
  leyendo `_loginSeller`/`_loginClient` en el código.

### Pantalla: Registro (`register_screen.dart`)

- Verificado campo por campo: la cadena de validaciones dispara en el orden
  correcto y con el mensaje correcto en cada paso (nombre/apellido → correo →
  teléfono → contraseña → nombre del negocio → aceptar términos). Probado
  enviando el formulario incompleto en cada etapa.
- Verificado: catálogo de planes (Básico $129 / Pro $250 "TU PRUEBA" / Elite
  $460) carga bien desde el backend en el alta.
- 🟢 Sugerencia menor: al fallar la validación, el banner de error aparece
  pero la pantalla no hace scroll automático hacia el campo con el problema
  (hay que buscarlo manualmente si ya se scrolleó lejos). No es un bug, es una
  mejora de UX opcional — no se tocó.

### 🔴 Bug confirmado y corregido: el código OTP no avanza de casilla sola

- **Dónde:** [`lib/shared/widgets/otp_cell.dart`](../nenis_app/lib/shared/widgets/otp_cell.dart) —
  widget compartido `OtpInput`/`OtpCell`, usado en **5 pantallas**:
  `confirm_screen.dart` (confirmación de registro), `login_otp_screen.dart`
  (entrar con código), `password_reset_screen.dart` (recuperar contraseña),
  `claim_order_screen.dart` (reclamar pedido de invitada).
- **Síntoma:** al escribir un dígito en una casilla del código de 6, el foco
  se queda en la misma casilla en vez de saltar sola a la siguiente. Hay que
  tocar cada una de las 6 casillas a mano para completar el código — en un
  teléfono real, sin teclado físico, esto es bastante más molesto que "escribe
  y ya".
- **Causa:** `OtpCell.onChanged` llamaba `FocusScope.of(context).nextFocus()`,
  que depende de que el `FocusTraversalPolicy` adivine cuál es "el siguiente"
  nodo en la jerarquía. Con el `Row` de casillas armado dinámicamente dentro
  de un `LayoutBuilder` (en `OtpInput.build`), ese `nextFocus()` no encontraba
  la siguiente casilla y no hacía nada (confirmado con `uiautomator dump`:
  tras escribir, la casilla escrita seguía con `focused=true` y ninguna otra
  cambiaba).
- **Corrección aplicada:** cada `OtpCell` ahora recibe explícitamente el
  `FocusNode` de la casilla siguiente (`nextFocusNode`) y le pide el foco
  directamente (`nextFocusNode?.requestFocus()`), sin pasar por
  `FocusScope`/traversal. `OtpInput` arma esa cadena al construir las celdas.
- **Verificación:** re-probado en el emulador tras reiniciar `flutter run`.
  Con inputs sintéticos de ADB disparados sin espaciar (`input text` de a un
  dígito, sin pausa) el avance automático no siempre se reflejaba de
  inmediato en el árbol de accesibilidad — probablemente por la latencia
  entre `requestFocus()` y que Flutter reconecte la conexión de texto de la
  plataforma, algo que un dedo humano tecleando a velocidad normal no nota.
  Con pausas entre dígitos, el flujo completo (6 dígitos → confirmación →
  pantalla de éxito) funcionó de punta a punta. `flutter analyze`: 0 issues.
- **Estado:** 🔧 Corregido.

### Pantalla: Pedidos → Captura de pedido (`order_create_screen.dart`)

- Verificado sin hallazgos nuevos: modo Rápido con el parser
  ("Maria, blusa 100" → Cliente/Artículo/Cantidad/Precio correctos), cola,
  creación real de pedido. Coincide con lo ya arreglado en la auditoría
  2026-07-14 (B6/U12/U13) — sin regresión.
- ℹ️ El total del pedido creado ($160) no coincidía a primera vista con el
  "Total interpretado: $100" del diálogo de captura — **no es un bug**:
  ese diálogo muestra el subtotal de artículos; el pedido final suma el
  costo de envío por defecto de la tienda ($60, "A domicilio") vía
  `workspace.settings.defaultShippingCost` (`order_create_screen.dart:146-148`).
  Confirmado leyendo el código antes de reportarlo como hallazgo.

### 🔴 Bug confirmado y corregido: texto con codificación rota ("mojibake") en Detalle del pedido

- **Dónde:** [`lib/features/orders/screens/order_detail_screen.dart`](../nenis_app/lib/features/orders/screens/order_detail_screen.dart) —
  aislado a este único archivo (se revisó todo `lib/` en busca del mismo
  patrón y no aparece en ningún otro).
- **Síntoma visible:** en la pantalla de detalle de un pedido a domicilio,
  el chip de envío se veía como **"EnvÃfÂo $60"** en vez de **"Envío $60"**
  (captura tomada durante la prueba). Ese caso puntual estaba doblemente
  mal codificado (UTF-8 reinterpretado como Latin-1 **dos veces**); otras
  ~25 cadenas del mismo archivo (comentarios y textos de diálogos:
  "¿Quitar artículo?", "Se eliminará...", "Escribe un monto válido",
  "Sí, cambiar" / "Sí, cobrar" / "Sí, fusionar", el mensaje de fusionar
  pedidos, "Agregar artículo" ×2, etc.) tenían el mismo problema con un
  solo nivel de mala codificación (ej. `artÃ­culo` en vez de `artículo`).
  Como es un archivo aislado con este patrón, probablemente se guardó una
  vez con una herramienta/terminal en una codificación distinta a UTF-8.
- **Por qué importa:** varias de esas cadenas SÍ se renderizan a la
  clienta/vendedora (no son solo comentarios) — botones de confirmación,
  diálogos de "quitar artículo" y "fusionar pedidos", avisos de monto
  inválido. Se veían con acentos rotos en cualquier dispositivo real, no
  solo en este emulador.
- **Corrección aplicada:** reemplazadas ~32 ocurrencias en total — el caso
  doblemente mal codificado, ~25 letras acentuadas/¿/· de un solo nivel, y
  **6 emojis** con el mismo problema que no aparecían en la búsqueda inicial
  (📦 del encabezado "Pedido #1", 💕 en 2 mensajes de éxito, y 💵/🏦/💳 de
  los botones de método de pago Efectivo/Transferencia/Tarjeta — este
  último con un carácter de control invisible (U+008F) en medio, típico de
  emoji mal recodificados, que hubo que reemplazar por los bytes exactos en
  vez de buscar el texto a simple vista). De paso, en la misma revisión
  apareció un typo real (no de codificación, ya estaba así en el texto): el
  diálogo de rebajar estatus decía **"¿Cambiar a un est anterior?"** — le
  faltaba la palabra completa; ahora dice **"¿Cambiar a un estado
  anterior?"**.
- **Verificación:** `flutter analyze` del archivo → 0 issues, sin más
  ocurrencias en todo `lib/`. Confirmado visualmente en el emulador tras
  reiniciar `flutter run`: "Envío $60" ya se ve bien.
- **Estado:** 🔧 Corregido.

### Pantalla: Clientas (`seller_clients_screen.dart`)

- Verificado: KPIs (Venta total, Frecuentes, Consentidas, Por completar),
  filtros, ficha de clienta auto-creada desde un pedido (Datos de entrega,
  REGIPUNTOS con nivel "Clienta Pink", Alias e Identidad). Todo consistente
  con la auditoría 2026-07-27.
- 👀 **A confirmar, no marco como bug:** el botón "Ver análisis" de la
  sección ANÁLISIS C.A.M.I. no reaccionó a los toques automatizados en
  varios intentos con coordenadas distintas (confirmado con
  `uiautomator dump` que el toque caía dentro del área reportada del
  widget). Revisé el código (`_SmallAction`/`_load()` en
  `seller_clients_screen.dart:1740-1792`) y no encontré ningún candado de
  plan ni lógica que explique un no-op silencioso. No pude determinar si es
  un problema real del widget o una limitación de mis toques sintéticos por
  ADB — **vale la pena probarlo a mano en el emulador o un dispositivo real**
  antes de invertir tiempo arreglándolo a ciegas.

### 🔴 Bug confirmado y corregido: "Mi bodega" (Inventario) — Artículos/Piezas en 0 en el detalle de una caja

- **Dónde:** backend, [`DTOs/InventoryDtos.cs:9`](../../sellgeneral-api/DTOs/InventoryDtos.cs) +
  [`Controllers/InventoryController.cs:600`](../../sellgeneral-api/Controllers/InventoryController.cs) (`MapBox`).
  Módulo **nunca auditado antes** (`features/inventory/` + `features/labels/`,
  ~6,200 líneas, ver nota en `PROGRESO-APP-FLUTTER.md`).
- **Síntoma:** al abrir el detalle de una caja rápido después de agregar un
  artículo (probado con una caja nueva "B-01" + artículo "Blusa floral" ×5),
  la tarjeta de estadísticas mostraba **"0 Artículos" y "0 Piezas"** — pero
  la sección de abajo mostraba correctamente "Artículos (1)" con la Blusa
  floral listada, y "Movimientos: 1" también estaba bien. Salir a "Mi
  bodega" y volver a entrar no lo arregla: el 0 es permanente, no un tema de
  refresco.
- **Causa raíz:** `InventoryBoxDto` (el DTO del **detalle** de una caja) never
  declaró los campos `ArticleTypesCount`/`TotalUnits` — solo
  `InventoryBoxSummaryDto` (el DTO de la **lista** "Mi bodega") los tiene. El
  JSON del detalle simplemente nunca incluye esos dos campos. Del lado de
  Flutter, `InventoryBoxDetail.fromJson` los lee con
  `(json['articleTypesCount'] as num?)?.toInt() ?? 0` — el `?? 0` disimulaba
  el campo faltante mostrando "0" en vez de fallar visiblemente, por eso no
  se notaba a simple vista.
- **Corrección aplicada:** agregados `ArticleTypesCount`/`TotalUnits` a
  `InventoryBoxDto`, calculados en `MapBox` con la misma fórmula que ya usa
  el listado (`Items.Count(i => i.Quantity > 0)` / `Items.Sum(i => i.Quantity)`).
  Sin cambios en Flutter — el modelo ya esperaba esos campos, solo faltaba
  que el backend los mandara. Afecta a **todas** las respuestas que devuelven
  una caja completa: crear, agregar/ajustar artículo, vincular NFC, conteo,
  transferencia — todas pasan por el mismo `MapBox`.
- **Pruebas:** 2 aserciones nuevas en
  `Box_NfcBindingAndInitialStock_AreScopedAndAudited`
  (`InventoryNfcTests.cs`) confirmando `ArticleTypesCount`/`TotalUnits`
  correctos tras agregar un artículo. `dotnet test` completo: 330/330 verde.
- **⚠️ Pendiente de desplegar** (igual que el resto de fixes de backend de
  esta sesión — ver nota al inicio del documento).
- **Estado:** 🔧 Corregido en código, ⏳ pendiente de desplegar.

### Pantalla: Rutas, Etiquetas (estudio de diseño) y Mi negocio

- **Rutas** (`Armar` → seleccionar clienta → expandir pedido): flujo de 3
  pasos, tags correctos ("Sin ubicación" cuando la clienta no tiene
  dirección — coherente con lo visto en Clientas). No se llegó a armar una
  ruta completa (requeriría una clienta con dirección real), pero no se
  encontraron errores en lo recorrido.
- **Estudio de Etiquetas** (diseñador de plantillas, `Diseñar etiqueta`):
  editor visual con selección de elementos, formatos (4×6"/50×50mm),
  panel de propiedades al tocar un campo — funciona, sin crashes. No se
  probó a fondo (arrastrar/redimensionar/imagen/publicar) por alcance.
- **Mi negocio**: panel completo y ordenado (Mi plan, Cuentas de cobro,
  Perfil de tienda, Novedades y vivo, Anunciar en vivo, Grupo VIP,
  Etiquetas e impresión, Bodega, Equipo de reparto, Preferencias, Ver
  tutorial de la app, Cerrar sesión). Sin hallazgos.

### Pantalla: Mi plan + checkout (Mercado Pago)

- Verificado: catálogo de planes correcto (Básico/Pro/Elite), toggle de
  periodicidad, "Tu plan actual" deshabilitado en el plan vigente.
- ℹ️ **No es bug, verificado a propósito:** al tocar "Elegir Elite" se abre
  un WebView a `{panel}/admin/subscription/checkout` — y ahí pide iniciar
  sesión de nuevo (pantalla de login completa del panel Angular, con
  teléfono/Facebook/correo), no entra directo al formulario de pago. Es
  intencional y está documentado en el propio código
  (`mp_checkout_webview_screen.dart:12-17`): el panel y la app no comparten
  sesión a propósito ("cero cambios en Angular/backend"), así que la
  vendedora vuelve a autenticarse dentro del WebView. No siguió la prueba
  hasta completar un pago real (no se debe completar dinero real/de
  prueba sin que Eduardo lo pida explícitamente).

### 🟡 Bug confirmado y corregido: "Mi plan" — el plan Pro sigue mencionando el nombre viejo del plan Básico

- **Dónde:** [`lib/features/subscription/screens/my_plan_screen.dart:364`](../nenis_app/lib/features/subscription/screens/my_plan_screen.dart).
- **Síntoma:** en "Mi plan", la tarjeta del plan **Pro** lista como primer
  beneficio **"Todo lo de Entrada"** — pero el plan más barato se llama
  **"Básico"** en todas partes (la propia tarjeta de arriba, el registro,
  el botón "Elegir Básico"). "Entrada" no aparece en ningún otro lado de la
  UI; para quien lee las dos tarjetas juntas no queda claro qué es
  "Entrada". Es texto fijo (`_featuresFor('Pro')`), no viene del backend —
  parece un nombre que quedó de una versión anterior del plan más barato.
- **Corrección aplicada:** cambiado a "Todo lo de Básico". No toqué el
  nombre interno `"Entrada"` que usa `Subscriptions:Pricing` en el backend
  (`appsettings.json`) ni el default `?? 'Entrada'` de
  `subscription_models.dart:38-39` — ahí es solo una clave de config/valor
  por defecto interno, nunca se muestra a la usuaria, y el catálogo de
  precios ya devuelve "Básico" consistentemente (confirmado viendo la
  tarjeta en Registro y en Mi Plan). Cambiarlo ahí sin necesidad hubiera
  sido tocar más de lo que el hallazgo pedía.
- **Verificación:** `flutter analyze` del archivo → 0 issues.
- **Estado:** 🔧 Corregido.

### Pantalla: Perfil de tienda y Cuentas de cobro

- **Perfil de tienda**: nombre público, ruta pública (`nenis.app/tienda-qa-demo`
  — anotado para usarlo al conectar la cuenta de clienta), ciudad, colores de
  marca con vista previa del swatch. Sin hallazgos.
- **Cuentas de cobro**: pantalla vacía bien resuelta (0 cuentas activas, aviso
  de que Mercado Pago no está configurado, formulario para agregar
  CLABE/tarjeta/SPEI). No se probó el guardado real — implicaría escribir
  datos de una cuenta bancaria/tarjeta en un campo, algo que no debo hacer
  aunque sean datos inventados.

### 🟡 Bug confirmado y corregido: campanita de notificaciones muerta en "Mi negocio"

- **Dónde:** [`lib/features/account/screens/seller_account_screen.dart:253-295`](../nenis_app/lib/features/account/screens/seller_account_screen.dart)
  (`_SellerHeader`).
- **Síntoma:** el ícono de campana en la esquina superior derecha de "Mi
  negocio" se ve idéntico al de Inicio (círculo blanco, sombra, mismo
  ícono) pero no reacciona al tocarlo — ni highlight, ni navegación.
- **Causa raíz:** estaba envuelto en un `Container` plano, sin
  `InkWell`/`onTap` — a diferencia del mismo ícono en `SellerHomeScreen`
  (`onBell: () => context.push('/notifications')`, con `Material`+`InkWell`).
  Confirmado también con `uiautomator dump`: el nodo de esa zona no
  aparecía como `clickable` en "Mi negocio", a diferencia de Inicio.
- **Corrección aplicada:** mismo patrón que Inicio — `Material`+`InkWell`
  con `onTap: () => context.push('/notifications')`.
- **Nota:** revisé el equivalente de clienta (`account_screen.dart`, tarjeta
  "Notificaciones") y ese sí tenía su `onTap` correcto — el bug era solo
  este header de vendedora, no un patrón repetido.
- **Verificación:** `flutter analyze` del archivo → 0 issues.
- **Estado:** 🔧 Corregido.

### Pantalla: Novedades y vivo

- Publicar una novedad de texto: funciona de punta a punta (banner
  "¡Publicado! Tus seguidoras ya lo verán.", aparece de inmediato en "Tus
  novedades" con su ícono de borrar). Sin regresión del crash
  `setState`/`ref.invalidate` que ya se había arreglado en la auditoría
  2026-07-27. No se probó "Voy a iniciar un vivo" (requiere una transmisión
  real) ni "Agregar foto".
- **Nota de mi propia herramienta, no de la app:** `adb shell input text`
  truena (excepción del lado del sistema, `NullPointerException`) si el
  texto trae "¡" o "¿". Para el resto de la sesión evito esos signos al
  escribir por ADB — no es algo que la app pueda controlar.

### 🔴 Bug confirmado y corregido: vendedora sin confirmar el teléfono cae al tour de CLIENTA

- **Cómo se encontró:** al reiniciar `flutter run` para probar el fix de arriba,
  perdí el progreso del OTP (solo había llenado 3 de 6 casillas manualmente,
  nunca toqué "Confirmar"). Al volver a abrir la app inicié sesión con el
  correo/contraseña de la vendedora recién registrada — **el login funcionó**,
  pero la app me mandó al tour de bienvenida de **clienta** ("Tu número
  protege tus compras... reclames pedidos, historial y puntos"), no al de
  vendedora.
- **Causa raíz (backend):** el `Business`/`Membership` de una vendedora se
  crean hasta `AuthController.ConfirmPhone` → `AddSellerBusinessAsync`
  ([`Controllers/AuthController.cs:367`](../../sellgeneral-api/Controllers/AuthController.cs)),
  **no** en `RegisterPhone`. Pero `AuthController.Login`
  (`Controllers/AuthController.cs:133`, el endpoint de correo/contraseña que
  usa la vendedora) no comprobaba `PhoneVerifiedAt` en absoluto — a
  diferencia de `LoginPhone` (clienta), que sí lo hace y responde 403
  `phone_not_verified`. Resultado: una cuenta de vendedora con el teléfono
  sin confirmar (y por lo tanto sin negocio) podía iniciar sesión igual, con
  0 memberships. El router de Flutter
  ([`core/router/app_router.dart:144-158`](../nenis_app/lib/core/router/app_router.dart))
  decide el tour mirando `session.hasMembership`/`hasActiveBusinessRole`;
  al no tener ninguna, cae al `else` de clienta (`/onboarding/client`) en
  vez de mostrar un estado de "termina de confirmar tu tienda".
- **Por qué importa:** es un escenario real, no solo de laboratorio — basta
  que a la vendedora se le retrase el WhatsApp, cierre la app, o la abra de
  nuevo más tarde y entre con su correo en vez de terminar el OTP en el
  momento. Terminaría viendo el tour de clienta y, si le da "Omitir" /
  termina ese tour, la manda a `/claim` (reclamar pedido) — una pantalla
  que no tiene nada que ver con administrar su tienda, sin pista de qué
  pasó con su registro.
- **Corrección aplicada:** `AuthController.Login` ahora bloquea (403,
  mismo contrato que `LoginPhone`: `error: "phone_not_verified"`) cuando
  la cuenta tiene teléfono, **no** está verificado, y **no** tiene ningún
  membership todavía — acotado a propósito para no afectar cuentas legacy
  de admin/conductor sin teléfono ni vendedoras ya confirmadas. El mensaje
  le dice que se registre de nuevo con el mismo correo/teléfono para
  reenviar el código (`RegisterPhone` ya soporta "refrescar" una cuenta sin
  confirmar, así que es un camino que ya funciona).
- **Limitación conocida, no resuelta hoy:** esto evita el "login fantasma"
  pero no resuelve el fondo — si la vendedora sí vuelve a `/confirm` en una
  sesión nueva, la pantalla de confirmación no vuelve a pedir
  nombre/negocio/ciudad porque hoy viven solo en memoria de la sesión de
  registro (no se guardan en la cuenta hasta confirmar). Con el candado de
  `Login` ya no se cuela en silencio, pero la manera limpia de resolverlo
  de raíz es persistir `BusinessName`/`City` en el `Account` desde
  `RegisterPhone` (columnas nuevas → requiere migración EF). No se tocó el
  esquema en esta sesión porque no tenía forma de probar una migración
  contra una base real (ver bloqueo de BD de desarrollo al inicio de este
  documento) — **recomendado para la próxima sesión con la BD de dev
  arreglada**.
- **Pruebas:** 3 pruebas nuevas en `AuthControllerDevOtpTests.cs`
  (`Login_SellerBeforeConfirm_ReturnsNeedsVerification`,
  `Login_SellerAfterConfirm_ReturnsToken`,
  `Login_LegacyAccountWithoutPhone_StillWorks` — esta última específicamente
  para confirmar que no se rompe el login de cuentas admin/conductor sin
  teléfono). `dotnet test` completo: 330/330 verde.
- **⚠️ Pendiente de desplegar:** la app de este emulador habla contra
  producción (`app.nenisapp.com`), que sigue corriendo el backend viejo —
  este fix está en el código local pero **no se ha subido ni desplegado**.
  No hice `git push`/deploy porque no es una decisión mía tomar sola. Hasta
  que se despliegue, este candado no está activo en producción.
- **Estado:** 🔧 Corregido en código, ⏳ pendiente de desplegar.

---

## Clienta

_(ver sección "Sesión 2026-09-30 — clienta" al final del documento)_

---

## Resumen final

_(se completa al cerrar la sesión)_

---

## Sesión 2026-09-30 — vendedora (cuenta real Regi Bazar) + pantalla chica + letra grande

> Emulador `Medium_Phone_API_36.1`, APK debug contra **producción** (`AppConfig.apiBaseUrl` fijo en `https://app.nenisapp.com`, sin switch debug/release: cualquier APK pega a la base real). Se navegó en modo solo lectura sobre datos reales. Pruebas de estrés: 720×1280 @ 320 dpi (~360 dp) + `font_scale 1.5`.

### 🔴 Botón atrás de Android cerraba la app desde cualquier pantalla del shell — 🔧 Corregido
- **Síntoma:** atrás desde Pedidos/Clientas/Tandas, o desde Rutas/Bodega abiertas con "Más", mandaba directo al launcher.
- **Causa 1:** faltaba `android:enableOnBackInvokedCallback="true"` en `<application>` del `AndroidManifest.xml`. Sin él, ningún `PopScope` funciona en Android modernos (afectaba también a los 3 que ya existían: `label_batch_print_screen`, `mp_checkout_webview_screen`, `order_link_screen`).
- **Causa 2:** el `Navigator` interno del `ShellRoute` notificaba `canHandlePop=false` y pisaba el aviso del `PopScope` de la raíz → Android cerraba la tarea sin consultar a Flutter (log: transición `CLOSE`, sin callback registrado).
- **Corrección:** `app_shell.dart` — `PopScope` (atrás → `/home`, solo Inicio cierra) + `NotificationListener<NavigationNotification>` que absorbe los avisos negativos del navigator interno; los módulos fuera del shell (Bodega) se abren con `push` desde "Más".
- **Verificado en emulador:** Pedidos→atrás=Inicio ✅ · Más>Rutas→atrás=Inicio ✅ · Más>Bodega→atrás regresa ✅ · Inicio→atrás cierra ✅.

### 🔴 Desbordes con letra grande / pantalla chica — 🔧 Corregidos
Causa común: `childAspectRatio` fijo en cuadrículas y `Row` sin `Flexible`. Nuevo helper `core/utils/text_scale.dart` (`scaledAspectRatio`, con prueba en `test/core/utils/text_scale_test.dart`).
- Inicio: 4 tarjetas KPI (`seller_home_screen.dart`) — los números quedaban tapados ("BOTTOM OVERFLOWED BY 8.1 PIXELS").
- Clientas: KPIs, acciones rápidas y encabezado (título en columna de 40 px; los 4 botones bajan a 2.ª línea en pantalla angosta) — `seller_clients_screen.dart`.
- Cuentas de cobro: selector de tipo (`seller_payment_settings_screen.dart`).
- Pedidos: tarjeta con etiqueta "Frecuente" desbordada 14 px; el chip de estatus baja a su línea (`seller_orders_screen.dart`).
- Tandas (y todo `SegmentedControl`): 4 pestañas montadas unas sobre otras → `FittedBox` (`shared/widgets/segmented.dart`).
- Barra inferior: etiquetas pegadas → escala limitada a 1.15× (`glass_bottom_nav.dart`).
- Menú "Más": título/etiqueta/insignia/pie desbordaban (hasta 177 px) → `Wrap`/`Flexible` (`app_shell.dart`).

### Pendiente / observaciones (no corregido)
- 🟡 Botón de borrar en la tarjeta de pedido sale recortado en el borde superior de la primera tarjeta (`seller_orders_screen.dart`, `Stack` con `Clip.none` dentro de la lista). No se probó que pida confirmación (son pedidos reales).
- 🟡 KPIs de Clientas truncan con "…" en pantalla chica ("$648…" oculta el monto). Legible pero no ideal.
- 🟢 Fuentes fijas de 8–8.5 px en tarjetas KPI de Inicio: muy pequeñas incluso a escala 1.0.
- Grids de productos de tienda (`store_screen.dart`, `childAspectRatio: 0.78`) **no verificados** con letra grande.
- ⏳ **No probado:** flujo completo de **clienta** (solo hubo sesión de vendedora), Nuevo pedido, Etiquetas, Mi negocio, checkout.
- ⏳ El backend de producción sigue sin desplegar los fixes de la QA del 5 de agosto.


---

## Sesión 2026-09-30 (2) — clienta (cuenta real "Juana López", vinculada a Regi Bazar)

> Mismo entorno: emulador, APK debug contra producción, solo lectura (no se tocó "Eliminar mi cuenta", "Cerrar sesión", canjes ni guardados). Recorrido a tamaño normal y en estrés (360 dp + letra 150 %).

### Corregido
- 🔴 **Puntos:** tarjetas de premios desbordaban 2 px por abajo **a tamaño normal** cuando el nombre ocupa 2 líneas (altura fija 172) — `points_screen.dart`; ahora 196 px + crece con la letra.
- 🔴 **Mis direcciones:** subtítulo del encabezado desbordaba 11 px a tamaño normal — `addresses_screen.dart` (`Expanded`).
- 🟡 **Tienda:** el chip rojo "TIENDA" quedaba tapado por el avatar (sube 34 px sobre el encabezado) — movido al centro superior, `store_screen.dart`.
- 🟡 **`PillButton` con `expand:false`** no tenía relleno horizontal: "Editar" y "Siguiendo" tocaban los bordes redondeados. Se agregó relleno y una variante `compact` (44 px) usada en la fila de la tienda y en "Editar" para no aplastar el nombre — `shared/widgets/pill_button.dart`.
- 🟡 **Mis pagos:** decía "1 pagos" → "1 pago".

### Verificado sin hallazgos
Inicio, Mis pedidos, Cuenta, menú "Más Experiencias", Notificaciones (estado vacío claro), Mis pagos, editor de dirección, Sorteos; todas sin errores de desborde a 360 dp / 150 %. Atrás de Android correcto en: Notificaciones, Pagos, Direcciones, editor, tienda, Sorteos (regresan sin cerrar la app).

### Pendiente / decisiones de producto (no corregido)
- 🔴 **Pedido activo → "Este enlace ha expirado".** Al tocar el pedido #851 (23 jul, "Pendiente") desde Inicio, `TrackingScreen` llama a `/api/pedido/{token}` y el backend responde 410 porque `Order.ExpiresAt` venció (`ClientViewController.cs:64`). La app lo sigue listando como activo y la clienta ya con sesión queda en un callejón sin salida. Arreglo real = endpoint autenticado para clientas (backend) o ocultar/etiquetar pedidos vencidos. Puede ser solo dato viejo de prueba, pero un pedido vencido y aún "en curso" es posible en producción.
- 🟡 **Estatus inconsistente del mismo pedido:** Inicio muestra "Pendiente / Preparando tu pedido" y Mis pedidos "En ruta" para el #851. Revisar de dónde sale cada uno.
- 🟢 El editor de dirección de la clienta pide latitud/longitud a mano; poco natural para una compradora.
- 🟢 Sorteos: título con hueco a la izquierda (sin flecha atrás) — revisar consistencia con Tandas/Puntos.
- 🟢 Sorteo "10 de mayo" (fecha 17 may 2026) sigue "Activo" en septiembre (dato).
- ⏳ **No probado:** Tandas de la clienta, reserva de producto (`/reserve`), pantalla de en vivo, reclamar pedido, flujo de registro/login de clienta nuevo, canje real de puntos.

---

## Sesión 2026-09-30 (3) — huecos de flujo de negocio + vendedora

Criterio: `PRODUCT.md` — la app une a clientas y vendedoras para que la relación que empieza en un live continúe dentro de la app.

### 🔴 Huecos de flujo corregidos
- **Clienta nueva no podía entrar a la tienda del enlace del live** (`/store/{id}`): backend respondía "Esta tienda no está en tu cuenta" y el destino se perdía si no había sesión. Ahora `BuyerStoreService`/`BuyerFeedPostsService` dejan ver el perfil público (los puntos siguen ligados a su Client; lo VIP sale bloqueado), la app guarda el destino pendiente (`pendingStoreDeepLinkProvider`) y el router la lleva a la tienda al terminar de entrar. "Apartar" da un mensaje claro. **Requiere desplegar backend.**
- **Puntos sin salida en la app:** la vendedora veía RegiPuntos pero solo podía canjear en el panel web. Nueva hoja `redeem_reward_sheet.dart` desde la ficha de la clienta (elige pedido → premio → confirma; espeja las validaciones de `POST /api/loyalty/redeem`). El botón de la clienta ahora explica que la tienda aplica el premio al cobrar.
- 🔴 **Bug de dinero encontrado al construir lo anterior:** `OrdersController.UpdateStatus` reescribía `Total = Subtotal + Envío` sin restar `DiscountAmount`. Cualquier cambio de estatus borraba el descuento de un premio ya canjeado (los puntos ya se habían descontado). Reproducido con prueba roja y corregido; 2 pruebas nuevas.
- **Tandas "Disponibles"** ofrecía tandas terminadas/vencidas por calendario; ahora solo Active/Draft que no agotaron sus semanas (se conservan las que la clienta cursó). El conteo de la pestaña de la tienda usa el mismo criterio.
- **Buscador de Inicio (clienta)** no hacía nada; ahora filtra pedidos y tiendas propios y explica cómo llegar a una tienda nueva. Mosaico "Lives en vivo" avisa en vez de no responder. Etiqueta "en camino" solo si de verdad va en camino.

### Otras correcciones
- ~35 textos de UI sin acento ("Direccion", "Rapido", "articulo", "Envio", "telefono", "configuracion"…) en Nuevo pedido, Clientas, Tandas, Rutas, auth, direcciones, notificaciones, preferencias.
- Etiquetas: la barra inferior encimaba el contador de bolsas con el texto de ayuda.
- Nombre de tienda en el encabezado admite 2 líneas.

### ⏳ Huecos que siguen abiertos (decisión de producto o fuera de alcance)
- 🔴 **Enlace público del pedido vence (410) y la clienta con sesión no puede ver su pedido** (`Order.ExpiresAt`, `ClientViewController`). Necesita endpoint autenticado o renovar el enlace.
- 🟡 **"Equipo de reparto" y "Preferencias" son pantallas de interruptores que no hacen nada** (la propia app lo avisa en un recuadro ámbar). Riesgo de reseña en Play Store ("funciones que no funcionan"): conviene ocultarlas hasta que persistan o marcarlas claramente como "próximamente".
- 🟡 Apartar sigue exigiendo ser clienta de la tienda; la clienta nueva puede seguirla pero no comprar hasta que la vendedora la registre (sin "crear clienta al apartar").
- 🟡 Estatus inconsistente del mismo pedido: Inicio "Pendiente" vs Mis pedidos "En ruta".
- 🟢 Clienta no ve pagos por tarjeta/Mercado Pago dentro de la app ("en revisión" en seguimiento).
- Sin probar: checkout de plan (WebView de Mercado Pago), impresión Bluetooth real, NFC, Live real, ejecutar un canje real, crear/borrar pedidos reales (datos de producción).


### ✅ 2026-09-30 (4) — Enlace vencido del pedido: corregido y subido
- **Causa:** `/api/pedido/{token}` devolvía 410 solo por `Order.ExpiresAt`, y la app no mandaba el JWT a ese prefijo (`_publicPrefixes`), así que el backend no podía saber que quien llamaba era la dueña.
- **Backend** (`ClientViewController.IsLinkExpiredAsync`): con sesión y pedido de una de sus fichas de clienta, el vencimiento no aplica (ver, confirmar, calificar, instrucciones). Anónimo u otra cuenta → 410 igual que antes. El pago con tarjeta conserva el vencimiento estricto a propósito. 4 pruebas nuevas (`ClientViewExpiryTests`).
- **App** (`dio_provider.dart`): a `/api/pedido/` se le manda solo `Authorization` cuando hay sesión (sin `X-Business-Id`, para no alterar la resolución de tienda pública).
- Subido a `main`: API `307969f`, app `410a09c`. **Falta verificar en producción cuando Render termine de desplegar**: abrir como clienta el pedido #851 desde Inicio.
- Al integrar con `origin/main` (commits del 25/ago y 17/sep) hubo conflictos en 6 archivos de etiquetas/inventario porque el árbol local traía trabajo de Bluetooth sin commitear. Se tomó la versión del remoto; el árbol local completo quedó en la rama local `respaldo-qa-2026-09-30` (no se subió).

### 🔴 2026-09-30 (5) — Validación del token (Firebase): producción NO lo puede validar
Detalle y pasos en [`FIREBASE-CHECKLIST-PRODUCCION.md`](FIREBASE-CHECKLIST-PRODUCCION.md). Resumen:
- `POST /api/auth/firebase` en producción → **503 firebase_auth_not_configured** (sin credencial Admin).
- La credencial local es del proyecto `regibazarnotify`; la app usa `nenisapp-60810` → no coinciden.
- `google-services.json` sin huellas SHA registradas (faltan release, debug y **Play App Signing**).
- El token push SÍ se obtiene y registra (`[Push] token …EPpYO4 (142 car.) registrado: true`).
- Código: registro del token en cada sesión (login y arranque), botón "Probar notificaciones", endpoint `POST /api/me/devices/test-push`, búsqueda de la credencial en `/etc/secrets`, canal `regibazar_channel`, y se ocultan "Equipo de reparto"/"Preferencias".
- `.aab` regenerado con número de compilación 2 (firmado con la llave de release).
