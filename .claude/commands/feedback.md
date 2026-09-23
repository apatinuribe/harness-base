---
description: Triaje de lo que dicen los usuarios. Clasifica cada punto (bug, clarificación, feature nueva, futuro, descartar), propone su destino y, tras tu confirmación, lo mueve y lo registra en docs/feedback.md.
argument-hint: [<ruta-al-archivo>]  (o pega el texto después del comando)
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# /feedback — Triaje de lo que dicen los usuarios

Argumentos recibidos: **$ARGUMENTS**

**Léelos así antes de nada:** si `$ARGUMENTS` es una ruta que existe, el
feedback es ese archivo. Si no, el feedback es el texto pegado —en los
argumentos o en el mensaje—. Si no hay ninguno de los dos, pídelo y no sigas.

Cuando un usuario dice algo, lo fácil es convertirlo directamente en trabajo:
«quieren exportar a Excel» → feature → a construir. Así el backlog lo termina
escribiendo quien habló más fuerte la última semana, sin pasar por el
`estratega`, y sin que nadie compare lo que pidió con lo que el spec ya decía.

Este comando pone un paso en medio: **cada punto se clasifica, se le propone un
destino, y nada se mueve hasta que confirmas**. Y todo queda registrado, incluido
lo que se descarta — un pedido que se repite diez veces solo se ve si las diez
quedaron escritas.

**Se corre en la sesión principal, no como subagente**: la clasificación se
confirma contigo.

## Los cinco tipos

| Tipo | Qué es | La prueba | Destino |
|---|---|---|---|
| **bug** | Algo que ya existe no hace lo que su spec dice | Puedes citar el `RN-*`, el criterio de acceptance o el estado de §4.2 que incumple | Feature de corrección (ver abajo) |
| **clarificación** | El spec no dice qué pasa en ese caso, dentro del alcance que ya tiene | Encaja en una sección del spec pero la respuesta no está escrita | `## Clarificaciones` del spec |
| **feature nueva** | Algo que ningún spec cubre | No puedes citar ninguna sección que lo incluya | Candidata a `/especificar` — pasa por el `estratega` |
| **futuro** | Válido, pero no ahora | Tiene sentido y no mueve ningún KR actual, o depende de algo que no existe | `docs/futuro/<tema>.md` con su señal de activación |
| **descartar** | No se va a hacer | Contradice la constitución §1-§2, o es de otro producto | Solo el registro, **con la razón** |

La frontera que más se equivoca es **bug frente a feature nueva**: si el spec
no decía que eso tenía que pasar, no es un bug aunque el usuario lo llame así.
Y **clarificación frente a feature nueva**: una clarificación completa algo que
ya está en alcance; una feature nueva lo amplía.

## Protocolo

### 1. Contexto

Lee `docs/index.md`, `feature_list.json`, los specs de `docs/specs/` que el
feedback toque, `docs/futuro/` y `docs/feedback.md` si existe. Si existe
`PROYECTO.md`, lee sus KRs.

### 2. Partir en puntos

Un punto es **una** afirmación o un pedido. «El login es lento y además quiero
modo oscuro» son dos puntos. Conserva el **texto literal** de cada uno — la
interpretación va en otra columna.

**Datos personales fuera.** Si el feedback trae nombres, emails o teléfonos de
usuarios, la fuente se escribe por rol y canal («cliente, por soporte»), no por
persona. `docs/feedback.md` está en el repo; lo que diga la constitución §5.3
sobre datos sensibles aplica aquí igual.

### 3. Clasificar

Para cada punto: tipo, el destino concreto y el `kr` si aplica (el de la
feature afectada; para una feature nueva, el KR al que serviría, o ninguno).

Busca en `docs/feedback.md` si el punto **ya había llegado antes**. Una
repetición se anota —«se repite: #12, #31»—. Si el punto coincide con algo de
`docs/futuro/`, compara con su señal de activación: si ya se cumple, recomiéndalo
en vez de volver a aplazarlo.

### 4. Mostrar y confirmar

Muestra **una sola tabla** y espera:

```markdown
| # | Texto | Tipo | Destino propuesto | KR |
|---|---|---|---|---|
| 1 | «No me deja cancelar el mismo día» | bug | `fix_reservas_cancelar` (corrige F8): RN-004 dice que se puede hasta 2 h antes | KR2 |
| 2 | «¿Qué pasa si reservo para otra persona?» | clarificación | reservas §Clarificaciones | KR1 |
| 3 | «Quiero pagar con transferencia» | feature nueva | borrador de `pagos` → /especificar | KR1 |
| 4 | «Una app de escritorio estaría genial» | futuro | docs/futuro/app-escritorio.md — señal: 30% del uso desde escritorio | — |
| 5 | «Que se integre con mi CRM» | descartar | §1: el producto es para negocios sin equipo de ventas | — |

Confirma la tabla, o dime qué fila cambiarías y cómo.
```

**No escribas nada antes de la confirmación**, ni siquiera `docs/feedback.md`.
Si el usuario corrige una fila, vuelve a mostrar la tabla entera.

