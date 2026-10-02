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
constitución ya está ratificada (§8 con versión y sin `TODO:`), **no la
reescribas**: pasa a modo enmienda (paso 5).

### 2. Escaneo de cobertura

Recorre estas áreas y marca cada una **Clara / Parcial / Ausente** según lo que
ya sepas del proyecto. No muestres la tabla completa al usuario: es tu insumo
para priorizar.

| Área | Qué tiene que quedar decidido |
|---|---|
| Audiencia (§1) | ¿Lo usan personas ajenas al equipo (público) o solo el equipo (interno)? Si es público, `/diseno` es obligatorio antes de la primera feature con pantalla y hacen falta referencias visuales o un `DESIGN.md` de marca |
| Identidad y permisos | Quién entra, cómo, qué roles existen, qué puede hacer cada uno |
| Errores y validación | Dónde se valida, qué ve el usuario cuando algo falla, qué se reintenta |
| Datos y privacidad | Qué dato es sensible, quién lo ve, cuánto se guarda, cómo se borra |
| Observabilidad | Qué se loguea, qué se mide, cómo se entera alguien de que algo se rompió, y **dónde se ven los eventos de producto** (§5.4 «Analítica / evidencia de hecho»: lo que `despliegue_inicial` tiene que dejar funcionando) |
| Tiempo, moneda e idioma | Zona horaria de referencia, formato de fechas, monedas, idiomas |
| Rendimiento y límites | Cuánto puede tardar algo antes de considerarse roto, cuántos usuarios se esperan |
| Entornos y despliegue | Qué entornos hay, cómo se sube a producción, cómo se revierte |
| Terceros y costos | De qué servicios externos dependemos, qué pasa si se caen, qué cuestan |
| Soporte y operación | Quién opera esto a diario, qué hace cuando un cliente reclama |

### 3. Preguntas

**Máximo 10 preguntas** (las diez áreas, una cada una). Si el escaneo deja más
huecos que preguntas, **pide permiso antes de agrupar dos áreas en una
pregunta** —di cuáles y por qué van juntas— en vez de saltarte una. Formato y
reglas: @.claude/formato-preguntas.md

La de **audiencia va primero**: condiciona el resto. Si el producto es público,
en la misma pregunta pide **referencias visuales** (capturas, URLs de productos
que le gusten) o un **`DESIGN.md` de marca** si ya existe; déjalas anotadas en
§7 para que `/diseno` las encuentre, y di que `/diseno` es obligatorio antes de
la primera feature con pantalla (`./init.sh` lo bloquea).

### 4. Escritura incremental

Después de cada respuesta aceptada escribe en `docs/architecture.md`, y registra
la respuesta en `## 8. Gobernanza → Bitácora`:

```markdown
### Sesión 2026-08-25
- P: ¿Qué debe pasar cuando un usuario intenta abrir algo sin permiso? → R: Opción B
```

**Fuente y fecha.** Toda política que dependa de un plan, un límite o un precio
de un tercero (§5.6, §6.2: cuotas de API, tamaño máximo de archivo, coste por
volumen) se escribe con la **URL de la documentación del proveedor y la fecha
en que la verificaste**, no de memoria ni de lo que diga el usuario. Si no
puedes verificarla en la sesión, queda como `TODO:` con la URL a consultar: un
límite inventado llega a producción como un bug que nadie busca.

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

- `docs/architecture.md` sin ningún `TODO:` en §1 (`**Audiencia:**` resuelta
  a `público` o `interno`), §5, §6 y §8. En §5.4, «Analítica / evidencia de
  hecho» resuelta: es lo que `despliegue_inicial` tiene que dejar funcionando.
- Recuerda al usuario que la rúbrica de §4 es lo que el `reviewer` usa para
  puntuar: si está genérica, el reviewer aprueba cualquier cosa. Sus criterios
  hablan del entregable; no citan marcadores del arnés (`TODO:`,
  `[NEEDS CLARIFICATION: …]`): eso lo comprueba `./init.sh`, no el reviewer.
- Si en las respuestas aparecieron objetivos medibles o resultados clave y
  `PROYECTO.md` no declara KRs (su cabecera dice cuándo), **ofrece rellenarlo**
  con lo ya dicho: problema, usuario y cada KR con su métrica y su meta. Sin
  preguntas nuevas: muestra el contenido propuesto y pide una confirmación; lo
  que no se dijo queda con su `<…>`. Si el usuario no quiere, no insistas:
  `/especificar` lo exigirá cuando un spec nombre un KR.
- Siguiente paso: `/especificar <modulo>` para el primer módulo. Si el
  producto es público, recuérdalo: `/diseno <modulo>` antes de arrancar la
  primera feature con pantalla.

## Reglas duras

Las de `.claude/formato-preguntas.md`. La decisión aceptada por «lo que
recomiendes» se registra en la bitácora de §8 como cualquier otra.
