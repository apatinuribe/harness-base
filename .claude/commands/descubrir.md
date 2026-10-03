---
description: Entrevistas a clientes antes de especificar. Guion, un archivo por entrevista en docs/descubrimiento/, autoentrevista en 3 preguntas si el usuario eres tú, y síntesis (problema, personas, journey actual con fricciones, métrica candidata) que alimenta PROYECTO.md y al estratega.
argument-hint: [<ruta-o-texto-de-la-entrevista> | yo | sintesis]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# /descubrir — Hablar con los usuarios antes de decidir qué construir

Argumentos recibidos: **$ARGUMENTS**

**Léelos así antes de nada:** mira el **primer token**.

- `yo` → autoentrevista (§3).
- `sintesis` → síntesis de todas las entrevistas (§4).
- Una ruta que existe → registra esa entrevista (§2).
- Cualquier otro texto, o texto en el mensaje → registra lo pegado (§2).
- Nada → muestra el guion y los tres caminos (§1).

```
/descubrir                                          → guion
/descubrir notas/llamada-dueno-tienda.md            → registra una entrevista hecha
/descubrir yo                                       → autoentrevista: el usuario eres tú
/descubrir sintesis                                 → problema, personas, journey, métrica
```

Este comando existe porque el arnés arranca en `/constitucion` y
`/especificar` dando por sentado que alguien ya sabe **qué duele, a quién y
cómo lo resuelve hoy**. Sin este paso, `PROYECTO.md` se rellena de memoria,
el `estratega` formula hipótesis sobre usuarios con los que nadie habló, y el
spec salta al journey nuevo (§4.1) sin describir el proceso que reemplaza.
Aquí lo que se escribe es lo que dijeron los usuarios, con sus palabras, y la
síntesis cuenta cuántos lo dijeron.

**Se corre en la sesión principal, no como subagente**: la autoentrevista
pregunta, y nada se escribe sin tu confirmación.

## Dónde encaja

Antes de `/constitucion` (su §1 —qué produce, para quién, audiencia— se
deduce de aquí) y antes de cada `/especificar` (su §4.0 sale de la síntesis).
Es **opcional**: no todo proyecto tiene a quién preguntar. Y es **repetible**:
cada entrevista nueva es un archivo más, y `/descubrir sintesis` vuelve a
cruzarlas todas.

| Hace | No hace |
|---|---|
| Da el guion de entrevista (`docs/descubrimiento/_guion.md`) | Presentar el producto ni preguntar por features |
| Escribe **un archivo por entrevista**, con citas literales | Rellenar lo que la persona no dijo |
| Autoentrevista de 3 preguntas si el usuario eres tú | Sustituir a una entrevista real cuando hay otros usuarios |
| Síntesis: problema, personas, journey actual con fricciones, métrica candidata | Decidir KRs: la métrica es **candidata** hasta que confirmes meta y fecha |
| Ofrece rellenar `PROYECTO.md` §Problema y §Usuario | Tocar specs, `feature_list.json` ni la constitución |

## Protocolo

### 1. Guion (sin argumentos)

Lee `docs/descubrimiento/_guion.md`. Si no existe (instancia anterior a este
comando), créalo con las cinco preguntas de abajo y la plantilla de notas, y
dilo. Muestra la tabla y los tres caminos:

| # | Pregunta |
|---|---|
| 1 | ¿Quién eres y qué intentas conseguir cuando haces esto? |
| 2 | ¿Qué hiciste la última vez, paso a paso? |
| 3 | ¿En qué paso se te va el tiempo, el dinero o los errores? |
| 4 | ¿Qué has probado ya, y por qué lo dejaste? |
| 5 | ¿Cómo sabrías que está resuelto? ¿Qué número cambiaría? |

- Ya hiciste una entrevista → `/descubrir <ruta>` o pega las notas.
- El usuario del producto eres tú → `/descubrir yo`.
- Ya hay entrevistas en `docs/descubrimiento/` → `/descubrir sintesis`.

### 2. Registrar una entrevista

