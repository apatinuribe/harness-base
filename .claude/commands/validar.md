---
description: Mide si lo que ya corre en producción movió la métrica. Consulta la fuente de analítica (constitución §5.4), compara el evento contra el CE-* del spec y la meta del KR, y deja fecha, resultado y decisión (seguir / ajustar / cortar) en docs/validacion.md.
argument-hint: <id|kr>  (F7, 7 o KR2)
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# /validar — ¿Sirvió lo que lanzamos?

Argumentos recibidos: **$ARGUMENTS**

**Léelos así antes de nada:** el primer token decide el objeto. `F7` o `7` →
la feature con ese `id` en `feature_list.json`. `KR2` o `kr2` → ese resultado
clave de `PROYECTO.md`. Sin argumento, lista los candidatos —features `done` con
`evento` sin fila `F<id>` en `docs/validacion.md`, y los KR de `PROYECTO.md`— y
pregunta cuál; no elijas tú.

Una feature cierra cuando corre en producción y su evento se emite
(`docs/verification.md` §«Hecho»). Eso prueba que **llegó**; no prueba que
**sirvió**. El backlog dice `done`, la Trazabilidad dice `en producción`, y la
meta del KR —«60 % de los pedidos desde la app a fin de trimestre»— sigue sin
que nadie la compare con lo que pasó. Este comando hace esa comparación y la
deja escrita con una decisión: seguir invirtiendo, ajustar o cortar.

**Se corre en la sesión principal, no como subagente**: el número y la decisión
se confirman contigo.

| Hace | No hace |
|---|---|
| Lee la métrica real desde la fuente que declara la constitución §5.4 (o te la pide) | No estima, no extrapola, no inventa un número |
| Compara contra el `CE-*` del spec y la meta del KR | No redefine la meta ni el criterio para que cuadre |
| Escribe la fila en `docs/validacion.md` y la consecuencia de la decisión | No cambia estados de `feature_list.json`, ni la Trazabilidad, ni crea features |
| Recomienda seguir / ajustar / cortar con su porqué | No decide por ti |

## Protocolo

### 1. Resolver el objeto y sus datos

Lee `PROYECTO.md` (§Resultados clave y §Trazabilidad), `feature_list.json`,
`docs/architecture.md` §5.4 «Analítica / evidencia de hecho» y
`docs/validacion.md` si existe.

- **Feature `F<id>`.** Tiene que estar `done` y declarar `evento`: una `infra`
  no se valida (no tiene nada que medir) y una que no está `done` todavía no
  llegó a producción —dilo y para—. Su métrica es el `CE-*` de §8 de su `spec`
  que mide su `kr` (la columna «Criterio que lo mide» del KR en `PROYECTO.md`);
  su evidencia de producción está en la fila `F<id>` de §Trazabilidad.
- **KR `KR<n>`.** Su fila en §Resultados clave: Métrica, Meta y fecha, y el
  `CE-*` que lo mide. Las features que lo mueven son las que declaran ese `kr`.

Si el KR no cita ningún `CE-*`, o el spec no lo tiene, o el `CE-*` no trae
número, **es un hueco del spec**: dilo, propón `/especificar <modulo>` y no
sigas. Validar contra una métrica que te inventas aquí es peor que no validar.

Si §5.4 sigue en `TODO:`, no hay fuente: propón `/constitucion` y para.

### 2. Medir

La fuente es la de §5.4. Si desde este repo se puede consultar —un comando, un
archivo exportado, una tabla alcanzable, una herramienta conectada—, consúltala
y muestra **la consulta y el resultado tal cual**. Si no, pide el número al
usuario con tres cosas: el valor, el periodo que cubre y qué miró para
obtenerlo. Preguntas en el formato de `.claude/formato-preguntas.md`.

Un número sin periodo ni fuente no se registra. Y si el evento no aparece en la
fuente, eso también es un resultado: `0` con su periodo, no «sin datos».

### 3. Comparar y proponer

Muestra **una sola tabla** con la fila que vas a escribir, la decisión que
recomiendas y su consecuencia, y espera:

```markdown
| Objeto | Métrica | Meta y fecha | Medido | Fuente | Decisión propuesta | Consecuencia |
|---|---|---|---|---|---|---|
| KR1 | % de pedidos creados desde la app | 60 % a fin de trimestre | 42 % (1 200 de 2 850, 1–14 nov) | Mixpanel, panel «Pedidos», `pedido_creado` por origen | ajustar | clarificación en docs/specs/pedidos.md: el 58 % restante entra por teléfono porque la app no permite pedidos recurrentes |

Confirma la fila, o dime qué cambiarías: el número, la decisión o la consecuencia.
```

