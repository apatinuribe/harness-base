---
description: Escribe el plan técnico de UNA feature en progress/plan_<name>.md —módulos a tocar, orden de tareas, migraciones, riesgos y cómo se verifica cada criterio—, lo confirmas, y el implementer lo sigue en vez de improvisar mientras el reviewer compara lo hecho contra él.
argument-hint: <id-o-name-de-la-feature>
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

# /planear — El plan técnico antes del código

Argumentos recibidos: **$ARGUMENTS**

**Léelos así antes de nada:** el **primer token** es la feature: su `id`
numérico o su `name` en `feature_list.json`. Si no resuelve a una feature,
pídelo y no sigas.

```
/planear 7                → plan de la feature #7
/planear alta_suscripcion → la misma, por nombre
```

Sin este comando, el `implementer` decide dentro del subagente qué módulos
toca, en qué orden, qué migración escribe y cómo prueba cada criterio — y lo
ejecuta sin que nadie lo haya visto. Cuando el reviewer llega, no tiene contra
qué comparar: solo puede juzgar el resultado, no el camino. Este comando saca
esas decisiones a un archivo **antes** del código, para que las confirmes tú.

**Se corre en la sesión principal, no como subagente**: el plan se confirma
contigo. `progress/` es territorio del líder, así que lo escribe él; para leer
el código puede lanzar `explorer`s.

## Dónde encaja

Después del spec (`/especificar`) y del diseño si lo hay (`/diseno`), y
**antes** de «implementa la feature #N». Es obligatorio cuando `./init.sh` §3f
lo dice —`plan_requerido` en `harness.config.json`: por defecto, features que
tocan migraciones o tienen más de 4 criterios— y opcional para el resto.

| Hace | No hace |
|---|---|
| Lee el spec, la constitución y el código que la feature va a tocar | Escribir código o tests |
| Escribe `progress/plan_<name>.md` y lo deja `confirmado` solo con tu OK | Cambiar estados en `feature_list.json` |
| Señala rutas fuera de `touches` y criterios sin forma de verificarse | Editar el spec o inventar la regla de negocio que falta |

## Protocolo

### 1. Requisitos previos

- La feature existe y está `pending` o `in_progress`. Si está `done`, no hay
  nada que planear: dilo y termina.
- Su `spec` existe y no tiene `[NEEDS CLARIFICATION]` pendientes. Si no,
  **detente** y propón `/especificar <modulo>`: un plan sobre reglas sin
  decidir es decidirlas aquí, y aquí no es.
- Si el spec tiene pantallas y no existe `docs/diseno/<modulo>.md`, aplica lo
  que dice `./init.sh` §3e: con producto público, **detente** y propón
  `/diseno <modulo>`; con interno, anótalo en «Riesgos» y sigue.
- Si alguna de `depends_on` no está `done`, dilo y sigue: planear sí se puede,
  construir no.
- Si ya existe `progress/plan_<name>.md` **confirmado**, muéstralo y pregunta
  si se replanifica (se sobrescribe entero) o se deja. Un plan confirmado no se
  retoca por partes.

### 2. Lee

- El spec completo de la feature; la constitución (`docs/architecture.md` §2,
  §3, §5, §6); `docs/conventions.md`.
- `docs/esquema.md` y `docs/diseno/<modulo>.md`, si existen.
- El código bajo `touches` (Glob, Grep, Read). Si son más de unos diez archivos
  o hay integraciones de por medio, lanza **2-3 `explorer`** en paralelo con
  una pregunta acotada cada uno, escribiendo en
  `progress/explore_plan_<name>_<tema>.md`.
- `harness.config.json` → `plan_requerido`, y di al usuario si este plan es
  requerido y por qué (la regla es la de `./init.sh` §3f; cítala, no la
  reescribas).

### 3. Preguntas — máximo 3

Solo decisiones técnicas con **dos o más caminos que cambian alcance o
riesgo**: dónde va la migración, si se reutiliza un módulo existente o se crea
otro, si un criterio se prueba con test o de forma manual. Lo que se deduce
del repo no se pregunta. Formato: `.claude/formato-preguntas.md`.

