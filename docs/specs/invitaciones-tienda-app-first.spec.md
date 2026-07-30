# Feature: Invitaciones de tienda app-first

**Estado:** Dirección de producto aprobada  
**Fecha:** 2026-07-27  
**Producto principal:** Aplicación móvil Neni's  
**Rol de la web:** Puente mínimo no indexable para abrir o instalar la app

## 1. Resumen

Las vendedoras podrán compartir una invitación segura a su tienda para atraer
nuevas clientas a Neni's. El enlace deberá abrir la tienda directamente en la
app, conservar el destino durante instalación, registro o inicio de sesión y
permitir que una persona nueva conozca, siga y compre en esa tienda sin salir
de Neni's.

La página web no será un storefront ni un producto paralelo. Solo mostrará la
identidad mínima de la tienda y las acciones necesarias para abrir o instalar
la aplicación.

## 2. Valor para las usuarias

### Para la clienta

- Llega directamente a la tienda que le compartieron.
- No necesita volver a buscarla después de registrarse.
- Puede conocerla y seguirla sin haber comprado antes.
- Puede realizar su primer apartado completamente dentro de Neni's.
- Conserva en un solo lugar tiendas, compras, puntos, avisos y entregas.

### Para la vendedora

- Convierte conversaciones de Facebook, Messenger o WhatsApp en instalaciones
  y registros de Neni's.
- Puede compartir, revocar y regenerar su invitación desde la app.
- No llena su directorio con visitantes: una cuenta se convierte en `Client`
  únicamente al realizar una acción comercial concreta.
- Puede medir aperturas, registros, nuevas seguidoras y primeras compras
  originadas por su invitación.

### Para Neni's

- La app permanece como centro de la experiencia.
- El enlace compartido funciona como canal de adquisición medible.
- El modelo no se convierte prematuramente en un marketplace web.

## 3. Principios de producto

1. **App primero:** toda interacción útil ocurre en Flutter.
2. **Web mínima:** la web no tendrá catálogo, puntos, tandas, sorteos ni compra.
3. **Destino persistente:** ningún login, OTP, registro o instalación debe
   mandar a la usuaria a un inicio genérico si llegó por una invitación válida.
4. **Relaciones progresivas:** visitar, seguir y comprar son estados distintos.
5. **Privacidad explícita:** la invitación no expone información personalizada.
6. **Conversión dentro de Neni's:** una clienta nueva podrá realizar su primer
   apartado sin tener que regresar a Messenger.
7. **Sin directorio público:** el MVP no incluye búsqueda global de tiendas.

## 4. Personas y estados

### Visitante invitada

Cuenta autenticada que llegó mediante una invitación válida, pero todavía no
sigue la tienda ni tiene un `Client` asociado a ella.

Puede:

- Ver identidad, catálogo, precios, disponibilidad general, calificación y live.
- Seguir la tienda.
- Iniciar su primer apartado.

No puede ver:

- Puntos personales.
- Estado VIP.
- Participaciones o resultados personales.
- Pedidos, pagos, direcciones ni datos de otras clientas.

### Seguidora

Cuenta con un `StoreFollower` activo, pero sin `Client` en el negocio.

Puede:

- Hacer todo lo permitido a la visitante.
- Ver novedades autorizadas.
- Configurar avisos de publicaciones y lives.
- Encontrar la tienda nuevamente desde su inicio.

### Clienta

Cuenta con un `Client` reclamado o creado dentro del negocio.

Puede:

- Ver y usar puntos, apartados, tandas, sorteos y demás funciones de clienta.
- Conservar también su relación de seguidora si decide seguir la tienda.

### Vendedora

Miembro con permisos de administración de la tienda.

Puede:

- Crear, copiar, compartir, revocar y regenerar la invitación.
- Ver una vista previa del recorrido de una clienta.
- Consultar métricas de conversión.

## 5. Recorridos

### 5.1 App instalada y sesión activa

1. La usuaria toca `https://app.nenisapp.com/s/{token}`.
2. Android App Links o iOS Universal Links abre Neni's.
3. La app valida y resuelve el token.
4. La app navega directamente a `StoreScreen`.

### 5.2 App instalada sin sesión

