---
description: Convierte el spec de un módulo en un brief por pantalla listo para pegar en Claude Design. Si falta DESIGN.md (el sistema visual del producto), lo crea primero con una entrevista corta.
argument-hint: <nombre-del-modulo> [--devuelto <url-o-ruta>]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# /diseno — Del spec a un brief de diseño

Argumentos recibidos: **$ARGUMENTS**

**Léelos así antes de nada:** el **primer token** es el módulo —`<modulo>`, el
de `docs/specs/<modulo>.md`—. Si aparece `--devuelto`, lo que le sigue es dónde
quedó el diseño que volvió de Claude Design, y solo se ejecuta el paso 5.

```
/diseno reservas                                         → brief (y DESIGN.md si falta)
/diseno reservas --devuelto https://claude.ai/design/…   → registrar el diseño devuelto
```

Una herramienta de diseño con IA genera lo que le pides, y **decide todo lo que
no le pides**. Si el brief dice «pantalla de reservas», va a inventar qué pasa
cuando no hay reservas, qué ve quien no tiene permiso y qué hace el botón de
cancelar. Todo eso ya está decidido en el spec: este comando lo lleva hasta el
diseño, para que no se decida dos veces y de forma distinta.

Y como cada pantalla se diseña por separado, sin un sistema visual común cada
una llega con su propio espaciado, sus propios botones y su propia jerarquía.
Eso es lo que resuelve `DESIGN.md`.

**Se corre en la sesión principal, no como subagente**: la entrevista de
`DESIGN.md` necesita hacerte preguntas.

## Las dos piezas

| Archivo | Qué es | Cuántos | Quién lo lee |
|---|---|---|---|
| `DESIGN.md` (raíz) | El sistema visual del producto: tokens y reglas | **Uno** por producto | Toda herramienta de IA que genere UI — lo busca en la raíz, igual que `CLAUDE.md` |
| `docs/diseno/<modulo>.md` | El brief de las pantallas de un módulo | Uno por módulo | Claude Design, y después el `implementer` |

`DESIGN.md` dice **cómo se ve** cualquier pantalla. El brief dice **qué tiene**
cada pantalla de este módulo. Ninguno de los dos decide reglas de negocio: esas
vienen del spec.

## Protocolo

### 1. Requisitos previos

- `docs/specs/<modulo>.md` existe. Si no, **detente** y propón
  `/especificar <modulo>`.
- Si el spec tiene `[NEEDS CLARIFICATION]` en §1, §2, §4.1, §4.2 o §4.6,
  **detente**: diseñar una pantalla cuyo comportamiento no está decidido es
  decidirlo en el diseño, y el diseño no es el sitio. Nombra cuáles son y
  propón `/especificar <modulo>`. Los pendientes en otras secciones no bloquean.
- Si el módulo no tiene pantallas (§4.2 vacía porque es un módulo de fondo:
  cobros programados, integraciones), dilo y no escribas nada.

### 2. `DESIGN.md` — solo si no existe en la raíz

Si ya existe, léelo y pasa al paso 3. No lo reescribas desde aquí: se enmienda
a mano o con una sesión dedicada, porque un cambio en él cambia todas las
pantallas ya diseñadas.

Si no existe, primero **pregunta si hay referencias**: capturas, mockups, URLs
de productos cuyo aspecto le guste al usuario, o un `DESIGN.md` exportado de
Google Stitch. Con referencias, extrae de ellas los tokens y pregunta solo lo
que no se deduzca. Sin referencias, entrevista.

**Máximo 4 preguntas. Una a la vez.** Misma forma que el resto de comandos del
arnés: interrogación completa que termina en `?`, línea `Por qué importa:`,
recomendación explícita, tabla de opciones con su consecuencia, y
`Responde con la letra, o descríbeme la tuya.` Prioriza:

1. **Dirección** — qué experiencia debe crear el producto (sobria y densa para
   uso diario, cálida y espaciosa para uso ocasional...). Parte de §1 de la
   constitución: quién lo usa y para qué.