### 4. Escribe el borrador

`progress/plan_<name>.md`, con `**Estado:** borrador`:

```markdown
# Plan — feature <id> <name>

**Estado:** borrador · **Fecha:** YYYY-MM-DD
**Requerido:** sí — <N criterios | toca migraciones | plan_requerido: true> | no (opcional)

## Módulos a tocar
| Ruta | Qué cambia | En `touches` |
|---|---|---|
| src/suscripciones/alta.ts | nuevo: caso de uso de alta | sí |
| src/pagos/cliente.ts | se añade un método | **no — ampliar touches o partir la feature** |

## Orden de tareas
1. <tarea> → <qué deja listo>
2. <tarea> → <qué deja listo>

## Migraciones
- ninguna
- (o) <archivo> — qué añade — cómo se revierte — feature `infra` que la aplica, si es otra

## Riesgos
| Riesgo | Cómo se nota | Qué se hace |
|---|---|---|
| <qué puede salir mal> | <señal observable> | <mitigación o decisión> |

## Verificación por criterio
| Criterio | Cómo | Dónde |
|---|---|---|
| F<id>-C1 · <texto literal del acceptance> | test | tests/<ruta> — «F<id>-C1 …» |
| F<id>-C3 · <texto literal del acceptance> | manual — <por qué no se automatiza> | <evidencia prevista> |

## Preguntas abiertas
- (vacío, o `[NEEDS CLARIFICATION: …]` — con una, el plan no se confirma)
```

Reglas del contenido:

- Cada ruta de «Módulos» está dentro de `touches`, o queda marcada como fuera:
  eso se resuelve ampliando `touches` o partiendo la feature **antes** de
  confirmar, no durante la construcción.
- Cada criterio de `acceptance` tiene su fila en «Verificación», con el
  identificador `F<id>-C<n>` que `docs/verification.md` exige en los tests.
- Toda migración nombra cómo se revierte.
- Todo riesgo tiene una señal observable: «puede fallar» no es un riesgo.
- Una regla de negocio que el spec no cubre va a «Preguntas abiertas» como
  `[NEEDS CLARIFICATION: …]`, y el plan no se confirma hasta que
  `/especificar` la resuelva.

### 5. Confirmación

Muestra el resumen —tareas, migraciones, riesgos, criterios con test / manual,
rutas fuera de `touches`— y **una sola pregunta**, en el formato de
`.claude/formato-preguntas.md`, con tres opciones: **A** confirmar tal cual ·
**B** cambiar algo (describe qué) · **C** descartar el plan.

- Con **B**: edita el borrador y vuelve a preguntar.
- Con **A**: pon `**Estado:** confirmado` y la fecha. **Nunca sin una respuesta
  explícita**: un plan que nadie confirmó es el plan del implementer con otro
  nombre.
- Con **C**: borra el archivo y dilo.

### 6. Cierre

Reporta en cuatro líneas:

```
Plan: progress/plan_<name>.md (confirmado · N tareas · M migraciones · K riesgos)
Requerido: sí — <razón> | no (opcional)
Criterios: n con test previsto · m manual · 0 sin cubrir
Siguiente: «implementa la feature #N» — o lo que falte antes: /especificar <modulo>, /diseno <modulo>
```

## Reglas duras

- No escribes fuera de `progress/`. Ni código, ni tests, ni spec, ni
  `feature_list.json`: si el plan revela que `touches` está mal, se dice en el
  cierre y lo cambia quien edita el backlog.
- No inventas reglas de negocio. Lo que el spec no dice es
  `[NEEDS CLARIFICATION]`, no una suposición razonable.
- Un plan confirmado no se edita: se replanifica entero (paso 1) y se vuelve a
  confirmar. Las desviaciones durante la construcción las anota el
  `implementer` en su informe, con su razón, y el `reviewer` las juzga.
- Si prefieres que el borrador lo escriba el `implementer`, lánzalo con esta
  instrucción literal: «solo planifica: escribe `progress/plan_<name>.md` en
  estado borrador con el formato de `/planear` y no toques nada más». La
  confirmación (paso 5) sigue siendo tuya, en la sesión principal.