1. La usuaria toca la invitación.
2. Neni's conserva el token en almacenamiento seguro.
3. La app muestra autenticación contextual:
   “{Tienda} te invitó a conocer su tienda”.
4. La usuaria inicia sesión o se registra.
5. Al terminar, la app consume el token y abre la tienda.

### 5.3 Android sin la app

1. El navegador muestra el puente mínimo de instalación.
2. El botón de Play Store incluye el token mediante Install Referrer.
3. En el primer arranque, Neni's recupera el token.
4. La app muestra autenticación contextual y abre la tienda al terminar.

### 5.4 iPhone sin la app

iOS no ofrece un equivalente nativo al Install Referrer de Android.

Para el MVP:

1. La landing muestra “Instala Neni's y vuelve a tocar este enlace”.
2. El enlace permanece compartible para abrirlo de nuevo después de instalar.
3. Una vez instalada, Universal Links abre la invitación en Neni's.

No se deberá afirmar que la instalación de iOS conserva automáticamente el
token. Un deep link diferido automático en iOS requeriría evaluar posteriormente
un proveedor especializado como Branch o AppsFlyer.

### 5.5 Primera compra

1. La visitante selecciona un producto y confirma el apartado.
2. El backend busca un `Client` ya asociado a su `Account`.
3. Si no existe, intenta reclamar de forma segura un registro sin cuenta que
   coincida con su teléfono verificado.
4. Si no existe coincidencia, crea un `Client` para ese negocio.
5. Crea el pedido de apartado de manera transaccional.
6. La tienda queda disponible como tienda de clienta.
7. La vendedora recibe la notificación del nuevo apartado.

Visitar o seguir una tienda nunca deberá crear por sí solo un `Client`.

## 6. Requisitos funcionales

### FR-LINK-001: Token de invitación

El sistema deberá asignar a cada tienda un token de invitación aleatorio,
no predecible y distinto de su `BusinessId`.

### FR-LINK-002: Administración del enlace

Mientras una cuenta tenga permisos de administración, cuando solicite
regenerar o desactivar la invitación, el sistema deberá invalidar el token
anterior y reflejar el nuevo estado en la app.

### FR-LINK-003: Compatibilidad interna

Mientras la app navegue internamente, el sistema podrá conservar la ruta
`/store/{businessId}`; el token externo deberá resolverse antes de navegar.

### FR-LINK-004: Negocio válido

Cuando se resuelva una invitación, el sistema deberá aceptar únicamente
negocios activos con un token vigente.

### FR-WEB-001: Puente web mínimo

Cuando un navegador abra una invitación válida sin que el sistema operativo
abra la app, el servidor deberá mostrar nombre, logo, mensaje de invitación y
botones para abrir o instalar Neni's.

### FR-WEB-002: Sin storefront web

El puente web no deberá mostrar catálogo, existencias, puntos, novedades,
tandas, sorteos ni acciones de compra.

### FR-WEB-003: No indexación

El puente web deberá indicar `noindex` y no deberá incluir la tienda en
directorios o mapas de sitio públicos.

### FR-DEEP-001: Persistencia antes de autenticación

Mientras exista una invitación pendiente, cuando la app navegue por login,
OTP o registro, el sistema deberá conservar el token hasta consumirlo o
descartarlo explícitamente.

### FR-DEEP-002: Prioridad de destino

Cuando una usuaria complete la autenticación con una invitación pendiente,
la app deberá abrir la tienda invitante en lugar del inicio genérico.

### FR-DEEP-003: Arranque en frío

Cuando la app se reinicie con una invitación pendiente válida, la app deberá
restaurar el recorrido contextual.

### FR-DEEP-004: Android diferido

Cuando una instalación Android provenga del enlace de una tienda, la app deberá
leer una sola vez el Install Referrer y sembrar la invitación pendiente.

### FR-AUTH-001: Contexto de invitación

Mientras exista una invitación válida, las pantallas de acceso deberán mostrar
el nombre de la tienda que invitó a la usuaria.

### FR-STORE-001: Vista para visitante

Mientras una cuenta autenticada posea una invitación válida, cuando abra la
tienda, el sistema deberá permitir la consulta aunque no exista `Client` ni
`StoreFollower`.

### FR-STORE-002: Datos visibles