Las tres decisiones y lo que cada una obliga a escribir:

| Decisión | Cuándo | Consecuencia |
|---|---|---|
| `seguir` | La métrica va hacia la meta al ritmo que hace falta, o ya la cumple | Nada cambia. «Siguiente» dice cuándo se revalida |
| `ajustar` | El porqué sigue en pie —la gente quiere esto— pero el cómo no alcanza | Entrada append-only en `## Clarificaciones` del spec, `### Sesión <fecha> — desde validación (#n)`, con lo que se aprendió; o `/especificar <modulo>` si el cambio es mayor. Si lo que falla **contradice** el spec, no es ajuste: es un bug → `/feedback` |
| `cortar` | La hipótesis no se sostiene: el evento no ocurre o la métrica no se mueve con lo que ya se construyó | `docs/futuro/<tema>.md` con **señal de activación** (formato en `/feedback`, apartado «futuro») y la recomendación de no arrancar lo pendiente de ese KR. Las features abiertas las mueves tú después; `./init.sh` (3h) lo recuerda mientras queden |

Recomienda una, con el porqué en una línea. **No escribas nada antes de la
confirmación**, ni siquiera `docs/validacion.md`.

### 4. Escribir

**`docs/validacion.md`.** Si no existe, créalo. Append-only: una fila por
validación. Un objeto se valida tantas veces como haga falta; la última fila es
la vigente.

```markdown
# Validación — qué movió la métrica y qué decidimos

> Append-only. Lo escribe /validar. Una fila por validación; un objeto se
> valida tantas veces como haga falta: la última fila es la vigente.

| # | Fecha | Objeto | Métrica | Meta y fecha | Medido | Fuente | Decisión | Siguiente |
|---|---|---|---|---|---|---|---|---|
| 1 | 2026-11-15 | KR1 | % de pedidos creados desde la app | 60 % a fin de trimestre | 42 % (1 200 de 2 850, 1–14 nov) | Mixpanel, panel «Pedidos», `pedido_creado` por origen | ajustar | docs/specs/pedidos.md §Clarificaciones sesión 2026-11-15 |
| 2 | 2026-11-15 | F7 | CE-002 · alta en menos de 2 minutos | 80 % de altas | 91 % (p50 1 m 20 s, 1–14 nov) | Mixpanel, funnel «Alta» | seguir | revalidar 2026-12-15 |
```

«Objeto» es `KR<n>` o `F<id>` y «Decisión» es exactamente `seguir`, `ajustar`
o `cortar`: `./init.sh` (3h) los lee. La numeración continúa la del archivo;
nunca se reutiliza un número.

**La consecuencia**, según la tabla del paso 3: la clarificación en el spec o el
archivo en `docs/futuro/`. Nada más: ni `feature_list.json`, ni la Trazabilidad
de `PROYECTO.md` (la mantiene el `implementer`), ni el spec fuera de
`## Clarificaciones`.

Si el spec es el de una feature `in_progress`, el hook no te deja editarlo:
deja la consecuencia en «Siguiente» como `pendiente: clarificación en <spec>` y
dilo.

### 5. Cierre

```
Validación #1: KR1 — medido 42 % vs meta 60 % a fin de trimestre (Mixpanel, 1–14 nov)
Decisión: ajustar → docs/specs/pedidos.md §Clarificaciones (sesión 2026-11-15)
Pendientes de validar: F5, F8 (en producción desde hace 21 y 16 días)
Siguiente: /especificar pedidos
```

## Reglas duras

- ❌ Nunca escribas un «Medido» que no venga de la fuente de §5.4 o del usuario
  con su periodo: ni estimado, ni extrapolado, ni «aprox».
- ❌ Nunca valides sin fuente declarada en §5.4 ni sin `CE-*` con número.
- ❌ Nunca toques `feature_list.json`, los estados ni la Trazabilidad de
  `PROYECTO.md`.
- ❌ Nunca borres ni reescribas una fila de `docs/validacion.md`: se añade otra.
- ❌ Nunca registres `cortar` sin señal de activación en `docs/futuro/`.
- ❌ Nunca cambies la meta o el criterio para que el resultado cuadre: si la
  meta estaba mal, eso es una clarificación que se escribe como tal.
- ✅ Si el usuario responde «lo que recomiendes», acepta tu decisión y
  regístrala como suya.
