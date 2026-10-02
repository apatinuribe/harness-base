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

# caso <desc> <exit esperado> <dir> <texto que debe aparecer, o ""> [<texto que NO debe aparecer>]
caso() {
  local desc="$1" esperado="$2" dir="$3" texto="$4" sin="${5:-}"
  total=$((total + 1))
  local salida rc
  salida=$(cd "$dir" && bash ./init.sh --quick 2>&1); rc=$?
  local ok=1
  [ "$rc" -eq "$esperado" ] || ok=0
  if [ -n "$texto" ] && ! printf '%s\n' "$salida" | grep -qF -- "$texto"; then ok=0; fi
  if [ -n "$sin" ] && printf '%s\n' "$salida" | grep -qF -- "$sin"; then ok=0; fi
  if [ "$ok" -eq 1 ]; then
    printf '[OK]    %-58s exit=%s\n' "$desc" "$rc"
  else
    fallos=$((fallos + 1))
    printf '[FAIL]  %-58s exit=%s (esperado %s' "$desc" "$rc" "$esperado"
    [ -n "$texto" ] && printf ', con "%s"' "$texto"
    [ -n "$sin" ] && printf ', sin "%s"' "$sin"
    printf ')\n'
    printf '%s\n' "$salida" | sed -n '/── 2\./,/Resumen/p' | sed 's/^/        | /'
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

# 'kr' solo es obligatorio cuando PROYECTO.md declara KRs (la regla esta en su
# cabecera): la plantilla sin rellenar no cuenta, ni KR<n> en backticks o citas.
copia_limpia "$D"; muta "$D" 'F[1]["status"] = "done"'
review_ok "$D" despliegue_inicial; impl_ok "$D" despliegue_inicial; tests_con "$D" F1-C1 F1-C2 F1-C3
caso "sin kr, PROYECTO.md de plantilla (no declara KRs)" 0 "$D" "1 feature(s) done con review APPROVED"
printf '| KR1 | Pedidos sin llamar | %% desde la app | 60 %% | CE-001 |\n' >> "$D/PROYECTO.md"
caso "sin kr, PROYECTO.md declara KR1" 1 "$D" "Feature 1 (despliegue_inicial) done sin 'kr'"
copia_limpia "$D"; muta "$D" 'F[1]["status"] = "done"'
review_ok "$D" despliegue_inicial; impl_ok "$D" despliegue_inicial; tests_con "$D" F1-C1 F1-C2 F1-C3
printf 'Inline: `KR1`.\n```\n| KR1 | en bloque |\n```\n> KR1 en cita\n' >> "$D/PROYECTO.md"
caso "KR1 solo en backticks o en cita no cuenta" 0 "$D" "1 feature(s) done con review APPROVED"

# ── Marcadores (init.sh §2 y §3b) ────────────────────────
# §2 avisa por 'TODO:' como token (inicio de linea, cita, celda, etiqueta) y
# §3b bloquea por '[NEEDS CLARIFICATION: ...]' con contenido. Ninguno cuenta
# dentro de backticks ni de bloques ```; 'TODO(#12)' en prosa tampoco.
echo ""
echo "── Marcadores (init.sh §2 y §3b) ───────────────────────"

W_TODO="contiene 'TODO:' sin resolver"
W_NEEDS="'[NEEDS CLARIFICATION: ...]' sin resolver"
# resuelve_todos <dir>: deja los tres docs de §2 sin ningun 'TODO:'.
resuelve_todos() {
  local p
  for p in docs/architecture.md docs/conventions.md docs/verification.md; do
    sed -i 's/TODO:/Hecho:/g' "$1/$p"
  done
}

copia_limpia "$D"
caso "plantilla: avisa 'TODO:' en los docs" 0 "$D" "$W_TODO"
resuelve_todos "$D"
caso "docs sin 'TODO:': no avisa" 0 "$D" "" "$W_TODO"
printf 'Los pendientes en código llevan id: TODO(#12) y se cierran con el issue.\nUn TODO-123 o un #TODO tampoco son huecos.\n' >> "$D/docs/conventions.md"
caso "TODO(#12) en prosa no es un hueco" 0 "$D" "" "$W_TODO"
printf 'Ejemplo: `TODO: en backticks`.\n```\nTODO: en bloque de código\n```\n' >> "$D/docs/conventions.md"
caso "'TODO:' solo en backticks o bloque no cuenta" 0 "$D" "" "$W_TODO"
printf 'TODO: al inicio de línea.\n' >> "$D/docs/conventions.md"
caso "'TODO:' al inicio de línea avisa" 0 "$D" "docs/conventions.md $W_TODO"
resuelve_todos "$D"
printf '> TODO: en una cita de plantilla.\n' >> "$D/docs/verification.md"
caso "'> TODO:' en cita avisa" 0 "$D" "docs/verification.md $W_TODO"
resuelve_todos "$D"
printf '| Criterio | TODO: qué es un 1 | ok |\n' >> "$D/docs/architecture.md"
caso "'| TODO:' en celda avisa" 0 "$D" "docs/architecture.md $W_TODO"
resuelve_todos "$D"
printf '**Ratificada:** TODO: fecha\n' >> "$D/docs/architecture.md"
caso "'**Etiqueta:** TODO:' avisa" 0 "$D" "docs/architecture.md $W_TODO"

# §3b: la feature 1 apunta a docs/architecture.md; in_progress convierte el
# aviso en bloqueo.
copia_limpia "$D"; muta "$D" 'F[1]["status"] = "in_progress"'
caso "spec sin pendientes: in_progress pasa" 0 "$D" "1 feature(s) con spec resuelto"
printf '\n[NEEDS CLARIFICATION: ¿quién aprueba el despliegue?]\n' >> "$D/docs/architecture.md"
caso "spec con [NEEDS CLARIFICATION: ...] bloquea" 1 "$D" "tiene 1 $W_NEEDS"
copia_limpia "$D"; muta "$D" 'F[1]["status"] = "in_progress"'
printf '\nSin `[NEEDS CLARIFICATION]` ni `[NEEDS CLARIFICATION: ejemplo]` abiertos.\n```\n[NEEDS CLARIFICATION: en bloque]\n```\n' >> "$D/docs/architecture.md"
caso "marcador citado en backticks o bloque no cuenta" 0 "$D" "1 feature(s) con spec resuelto"
printf '\nQueda [NEEDS CLARIFICATION] sin pregunta, y [NEEDS CLARIFICATION:   ] vacío.\n' >> "$D/docs/architecture.md"
caso "marcador sin contenido no cuenta" 0 "$D" "1 feature(s) con spec resuelto"
printf '\n[NEEDS CLARIFICATION: ¿una?] y [NEEDS CLARIFICATION: ¿dos?]\n' >> "$D/docs/architecture.md"
caso "dos pendientes reales: cuenta 2" 1 "$D" "tiene 2 $W_NEEDS"

echo ""
if [ "$fallos" -eq 0 ]; then
  echo "[OK]    Gate de cierre: $total casos, todos pasan"
else
  echo "[FAIL]  Gate de cierre: $fallos de $total casos fallan"
  exit 1
fi