La vista de visitante deberá mostrar únicamente identidad comercial, productos
activos, precio, disponibilidad general, calificación, estado de live y enlaces
de contacto autorizados.

### FR-STORE-003: Datos personalizados

Mientras no exista un `Client`, la app deberá ocultar puntos, resultados
personales, información de pedidos y acciones que dependan de una relación
previa.

### FR-FOLLOW-001: Seguir tienda

Mientras una visitante esté autenticada, cuando toque “Seguir”, el sistema
deberá crear o reactivar `StoreFollower` sin crear un `Client`.

### FR-FOLLOW-002: Tiendas seguidas en inicio

Mientras una cuenta siga una tienda, la pantalla de inicio deberá mostrarla
aunque la cuenta nunca haya comprado allí.

### FR-FOLLOW-003: Sin duplicados

Mientras una cuenta sea seguidora y clienta de la misma tienda, el inicio
deberá mostrar una sola entrada y conservar sus puntos reales.

### FR-RESERVE-001: Alta comercial diferida

Mientras una cuenta autenticada no tenga `Client`, cuando confirme su primer
apartado, el sistema deberá reclamar o crear el `Client` antes de crear el
pedido.

### FR-RESERVE-002: Teléfono verificado

Mientras la cuenta no tenga un teléfono verificado, cuando intente su primer
apartado, la app deberá solicitar completar la verificación antes de continuar.

### FR-RESERVE-003: Idempotencia

Cuando dos intentos concurrentes realicen el primer apartado de la misma cuenta
en el mismo negocio, el sistema deberá producir como máximo un `Client`.

### FR-RESERVE-004: Conflicto de identidad

Cuando el teléfono verificado coincida con un `Client` reclamado por otra
cuenta, el sistema no deberá crear un duplicado ni revelar datos del registro;
deberá indicar que se necesita asistencia.

### FR-SELLER-001: Compartir desde la app

Mientras una usuaria tenga permisos de administración, la app deberá ofrecer
acciones para copiar, compartir, regenerar y desactivar la invitación.

### FR-SELLER-002: Vista previa

Cuando la vendedora solicite una vista previa, la app deberá mostrar el estado
de visitante sin exponer controles personales de compradora.

### FR-METRIC-001: Conversión

El sistema deberá registrar, sin guardar contenido sensible, impresiones del
puente, aperturas de app, registros, seguimientos y primeras compras atribuibles
a una invitación.

## 7. Requisitos no funcionales

### Seguridad

- Los tokens deberán generarse con entropía criptográfica suficiente.
- Un token revocado no deberá resolver una tienda.
- La API pública del puente solo podrá devolver nombre y logo de la tienda.
- La vista completa de tienda requerirá una cuenta autenticada y una invitación
  válida, una relación `StoreFollower` o un `Client`.
- No se deberán exponer SKU, existencias exactas, puntos, VIP, teléfonos,
  direcciones, pedidos ni identificadores personales en endpoints públicos.
- Los endpoints públicos deberán usar rate limiting.
- El alta de `Client` y pedido deberá respetar aislamiento por `BusinessId`.

### Rendimiento

- La resolución de una invitación deberá responder en menos de 500 ms p95,
  excluyendo cold starts del proveedor de alojamiento.
- La navegación desde autenticación completada hasta `StoreScreen` no deberá
  requerir más de dos solicitudes de red.
- La landing deberá ser ligera y utilizable en conexiones móviles lentas.

### Confiabilidad

- El token pendiente deberá sobrevivir cierre de proceso y reinicio.
- El consumo deberá ser idempotente.
- Un fallo de analítica nunca deberá bloquear apertura, registro o compra.
- La creación del primer `Client` y el apartado deberá ser transaccional o
  compensarse sin dejar un `Client` huérfano por un pedido fallido.

### Accesibilidad

- Todos los botones deberán tener etiquetas semánticas.
- Las áreas táctiles deberán medir al menos 48 × 48 puntos lógicos.
- Los mensajes importantes no deberán depender exclusivamente del color.

## 8. Manejo de errores

