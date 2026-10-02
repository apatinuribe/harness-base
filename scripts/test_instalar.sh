#!/usr/bin/env bash
# test_instalar.sh — Pruebas de scripts/instalar.sh.
#
# Copia el molde a un directorio temporal (origen) y monta destinos con las
# situaciones reales: repo vacío, sin git, con .gitignore o README propios,
# con colisiones, ya instanciado, el error del arnés anidado (mi-proyecto/
# harness-base/) con y sin trabajo, con y sin conflicto, y el repo creado
# con «Use this template» (--desde-template y su detección). Comprueba el
# código de salida, el texto que tiene que aparecer y el estado del disco.
# No toca el repo. Todo corre con stdin cerrado (sin terminal).
#
# Uso:  bash scripts/test_instalar.sh        (desde la raiz del proyecto)
# Sale con 1 si algun caso falla.
set -u
export PYTHONIOENCODING=utf-8

RAIZ=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

total=0; fallos=0

# copia_molde <dir>: el molde sin .git ni artefactos (así el origen no
# depende del estado del clon, y sirve también como "copia anidada").
copia_molde() {
  rm -rf "$1"; mkdir -p "$1"
  (cd "$RAIZ" && tar --exclude=.git --exclude=node_modules --exclude=.worktrees \
      --exclude=.harness -cf - .) | (cd "$1" && tar -xf -)
}
MOLDE="$TMP/molde"; copia_molde "$MOLDE"
INSTALAR="$MOLDE/scripts/instalar.sh"

configurada() {  # marca una copia como "con trabajo": project resuelto
  sed -i 's/"project": *"TODO[^"]*"/"project": "tienda"/' "$1/harness.config.json"
}
# template <dir>: lo que deja «Use this template»: la copia con historia y origin propio.
template() {
  copia_molde "$1"; git -C "$1" init -q
  git -C "$1" add -A >/dev/null 2>&1 && git -C "$1" -c user.name=t -c user.email=t@t commit -qm "Initial commit"
  git -C "$1" remote add origin https://github.com/alguien/mi-proyecto.git
}
# antigua <dir>: disposición hasta 1.1.0: el README era el manual, sin HARNESS.md.
antigua() {
  rm -f "$1/HARNESS.md"; printf '# harness-base — Plantilla de Harness Engineering\n\nmanual\n' > "$1/README.md"
}

# caso <desc> <exit esperado> <texto que debe aparecer o ""> <comprobación bash o ""> -- <args de instalar.sh>
caso() {
  local desc="$1" esperado="$2" texto="$3" check="$4"; shift 4
  [ "${1:-}" = "--" ] && shift
  total=$((total + 1))
  local salida rc ok=1 motivo=""
  salida=$(bash "$INSTALAR" "$@" < /dev/null 2>&1); rc=$?
  [ "$rc" -eq "$esperado" ] || { ok=0; motivo="exit $rc (esperado $esperado)"; }
  if [ -n "$texto" ] && ! printf '%s\n' "$salida" | grep -qF -- "$texto"; then
    ok=0; motivo="${motivo:+$motivo; }no aparece «$texto»"
  fi
  if [ $ok -eq 1 ] && [ -n "$check" ] && ! eval "$check"; then
    ok=0; motivo="disco: falló «$check»"
  fi
  if [ $ok -eq 1 ]; then
    echo "[OK]    $desc"
  else
    fallos=$((fallos + 1))
    echo "[FAIL]  $desc — $motivo"
    printf '%s\n' "$salida" | sed 's/^/        | /' | tail -25
  fi
}

# ---------------------------------------------------------------------------
D="$TMP/1"; mkdir -p "$D"; git -C "$D" init -q
caso "instalación limpia en repo git vacío" 0 "Siguiente paso" \
  '[ -f "$D/harness.config.json" ] && [ -f "$D/init.sh" ] && [ -f "$D/HARNESS.md" ] && [ -f "$D/.claude/settings.json" ] \
   && [ -f "$D/.githooks/pre-push" ] && grep -q "^# TODO-nombre-del-proyecto" "$D/README.md" && [ -f "$D/PROYECTO.md" ] \
   && [ ! -d "$D/docs-molde" ] && [ ! -d "$D/.harness" ] && [ ! -f "$D/scripts/instalar.sh" ] && [ ! -f "$D/scripts/test_instalar.sh" ] \
   && [ -f "$D/.claude/formato-preguntas.md" ] \
   && (cd "$D" && bash ./init.sh --quick >/dev/null 2>&1) && [ "$(git -C "$D" remote get-url molde)" = "https://github.com/apatinuribe/harness-base.git" ]' \
  -- "$D"

