#!/usr/bin/env bash
# test_cierre.sh — Pruebas del gate de cierre de init.sh (§3d, features done).
#
# Copia la plantilla a un directorio temporal, la muta (feature done sin
# review, sin tests, con veredicto rechazado, etc.), corre `init.sh --quick`
# y comprueba el codigo de salida y el texto que tiene que aparecer.
# No toca el repo.
#
# Uso:  bash scripts/test_cierre.sh        (desde la raiz del proyecto)
# Sale con 1 si algun caso falla.
set -u

RAIZ=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PY=""
for candidate in "python" "python3" "py -3"; do
  resolved=$(command -v ${candidate%% *} 2>/dev/null || true)
  case "$resolved" in *WindowsApps*) continue ;; esac
  if $candidate -c "import sys" >/dev/null 2>&1; then PY="$candidate"; break; fi
done
[ -z "$PY" ] && { echo "[FAIL]  No se encontro Python"; exit 1; }

total=0; fallos=0

# copia_limpia <dir>: la plantilla sin .git ni artefactos.
copia_limpia() {
  rm -rf "$1"; mkdir -p "$1"
  (cd "$RAIZ" && tar --exclude=.git --exclude=node_modules --exclude=.worktrees \
      --exclude=.harness -cf - .) | (cd "$1" && tar -xf -)
  rm -f "$1"/progress/review_*.md "$1"/progress/impl_*.md
}

