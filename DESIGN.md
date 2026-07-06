---
name: "Neni's App"
description: "El espacio moderno donde clientas y vendedoras siguen conectadas."
colors:
  ink-plum: "#3A2233"
  ink-muted: "#8A6F82"
  ink-soft: "#B6A4B1"
  surface-petal: "#FFFCFD"
  surface-blush: "#FDF4F7"
  line-plum: "#3A223314"
  neni-pink: "#FB6F9C"
  neni-deep: "#E84E83"
  lavender: "#9B7BE0"
  celebration-gold: "#F3B341"
  facebook-blue: "#1877F2"
typography:
  display:
    fontFamily: "Poppins, sans-serif"
    fontSize: "30px"
    fontWeight: 700
    lineHeight: 1.12
    letterSpacing: "-0.6px"
  headline:
    fontFamily: "Poppins, sans-serif"
    fontSize: "22px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.3px"
  title:
    fontFamily: "Poppins, sans-serif"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: 1.3
  body:
    fontFamily: "Poppins, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "Poppins, sans-serif"
    fontSize: "12.5px"
    fontWeight: 600
    lineHeight: 1
rounded:
  tile: "13px"
  control: "18px"
  soft: "20px"
  card: "28px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "22px"
  xxl: "28px"
components:
  button-primary:
    backgroundColor: "{colors.neni-deep}"
    textColor: "{colors.surface-petal}"
    typography: "{typography.title}"
    rounded: "{rounded.pill}"
    height: "56px"
    padding: "0 22px"
  button-ghost:
    backgroundColor: "{colors.surface-petal}"
    textColor: "{colors.ink-plum}"
    typography: "{typography.title}"
    rounded: "{rounded.pill}"
    height: "56px"
    padding: "0 22px"
  input:
    backgroundColor: "{colors.surface-petal}"
    textColor: "{colors.ink-plum}"
    typography: "{typography.body}"
    rounded: "{rounded.control}"
    height: "58px"
    padding: "0 18px"
  role-selector:
    backgroundColor: "{colors.surface-petal}"
    textColor: "{colors.ink-plum}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    height: "52px"
    padding: "5px"
---

# Design System: Neni's App

## Overview

**Creative North Star: "El listón que une"**

La interfaz representa dos recorridos, clienta y vendedora, que se encuentran dentro de una misma comunidad. La feminidad aparece en curvas tensas, detalles de listón y una paleta de pétalo, rosa y ciruela. La estructura se mantiene limpia y reconocible para que el producto se sienta actual y confiable.

El sistema rechaza las plantillas genéricas, los adornos acumulados y cualquier jerarquía que haga parecer secundario a uno de los roles. La personalidad vive en la composición y en pequeños detalles precisos, nunca en ruido visual.

**Key Characteristics:**

- Femenino con madurez.
- Dos roles con jerarquía equivalente.
- Controles familiares y táctiles.
- Capas suaves sobre fondos rosados muy claros.
- Movimiento breve que comunica estado.

## Colors

La paleta combina un marfil rosado luminoso con rosa coral, ciruela y lavanda contenida.

### Primary

- **Rosa Neni:** acción principal, selección y momentos de marca.
- **Rosa profundo:** contraste, estado activo y continuidad de marca.

### Secondary

- **Lavanda conexión:** identifica el camino de vendedora y complementa al rosa sin competir.

### Tertiary

- **Oro celebración:** reservado para puntos, logros y detalles excepcionales.

### Neutral

- **Ciruela tinta:** texto principal y anclaje visual.
- **Ciruela suave:** texto secundario y ayudas.
- **Pétalo:** superficies elevadas.
- **Rubor:** fondo general.

### Named Rules

**The Pink With Purpose Rule.** El rosa señala marca, selección o acción. Nunca se usa como relleno indiscriminado.

**The Two Roles Rule.** Clienta y vendedora se distinguen también con icono y texto. El color nunca carga solo con el significado.

## Typography

**Display Font:** Poppins (con respaldo sans-serif)
**Body Font:** Poppins (con respaldo sans-serif)

**Character:** Geométrica, amable y suficientemente neutra para que la personalidad venga de la composición. Los pesos fuertes crean confianza; los textos de apoyo se mantienen ligeros y legibles.

