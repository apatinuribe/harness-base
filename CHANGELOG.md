# Changelog

Versión del molde: `harness_version` en `harness.config.json`. Una instancia
compara la suya con la del molde y lee aquí qué cambió entre las dos
(README §«Actualizar una instancia»). Formato: [Keep a Changelog](https://keepachangelog.com/es/).

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