1. **Lee el texto** (la ruta o lo pegado). Mapea cada frase a las cinco
   secciones del archivo de entrevista. **Conserva las citas literales**
   —como en `/especificar` 2b: lo que ya es preciso no se reescribe— y marca
   con «…» lo que es cita. Lo que el guion no cubrió, o la persona no
   contestó, va a «Sin responder»: **no se rellena**.
2. **Deduce rol y canal** del texto. Si no están, haz **una** pregunta en
   formato `@.claude/formato-preguntas.md`. **Datos personales fuera**: la
   regla de `/feedback` §2 aplica igual —rol y canal, nunca nombre, email ni
   teléfono.
3. **Muestra el archivo propuesto** completo y espera. No escribas antes de
   la confirmación.
4. Con el OK, escribe `docs/descubrimiento/YYYY-MM-DD-<rol-slug>.md`
   (minúsculas, guiones, sin acentos; si ya existe, sufijo `-2`):

```markdown
# Entrevista — <rol> · YYYY-MM-DD

**Quién:** <rol y contexto, sin nombre> · **Canal:** <llamada | en persona | escrito | autoentrevista> · **Entrevistó:** <alias>

## 1. Quién es y qué intenta conseguir
## 2. Qué hace hoy (paso a paso, la última vez que lo hizo)
## 3. Qué le cuesta (tiempo, dinero, errores — con el número si lo dio)
## 4. Qué ha probado (y por qué no le sirvió)
## 5. Cómo sabría que está resuelto (la señal o el número)

## Citas literales
- «…»

## Sin responder
- <pregunta del guion que no se llegó a hacer o no contestó>
```

5. Cierre (§5).

### 3. Autoentrevista (`yo`)

Sirve cuando **el usuario del producto es quien lo construye**: una
herramienta propia, un producto interno de una persona. Si hay otros
usuarios, dilo antes de empezar: lo honesto es entrevistarlos con el guion,
y esta versión solo cuenta como **una** entrevista más.

**Máximo 3 preguntas.** Formato y reglas: `@.claude/formato-preguntas.md`.
Las opciones de cada tabla salen de lo que el repo ya dice (`README.md`,
`PROYECTO.md`, `docs/architecture.md` §1 si está) o son las respuestas
típicas para ese tipo de producto; la recomendación es la más probable
según eso. Las tres preguntas colapsan las cinco del guion:

1. **Quién + qué hace hoy:** ¿qué haces hoy, paso a paso, para <lo que el
   producto resuelve>, y en cuál de esos pasos pierdes más tiempo?
2. **Qué le cuesta + qué ha probado:** ¿cuánto te cuesta ese paso (tiempo,
   dinero, errores) y qué has probado ya para arreglarlo?
3. **Cómo sabría que está resuelto:** ¿qué número cambiaría, y cuánto,
   cuando esté resuelto?

Escribe `docs/descubrimiento/YYYY-MM-DD-autoentrevista.md` (formato de §2,
`**Canal:** autoentrevista`) **después de cada respuesta aceptada**. Lo que
no sepas responder va a «Sin responder», no se adivina. Cierre (§5).

### 4. Síntesis (`sintesis`)

**Requisito previo:** al menos una entrevista en `docs/descubrimiento/`
(archivos `.md` que no empiezan por `_`). Si no hay ninguna, **detente** y
propón `/descubrir` o `/descubrir yo`.

1. **Lee todas las entrevistas**, `PROYECTO.md` y `docs/architecture.md` §1
   si no está en `TODO`.
2. **Escribe el borrador** con este formato. **Cada fila nombra las
   entrevistas que la sostienen** («2 de 3») — es lo que permite al
   `estratega` pesar una hipótesis. Lo que ninguna entrevista dijo **no
   está**. Las contradicciones entre entrevistas van a «Lo que no sabemos»,
   no se resuelven por mayoría. La métrica candidata sale de la pregunta 5
   de las entrevistas, no de lo que sería bonito medir.