| Condición | Respuesta | Mensaje para la usuaria |
|---|---:|---|
| Token vacío o malformado | 404 | “Este enlace de tienda no es válido.” |
| Token revocado | 404 | “Esta invitación ya no está disponible.” |
| Negocio inactivo | 404 | “Esta tienda no está disponible.” |
| Sin conexión al resolver | Error recuperable | “No pudimos abrir la tienda. Reintentar.” |
| Sesión expirada | 401 | Conservar invitación y solicitar acceso |
| Cuenta sin teléfono verificado al comprar | Flujo de verificación | “Verifica tu teléfono para apartar.” |
| Teléfono ligado a otra cuenta | 409 | “Necesitamos ayudarte a vincular tu perfil.” |
| Producto inactivo o agotado | 400 | “Este producto ya no está disponible.” |
| Apartado duplicado concurrente | Respuesta idempotente | Mostrar un solo resultado |
| Analítica no disponible | Sin bloqueo | No mostrar error |
| Install Referrer sin token | Flujo normal | Abrir inicio sin invitación |

## 9. Criterios de aceptación

### AC-001: Apertura con sesión

Given una clienta con Neni's instalada y sesión activa  
When toca una invitación vigente  
Then la app abre directamente la tienda invitante.

### AC-002: Apertura sin sesión

Given una usuaria sin sesión y una invitación vigente  
When inicia sesión o se registra  
Then la app conserva la invitación y abre la tienda al terminar.

### AC-003: Reinicio durante OTP

Given una invitación pendiente durante la verificación OTP  
When la app se cierra y vuelve a abrir  
Then el contexto de la tienda continúa disponible.

### AC-004: Instalación Android

Given una usuaria Android sin Neni's  
When instala la app desde el enlace de la tienda y completa el acceso  
Then Neni's recupera el token y abre la tienda invitante.

### AC-005: Puente web

Given un navegador que no abrió la app  
When carga una invitación vigente  
Then muestra identidad mínima y acciones de apertura/instalación  
And no muestra catálogo ni información personalizada.

### AC-006: Invitación revocada

Given un token regenerado o desactivado  
When alguien intenta usar el token anterior  
Then el sistema no revela la identidad ni los datos de la tienda.

### AC-007: Visitante sin relación

Given una cuenta autenticada sin `Client` ni `StoreFollower`  
When abre una invitación válida  
Then puede consultar el catálogo autorizado y seguir la tienda  
And no ve puntos, VIP ni participaciones personales.

### AC-008: Seguir sin crear Client

Given una visitante autenticada  
When toca “Seguir”  
Then se crea `StoreFollower`  
And no se crea ningún `Client`.

### AC-009: Tienda seguida en inicio

Given una cuenta que sigue una tienda donde nunca ha comprado  
When abre su inicio  
Then la tienda aparece una sola vez con cero puntos.

### AC-010: Primera compra

Given una visitante con teléfono verificado y producto disponible  
When confirma su primer apartado  
Then el sistema crea o reclama un único `Client`  
And crea el pedido  
And notifica a la vendedora.

### AC-011: Compra concurrente

Given una cuenta sin `Client`  
When se envían dos confirmaciones simultáneas en la misma tienda  
Then existe un solo `Client` al finalizar.

### AC-012: Clienta existente

Given una cuenta con `Client` reclamado en la tienda  
When abre la misma invitación  
Then conserva sus puntos y funciones de clienta  
And no se crean relaciones duplicadas.

### AC-013: Vendedora

Given una dueña o administradora  
When abre “Compartir mi tienda”  
Then puede compartir, regenerar, desactivar y previsualizar la invitación.

### AC-014: Privacidad pública

Given una solicitud anónima al endpoint del puente  
When la respuesta es inspeccionada  
Then no contiene productos, SKU, stock, puntos, VIP, teléfonos, pedidos,
direcciones ni identificadores de clientas.

### AC-015: Analítica no bloqueante

Given el servicio de métricas no disponible  
When una usuaria abre o usa la invitación  
Then el recorrido principal continúa sin error.

## 10. Plan de implementación

### Fase 1: Modelo y API

- [ ] Agregar token de invitación y estado habilitado al negocio.
- [ ] Crear migración con token único e índice.
- [ ] Implementar generación criptográfica, rotación y revocación.
- [ ] Crear endpoint público de teaser mínimo.
- [ ] Crear endpoint autenticado para resolver la invitación.
- [ ] Agregar endpoints administrativos para compartir y rotar.
- [ ] Aplicar autorización, aislamiento tenant y rate limiting.
- [ ] Mantener compatibilidad con rutas internas por `businessId`.