# muta <dir> <script python>: edita feature_list.json de la copia.
muta() {
  "$PY" - "$1/feature_list.json" <<PYCODE
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
F = {f["id"]: f for f in d["features"]}
$2
json.dump(d, open(p, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
PYCODE
}

review_ok()  { printf '# Review — feature %s\n\n**Veredicto:** APPROVED\n' "$2" > "$1/progress/review_$2.md"; }
review_ko()  { printf '# Review — feature %s\n\n**Veredicto:** CHANGES_REQUESTED\n\nAPPROVED no, todavia.\n' "$2" > "$1/progress/review_$2.md"; }
impl_ok()    { printf '# Informe — %s\n\n- producción: exenta — infra: plantilla\n' "$2" > "$1/progress/impl_$2.md"; }
tests_con()  { local dir="$1"; shift; mkdir -p "$dir/tests"; { for id in "$@"; do printf 'test("%s pasa", () => {});\n' "$id"; done; } > "$dir/tests/cierre.test.js"; }

# caso <desc> <exit esperado> <dir> <texto que debe aparecer, o "">
caso() {
  local desc="$1" esperado="$2" dir="$3" texto="$4"
  total=$((total + 1))
  local salida rc
  salida=$(cd "$dir" && bash ./init.sh --quick 2>&1); rc=$?
  local ok=1
  [ "$rc" -eq "$esperado" ] || ok=0
  if [ -n "$texto" ] && ! printf '%s\n' "$salida" | grep -qF -- "$texto"; then ok=0; fi
  if [ "$ok" -eq 1 ]; then
    printf '[OK]    %-58s exit=%s\n' "$desc" "$rc"
  else
    fallos=$((fallos + 1))
    printf '[FAIL]  %-58s exit=%s (esperado %s' "$desc" "$rc" "$esperado"
    [ -n "$texto" ] && printf ', con "%s"' "$texto"
    printf ')\n'
    printf '%s\n' "$salida" | sed -n '/3d\./,/Resumen/p' | sed 's/^/        | /'
  fi
}

D="$TMP/t"

echo "── Gate de cierre (init.sh §3d) ────────────────────────"

copia_limpia "$D"
caso "plantilla limpia: nada que auditar" 0 "$D" "Sin features done que auditar"

copia_limpia "$D"; muta "$D" 'F[1]["status"] = "done"'
caso "done sin review ni informe ni tests" 1 "$D" "no existe progress/review_despliegue_inicial.md"
caso "  ...tambien reclama el informe" 1 "$D" "no existe progress/impl_despliegue_inicial.md"
caso "  ...y cada criterio sin test (F1-C3)" 1 "$D" "ningún archivo menciona F1-C3"

copia_limpia "$D"; muta "$D" 'F[1]["status"] = "done"'
review_ko "$D" despliegue_inicial; impl_ok "$D" despliegue_inicial; tests_con "$D" F1-C1 F1-C2 F1-C3
caso "review con CHANGES_REQUESTED" 1 "$D" "es CHANGES_REQUESTED, no APPROVED"

copia_limpia "$D"; muta "$D" 'F[1]["status"] = "done"'
review_ok "$D" despliegue_inicial; impl_ok "$D" despliegue_inicial; tests_con "$D" F1-C1 F1-C2 F1-C3
caso "done completa (review, informe, 3 tests, infra)" 0 "$D" "1 feature(s) done con review APPROVED"

copia_limpia "$D"; muta "$D" 'F[1]["status"] = "done"'
review_ok "$D" despliegue_inicial; impl_ok "$D" despliegue_inicial; tests_con "$D" F1-C1 F1-C2
printf -- '- criterio: "F1-C3 · DADO un despliegue fallido..."\n  manual: la reversión la hace el proveedor, no hay API\n  evidencia: docs/capturas/rollback.png\n' >> "$D/progress/impl_despliegue_inicial.md"
caso "criterio 3 declarado manual en el informe" 0 "$D" "1 feature(s) done con review APPROVED"

copia_limpia "$D"; muta "$D" 'F[1]["status"] = "done"'
review_ok "$D" despliegue_inicial; impl_ok "$D" despliegue_inicial; tests_con "$D" F1-C10 F1-C2 F1-C3
caso "F1-C10 no cuenta como F1-C1 (borde de palabra)" 1 "$D" "ningún archivo menciona F1-C1 "

copia_limpia "$D"; muta "$D" 'F[1]["status"] = "done"'
review_ok "$D" despliegue_inicial; impl_ok "$D" despliegue_inicial
printf -- '- [x] F1-C1 test\n- [x] F1-C2 test\n- [x] F1-C3 test\n' >> "$D/progress/review_despliegue_inicial.md"
caso "citar el id en progress/ no vale como test" 1 "$D" "ningún archivo menciona F1-C1 "

# Feature 2 (evento) done encima de la 1 done y completa.
base2='F[1]["status"] = "done"; F[2]["status"] = "done"; F[2]["spec"] = "docs/architecture.md"'
copia_limpia "$D"; muta "$D" "$base2"'; F[2]["depends_on"] = []'
review_ok "$D" despliegue_inicial; impl_ok "$D" despliegue_inicial; review_ok "$D" ejemplo_slug; impl_ok "$D" ejemplo_slug
tests_con "$D" F1-C1 F1-C2 F1-C3 F2-C1 F2-C2
caso "evento sin depender de despliegue_inicial" 1 "$D" "no depende de despliegue_inicial (#1)"

copia_limpia "$D"; muta "$D" "$base2"'; del F[2]["evento"]'
review_ok "$D" despliegue_inicial; impl_ok "$D" despliegue_inicial; review_ok "$D" ejemplo_slug; impl_ok "$D" ejemplo_slug
tests_con "$D" F1-C1 F1-C2 F1-C3 F2-C1 F2-C2
caso "done sin evento ni infra" 1 "$D" "Feature 2 (ejemplo_slug) done no declara evento ni infra"

copia_limpia "$D"; muta "$D" "$base2"
review_ok "$D" despliegue_inicial; impl_ok "$D" despliegue_inicial; review_ok "$D" ejemplo_slug; impl_ok "$D" ejemplo_slug
tests_con "$D" F1-C1 F1-C2 F1-C3 F2-C1 F2-C2
caso "dos done completas (infra + evento con dependencia)" 0 "$D" "2 feature(s) done con review APPROVED"

echo ""
if [ "$fallos" -eq 0 ]; then
  echo "[OK]    Gate de cierre: $total casos, todos pasan"
else
  echo "[FAIL]  Gate de cierre: $fallos de $total casos fallan"
  exit 1
fi