```markdown
# Síntesis de descubrimiento — <proyecto>

**Fecha:** YYYY-MM-DD · **Entrevistas:** N (`2026-10-02-dueno-tienda.md`, `2026-10-03-autoentrevista.md`)

## Problema

<2-3 frases: qué duele, a quién, cómo se resuelve hoy. Es lo que va a PROYECTO.md §Problema.>

## Personas

| Persona | Quién es | Qué quiere conseguir | Qué le cuesta hoy | Entrevistas |
|---|---|---|---|---|
| Dueño de tienda | Lleva solo el negocio, sin equipo | Que los pedidos entren sin llamadas | Transcribe pedidos de WhatsApp a mano, 2 h/día | 2 de 3 |

## Journey actual con fricciones

| Paso | Cómo se hace hoy | Fricción | Quién la sufre | Entrevistas |
|---|---|---|---|---|
| 1. Recibir el pedido | Mensaje de WhatsApp | Se pierden entre otras conversaciones | Dueño de tienda | 3 de 3 |

## Qué han probado

| Alternativa | Por qué no sirvió | Entrevistas |
|---|---|---|
| Hoja de cálculo compartida | Nadie la actualizaba desde el móvil | 2 de 3 |

## Métrica candidata

| Métrica | Hoy (si lo dijeron) | De dónde sale | Cómo se mediría |
|---|---|---|---|
| Pedidos perdidos por semana | «unos tres» (1 de 3) | Pregunta 5, entrevistas 1 y 2 | Pedidos recibidos − pedidos atendidos |

> Candidata: pasa a resultado clave en PROYECTO.md cuando confirmes meta y fecha.

## Lo que no sabemos

- <contradicciones entre entrevistas y huecos del guion, con qué entrevista dice qué>
```

3. **Muestra la síntesis** y espera. Con el OK, escribe
   `docs/descubrimiento/_sintesis.md` —**sobrescribe** la anterior: la
   síntesis es derivada; la fuente son las entrevistas—. La línea
   `**Entrevistas:**` nombra **todos** los archivos que cruzaste: es lo que
   `./init.sh` (3g) compara para avisar cuando llegan entrevistas nuevas.
4. **Ofrece rellenar `PROYECTO.md`.** Si §Problema o §Usuario siguen con
   `<…>`, muestra el contenido propuesto —Problema = el de la síntesis;
   Usuario = las Personas, una por línea, primero la que se sirve antes— y
   la métrica candidata como **cita** bajo §Resultados clave:

   ```markdown
   > Candidata (de /descubrir, 2026-10-03): pedidos perdidos por semana — hoy «unos tres»; sin meta ni fecha todavía.
   ```

   Una sola confirmación, sin preguntas nuevas. Si el usuario no quiere, no
   insistas: `/constitucion` y `/especificar` lo volverán a ofrecer. **Nunca
   escribas un resultado clave numerado fuera de una cita**: la cabecera de
   `PROYECTO.md` dice qué pasa desde el primero, y la meta y la fecha son
   decisiones del usuario, no de una entrevista.

5. Cierre (§5).

### 5. Cierre

Cuatro líneas, según el modo:

```
Entrevista: docs/descubrimiento/2026-10-02-dueno-tienda.md (5/5 preguntas · 1 sin responder)
Entrevistas: 3 en docs/descubrimiento/ (síntesis: pendiente | al día | desactualizada — 1 sin incorporar)
PROYECTO.md: Problema y Usuario rellenados | sin cambios | ya estaba
Siguiente: /descubrir sintesis | /constitucion | /especificar <modulo>
```

## Reglas duras

Las de `.claude/formato-preguntas.md` en la autoentrevista, y además:

- ❌ Nunca escribas nada antes de la confirmación: ni la entrevista, ni la
  síntesis, ni `PROYECTO.md`.
- ❌ Nunca rellenes una sección de entrevista con lo que la persona
  «seguramente» diría: va a «Sin responder».
- ❌ Nunca una fila de síntesis sin las entrevistas que la sostienen.
- ❌ Nunca un resultado clave numerado en `PROYECTO.md` fuera de una cita.
- ❌ Nombres, emails o teléfonos no entran al repo.
- ✅ Si el usuario responde «lo que recomiendes» en la autoentrevista, acepta
  tu recomendación y regístrala como decisión suya.
