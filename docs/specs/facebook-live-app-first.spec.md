# Facebook Live + Neni’s — estrategia app-first

Fecha de decisión: 27 de julio de 2026  
Estado: prueba de factibilidad implementada; falta validación con cuentas y Lives reales.

## Decisión

Neni’s no hospedará, retransmitirá ni almacenará el video de los Lives.

Facebook seguirá siendo el lugar donde la vendedora transmite y conserva su
audiencia. La app de Neni’s será el centro de operación de la venta:

- detectar el Live y sus comentarios;
- identificar comandos de compra;
- convertirlos en apartados, lista de espera y pedidos;
- mostrar el producto que se está vendiendo;
- notificar a la clienta dentro de Neni’s;
- cerrar pago, entrega y seguimiento en Neni’s.

En términos simples: Facebook carga con el video; Neni’s carga con la venta.

El alcance contempla Lives públicos hechos:

- desde un perfil personal de Facebook;
- desde una Página administrada por la vendedora.

No se diseñará integración para grupos privados.

## Por qué se descarta el video nativo

| Opción | Costo de Neni’s | Escalabilidad | Cambio de hábito | Decisión |
|---|---:|---|---|---|
| Video nativo en Neni’s | Alto y variable por minutos, audiencia, transcodificación, CDN y grabaciones | Exige infraestructura especializada | Muy alto: la vendedora abandona su audiencia de Facebook | Descartada |
| Facebook Live + automatización Neni’s | Bajo: API, workers, base de datos, notificaciones y SignalR | Escala por número de Lives/comentarios, no por minutos vistos | Bajo: la vendedora sigue transmitiendo donde ya lo hace | Elegida |
| Live en Facebook + operación totalmente manual | Muy bajo | Fácil, pero no automatiza la captura | Bajo | Respaldo si Meta restringe un caso |

Con la opción elegida, cien personas viendo un Live no generan cien flujos de
video para Neni’s. El costo crece principalmente con el número de comentarios,
apartados y notificaciones. El límite más importante será la capacidad y las
reglas de la API de Meta, no el ancho de banda de video.

## Arquitectura objetivo

### Plano de video: Facebook

- Facebook recibe y entrega el video.
- Facebook conserva las reacciones, comentarios y audiencia.
- La vendedora puede seguir iniciando su transmisión desde Facebook.
- En una fase futura, Neni’s podría crear el Live mediante la API y entregar la
  URL RTMPS a una herramienta de transmisión, sin convertirse en proveedor de
  video.

### Plano de venta: Neni’s

- La vendedora conecta su perfil y las Páginas que administra.
- Neni’s detecta la fuente y el Live activo.
- Neni’s recibe o consulta comentarios oficiales de Meta.
- Un parser reconoce comandos configurables como `mío 12`, `quiero A3` o
  equivalentes.
- El backend aplica inventario, orden de llegada, duplicados y lista de espera.
- La app informa a la clienta y completa el pedido.
- La vendedora controla el producto actual desde la pantalla
  **Anunciar en vivo**.

## Prueba de factibilidad actual

Se implementó un diagnóstico de solo lectura antes de construir pedidos
automáticos. Su objetivo es responder con evidencia real:

1. ¿Meta devuelve los Lives iniciados directamente en un perfil?
2. ¿Meta devuelve los Lives iniciados directamente en una Página?
3. ¿Se pueden leer sus comentarios?
4. ¿Cada comentario incluye un identificador estable de autora?
5. ¿Ese identificador coincide con el `FacebookUserId` obtenido por Facebook
   Login en Neni’s?

La app solicita temporalmente:

- `public_profile`;
- `publish_video`;
- `pages_show_list`;
- `pages_read_engagement`;
- `pages_read_user_content`.

Permisos que solo se agregarán si una fase futura realmente los necesita:

- `pages_manage_metadata`: suscribir una Página a Webhooks;
- `pages_manage_engagement`: responder o moderar comentarios;
- `pages_manage_posts`: crear un Live de Página desde Neni’s.

## Seguridad del diagnóstico

- El access token viaja del SDK de Facebook a la API de Neni’s dentro del cuerpo
  de un `POST`, nunca como parámetro de URL.
- La API envía el token a Graph mediante `Authorization: Bearer`.
- El token de usuario solo existe durante la petición.
- Los tokens de Página que devuelve Meta se usan únicamente en memoria.
- Ningún token se guarda en base de datos ni regresa a la app.
- La API comprueba que el Facebook autorizado sea el mismo
  `FacebookUserId` vinculado a la cuenta Neni’s.
- Solo Owner o Admin del negocio puede ejecutar la prueba.
- La operación tiene límite de tres intentos por minuto.
- Las respuestas de error no incluyen cuerpos internos ni tokens de Meta.

## Implementación realizada

### API

- `Controllers/MetaLiveProbeController.cs`
- `DTOs/MetaLiveProbeDtos.cs`
- `Services/MetaLiveProbeService.cs`
- política `meta-live-probe`
- pruebas de identidad, lectura y no filtración de tokens

Endpoint:

```text
POST /api/business/meta-live/probe
```

El diagnóstico devuelve:

