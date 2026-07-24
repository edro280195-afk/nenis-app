# Paquete para Lovable — Rediseño de Rutas de Neni's

Este documento sirve para crear un proyecto separado en Lovable llamado **Neni's Route Studio**. Su propósito es diseñar y validar una experiencia realmente usable antes de llevarla al panel Angular y a la app Flutter. No debe conectarse a producción ni sustituir los proyectos existentes.

## Cómo usarlo

1. Crea un proyecto nuevo y privado en Lovable. No importes ni conectes aún el repositorio de producción.
2. En **Project settings → Knowledge**, pega el bloque de [Project Knowledge](#project-knowledge-para-pegar) completo.
3. Adjunta la marca [`nenis-mark.png`](../nenis_app/assets/branding/nenis-mark.png) y, antes de comenzar, capturas de la pantalla actual en móvil, escritorio y del histórico. Las capturas son evidencia del problema, no un modelo visual a copiar.
4. Abre **Plan mode** y envía el [Prompt 1](#prompt-1--plan-mode-no-construir-todavía). No apruebes un plan que no cubra todos los criterios de aceptación.
5. Tras aprobar el flujo, cambia a Agent mode y manda los prompts de construcción uno por uno. Revisa el resultado entre cada uno.
6. Usa el último prompt para que Lovable pruebe el flujo en 360 px y en escritorio. No le pidas una modificación grande y pruebas en el mismo mensaje.

No compartas tokens, llaves de Google Maps ni credenciales del API dentro del chat. En esta fase Lovable debe usar datos simulados y un contrato tipado; la integración real se hará después en nuestros repositorios.

---

## Project Knowledge para pegar

```text
Producto
Neni's es una herramienta de logística para vendedoras que gestionan pedidos de lives y ventas por redes sociales. El módulo Rutas sirve para convertir pedidos ya capturados en una ruta de entregas clara para una repartidora. No es un dashboard genérico: es una herramienta de trabajo que se usa deprisa, muchas veces desde un celular, entre empaquetar y coordinar entregas.

Usuario principal
La vendedora/administradora de Neni's. Necesita encontrar rápido a una clienta, decidir exactamente cuáles de sus pedidos entran, verificar o crear sus bolsas y formar una ruta con confianza. No es una persona técnica. El repartidor recibe un enlace de ruta, pero este proyecto se centra en la administración de rutas.

Objetivo principal
Completar esta secuencia con una mano en móvil y sin perder contexto:
1. Encontrar una clienta o pedido.
2. Seleccionar pedidos/tandas concretos.
3. Resolver la preparación de bolsas sin salir del flujo.
4. Revisar paradas, problemas de dirección y orden de entrega.
5. Crear y compartir la ruta con el repartidor.

Dominios y términos
- Clienta: persona que recibe uno o varios pedidos.
- Pedido: orden individual. Un pedido puede tener 0 o más bolsas.
- Bolsa: bulto físico con QR. “Crear 2 bolsas” agrega dos bolsas nuevas; nunca sobrescribe ni elimina las ya existentes.
- Tanda: pago/entrega semanal de una participante; también puede ser una parada.
- Parada: una entrega dentro de una ruta.
- Ruta pendiente: creada pero aún no iniciada. Ruta activa: en reparto. Ruta finalizada: histórico.
- El enlace de repartidor SIEMPRE debe usar https://app.nenisapp.com/repartidor/{driverToken}. Jamás mostrar, copiar ni derivar enlaces con regibazar.com.

Alcance del prototipo
- Construye un frontend web responsive con datos mock realistas y una capa RouteService tipada intercambiable. No crees una base de datos, autenticación, Supabase, edge functions ni llamadas a producción.
- La fuente de datos debe vivir en un único mock repository; los componentes no deben tener datos hardcodeados dispersos.
- Usa TypeScript estricto; no uses any. Nombres de código en inglés y textos de interfaz en español de México.
- Diseña las vistas /rutas, /rutas/nueva y /rutas/:id. Mantén componentes pequeños y reutilizables.

Flujo obligatorio de creación de ruta
- Móvil primero: “Nueva ruta” abre un workspace de 3 pasos visibles: 1 Seleccionar, 2 Preparar y revisar, 3 Crear y compartir. No comprimas tres columnas de escritorio en una pantalla móvil.
- En Seleccionar, un buscador fijo filtra instantáneamente por nombre de clienta, teléfono, dirección, número de pedido y nombre de tanda. Resultados agrupados por clienta; al abrir una clienta se ven sus pedidos/tandas por separado con checkbox, monto, dirección, coordenadas y estado de bolsas.
- Filtros rápidos: Todas, Seleccionadas, Sin bolsas, Sin ubicación, Pedidos y Tandas. Deben poder combinarse con la búsqueda y mostrar contador.
- Una bandeja fija de selección debe mostrar el número de paradas y un CTA “Revisar selección”; se puede quitar una selección sin regresar a la lista.
- Al seleccionar un pedido sin bolsas se muestra claramente “Sin bolsas” y una acción “Crear bolsas”. La acción abre un bottom sheet accesible con stepper +/−, resumen “Se agregarán N bolsas nuevas al pedido #…”, cancelar y confirmar. Al confirmar, actualiza de inmediato el estado a “N bolsas” y muestra toast de éxito. No bloquear la creación de ruta por bolsas faltantes: marcarlo como pendiente de preparar y pedir confirmación explícita al final.
- Si una parada no tiene coordenadas, no fingir que aparece en el mapa. Marcar “Ubicación pendiente”, explicar la consecuencia y ofrecer “Revisar dirección”; puede mantenerse en la ruta con una confirmación explícita. La cantidad de paradas sin ubicación debe ser visible en el resumen.
- En Preparar y revisar, presentar una lista ordenada de paradas que se pueda reordenar por controles accesibles (subir/bajar); no depender únicamente de drag and drop. Incluir resumen de paradas, bolsas, importe, tiempo/distancia estimada y pendientes. “Optimizar orden” es una acción explícita, no una caja mágica.
- En Crear y compartir, mostrar resultado, enlace de repartidor, botón Copiar, Compartir y una confirmación legible. El link mostrado debe comenzar con app.nenisapp.com/repartidor/.

Mapas interactivos
- Nunca usar una captura, un iframe estático ni un mapa de adorno. El mapa debe permitir pan, zoom y tocar/clic en un marcador.
- En el constructor: marcadores numerados de las paradas con coordenadas; tocar una parada en la lista centra/abre el marcador y tocar un marcador abre una ficha de la clienta/parada. Un mapa sin API key debe tener un estado de configuración claro, nunca una imagen falsa.
- Para el histórico: mostrar exclusivamente marcadores y su ficha interactiva. Prohibido dibujar líneas, polilíneas, rutas aproximadas o flechas entre puntos en una ruta finalizada.
- Los marcadores deben tener etiqueta accesible y color/forma que no dependan solo del color para indicar estado.

Diseño de marca
- Neni's debe sentirse femenino contemporáneo, cercano y ordenado; no infantil ni saturado. La interfaz ayuda a poner orden al caos de un live.
- Usa Poppins. Fondo marfil/blush muy claro, texto ciruela oscuro, rosa Neni como color de acción y lavanda suave solo como apoyo. Usa contraste AA, espacios generosos, bordes suaves y sombras cortas.
- La metáfora visual sutil es un listón que une pasos/paradas; úsala como línea de progreso o detalle fino, nunca como decoración excesiva.
- Evita: glassmorphism, gradientes fuertes, bento dashboards, métricas enormes, exceso de tarjetas anidadas, iconos sin etiqueta, colores de semáforo sin texto y copy genérico.
- Objetivos de interacción: área táctil mínima de 48 px, CTA principal fijo sin tapar contenido, foco visible, navegación por teclado y estados de carga/vacío/error útiles.

Reglas de negocio innegociables
- Cada pedido/tanda se selecciona de forma individual aunque pertenezcan a la misma clienta.
- Nunca mezclar o borrar bolsas existentes. “Crear bolsas” solo suma el número solicitado y las nuevas empiezan empacadas.
- No inventar direcciones, coordenadas, optimización, tiempos ni estados. Identificar siempre los datos de demostración como estimados.
- En histórico no hay líneas entre puntos.
- El link del repartidor no puede usar regibazar.com en ningún estado ni fallback.
```

---

## Prompt 1 — Plan mode (no construir todavía)

```text
Lee Project Knowledge y las capturas adjuntas. Estamos rediseñando por completo el módulo de Rutas de Neni's porque hoy el flujo móvil no es intuitivo ni el mapa se percibe interactivo.

No escribas código ni modifiques archivos. Trabaja exclusivamente en Plan mode.

Primero haz hasta 7 preguntas concretas que realmente puedan cambiar una decisión de UX. Si alguna respuesta no es indispensable, declara el supuesto y continúa.

Después crea un plan de producto y UX revisable que incluya:
1. El journey de la vendedora desde pedidos sin ruta hasta enlace compartido al repartidor.
2. Arquitectura de información de /rutas, /rutas/nueva y /rutas/:id.
3. Tres direcciones de flujo móvil distintas, con ventajas, riesgos y tu recomendación. No propongas tres skins; deben cambiar la forma de resolver la selección, preparación y revisión.
4. Wireframe escrito para móvil 360 px y para escritorio 1440 px. Identifica contenido fijo, bottom sheets, paneles y qué aparece al tocar cada elemento.
5. Inventario de componentes reutilizables, estados y datos que requiere cada componente.
6. Decisiones explícitas para búsqueda rápida, agrupación por clienta, bolsas, pedidos sin coordenadas, reordenamiento, mapa y ruta histórica.
7. Plan por fases de construcción pequeño y comprobable.
8. Matriz que relacione cada criterio de aceptación de este encargo con una pantalla/estado.

No aceptes estas soluciones: dashboard genérico, mapa de imagen estática, histórico con polilíneas, un modal que esconda toda la selección, ni un enlace de chofer que use regibazar.com.

Termina con la recomendación de una dirección y espera mi aprobación. Repite al final estas restricciones críticas: móvil primero; bolsas se crean dentro del flujo; histórico con marcadores sin líneas; enlace https://app.nenisapp.com/repartidor/{token}.
```

## Prompt 2 — Agent mode: fundamento y recorrido móvil

Envíalo solo después de aprobar el plan.

```text
Implementa únicamente la primera fase aprobada: fundación visual, shell de navegación y el recorrido móvil de Seleccionar hasta Revisar selección. No implementes aún histórico, API real ni autenticación.

Usa TypeScript estricto y una RouteService con mock repository tipado. Crea datos realistas con varias clientas, una clienta con tres pedidos, tandas, un pedido sin bolsas y dos paradas sin coordenadas. No disperses mocks en componentes.

En móvil (360 px):
- Muestra el progreso de 3 pasos y un buscador fijo.
- Agrupa resultados por clienta y permite expandirla sin seleccionar automáticamente todos sus pedidos.
- Implementa búsqueda instantánea por nombre, teléfono, dirección, #pedido y tanda; filtros combinables con contador.
- Implementa bandeja de selección fija, quitar elementos y CTA “Revisar selección”.
- Implementa bottom sheet “Crear bolsas” con stepper +/− y actualiza el número de bolsas solo después de confirmar.
- Incluye estados vacío, sin resultados, cargando y error.

En escritorio adapta el mismo flujo a una composición de dos paneles: lista/búsqueda y resumen. No reproduzcas la pantalla móvil ensanchada ni inventes un dashboard.

No construyas un mapa falso ni añadas líneas. Al terminar, resume los componentes creados y espera mi revisión visual antes de seguir.
```

## Prompt 3 — Agent mode: revisión, mapa y creación

```text
Implementa únicamente la segunda fase: Preparar y revisar, crear la ruta simulada y el componente de mapa interactivo.

El mapa debe permitir pan/zoom, tener marcadores numerados, abrir una ficha al tocar un marcador y sincronizarse en ambos sentidos con la lista de paradas. Tocar una parada de la lista debe centrar y abrir su marcador. Si el proveedor de mapa no está configurado, muestra un estado honesto de configuración; no uses imágenes, iframes estáticos ni una maqueta que parezca mapa real.

La lista de revisión permite reordenar con botones accesibles “Subir” y “Bajar” además de cualquier drag and drop. Expón una acción explícita “Optimizar orden”. Muestra cantidades de paradas, bolsas, importe, estimación y pendientes de ubicación/preparación con texto claro.

Permite crear una ruta aun con bolsas o ubicación pendientes, pero antes presenta una confirmación concreta que enumere esos pendientes. Al crearla, lleva a un resultado con botón Copiar y Compartir. Genera siempre el enlace desde driverToken con este formato exacto: https://app.nenisapp.com/repartidor/{driverToken}. Nunca uses route.driverLink si contiene regibazar.com.

Usa datos simulados y no añadas backend. Termina con una lista de comportamientos que puedan revisarse manualmente.
```

## Prompt 4 — Agent mode: rutas activas, histórico e interactividad real

```text
Implementa únicamente la tercera fase: lista de rutas, detalle e histórico.

- /rutas distingue visualmente borradores/pendientes, activas y finalizadas, sin convertirlo en tablero de métricas.
- Una ruta finalizada abre un mapa realmente interactivo: pan, zoom, marcadores de paradas y ficha al tocarlos.
- Regla absoluta: en el histórico NO renderices polyline, directions renderer, ruta aproximada, flechas ni línea alguna entre marcadores.
- El detalle muestra el orden, estado y bolsas de cada entrega. Un marcador y una fila se seleccionan mutuamente.
- Cada card de ruta tiene acción visible “Copiar enlace de repartidor”; copia/visualiza solo app.nenisapp.com/repartidor/{token} incluso si el dato legado contiene regibazar.com.
- Agrega feedback de copiado, carga, sin rutas y errores.

No cambies el flujo de creación construido antes. Muestra la respuesta en 360 px, 768 px y 1440 px antes de terminar.
```

## Prompt 5 — verificación obligatoria

```text
No cambies el diseño todavía. Usa browser testing y pruebas de frontend para verificar los casos de aceptación listados abajo en 360 px y 1440 px. Reporta cada caso como pasó/falló con evidencia y corrige solo los fallos comprobados. Vuelve a probar después de corregirlos.

No uses drag and drop como única forma de prueba; verifica también los botones de reordenamiento. No realices llamadas a servicios de producción.
```

---

## Contrato de integración para la siguiente etapa

Lovable debe crear una interfaz `RouteService`; en el prototipo se implementa con mocks. Más adelante, la capa se conectará a estos endpoints del API ASP.NET. Las llamadas autenticadas no deben salir directamente desde el prototipo publicado.

| Necesidad | Método y endpoint | Entrada principal | Resultado relevante |
|---|---|---|---|
| Workspace | `GET /api/routes`, `GET /api/orders`, `GET /api/routes/available-tandas` | — | rutas, pedidos elegibles y tandas disponibles |
| Vista previa | `POST /api/routes/preview` | `{ orderIds, tandaParticipantIds, startLat?, startLng? }` | paradas ordenadas, distancia, duración, pendientes y `polylineEncoded` |
| Crear | `POST /api/routes` | `{ orderIds, tandaParticipantIds, preOptimized }` | `{ route, skipped }` |
| Optimizar | `POST /api/routes/{routeId}/optimize` | — | ruta actualizada |
| Reordenar | `PUT /api/routes/{routeId}/reorder` | `deliveryIdsInOrder: number[]` | confirmación |
| Borrar | `DELETE /api/routes/{routeId}` | — | confirmación |
| Consultar bolsas | `GET /api/orders/{orderId}/packages` | — | bolsas, QR y estado |
| Crear bolsas | `POST /api/orders/{orderId}/packages/generate` | `{ count: number }` | únicamente las bolsas nuevas |
| Ruta del repartidor | `GET /api/driver/{driverToken}` | — | ruta y entregas públicas |

### Tipos mínimos

```ts
type RouteCandidate = {
  key: `order:${number}` | `tanda:${string}`;
  kind: 'Pedido' | 'Tanda';
  orderId?: number;
  tandaParticipantId?: string;
  clientName: string;
  phone?: string;
  address?: string;
  latitude?: number;
  longitude?: number;
  total: number;
  packageCount: number;
  subtitle?: string;
};

type RouteDelivery = {
  deliveryId: number;
  sortOrder: number;
  orderId?: number;
  clientName: string;
  clientAddress?: string;
  latitude?: number;
  longitude?: number;
  status: 'Pending' | 'InTransit' | 'Delivered' | 'NotDelivered';
  total: number;
  packages?: Array<{ id: string; packageNumber: number; status: string }>;
};

type DeliveryRoute = {
  id: number;
  driverToken: string;
  driverLink?: string;
  status: 'Pending' | 'Active' | 'Completed';
  deliveries: RouteDelivery[];
};
```

`polylineEncoded` sirve para la previa de una ruta que se está armando si se desea mostrar el recorrido; está prohibido usarlo en el mapa del histórico.

---

## Casos y criterios de aceptación

Lovable debe mostrar y probar estos escenarios, no solo dibujarlos:

1. En 360 px, una vendedora encuentra a “Ana López” escribiendo parte de su nombre, teléfono, dirección o `#1842`.
2. Ana tiene tres pedidos: elegir uno no selecciona los otros dos por accidente.
3. Los filtros Todas, Seleccionadas, Sin bolsas, Sin ubicación, Pedidos y Tandas actualizan resultados y contador junto con la búsqueda.
4. El pedido `#1842` empieza con 0 bolsas. Crear 3 bolsas desde la selección lo actualiza a 3 sin cerrar ni reiniciar el flujo.
5. El usuario puede conservar un pedido sin coordenadas, pero ve el pendiente tanto en la selección como antes de crear la ruta.
6. El resumen de selección mantiene el CTA visible sin tapar el último resultado ni los controles del bottom sheet.
7. Al tocar un marcador el mapa abre la ficha de esa parada; al tocar una fila, el mapa centra ese marcador.
8. El reordenamiento funciona con botones y conserva el nuevo orden en el resumen.
9. Crear una ruta con pendientes exige confirmación explícita y muestra cuáles son.
10. Copiar el enlace del repartidor produce exactamente `https://app.nenisapp.com/repartidor/{token}`. Se prueba también con un `driverLink` legado de `https://regibazar.com/repartidor/{token}`.
11. En la ruta histórica hay marcadores interactivos, pan y zoom; la inspección visual y el árbol de componentes confirman que no existe polyline, DirectionsRenderer ni línea entre puntos.
12. Hay estados de carga, error, cero resultados y cero rutas; no hay pantallas blancas ni textos de relleno.
13. Todo botón iconográfico tiene etiqueta accesible; áreas táctiles son de al menos 48 px y el foco de teclado es visible.
14. El resultado se mantiene legible y funcional en 360 px, 768 px y 1440 px.

---

## Qué entregar al cerrar el trabajo en Lovable

- Enlace al preview y una lista de pantallas/rutas implementadas.
- Árbol de componentes y breve guía de tokens visuales (colores, tipografía, espacios y estados).
- Mock repository y contrato `RouteService` sin secretos ni API de producción.
- Capturas de los casos de prueba 1, 4, 7, 10 y 11 en móvil y escritorio.
- Lista explícita de qué se debe portar a Angular y qué se debe portar a Flutter; no asumir que el código React de Lovable se copiará directamente.