### 5. Mover cada punto a su destino

**bug**

- Si la feature afectada está `done`: propón una feature nueva
  `fix_<name>` —**no la reabras**: ya se mergeó y su historial es parte de lo
  que se revisó—. La feature de corrección:
  - declara `"corrige": <id>` de la original;
  - **hereda** `spec`, `kr` y `evento` (o `infra`) de la original — corrige la
    misma apuesta, así que se mide igual;
  - su primer criterio de acceptance **reproduce el bug** en DADO/CUANDO/ENTONCES:
    es el test que, de haber existido, lo habría atrapado;
  - `touches` lo más estrecho posible, dentro del de la original.
- Si la feature está `pending` o `blocked`: el bug es un criterio que le
  faltaba. Propón añadirlo a su `acceptance`.
- Si está `in_progress`: no la toques. Con equipo y otro `owner`, anota el punto
  en `docs/feedback.md` para su dueño y díselo al usuario.

Como en `/especificar`, **ninguna feature entra en `feature_list.json` sin una
confirmación explícita** de la entrada concreta — la tabla del paso 4 aprueba el
destino, no el JSON.

**clarificación**

Añade al log `## Clarificaciones` del spec una sesión nueva:

```markdown
### Sesión 2026-09-23 — desde feedback (#2)
- P: ¿Qué pasa si un cliente reserva para otra persona? → R: <respuesta>
```

Si el usuario dio la respuesta al confirmar, va ahí y en la sección del spec que
corresponda. Si no, la pregunta se escribe en esa sección como
`[NEEDS CLARIFICATION: …]` — y `./init.sh` bloqueará las features de ese spec
hasta que se responda. Es lo correcto: el feedback acaba de demostrar que había
un hueco.

Si el spec es el de una feature `in_progress`, el hook del arnés no te deja
editarlo — el contrato no cambia a mitad de camino. Déjalo en `docs/feedback.md`
como `pendiente de destino` y dilo.

**feature nueva**

No va al backlog. Añade el punto a `docs/borradores/<modulo>.md` (el módulo
existente al que ampliaría, o uno nuevo), bajo un encabezado
`## Desde feedback — <fecha>`, con el texto literal y su número de registro. El
siguiente paso es `/especificar <modulo> --desde docs/borradores/<modulo>.md`,
y ahí el `estratega` decide si debe existir. Que un usuario lo pidiera es la
señal de la hipótesis, no la aprobación.

**futuro**

Crea `docs/futuro/<tema>.md` —o añade al existente si el tema ya está—:

```markdown
# Aplazado — <tema>

**Decidido:** 2026-09-23 · **Origen:** feedback #4
**Qué se pidió:** «<texto literal>»
**Por qué no ahora:** <una línea>
**Señal de activación:** <qué tendría que pasar, medible, para retomarlo>
```

Sin señal de activación no se aplaza: se descarta. Aplazar sin decir cuándo se
vuelve a mirar es olvidar con más pasos.

**descartar**

Solo la fila en `docs/feedback.md`, con la razón. La razón cita algo —la
constitución, un spec, un KR— y no una opinión.

### 6. Registrar en `docs/feedback.md`

Si no existe, créalo. Es append-only: una fila por punto, **todas**, incluidas
las descartadas.

```markdown
# Feedback — registro de lo que dicen los usuarios

> Append-only. Lo escribe /feedback. Una fila por punto; las descartadas también:
> un pedido que se repite solo se ve si todas sus apariciones quedaron escritas.

| # | Fecha | Fuente | Texto | Tipo | Destino | KR |
|---|---|---|---|---|---|---|
| 1 | 2026-09-23 | cliente, por soporte | «No me deja cancelar el mismo día» | bug | F12 fix_reservas_cancelar (corrige F8) | KR2 |
| 5 | 2026-09-23 | entrevista con cliente | «Que se integre con mi CRM» | descartar | — §1: producto para negocios sin equipo de ventas | — |
```

La numeración continúa la del archivo; nunca se reutiliza un número.

### 7. Cierre

```
Feedback: N puntos → X bug, Y clarificación, Z nueva, W futuro, V descartados
Features propuestas: fix_reservas_cancelar (pendiente de tu confirmación)
Specs con preguntas nuevas: reservas (1 [NEEDS CLARIFICATION] — bloquea sus features)
Siguiente: /especificar pagos --desde docs/borradores/pagos.md
```

## Reglas duras

- ❌ Nunca muevas nada antes de que el usuario confirme la clasificación.
- ❌ Nunca metas una feature nueva directo al backlog: pasa por `/especificar` y
  el `estratega`.
- ❌ Nunca llames bug a algo que el spec no prometía.
- ❌ Nunca reabras una feature `done`: se corrige con `fix_<name>`.
- ❌ Nunca descartes ni aplaces sin razón escrita.
- ✅ Si el usuario responde «lo que recomiendes», acepta tu clasificación y
  regístrala como decisión suya.