D="$TMP/2"; mkdir -p "$D"
caso "destino sin repo git: git init + hooks" 0 "git init" \
  '[ -d "$D/.git" ] && [ "$(git -C "$D" config core.hooksPath)" = ".githooks" ] && git -C "$D" remote get-url molde >/dev/null' \
  -- "$D"

D="$TMP/3"; mkdir -p "$D"; git -C "$D" init -q; printf 'node_modules/\n.env\nmio/\n' > "$D/.gitignore"
caso "destino con .gitignore propio: se fusiona, no se pisa" 0 "fusionado  .gitignore" \
  'grep -qx "mio/" "$D/.gitignore" && grep -qx ".harness/" "$D/.gitignore" && grep -qx ".worktrees/" "$D/.gitignore" && [ "$(grep -c "^node_modules/$" "$D/.gitignore")" = 1 ]' \
  -- "$D"

D="$TMP/4"; mkdir -p "$D"; git -C "$D" init -q; echo mio > "$D/CLAUDE.md"
caso "colisión (CLAUDE.md propio) sin --forzar: lista y no escribe" 1 "CLAUDE.md" \
  '[ ! -f "$D/harness.config.json" ] && [ ! -f "$D/init.sh" ] && [ "$(cat "$D/CLAUDE.md")" = "mio" ]' \
  -- "$D"

caso "misma colisión con --forzar: sobrescribe" 0 "sobrescrito CLAUDE.md" \
  '[ -f "$D/harness.config.json" ] && grep -q "Rol obligatorio" "$D/CLAUDE.md"' \
  -- "$D" --forzar

D="$TMP/5"; mkdir -p "$D"; git -C "$D" init -q; echo "# Mi tienda" > "$D/README.md"
caso "README propio: no es colisión, se conserva y no se añade al índice" 0 "conservado README.md" \
  '[ "$(cat "$D/README.md")" = "# Mi tienda" ] && [ -f "$D/HARNESS.md" ] && [ -z "$(git -C "$D" ls-files README.md)" ]' \
  -- "$D"

D="$TMP/5b"; mkdir -p "$D"; git -C "$D" init -q; echo "# Mi tienda" > "$D/README.md"; echo mio > "$D/CLAUDE.md"
caso "README propio ni con --forzar se pisa" 0 "conservado README.md" \
  '[ "$(cat "$D/README.md")" = "# Mi tienda" ] && grep -q "Rol obligatorio" "$D/CLAUDE.md"' \
  -- "$D" --forzar

D="$TMP/6"; mkdir -p "$D"; git -C "$D" init -q; bash "$INSTALAR" "$D" --si >/dev/null 2>&1 < /dev/null
echo "propio" > "$D/progress/current.md"
caso "destino ya instanciado: aborta y remite a actualizar" 1 "Actualizar una instancia" \
  '[ "$(cat "$D/progress/current.md")" = "propio" ]' \
  -- "$D"

D="$TMP/7"; mkdir -p "$D"; git -C "$D" init -q; echo '{}' > "$D/package.json"
copia_molde "$D/harness-base"; configurada "$D/harness-base"; mkdir -p "$D/harness-base/.git"; echo x > "$D/harness-base/.git/HEAD"
mkdir -p "$D/harness-base/docs/futuro"; echo mio > "$D/harness-base/docs/futuro/mio.md"   # decisión propia de la instancia: viaja
caso "anidado harness-base/ con trabajo, sin conflicto: se mueve a la raíz (docs/futuro propio incluido)" 0 "Movidos" \
  '[ -f "$D/init.sh" ] && [ -f "$D/HARNESS.md" ] && [ ! -e "$D/harness-base" ] && [ ! -d "$D/docs-molde" ] && [ -f "$D/docs/futuro/mio.md" ] \
   && [ ! -f "$D/scripts/instalar.sh" ] && [ ! -f "$D/scripts/test_instalar.sh" ] \
   && grep -q "\"project\": \"tienda\"" "$D/harness.config.json" && [ -f "$D/package.json" ] \
   && (cd "$D" && bash ./init.sh --quick >/dev/null 2>&1) && git -C "$D" remote get-url molde >/dev/null' \
  -- "$D" --si

D="$TMP/8"; mkdir -p "$D"; git -C "$D" init -q; echo mio > "$D/CLAUDE.md"
copia_molde "$D/harness-base"; configurada "$D/harness-base"
caso "anidado con trabajo y conflicto (CLAUDE.md propio): lista y no mueve" 1 "CLAUDE.md" \
  '[ -d "$D/harness-base" ] && [ -f "$D/harness-base/init.sh" ] && [ ! -f "$D/init.sh" ] && [ "$(cat "$D/CLAUDE.md")" = "mio" ]' \
  -- "$D" --si