### Fase 2: Deep links

- [ ] Registrar `/s/*` en Android App Links e iOS Universal Links.
- [ ] Crear almacenamiento seguro para invitación pendiente.
- [ ] Integrarlo con splash, router, login, OTP y registro.
- [ ] Implementar Install Referrer Android de un solo consumo.
- [ ] Crear experiencia honesta de reinstalación manual para iOS.
- [ ] Limpiar el token únicamente al abrir la tienda o descartarlo.

### Fase 3: Experiencia Flutter

- [ ] Agregar encabezado contextual de invitación en autenticación.
- [ ] Permitir `StoreScreen` para visitante invitada.
- [ ] Modelar explícitamente `isClient` e `isFollowing`.
- [ ] Ocultar contenido personalizado para visitantes.
- [ ] Incorporar tiendas seguidas al inicio sin duplicados.
- [ ] Agregar estados de carga, error, revocación y reintento.

### Fase 4: Primer apartado

- [ ] Reutilizar el servicio de reclamo por teléfono verificado.
- [ ] Crear `Client` solo si no existe una coincidencia segura.
- [ ] Añadir restricción de unicidad o candado para evitar duplicados.
- [ ] Integrar alta de `Client` y creación del apartado.
- [ ] Manejar conflictos sin revelar información de otras cuentas.
- [ ] Verificar que la vendedora reciba la notificación.

### Fase 5: Herramientas de vendedora

- [ ] Crear pantalla “Compartir mi tienda”.
- [ ] Agregar copiar y compartir con APIs nativas.
- [ ] Agregar regeneración y desactivación con confirmación.
- [ ] Crear vista previa segura.
- [ ] Mostrar métricas básicas de conversión.

### Fase 6: Puente web

- [ ] Reutilizar el patrón de `ShareLandingController`.
- [ ] Mostrar identidad mínima y botones de apertura/instalación.
- [ ] Configurar `noindex`.
- [ ] No renderizar catálogo ni funciones de negocio.
- [ ] Validar navegadores internos de Facebook, Instagram y WhatsApp.

### Fase 7: Pruebas y publicación

- [ ] Pruebas unitarias de token, rotación y resolución.
- [ ] Pruebas de autorización y privacidad.
- [ ] Pruebas de primer `Client` y concurrencia.
- [ ] Pruebas Flutter de los tres estados de relación.
- [ ] Pruebas del router antes y después de autenticación.
- [ ] Pruebas manuales en Android instalado/no instalado.
- [ ] Pruebas manuales en iOS instalado/no instalado.
- [ ] Verificar archivos `.well-known` con certificados de producción.
- [ ] Medir el embudo sin bloquear el flujo principal.

## 11. Métricas de éxito

- Invitaciones compartidas.
- Aperturas válidas por invitación.
- Instalaciones o registros atribuidos.
- Porcentaje de visitantes que siguen la tienda.
- Porcentaje de visitantes que realizan su primer apartado.
- Tiempo desde apertura hasta tienda visible.
- Errores de resolución y destinos perdidos después de autenticación.

## 12. Fuera de alcance del MVP

- Storefront o catálogo navegable en web.
- Directorio público y búsqueda global de tiendas.
- Checkout web.
- Deep linking diferido automático de iOS mediante proveedor externo.
- Alta de `Client` por solo visitar o seguir.
- Programa de referidos para atraer vendedoras.
- Streaming de video alojado por Neni's.

## 13. Evolución posterior

La captación de vendedoras deberá diseñarse como un recorrido separado:

- Enlace “Invita a una vendedora”.
- Registro contextual con rol de vendedora.
- Atribución de la invitación.
- Beneficio o recompensa configurable.

No se deberá reutilizar la invitación de tienda para este propósito porque las
personas, mensajes y pasos de activación son distintos.

## 14. Decisiones cerradas

- Neni's móvil es el producto principal.
- La web será secundaria y casi no navegable.
- El enlace externo atraerá clientas a la app.
- La vista y el seguimiento no crearán `Client`.
- El primer apartado sí podrá crear o reclamar `Client`.
- El catálogo y la compra vivirán en Flutter, no en web.
- La captación de vendedoras será un flujo independiente.
