# CHECKPOINTS — Evaluación del estado final

> En sistemas multi-agente no se evalúa el camino, se evalúa el destino.
> Un juez (humano o IA) usa estos checkpoints para decidir si el proyecto
> está sano. El reviewer rechaza el cierre si queda algún box vacío.

## C1 — El arnés está completo

- [ ] Existe `harness.config.json` con `project` configurado (sin TODO).
- [ ] Existen los archivos listados en `required_files`.
- [ ] `./init.sh` termina con exit code 0.

## C2 — El estado es coherente

- [ ] Como mucho una feature en `in_progress`.
- [ ] Ninguna feature `in_progress` o `done` tiene dependencias sin cerrar.
- [ ] Toda feature tiene `acceptance` y `touches` no vacíos.
- [ ] `progress/current.md` describe la sesión activa, sin restos de sesiones previas.

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
- [ ] Existe la entrada de esta sesión en `progress/history/` (un archivo por sesión).
- [ ] La feature quedó en su estado correcto (`done` o `blocked` con razón).

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