D="$TMP/9"; mkdir -p "$D"; copia_molde "$D/arnes"; configurada "$D/arnes"
caso "anidado con otro nombre (arnes/), sin --si ni terminal: detecta y pide --si" 1 "--si" \
  '[ -f "$D/arnes/init.sh" ] && [ ! -f "$D/init.sh" ]' \
  -- "$D"

D="$TMP/10"; mkdir -p "$D"; git -C "$D" init -q; copia_molde "$D/harness-base"; configurada "$D/harness-base"
sed -i '/"harness_version"/d; /"_ayuda_harness_version"/d' "$D/harness-base/harness.config.json"
caso "anidado con trabajo y sin harness_version: mueve y avisa que es anterior a 1.0.0" 0 "anterior a 1.0.0" \
  '[ -f "$D/init.sh" ] && [ ! -e "$D/harness-base" ] && (cd "$D" && bash ./init.sh --quick 2>&1) | grep -q "sin harness_version"' \
  -- "$D" --si

D="$TMP/11"; mkdir -p "$D"; git -C "$D" init -q; echo '{}' > "$D/package.json"
copia_molde "$D/harness-base"; mkdir -p "$D/harness-base/.git"; echo x > "$D/harness-base/.git/HEAD"
caso "anidado sin configurar (project TODO): reinstala limpio" 0 "REINSTALAR LIMPIO" \
  '[ ! -e "$D/harness-base" ] && [ -f "$D/init.sh" ] && [ -f "$D/HARNESS.md" ] && [ -f "$D/package.json" ] \
   && grep -q "\"harness_version\": \"1.1.0\"" "$D/harness.config.json" && (cd "$D" && bash ./init.sh --quick >/dev/null 2>&1)' \
  -- "$D" --si

D="$TMP/12"; mkdir -p "$D"; git -C "$D" init -q; bash "$INSTALAR" "$D" --si >/dev/null 2>&1 < /dev/null
copia_molde "$D/harness-base"
caso "raíz instanciada Y copia anidada: aborta y señala la que sobra" 1 "harness-base" \
  '[ -d "$D/harness-base" ] && [ -f "$D/init.sh" ]' \
  -- "$D" --si

# El caso real: el instalador corre DESDE la copia anidada (bash harness-base/scripts/instalar.sh .)
D="$TMP/13"; mkdir -p "$D"; git -C "$D" init -q; echo '{}' > "$D/package.json"; copia_molde "$D/harness-base"
INSTALAR_ORIG="$INSTALAR"; INSTALAR="$D/harness-base/scripts/instalar.sh"
caso "instalador corrido desde la copia anidada sin configurar: reinstala y borra su propio origen" 0 "eliminado" \
  '[ ! -e "$D/harness-base" ] && [ -f "$D/init.sh" ] && [ ! -f "$D/scripts/instalar.sh" ] && [ -f "$D/package.json" ] \
   && [ "$(git -C "$D" ls-files --stage scripts/hooks.sh | cut -c1-6)" = 100755 ] && (cd "$D" && bash ./init.sh --quick >/dev/null 2>&1)' \
  -- "$D" --si
INSTALAR="$INSTALAR_ORIG"

D="$TMP/14"; mkdir -p "$D"; git -C "$D" init -q; copia_molde "$D/harness-base"; configurada "$D/harness-base"
INSTALAR="$D/harness-base/scripts/instalar.sh"
caso "instalador corrido desde la copia anidada con trabajo: mueve la copia y se descarta a sí mismo" 0 "Movidos" \
  '[ ! -e "$D/harness-base" ] && [ -f "$D/scripts/hooks.sh" ] && [ ! -f "$D/scripts/instalar.sh" ] && grep -q "\"project\": \"tienda\"" "$D/harness.config.json" \
   && (cd "$D" && bash ./init.sh --quick >/dev/null 2>&1)' \
  -- "$D" --si
INSTALAR="$INSTALAR_ORIG"