- perfil confirmado;
- permisos otorgados, rechazados y faltantes;
- Páginas administradas visibles;
- Lives recientes del perfil y de cada Página;
- hasta diez comentarios por Live;
- nombre e identificador de autora cuando Meta los entrega;
- errores aislados por perfil, Página o comentarios.

### App Flutter

En **Mi negocio → Anunciar en vivo** aparece
**Probar conexión con Facebook**.

El resultado muestra:

- cuenta de Facebook conectada;
- total de Lives y comentarios encontrados;
- si los comentarios traen identificador de autora;
- permisos pendientes;
- resultado individual del perfil y de cada Página;
- muestras de comentarios, sin mostrar tokens.

## Prueba manual que falta

### Preparación en Meta

1. Entrar a Meta for Developers con la cuenta propietaria de la app de Neni’s.
2. Confirmar que el App ID usado por Android/iOS y por la API sea el mismo.
3. Mantener el App Secret únicamente en secretos del servidor:

   ```text
   Facebook__AppSecret
   ```

4. Habilitar Facebook Login y los permisos usados por el diagnóstico.
5. Mientras la app esté en modo Development, agregar como tester/desarrollador
   todas las cuentas reales que participarán.
6. No enviar contraseñas ni access tokens a otra persona.

### Escenario A: perfil personal

1. Iniciar sesión en Neni’s con Facebook como vendedora.
2. Abrir **Mi negocio → Anunciar en vivo**.
3. Tocar **Autorizar y probar** una vez, sin estar en vivo.
4. Guardar captura del resultado.
5. Iniciar desde Facebook un Live público de prueba en el perfil.
6. Desde otra cuenta, escribir:

   ```text
   Mío PRUEBA-01
   ```

7. Volver a Neni’s y tocar **Autorizar y probar**.
8. Confirmar si aparece:
   - el Live;
   - el comentario;
   - el nombre de autora;
   - “Autor identificable”.

### Escenario B: Página

Repetir el escenario anterior, transmitiendo desde una Página administrada por
la misma cuenta. El diagnóstico debe mostrar una fuente separada con la etiqueta
**Página**.

### Escenario C: Live creado por Neni’s

Solo se implementará si un Live iniciado directamente en Facebook no es visible.
Neni’s crearía el objeto Live mediante la API oficial y Facebook seguiría
recibiendo el video por RTMPS. Esto permitiría comprobar si Meta entrega más
control sobre Lives creados por la propia app.

## Matriz de decisión después de la prueba

| Resultado | Decisión |
|---|---|
| Perfil y Página permiten leer Live, comentarios e ID de autora | Construir captura automática para ambas fuentes |
| Página funciona, perfil no | Lanzar Pages-first y probar Live de perfil creado por Neni’s |
| Se leen comentarios pero no existe ID estable | Usar enlace/QR de apartado en Neni’s; no prometer asociación automática |
| Solo se leen Lives creados por Neni’s | Crear un flujo “Preparar mi Live” que mantenga Facebook como destino |
| Meta bloquea comentarios aun con permisos aprobados | Mantener anuncio de producto y apartado dentro de Neni’s; no usar scraping |

No se usará scraping, automatización del navegador ni captura de credenciales
como solución de producción. Son frágiles, escalan mal y ponen en riesgo la app
y las cuentas de las vendedoras.

## Fases posteriores si la prueba funciona

### Fase 1 — Conexión persistente

- pantalla de fuentes conectadas;
- selección de perfil o Página;
- almacenamiento cifrado de tokens de larga duración;
- revocación y reconexión;
- registro de consentimiento y caducidad.

### Fase 2 — Captura de comentarios

- comenzar con polling limitado para validar reglas;
- migrar a Webhooks o eventos oficiales cuando la fuente lo permita;
- idempotencia por `commentId`;
- reintentos con backoff;
- métricas por Live, fuente y error de Meta.

### Fase 3 — Motor de apartados

- códigos de producto configurables;
- normalización de comentarios;
- orden de llegada;
- inventario atómico;
- lista de espera;
- expiración de apartados;
- revisión manual de comentarios ambiguos.

### Fase 4 — Experiencia app-first

- clienta recibe su apartado dentro de Neni’s;
- checkout, pago, entrega y seguimiento en la app;
- vendedora anuncia el producto actual desde Neni’s;
- tablero de conversión del Live;
- enlace/QR visible durante la transmisión para atraer nuevas clientas a la app.

## Revisión de Meta para producción

Las pruebas con roles de la app pueden realizarse antes de una aprobación
pública. Para conectar cuentas de vendedoras externas se debe contemplar:

- Advanced Access para los permisos requeridos;
- App Review con video y pasos reproducibles;
- verificación del negocio cuando Meta la solicite;
- política de privacidad y eliminación de datos;
- explicación clara de por qué cada permiso es indispensable.

Referencias oficiales:

- https://developers.facebook.com/documentation/live-video-api
- https://developers.facebook.com/documentation/live-video-api/guides/streaming
- https://developers.facebook.com/documentation/live-video-api/interact-with-viewers
- https://developers.facebook.com/documentation/live-video-api/reference
- https://developers.facebook.com/docs/permissions/
- https://developers.facebook.com/docs/graph-api/overview/access-levels/