2. **Color** — la base neutra y **un** color de interacción. Pregunta por el
   acento; los neutros los propones tú.
3. **Densidad y forma** — espaciado, radios, cuánta información por pantalla.
4. **Qué evitar** — la pregunta más importante. La IA es buena **agregando**:
   más variantes, más sombras, más decoración, más soluciones locales. Lo que
   se prohíbe aquí es lo que protege al producto de eso.

Escribe `DESIGN.md` en la raíz con sus dos capas —tokens legibles por máquina
arriba, el porqué legible por humanos abajo:

```markdown
---
version: alpha
name: <nombre del sistema>
description: <una línea: la dirección visual>
colors:
  primary: "#1A1C1E"
  secondary: "#6C7278"
  tertiary: "#B8422E"
  neutral: "#F7F5F2"
typography:
  h1: { fontFamily: <familia>, fontSize: 2.25rem, fontWeight: 700 }
  body-md: { fontFamily: <familia>, fontSize: 1rem, fontWeight: 400 }
  label-sm: { fontFamily: <familia>, fontSize: 0.8125rem, fontWeight: 500 }
rounded:
  sm: 4px
  md: 8px
spacing:
  sm: 8px
  md: 16px
components:
  button-primary:
    backgroundColor: "{colors.tertiary}"
    textColor: "{colors.neutral}"
    rounded: "{rounded.sm}"
    padding: 12px
---

## Overview
## Colors
## Typography
## Layout
## Elevation & Depth
## Shapes
## Components
## Do's and Don'ts
```

Reglas del formato:

- **Las secciones van en ese orden** y ninguna se repite. Se pueden omitir,
  salvo **Do's and Don'ts**, que es obligatoria por lo dicho en la pregunta 4.
- Cada token tiene su **porqué** en la prosa: no basta con que `tertiary` sea
  `#B8422E`, hay que decir que es el único color reservado para la interacción.
- Los componentes se refieren a tokens con `{ruta.al.token}`, no con valores
  sueltos; las variantes (hover, disabled) van como entradas separadas.
- Accesibilidad: el contraste texto/fondo de cada par de tokens que se use
  junto cumple WCAG AA. Si uno no cumple, dilo y propón el ajuste.
- Si el proyecto ya tiene el linter de DESIGN.md instalado, córrelo y deja el
  archivo limpio. No lo instales sin preguntar.

### 3. Leer el spec

Del spec, lee **solo** lo que el diseño necesita:

| Sección | Qué aporta al brief |
|---|---|
| §1 En una frase | Para quién es y qué le importa — el tono de todo el módulo |
| §2 Historias | Qué intenta lograr el usuario en cada pantalla, y qué es P1 |
| §4.1 Journey | El orden de las pantallas, de dónde llega el usuario y adónde va |
| §4.2 Pantallas y estados | La lista de pantallas y lo que se ve en cada estado |
| §4.6 Permisos | Qué ve y qué puede hacer cada rol — y qué no |

Y de la constitución, §5.1: qué ve un usuario que intenta algo sin permiso
(¿se oculta la opción, se deshabilita, se redirige?). Es una decisión
transversal: el brief la aplica, no la vuelve a decidir.

No leas §4.4 ni §4.5 para rellenar huecos. Si una celda de §4.2 está vacía, el
brief no la inventa: escribe `⚠ el spec no lo define` y la cuentas en el cierre.
Un estado que nadie decidió lo termina decidiendo la herramienta de diseño.

### 4. Escribir `docs/diseno/<modulo>.md`

Un bloque por pantalla de §4.2, en el orden del journey:

