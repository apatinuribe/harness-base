# Changelog

Versión del molde: `harness_version` en `harness.config.json`. Una instancia
compara la suya con la del molde y lee aquí qué cambió entre las dos
(README §«Actualizar una instancia»). Formato: [Keep a Changelog](https://keepachangelog.com/es/).

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