### Hierarchy

- **Display** (700, 30px, 1.12): encabezados de bienvenida y mensajes únicos.
- **Headline** (700, 22px, 1.2): títulos de pantalla y secciones principales.
- **Title** (600, 17px, 1.3): botones, tarjetas y subtítulos.
- **Body** (400, 14px, 1.5): instrucciones y contenido, con un máximo de 70 caracteres por línea.
- **Label** (600, 12.5px): etiquetas compactas y estados.

### Named Rules

**The One Voice Rule.** Poppins cubre toda la interfaz. La jerarquía viene de tamaño, peso y espacio, no de mezclar tipografías decorativas.

## Elevation

El sistema usa una elevación ambiental: sombras rosadas amplias y tenues separan controles y superficies sin convertir cada bloque en una tarjeta. Las capas se reservan para elementos interactivos o contenido que realmente necesita agrupación.

### Shadow Vocabulary

- **Ambient small** (`0 8px 20px -10px rgba(214, 51, 108, 0.18)`): campos y controles en reposo.
- **Ambient card** (`0 18px 40px -12px rgba(214, 51, 108, 0.22), 0 6px 16px -8px rgba(58, 34, 51, 0.10)`): superficies protagonistas.
- **Action glow** (`0 14px 26px -12px rgba(232, 78, 131, 0.45)`): acciones primarias habilitadas.

### Named Rules

**The Earned Lift Rule.** Solo lo interactivo o agrupado se eleva. Si toda la pantalla proyecta sombra, ninguna capa tiene significado.

## Components

### Buttons

- **Shape:** cápsula cómoda y reconocible (999px).
- **Primary:** rosa profundo, texto pétalo, altura de 56px y padding horizontal de 22px.
- **Hover / Focus:** transición de 180ms, realce de contraste y anillo visible de 2px.
- **Secondary / Ghost:** superficie pétalo, borde ciruela tenue y texto ciruela.

### Chips

- **Style:** cápsulas compactas con fondo tonal, texto de contraste e icono cuando comunica estado.
- **State:** seleccionado sobre superficie clara; no seleccionado sobre una capa tonal sin saturación alta.

### Cards / Containers

- **Corner Style:** curvas suaves de 20px y tarjetas protagonistas de 28px.
- **Background:** pétalo o una tinta de rol muy clara.
- **Shadow Strategy:** elevación ambiental solo cuando la agrupación lo exige.
- **Border:** línea ciruela translúcida de 1 a 1.5px.
- **Internal Padding:** 16px, 22px o 28px según jerarquía.

### Inputs / Fields

- **Style:** superficie pétalo, borde tenue, radio de 18px y altura mínima de 58px.
- **Focus:** borde rosa profundo, etiqueta clara y anillo de enfoque visible.
- **Error / Disabled:** el error combina mensaje e icono; el estado deshabilitado reduce contraste sin ocultar el contenido.

### Navigation

La navegación usa etiquetas directas, iconos Material Symbols Rounded y áreas táctiles de al menos 48px. El estado activo combina color, peso e indicador visual.

### Role Selector

Control segmentado de dos opciones equivalentes. Cada opción incluye icono, nombre del rol y estado seleccionado; cambiar de rol adapta el formulario sin cambiar de pantalla ni romper el contexto.

## Do's and Don'ts

### Do:

- **Do** mostrar “Clienta” y “Vendedora” con el mismo peso visual.
- **Do** usar rosa, ciruela y lavanda como roles funcionales.
- **Do** respetar contraste WCAG AA, texto escalable y reducción de movimiento.
- **Do** mantener controles táctiles de al menos 48px.
- **Do** expresar lo coquette con curvas, ritmo y detalles precisos.

### Don't:

- **Don't** crear interfaces genéricas que parezcan una plantilla barata o desactualizada.
- **Don't** acumular adornos, corazones, brillos o recursos infantiles que resten claridad.
- **Don't** usar etiquetas impersonales como “Acceso de equipo” para las vendedoras.
- **Don't** crear jerarquías donde clientas o vendedoras parezcan usuarias de segunda categoría.
- **Don't** saturar formularios ni usar movimientos decorativos que dificulten entrar.
- **Don't** usar franjas laterales gruesas, texto con degradado ni glassmorphism decorativo.