```markdown
# Brief de diseño — <modulo>

> Para pegar en Claude Design. Pega o adjunta primero `DESIGN.md`: este brief
> dice qué tiene cada pantalla; `DESIGN.md` dice cómo se ve. Sin él, cada
> pantalla sale con su propio estilo.

**Producto:** <§1 de la constitución, una línea>
**Módulo:** <§1 del spec, una línea>
**Spec:** docs/specs/<modulo>.md · **Sistema visual:** DESIGN.md
**Journey:** Email de confirmación → Mis reservas → Detalle → Cancelar

---

## Pantalla 1 — Mis reservas

**Objetivo:** que el cliente vea de un vistazo su próxima reserva y pueda
cambiarla. (H1, P1)
**Llega desde:** el enlace del email de confirmación, o el menú principal.
**Quién la ve:** cliente (las suyas) · admin (todas, con filtro por cliente).

**Contenido**
- Próxima reserva destacada: fecha, hora, servicio, estado.
- Lista de reservas futuras, luego pasadas.

**Estados**
| Estado | Qué se ve |
|---|---|
| Vacío | «Todavía no tienes reservas» + acción principal «Reservar» |
| Cargando | La estructura de la lista, sin datos (no un spinner a pantalla completa) |
| Error | Mensaje sin detalle técnico + «Reintentar» (constitución §5.2) |
| Éxito | La lista con datos. Tras cancelar: aviso breve y la reserva pasa a «Canceladas» |
| Sin permiso | ⚠ el spec no lo define |

**Acciones**
| Acción | Quién | Lleva a |
|---|---|---|
| Ver detalle | cliente, admin | Pantalla 2 |
| Cancelar | cliente, solo si faltan más de 24 h (RN-004) | Confirmación → Éxito |

**Restricciones de permisos**
- Un cliente nunca ve reservas de otro cliente — ni en la lista ni en el recuento.
- «Cancelar» no aparece para un admin: él cancela desde su panel (§4.6).
```

Reglas del brief:

- **Los cinco estados siempre**, aunque la respuesta sea «no aplica — porque…».
  Un estado omitido es un estado que la herramienta inventa.
- **Las acciones citan su regla** (`RN-*`, §4.6) cuando la condicionan: el
  diseñador tiene que saber que ese botón a veces no está.
- **Nada técnico.** Ni endpoints, ni tablas, ni componentes de código: el brief
  describe lo que ve y hace una persona.
- **Nada visual.** Colores, tipografía y espaciado viven en `DESIGN.md`. Si el
  brief dice «botón azul», contradice al sistema.

Termina el archivo con la sección de registro vacía:

```markdown
---

## Diseño devuelto

> Append-only. Una fila por entrega de Claude Design.

| Fecha | Pantallas | Dónde está | Qué cambió respecto al brief | Decisión |
|---|---|---|---|---|
```

### 5. Registrar el diseño devuelto (`--devuelto <url-o-ruta>`)

Cuando el diseño vuelve, hay que dejar escrito **dónde quedó**. Sin esto, el
`implementer` construye desde el brief —o desde una captura suelta en un chat—
y el diseño que se aprobó se pierde.

1. Pregunta qué pantallas cubre la entrega, si no es obvio.
2. Compara lo devuelto con el brief. Si el diseño **cambió el comportamiento**
   —agregó una pantalla, quitó un estado, cambió quién ve qué—, eso no es una
   decisión de diseño: es un cambio de spec. Anótalo en «Qué cambió» y
   propón `/especificar <modulo>`. El diseño no enmienda el spec.
3. Añade la fila a `## Diseño devuelto`, con la fecha de hoy.

El `implementer` lee esta sección antes de construir: la última fila de cada
pantalla es la referencia visual vigente.

### 6. Cierre

```
DESIGN.md: creado | ya existía (sin cambios)
Brief: docs/diseno/<modulo>.md (N pantallas, M estados sin definir en el spec)
Siguiente: pega DESIGN.md y el brief en Claude Design; al volver, /diseno <modulo> --devuelto <url>
```

Si hubo estados sin definir, recuérdalo: se pueden diseñar igual, pero lo que
la herramienta decida para ellos no está validado por nadie.

## Reglas duras

- ❌ Nunca inventes un estado, una acción o un permiso que el spec no declare.
- ❌ Nunca pongas decisiones visuales en el brief: van en `DESIGN.md`.
- ❌ Nunca reescribas `DESIGN.md` desde este comando si ya existe.
- ❌ Nunca registres un diseño devuelto que cambia el comportamiento sin
  señalarlo como cambio de spec.
