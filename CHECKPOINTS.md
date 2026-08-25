# CHECKPOINTS — Evaluación del estado final

> En sistemas multi-agente no se evalúa el camino, se evalúa el destino.
> Un juez (humano o IA) usa estos checkpoints para decidir si el proyecto
> está sano. El reviewer rechaza el cierre si queda algún box vacío **de C1 a
> C5**. C6 y C7 son distintos y el reviewer los ignora: C6 se evalúa entre olas,
> y C7 en el momento del merge, que es después de su veredicto.

## C1 — El arnés está completo

- [ ] Existe `harness.config.json` con `project` configurado (sin TODO).
- [ ] Existen los archivos listados en `required_files`.
- [ ] `./init.sh` termina con exit code 0.

## C1b — El trabajo estaba especificado antes de empezar

- [ ] La constitución (`docs/architecture.md` §5, §6, §8) está ratificada, sin TODOs.
- [ ] La feature declara `spec`, y ese archivo existe.
- [ ] El spec no tiene `[NEEDS CLARIFICATION]` sin resolver.
- [ ] Existe `progress/audit_<modulo>.md` sin hallazgos CRITICAL abiertos.
- [ ] Ninguna regla del spec contradice una política transversal de la constitución.

## C2 — El estado es coherente

- [ ] Como mucho una feature en `in_progress` por persona. Con `team` de 2+,
      además, cada una declara su `owner`.
- [ ] Ninguna feature `in_progress` o `done` tiene dependencias sin cerrar.
- [ ] Toda feature tiene `acceptance` y `touches` no vacíos.
- [ ] Los criterios de `acceptance` están en DADO / CUANDO / ENTONCES y son observables.
- [ ] El archivo de sesión (`progress/current.md`, o `current_<alias>.md` con
      `team` de 2+) describe la sesión activa, sin restos de sesiones previas.

## C3 — El trabajo respeta la arquitectura

- [ ] El entregable solo tocó rutas declaradas en `touches` (`git diff --name-only`).
- [ ] Cumple lo definido en `docs/architecture.md` y `docs/conventions.md`.
- [ ] Ninguna ruta de `exclusive_paths` fue modificada por más de una feature abierta.
- [ ] Sin restos de debug, sin TODOs sin contexto, sin código muerto.

## C4 — La verificación es real

- [ ] Cada criterio de `acceptance` tiene evidencia citable (archivo:línea).
- [ ] Los comandos `required` de `harness.config.json` pasan al 100%.
- [ ] La evidencia prueba el resultado concreto, no solo la ausencia de error.
- [ ] Ningún criterio de la rúbrica del reviewer quedó por debajo de 3/5.

## C5 — La sesión se cerró bien

- [ ] Sin archivos temporales o sin trackear sospechosos.
- [ ] `progress/impl_<name>.md` y `progress/review_<name>.md` existen.
- [ ] Existe la entrada de esta sesión en `progress/history/` (un archivo por
      sesión). Con `team` de 2+, nombra a su `owner`.
- [ ] La feature quedó en su estado correcto (`done` o `blocked` con razón).
- [ ] Si el spec cambió durante la sesión, quedó registrado en su log de Clarificaciones.

## C6 — El conocimiento sigue sano

> **No lo evalúa el reviewer al cerrar una feature.** Es el chequeo periódico
> que se corre tras mergear una ola completa o tras enmendar la constitución.
> Un box vacío aquí no bloquea a nadie: abre una tarea de mantenimiento.

- [ ] Se corrió `bibliotecario` tras mergear la ola, o tras enmendar la constitución.
- [ ] `docs/index.md` refleja los módulos y entidades que existen hoy.
- [ ] Ningún hallazgo CRITICAL del último `progress/lint_*.md` sigue abierto.

## C7 — El merge pasó por otra persona

> **No lo evalúa el reviewer**: ocurre después de su veredicto, en el momento de
> mergear a `main`. Aplica solo si `require_peer_review` es `true` en
> `harness.config.json` y el `team` tiene 2 o más miembros.
>
> Por qué existe: cuando el reviewer es un LLM, la revisión sigue siendo IA
> aprobando IA. La segunda persona es la única verificación del sistema que no
> comparte los sesgos de la primera, y es gratis.
>
> **No es solo una regla escrita.** Lo comprueba `scripts/check_peer_review.py`:
> avisa en cada `./init.sh`, y bloquea en `./init.sh --merge` y al empujar a
> `main` (`.githooks/pre-push`).

- [ ] Alguien del `team` distinto del `owner` leyó `progress/review_<name>.md`
      y comprobó la evidencia citada, no solo el veredicto.
- [ ] Esa persona dejó constancia: su alias en la línea `Revisión cruzada:` de
      la entrada de `progress/history/`. Es la línea que lee el script.
- [ ] Si se saltó el cruce (el otro no estaba disponible), esa misma línea dice
      `omitida — <razón>`. Sin razón no pasa, y en blanco tampoco.

---

## Personalización

Añade aquí los checkpoints específicos de tu dominio. Ejemplos:

**Producto de software con Supabase**
- [ ] Toda tabla nueva tiene RLS activada y una policy explícita.
- [ ] Hay exactamente una migración nueva y es la única feature que tocó `supabase/migrations/`.

**Contenido / marketing**
- [ ] Cada pieza declara ángulo, avatar y formato antes del copy.
- [ ] Ninguna afirmación aparece en la lista de claims prohibidos.
- [ ] El paquete tiene los N archivos requeridos y `meta.json` valida contra schema.

**Research**
- [ ] Toda afirmación cuantitativa tiene fuente con URL y fecha de acceso.
- [ ] Existe `contradicciones.md` si dos fuentes se contradicen.