# ---- Repo creado con «Use this template» -----------------------------------
D="$TMP/20"; template "$D"; INSTALAR="$D/scripts/instalar.sh"
caso "--desde-template desde dentro del repo: borra lo del molde, remoto y queda en el índice" 0 "Siguiente paso" \
  '[ ! -d "$D/docs-molde" ] && [ ! -f "$D/scripts/instalar.sh" ] && [ ! -f "$D/scripts/test_instalar.sh" ] \
   && [ -f "$D/README.md" ] && [ -f "$D/HARNESS.md" ] && [ -f "$D/PROYECTO.md" ] && [ -f "$D/init.sh" ] \
   && [ "$(git -C "$D" remote get-url molde)" = "https://github.com/apatinuribe/harness-base.git" ] \
   && git -C "$D" diff --cached --name-only | grep -qx "scripts/instalar.sh" && git -C "$D" diff --cached --name-only | grep -q "^docs-molde/" \
   && (cd "$D" && bash ./init.sh --quick >/dev/null 2>&1)' \
  -- --desde-template --si
INSTALAR="$INSTALAR_ORIG"

D="$TMP/21"; copia_molde "$D"; git -C "$D" init -q; INSTALAR="$D/scripts/instalar.sh"
caso "sin flag, destino = este repo sin configurar y con docs-molde/: lo detecta y cierra" 0 "Use this template" \
  '[ ! -d "$D/docs-molde" ] && [ ! -f "$D/scripts/instalar.sh" ] && [ -f "$D/HARNESS.md" ] \
   && [ "$(git -C "$D" ls-files --stage scripts/hooks.sh | cut -c1-6)" = 100755 ] && (cd "$D" && bash ./init.sh --quick >/dev/null 2>&1)' \
  -- "$D" --si
INSTALAR="$INSTALAR_ORIG"

D="$TMP/22"; template "$D"; antigua "$D"
caso "copia de disposición antigua cerrada desde otro clon: README -> HARNESS.md y portada nueva" 0 "pasa a HARNESS.md" \
  'head -1 "$D/HARNESS.md" | grep -q "^# harness-base" && grep -q "^# TODO-nombre-del-proyecto" "$D/README.md" \
   && [ ! -d "$D/docs-molde" ] && [ ! -f "$D/scripts/instalar.sh" ] && git -C "$D" diff --cached --name-only | grep -qx "HARNESS.md"' \
  -- --desde-template "$D" --si

D="$TMP/23"; template "$D"; git -C "$D" remote set-url origin https://github.com/apatinuribe/harness-base.git; INSTALAR="$D/scripts/instalar.sh"
caso "origin es el molde: --desde-template se niega y no borra nada" 1 "es el propio molde" \
  '[ -d "$D/docs-molde" ] && [ -f "$D/scripts/instalar.sh" ] && [ -f "$D/scripts/test_instalar.sh" ]' \
  -- --desde-template --si
caso "origin es el molde, sin flag: no propone cerrar" 1 "El destino es el propio molde" \
  '[ -d "$D/docs-molde" ] && [ -f "$D/scripts/instalar.sh" ]' \
  -- "$D" --si
git -C "$D" remote set-url origin git@github.com:apatinuribe/harness-base.git
caso "  ...y con la URL ssh tampoco cierra" 1 "es el propio molde" '[ -d "$D/docs-molde" ]' -- --desde-template --si
INSTALAR="$INSTALAR_ORIG"

D="$TMP/24"; template "$D"; configurada "$D"; INSTALAR="$D/scripts/instalar.sh"
caso "copia ya configurada + --desde-template: limpia y conserva project" 0 "Eliminados docs-molde/" \
  '[ ! -d "$D/docs-molde" ] && [ ! -f "$D/scripts/instalar.sh" ] && grep -q "\"project\": \"tienda\"" "$D/harness.config.json"' \
  -- --desde-template --si
INSTALAR="$INSTALAR_ORIG"

D="$TMP/25"; template "$D"
caso "copia de template sin --si ni terminal: pide --si y no toca nada" 1 "Vuelve a correr con --si" \
  '[ -d "$D/docs-molde" ] && [ -f "$D/scripts/instalar.sh" ] && [ -f "$D/HARNESS.md" ]' \
  -- "$D"

D="$TMP/26"; mkdir -p "$D"
caso "--desde-template sobre un destino sin arnés: aborta" 1 "no tiene el arnés en la raíz" '[ ! -f "$D/init.sh" ]' -- --desde-template "$D" --si
caso "--desde-template sobre un destino inexistente: aborta sin crearlo" 1 "no existe" '[ ! -e "$TMP/nada" ]' -- --desde-template "$TMP/nada" --si

caso "sin argumentos: uso" 1 "Uso:" "" --
caso "flag desconocido: uso" 1 "Opción desconocida" "" -- "$TMP/x" --nope

echo ""
echo "$((total - fallos))/$total casos OK"
[ $fallos -eq 0 ]
