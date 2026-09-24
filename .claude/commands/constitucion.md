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

**Máximo 8 preguntas.** Formato y reglas: @.claude/formato-preguntas.md

### 4. Escritura incremental

Después de cada respuesta aceptada escribe en `docs/architecture.md`, y registra
la respuesta en `## 8. Gobernanza → Bitácora`:

```markdown
### Sesión 2026-08-25
- P: ¿Qué debe pasar cuando un usuario intenta abrir algo sin permiso? → R: Opción B
```

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

Las de `.claude/formato-preguntas.md`. La decisión aceptada por «lo que
recomiendes» se registra en la bitácora de §8 como cualquier otra.
