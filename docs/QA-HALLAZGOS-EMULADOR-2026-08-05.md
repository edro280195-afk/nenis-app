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

_(pendiente)_

---

## Resumen final

_(se completa al cerrar la sesión)_
