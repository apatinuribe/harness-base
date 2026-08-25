---
description: Entrevista única por proyecto para fijar las políticas transversales. Escribe docs/architecture.md (la constitución).
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# /constitucion — Fijar las reglas que atraviesan todo el producto

Se corre **una vez al empezar el proyecto**, y luego solo para enmendarla.

Produce `docs/architecture.md`: las decisiones que **no se rediscuten en cada
feature**. Sin esto, cada módulo reinventa cómo se autentica, cómo falla, qué
se loguea y en qué zona horaria vive — y el producto termina siendo un collage.

## Qué cubre esta entrevista (y qué no)

| Se resuelve aquí | Se resuelve en `/especificar` |
|---|---|
| **Transversal**: identidad, permisos, errores, validación, logs, idioma, moneda, zona horaria, PII, rendimiento | **Vertical**: el journey, las pantallas, las entidades y las reglas de negocio de UN módulo |
| **Alrededor del sistema**: entornos, despliegue, backups, terceros, soporte, costos | **Temporal**: estados, idempotencia, eventos, jobs y migraciones de UN módulo |

Regla: si la respuesta es la misma para todos los módulos, va aquí. Si cambia
módulo a módulo, va en el spec.

## Protocolo

### 1. Contexto

Lee `docs/architecture.md`, `harness.config.json` y `README.md`. Si la
constitución ya está ratificada (§8 con versión y sin TODOs), **no la
reescribas**: pasa a modo enmienda (paso 5).

### 2. Escaneo de cobertura

Recorre estas áreas y marca cada una **Clara / Parcial / Ausente** según lo que
ya sepas del proyecto. No muestres la tabla completa al usuario: es tu insumo
para priorizar.

| Área | Qué tiene que quedar decidido |
|---|---|
| Identidad y permisos | Quién entra, cómo, qué roles existen, qué puede hacer cada uno |
| Errores y validación | Dónde se valida, qué ve el usuario cuando algo falla, qué se reintenta |
| Datos y privacidad | Qué dato es sensible, quién lo ve, cuánto se guarda, cómo se borra |
| Observabilidad | Qué se loguea, qué se mide, cómo se entera alguien de que algo se rompió |
| Tiempo, moneda e idioma | Zona horaria de referencia, formato de fechas, monedas, idiomas |
| Rendimiento y límites | Cuánto puede tardar algo antes de considerarse roto, cuántos usuarios se esperan |
| Entornos y despliegue | Qué entornos hay, cómo se sube a producción, cómo se revierte |
| Terceros y costos | De qué servicios externos dependemos, qué pasa si se caen, qué cuestan |
| Soporte y operación | Quién opera esto a diario, qué hace cuando un cliente reclama |

### 3. Preguntas

**Máximo 8 preguntas. Una a la vez. Nunca reveles la cola de preguntas.**

Prioriza por **impacto × incertidumbre**: primero lo que, si se decide mal,
obliga a rehacer trabajo ya construido.

Cada pregunta cumple **todas** estas reglas:

- Es una **interrogación completa que termina en `?`**. Nunca una etiqueta
  («Zona horaria:») ni un tema suelto.
- Va seguida de una línea **`Por qué importa:`** en lenguaje llano — sin jerga,
  o con la jerga definida en la misma frase.
- Trae una **recomendación explícita** antes de las opciones:
  `**Recomendado:** Opción B — <razón en una línea>`
- Trae una **tabla de opciones** con la consecuencia de cada una.
- Cierra con: `Responde con la letra, o descríbeme la tuya.`
- **Autocomprobación antes de enviarla:** ¿alguien que no es técnico y no ha
  leído este repo puede responderla solo con lo que hay en pantalla? Si no,
  reescríbela.

Formato:

```markdown
**P3.** ¿Qué debe pasar cuando un usuario intenta abrir algo para lo que no tiene permiso?

Por qué importa: define si el producto se siente cerrado y seguro o confuso;
cambiarlo después toca todas las pantallas.

**Recomendado:** Opción B — no revela qué existe y no deja al usuario atascado.

| Opción | Qué ve el usuario | Consecuencia |
|---|---|---|
| A | Error 403 «no autorizado» | Claro, pero revela que ese recurso existe |
| B | Se le redirige a su inicio con un aviso | No filtra información; requiere una pantalla de inicio por rol |
| C | La opción ni siquiera aparece en el menú | Lo más limpio; obliga a que cada menú conozca los permisos |

Responde con la letra, o descríbeme la tuya.
```

### 4. Escritura incremental

**Después de CADA respuesta aceptada**, escribe en `docs/architecture.md` antes
de hacer la siguiente pregunta. Si la sesión se corta, no se pierde nada.

Cada respuesta se registra además en `## 8. Gobernanza → Bitácora`:

```markdown
### Sesión 2026-08-25
- P: ¿Qué debe pasar cuando un usuario intenta abrir algo sin permiso? → R: Opción B
```

Lo que el usuario **no sepa responder** no se inventa: queda como
`[NEEDS CLARIFICATION: <la pregunta concreta>]` en la sección que corresponda.

### 5. Enmiendas

Para cambiar una constitución ya ratificada:

1. Di **qué política cambia y qué specs existentes quedan en conflicto**
   (búscalos con `grep` en `docs/specs/`). Esto es lo importante: una enmienda
   silenciosa deja specs mintiendo.
2. Sube la versión en §8:
   - **MAJOR** — se elimina o se redefine una política de forma incompatible.
   - **MINOR** — se añade una política o una sección nueva.
   - **PATCH** — redacción, ejemplos, correcciones sin cambio de fondo.
3. Actualiza `Última enmienda`.
4. Recomienda correr `bibliotecario` para detectar los specs que quedaron
   desalineados.

### 6. Cierre

Al terminar:

- `docs/architecture.md` sin ningún `TODO` en §5, §6 y §8.
- Recuerda al usuario que la rúbrica de §4 es lo que el `reviewer` usa para
  puntuar: si está genérica, el reviewer aprueba cualquier cosa.
- Siguiente paso: `/especificar <modulo>` para el primer módulo.

## Reglas duras

- ❌ Nunca hagas dos preguntas en el mismo mensaje.
- ❌ Nunca uses jerga sin definirla en la misma frase (`RLS`, `idempotente`,
  `webhook`, `SLA`) — quien responde no es técnico.
- ❌ Nunca rellenes una política con un valor por defecto sin decirlo: si
  recomiendas, se ve la recomendación; si asumes, se marca `[NEEDS CLARIFICATION]`.
- ✅ Si el usuario responde «lo que recomiendes», acepta tu recomendación y
  regístrala como decisión suya en la bitácora.
