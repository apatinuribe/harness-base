# Changelog

Versión del molde: `harness_version` en `harness.config.json`. Una instancia
compara la suya con la del molde y lee aquí qué cambió entre las dos
(`HARNESS.md` §«Actualizar una instancia»). Formato: [Keep a Changelog](https://keepachangelog.com/es/).

## [1.2.0] — 2026-10-03

Lo que enseñó la primera instancia real: instalar desde «Use this template»,
chequeos que leen los marcadores reales, y el ciclo completo
`/descubrir → /planear → /validar` alrededor de construir.

### Añadido

- `PROYECTO.md` en la raíz y en `required_files`: problema, usuario, KRs con
  métrica y `CE-*`, Trazabilidad. La condición pasa de «si existe» a
  **«declara KRs»**: alguna línea nombra `KR<n>` fuera de backticks, bloques
  de código y citas (#7).
- `instalar.sh --desde-template [<destino>]` para repos creados con «Use this
  template» (borra `docs-molde/`, el instalador y su suite, añade el remoto
  `molde`); sin la bandera lo detecta y lo propone (#7).
- `HARNESS.md` es el manual del arnés (antes el `README.md` del molde);
  `README.md` pasa a portada mínima del proyecto, que `/configurar` rellena (#7).
- `**Audiencia:** público | interno` en la constitución §1 (pregunta de
  `/constitucion`) e `init.sh` **§3e Diseño**: feature `in_progress` con filas
  en §4.2 del spec y sin `docs/diseno/<modulo>.md` → `[FAIL]` si público,
  `[WARN]` si interno o sin resolver. `implementer` y `leader` 2b paran y
  proponen `/diseno` (#9).
- Constitución §5.4 «Analítica / evidencia de hecho»: dónde se mira que un
  evento llegó. `despliegue_inicial`, `/especificar` y `docs/verification.md`
  apuntan ahí (#9).
- Bloque **«Siguiente paso»** al final de `./init.sh` en ambos modos, por
  precedencia: `/configurar` → `/constitucion` → `/diseno <modulo>` →
  `/planear <id>` (#9, #10).
- `analista` pasada H: toda operación que crea un padre y sus hijos (o escribe
  en 2+ almacenes) declara atomicidad o compensación; todo texto con número
  variable lleva regla de plural 0/1/n (#9).
- `/planear <id>` → `progress/plan_<name>.md` confirmado por el usuario
  (módulos, orden, migraciones con reversión, riesgos, verificación por
  criterio). `plan_requerido` (`auto` | `true` | `false`) en
  `harness.config.json`; `init.sh` **3f Plan**: `[FAIL]` si una `in_progress`
  lo requiere y no está confirmado. `implementer` lo sigue y anota
  desviaciones; `reviewer` 5b «Contra el plan» (#10).
- `/descubrir` (guion, una entrevista por archivo, `yo`, `sintesis`) y
  `docs/descubrimiento/_guion.md`; §4.0 «Proceso actual y fricciones» +
  Personas en `docs/specs/_plantilla.md`; `init.sh` **3g Descubrimiento**
  (solo avisa). `/constitucion` deduce §1 de la síntesis, `/especificar` la
  lee, `estratega` marca MEDIUM la hipótesis que ninguna entrevista nombra (#11).
- `/validar <id|kr>` → `docs/validacion.md` append-only (medido vs meta,
  decisión `seguir` · `ajustar` · `cortar` y su consecuencia);
  `validar_tras_dias` (14) en `harness.config.json`; `init.sh` **3h
  Validación** (solo avisa: en producción sin validar pasado el periodo de
  gracia, o un `cortar` con features de ese KR aún abiertas) (#12).
- `/diseno` «Diseño devuelto» · Decisión: `aceptado` · `con cambios` ·
  `validado con usuario — <fecha>, <N> personas, <evidencia>` (#12).
- `scripts/test_cierre.sh` pasa de 15 a 70 casos (uno por rama nueva de
  `init.sh`) y se declara no aplicable cuando el backlog no es el de la
  plantilla (`[SKIP]`, exit 0) en vez de fallar en una instancia (#13).

### Cambiado

- `init.sh` §2 solo avisa del token **`TODO:`** (inicio de línea, cita, celda,
  tras `**Etiqueta:**`) fuera de código. `TODO(#12)`, `TODO-123`, `#TODO` y
  `TODO` sin dos puntos ya no cuentan (#8).
- `init.sh` §3b: el pendiente es **`[NEEDS CLARIFICATION: <contenido>]`**
  cerrado y fuera de código; citarlo en backticks o en la cabecera de
  `_plantilla.md` ya no bloquea el spec para siempre (#8).
- Plantillas con huecos `TODO: <qué va aquí>` (`| TODO: criterio |`,
  `**Ratificada:** TODO: fecha`); `/configurar`, `/constitucion` y
  `CHECKPOINTS.md` dicen `TODO:` (#8).
- `/constitucion`: máximo 10 preguntas (o permiso explícito para agrupar dos
  áreas); regla «fuente y fecha» para límites y planes de terceros (§5.6,
  §6.2: lo no verificado queda como `TODO:` con la URL); ofrece rellenar
  `PROYECTO.md` (#7, #9).
- `/configurar` §1b: andamiaje de herramientas en repo vacío sin código de
  producto (nota `TS18003`); entorno DOM (jsdom o equivalente) como opción
  explícita cuando hay interfaz (#9).
- `/especificar` §7: si la constitución o el spec nombran `KR<n>` y
  `PROYECTO.md` no declara ninguno, se detiene y propone rellenarlo (#7).
- `docs/index.md` §Orden de trabajo:
  `/configurar → /descubrir → /constitucion → … → /feedback → /validar` (#11, #12).
- Punteros `README §…` → `HARNESS.md §…` en `init.sh`, `instalar.sh`,
  `harness.config.json`, `docs/verification.md`, `/configurar` (#7).
- `HARNESS.md` §Actualizar una instancia: cuenta los conflictos reales de un
  merge con historias no relacionadas (todo lo que el molde cambió), un bucle
  que toma del molde los archivos que nunca editaste, el comando para
  `.gitignore` y `git rm -f` (#13).

### Eliminado

- `instalar.sh` ya no copia a la instancia `docs-molde/`, el propio instalador
  ni `test_instalar.sh` (#7).

### Notas de migración (1.1.0 → 1.2.0)

Sigue `HARNESS.md` §Actualizar una instancia (probado sobre una instancia
1.1.0 real con tres features `done`). Tras el bucle «archivos que nunca
editaste», quedan unos diez conflictos con trabajo tuyo:

- `harness.config.json` (quédate con el tuyo): sube `harness_version` a
  `1.2.0` y añade `"PROYECTO.md"` a `required_files`. `plan_requerido`
  ausente = `auto` y `validar_tras_dias` ausente = 14: copia la clave y su
  `_ayuda_…` desde el molde solo si quieres fijarlas.
- `PROYECTO.md`: si ya lo escribiste, quédate con el tuyo (`add/add` contra la
  plantilla). Si no, llega la plantilla: no declara KRs, así que `kr` sigue
  siendo opcional hasta que lo rellenes (`/descubrir sintesis` o
  `/constitucion` lo ofrecen).
- `README.md` llega del molde si no tenías; si tenías, el tuyo. `HARNESS.md`:
  el del molde.
- `docs/index.md` (el tuyo): copia las filas nuevas de la tabla de comandos
  (`/descubrir`, `/planear`, `/validar`), las dos de «Cómo navegar»
  (`PROYECTO.md`, `docs/descubrimiento/`, `docs/validacion.md`) y la línea de
  §Orden de trabajo.
- `docs/verification.md` (el tuyo): §«Hecho» cita ahora `docs/architecture.md`
  §5.4 «Analítica / evidencia de hecho» como la herramienta de analítica.
- La constitución no tiene `**Audiencia:**` en §1 ni «Analítica / evidencia de
  hecho» en §5.4: añádelas a mano o enmienda con `/constitucion` (MINOR). Sin
  la primera, §3e solo avisa; sin la segunda, `/validar` no tiene fuente.
- `despliegue_inicial` ya creada cita «analítica de §6» en su criterio 2:
  corrígelo si no está `done`.
- `TODO` sin dos puntos en `docs/*.md` **deja de avisar**:
  `grep -nw TODO docs/*.md | grep -v 'TODO:'` los lista; revísalos o pásalos
  a `TODO:`.
- `init.sh` 3h avisará de tus features `done` con `evento` cuando lleven
  `validar_tras_dias` desde su entrada en `progress/history/`
  (`YYYY-MM-DD-f<id>-*.md`; sin entrada, avisa ya): es la señal para
  `/validar <id>`. Solo avisa, no cambia el exit.
- Nada que hacer a mano con `docs/descubrimiento/_guion.md`, §4.0 de
  `_plantilla.md` (los specs existentes no lo necesitan), 3g, 3h ni
  `docs/validacion.md` (lo crea `/validar`). Briefs existentes de
  `docs/diseno/`: las filas viejas de Decisión no hace falta tocarlas.
- `scripts/test_cierre.sh` ya no es un chequeo válido dentro de una instancia
  (muta el backlog de la plantilla; ahora lo dice y sale en 0). Tras
  actualizar: `./init.sh --quick` y `bash scripts/test_guard.sh`.

## [1.1.0] — 2026-09-24

Deduplicación: una fuente por cosa, y el resto apunta a ella.

### Cambiado

- **Formato de entrevista** en un solo sitio: `.claude/formato-preguntas.md`.
  `/configurar`, `/constitucion`, `/especificar`, `/esquema` y `/diseno` lo
  cargan con `@.claude/formato-preguntas.md` y conservan solo su máximo de
  preguntas y sus prioridades. Entra en `required_files`.
- **Orden de comandos** solo en `docs/index.md` §Orden de trabajo (con la tabla
  Cuándo/Produce que estaba en `CLAUDE.md`). `CLAUDE.md`, `README.md`,
  `AGENTS.md`, `/configurar` y `/esquema` apuntan ahí.
- **Protocolo de sesión** solo en `AGENTS.md` §1 (arranque) y §5 (cierre).
  `CLAUDE.md` y `leader.md` apuntan ahí.
- **Ejemplos por dominio** solo en README §«Ejemplos de configuración» (ahora
  también Campañas). `/configurar` §4 y `docs/verification.md` apuntan ahí.
- `docs/futuro/wiki-de-conocimiento.md` pasa a `docs-molde/`: el molde ya no
  tiene `docs/futuro/` (es carpeta de la instancia, la crea `/feedback`) e
  `instalar.sh` deja de excluirla — al mover una copia anidada con trabajo ya
  no se pierde el `docs/futuro/` propio de la instancia.

### Eliminado

- README §«Qué cambia respecto al repo original».
- `domain` en `harness.config.json`; `rules.one_feature_at_a_time_per_owner`,
  `rules.require_spec_to_start` y `rules.require_verification_to_close` en
  `feature_list.json`; la línea `**Estado:**` de `docs/specs/_plantilla.md`.
  Nada los leía: las reglas las aplica `init.sh` por su cuenta y el estado
  sale de `feature_list.json`.

### Notas de migración

- Al mezclar el molde, `docs/futuro/wiki-de-conocimiento.md` desaparece y
  aparece `docs-molde/`: bórralo (`rm -rf docs-molde`).
- `.claude/formato-preguntas.md` es nuevo y obligatorio: sin él `./init.sh`
  se pone en rojo. Llega con el merge; si tu instancia edita los comandos,
  toma la versión del molde de `.claude/`.
- `domain` y `rules.*` (salvo `valid_status`) se pueden quitar o dejar en la
  instancia: nada los lee.

## [1.0.0] — 2026-09-24

Primera versión numerada. Recoge la ola A (PRs #2, #3, #4) y este PR.

### Añadido

- **Guard de escritura R1-R4** (`scripts/hooks.sh guard` / `guard-bash`): los
  archivos del estándar del arnés y el spec de la feature en curso son
  inmutables mientras haya una feature `in_progress`; `protected_paths` solo
  los edita el `implementer`; `feature_list.json` solo lo edita la sesión
  principal. Cubre Edit, Write, MultiEdit, NotebookEdit y, en Bash, `>`,
  `>>`, `tee` y `sed -i`. Si `harness.config.json` no se puede leer, avisa
  (WARN visible) en vez de callar. Suite: `scripts/test_guard.sh`. (#2, #4)
- **Gate de cierre §3d en `init.sh`**: una feature `done` necesita veredicto
  `APPROVED` del reviewer en `progress/review_<name>.md`, informe del
  implementer en `progress/impl_<name>.md`, un test `F<id>-C<n>` por criterio
  de `acceptance`, y `evento` o `infra` declarado. Suite:
  `scripts/test_cierre.sh`. (#3)
- **Pre-push como gate de merge**: `.githooks/pre-push` corre
  `./init.sh --merge` antes de que `main` cambie, y falla (no pasa en
  silencio) si no hay Python. (#4)
- **Instalación**: `scripts/instalar.sh <destino>` copia el molde a la raíz
  del proyecto, guarda el README del molde como `HARNESS.md`, hace `git init`
  si hace falta, añade el remoto `molde`, y detecta el arnés copiado como
  subcarpeta (`mi-proyecto/harness-base/`): lo reinstala limpio si no tenía
  trabajo o lo mueve a la raíz si lo tenía, sin pisar archivos del proyecto.
  Suite: `scripts/test_instalar.sh`.
- `harness_version` en `harness.config.json`, mostrada por `./init.sh`, este
  `CHANGELOG.md` y el flujo «Actualizar una instancia» en el README.

### Cambiado

- El hook `Stop` corre `./init.sh --quick`; la verificación completa del
  proyecto queda para `--merge` y el pre-push. (#4)
- `reviewer` tiene `Write` (para su informe) y `leader` tiene `Write`/`Edit`
  (solo `progress/` y estados de `feature_list.json`; el hook bloquea el
  resto). (#4)
- `required_files` incluye los scripts y hooks del arnés
  (`scripts/hooks.sh`, `scripts/check_peer_review.py`, `.claude/settings.json`,
  `.githooks/pre-push`, `scripts/test_guard.sh`, `scripts/test_cierre.sh`):
  una instancia a la que le falte uno se pone en rojo.
- `/configurar` elimina la feature de ejemplo `ejemplo_slug` del backlog en
  su paso de escritura; ya no hay que vaciarlo a mano.

### Notas de migración

- **D3 exige `evento` o `infra` en toda feature `done`.** Las instancias
  anteriores a 1.0.0 con features cerradas sin declararlo quedan en rojo en
  `./init.sh` hasta que se añada el campo a cada una (`docs/verification.md`
  §«Hecho»).
- **El push directo a `main` queda bloqueado por `verify.tests`** hasta que
  `/configurar` deje comandos reales en `verify[]`: el pre-push corre
  `./init.sh --merge` y el comando de plantilla (`TODO`) falla. Los merges
  hechos vía `gh pr merge` o la interfaz de GitHub no pasan por el hook y no
  se ven afectados.
