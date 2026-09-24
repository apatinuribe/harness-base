#!/usr/bin/env bash
# test_instalar.sh — Pruebas de scripts/instalar.sh.
#
# Copia el molde a un directorio temporal (origen) y monta destinos con las
# situaciones reales: repo vacío, sin git, con .gitignore propio, con
# colisiones, ya instanciado, y el error del arnés anidado (mi-proyecto/
# harness-base/) con y sin trabajo, con y sin conflicto. Comprueba el código
# de salida, el texto que tiene que aparecer y el estado del disco.
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
   && [ -f "$D/.githooks/pre-push" ] && [ ! -f "$D/README.md" ] && [ ! -d "$D/docs/futuro" ] && [ ! -d "$D/.harness" ] \
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

D="$TMP/6"; mkdir -p "$D"; git -C "$D" init -q; bash "$INSTALAR" "$D" --si >/dev/null 2>&1 < /dev/null
echo "propio" > "$D/progress/current.md"
caso "destino ya instanciado: aborta y remite a actualizar" 1 "Actualizar una instancia" \
  '[ "$(cat "$D/progress/current.md")" = "propio" ]' \
  -- "$D"

D="$TMP/7"; mkdir -p "$D"; git -C "$D" init -q; echo '{}' > "$D/package.json"
copia_molde "$D/harness-base"; configurada "$D/harness-base"; mkdir -p "$D/harness-base/.git"; echo x > "$D/harness-base/.git/HEAD"
caso "anidado harness-base/ con trabajo, sin conflicto: se mueve a la raíz" 0 "Movidos" \
  '[ -f "$D/init.sh" ] && [ -f "$D/HARNESS.md" ] && [ ! -e "$D/harness-base" ] && [ ! -d "$D/docs/futuro" ] \
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
   && grep -q "\"harness_version\": \"1.0.0\"" "$D/harness.config.json" && (cd "$D" && bash ./init.sh --quick >/dev/null 2>&1)' \
  -- "$D" --si

D="$TMP/12"; mkdir -p "$D"; git -C "$D" init -q; bash "$INSTALAR" "$D" --si >/dev/null 2>&1 < /dev/null
copia_molde "$D/harness-base"
caso "raíz instanciada Y copia anidada: aborta y señala la que sobra" 1 "harness-base" \
  '[ -d "$D/harness-base" ] && [ -f "$D/init.sh" ]' \
  -- "$D" --si

# El caso real: el instalador corre DESDE la copia anidada (bash harness-base/scripts/instalar.sh .)
D="$TMP/13"; mkdir -p "$D"; git -C "$D" init -q; echo '{}' > "$D/package.json"; copia_molde "$D/harness-base"
INSTALAR_ORIG="$INSTALAR"; INSTALAR="$D/harness-base/scripts/instalar.sh"
caso "instalador corrido desde la copia anidada sin configurar: reinstala y borra su propio origen" 0 "eliminado"   '[ ! -e "$D/harness-base" ] && [ -f "$D/init.sh" ] && [ -f "$D/scripts/instalar.sh" ] && [ -f "$D/package.json" ]    && [ "$(git -C "$D" ls-files --stage scripts/instalar.sh | cut -c1-6)" = 100755 ] && (cd "$D" && bash ./init.sh --quick >/dev/null 2>&1)'   -- "$D" --si
INSTALAR="$INSTALAR_ORIG"

D="$TMP/14"; mkdir -p "$D"; git -C "$D" init -q; copia_molde "$D/harness-base"; configurada "$D/harness-base"
INSTALAR="$D/harness-base/scripts/instalar.sh"
caso "instalador corrido desde la copia anidada con trabajo: se mueve a sí mismo a la raíz" 0 "Movidos"   '[ ! -e "$D/harness-base" ] && [ -f "$D/scripts/instalar.sh" ] && grep -q "\"project\": \"tienda\"" "$D/harness.config.json"    && (cd "$D" && bash ./init.sh --quick >/dev/null 2>&1)'   -- "$D" --si
INSTALAR="$INSTALAR_ORIG"

caso "sin argumentos: uso" 1 "Uso:" "" --
caso "flag desconocido: uso" 1 "Opción desconocida" "" -- "$TMP/x" --nope

echo ""
echo "$((total - fallos))/$total casos OK"
[ $fallos -eq 0 ]
