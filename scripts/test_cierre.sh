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

# Los casos mutan el backlog de la plantilla (F1 despliegue_inicial pending,
# F2 ejemplo_slug pending). En una instancia con su propio backlog no hay nada
# que mutar: la suite no aplica, y decirlo vale mas que 60 fallos engañosos.
if ! $PY - "$RAIZ/feature_list.json" <<'PYCODE'
import json, sys
f = json.load(open(sys.argv[1], encoding="utf-8")).get("features", [])
ok = (len(f) == 2 and [x.get("name") for x in f] == ["despliegue_inicial", "ejemplo_slug"]
      and all(x.get("status") == "pending" for x in f))
sys.exit(0 if ok else 1)
PYCODE
then
  echo "[SKIP]  Gate de cierre: esta suite muta el backlog de la plantilla y aqui hay uno propio; corre ./init.sh --quick (o la suite en un clon del molde)"
  exit 0
fi

total=0; fallos=0

# copia_limpia <dir>: la plantilla sin .git ni artefactos.
copia_limpia() {
  rm -rf "$1"; mkdir -p "$1"
  (cd "$RAIZ" && tar --exclude=.git --exclude=node_modules --exclude=.worktrees \
      --exclude=.harness -cf - .) | (cd "$1" && tar -xf -)
  rm -f "$1"/progress/review_*.md "$1"/progress/impl_*.md "$1"/progress/plan_*.md
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

# ── Diseño (init.sh §3e y «Siguiente paso») ─────────────
# Una feature in_progress cuyo spec tiene pantallas (§4.2 con filas) y sin
# docs/diseno/<modulo>.md: FAIL si la constitución dice Audiencia: público,
# WARN con interno o sin resolver. «Siguiente paso» sale del estado, por
# precedencia: /configurar, /constitucion, /diseno <modulo>.
echo ""
echo "── Diseño (init.sh §3e y Siguiente paso) ───────────────"

SIN_DISENO="no existe docs/diseno/ejemplo.md"
# configura <dir>: project y description reales en harness.config.json.
configura()      { sed -i 's/"project": *"TODO[^"]*"/"project": "tienda"/; s/"description": *"TODO[^"]*"/"description": "x"/' "$1/harness.config.json"; }
# audiencia <dir> <valor>: resuelve la linea '**Audiencia:**' de la constitucion.
audiencia()      { sed -i "s/^\*\*Audiencia:\*\*.*/**Audiencia:** $2/" "$1/docs/architecture.md"; }
# spec_pantallas <dir> <modulo> [vacio]: spec con §4.2 con una fila de datos, o solo la fila vacia.
spec_pantallas() {
  local fila='| Lista | «Nada aún» | spinner | tabla | toast | 403 |'
  [ "${3:-}" = "vacio" ] && fila='| | | | | |'
  printf '# Spec — %s\n\n## 4. Vertical\n\n### 4.2 Pantallas y estados\n\n| Pantalla | Vacío | Cargando | Con datos | Error | Sin permiso |\n|---|---|---|---|---|---|\n%s\n\n### 4.3 Entidades\n\nninguna\n' "$2" "$fila" > "$1/docs/specs/$2.md"
}
diseno()         { mkdir -p "$1/docs/diseno"; printf '# Diseño — %s\n' "$2" > "$1/docs/diseno/$2.md"; }

# Base: feature 1 done y completa; feature 2 in_progress con spec propio.
base_dis='F[1]["status"] = "done"; F[2]["status"] = "in_progress"'
prepara_dis() {
  copia_limpia "$D"; muta "$D" "$base_dis"
  review_ok "$D" despliegue_inicial; impl_ok "$D" despliegue_inicial; tests_con "$D" F1-C1 F1-C2 F1-C3
  spec_pantallas "$D" ejemplo "${1:-}"
}

prepara_dis
caso "pantallas sin diseño, audiencia sin resolver: avisa" 0 "$D" "[WARN]  Feature 2 (ejemplo_slug): el spec tiene pantallas (§4.2) y $SIN_DISENO"
audiencia "$D" interno
caso "pantallas sin diseño, interno: avisa" 0 "$D" "[WARN]  Feature 2 (ejemplo_slug): el spec tiene pantallas (§4.2) y $SIN_DISENO — corre /diseno ejemplo"
audiencia "$D" público
caso "pantallas sin diseño, público: bloquea" 1 "$D" "[FAIL]  Feature 2 (ejemplo_slug): el spec tiene pantallas (§4.2) y $SIN_DISENO — producto público"
diseno "$D" ejemplo
caso "público con docs/diseno/ejemplo.md: pasa" 0 "$D" "diseño en docs/diseno/ejemplo.md" "$SIN_DISENO"
prepara_dis vacio; audiencia "$D" público
caso "público, §4.2 solo con la fila vacía: sin pantallas" 0 "$D" "Sin pantallas que diseñar"
prepara_dis; audiencia "$D" público; muta "$D" 'F[2]["status"] = "pending"'
caso "público, pantallas sin diseño pero pending: no aplica" 0 "$D" "Sin pantallas que diseñar" "$SIN_DISENO"

# Siguiente paso
copia_limpia "$D"
caso "siguiente paso: config sin configurar → /configurar" 0 "$D" "corre /configurar"
configura "$D"
caso "siguiente paso: constitución con TODO: → /constitucion" 0 "$D" "corre /constitucion" "corre /configurar"
prepara_dis; configura "$D"; resuelve_todos "$D"; audiencia "$D" público
caso "siguiente paso: pantallas sin diseño → /diseno ejemplo" 1 "$D" "corre /diseno ejemplo"
diseno "$D" ejemplo
caso "siguiente paso: nada pendiente → sin bloque" 0 "$D" "" "Siguiente paso"

# ── Plan (init.sh §3f y Siguiente paso) ──
# Una in_progress que requiere plan (plan_requerido: auto → migraciones o más
# de 4 criterios; true → siempre) no arranca sin progress/plan_<name>.md con
# '**Estado:** confirmado'. Solo mira las in_progress; §3d no cambia.
echo ""
echo "── Plan (init.sh §3f y Siguiente paso) ─────────────────"

PLAN_EJ="progress/plan_ejemplo_slug.md"
# plan <dir> <name> [borrador]: escribe progress/plan_<name>.md confirmado, o en borrador.
plan()           { printf '# Plan — feature %s\n\n**Estado:** %s · **Fecha:** 2026-01-01\n\n## Módulos a tocar\n\n| src/ejemplo/ | x | sí |\n' "$2" "${3:-confirmado}" > "$1/progress/plan_$2.md"; }
# plan_cfg <dir> <true|false|borra>: fija plan_requerido en harness.config.json, o quita la clave.
plan_cfg()       { if [ "$2" = "borra" ]; then sed -i '/"plan_requerido":/d' "$1/harness.config.json"; else sed -i "s/\"plan_requerido\": *\"auto\"/\"plan_requerido\": $2/" "$1/harness.config.json"; fi; }
# exclusiva <dir> <ruta>: declara una ruta en exclusive_paths.
exclusiva()      { sed -i "s|\"exclusive_paths\": *\[\]|\"exclusive_paths\": [\"$2\"]|" "$1/harness.config.json"; }
cinco='F[2]["acceptance"] = ["DADO a CUANDO b ENTONCES c"] * 5'

# Base: feature 1 done y completa; feature 2 in_progress sin pantallas (2 criterios, src/ejemplo/).
prepara_plan() {
  copia_limpia "$D"; muta "$D" "$base_dis"
  review_ok "$D" despliegue_inicial; impl_ok "$D" despliegue_inicial; tests_con "$D" F1-C1 F1-C2 F1-C3
  spec_pantallas "$D" ejemplo vacio
}

prepara_plan
caso "auto, 2 criterios, sin migraciones: plan opcional" 0 "$D" "[OK]    Feature 2 (ejemplo_slug): plan opcional (2 criterios, sin migraciones)"
muta "$D" "$cinco"
caso "auto, 5 criterios, sin plan: bloquea" 1 "$D" "[FAIL]  Feature 2 (ejemplo_slug): requiere plan (5 criterios) y no existe $PLAN_EJ — corre /planear 2"
plan "$D" ejemplo_slug borrador
caso "auto, 5 criterios, plan en borrador: bloquea" 1 "$D" "[FAIL]  Feature 2 (ejemplo_slug): $PLAN_EJ sin confirmar — corre /planear 2"
plan "$D" ejemplo_slug
caso "auto, 5 criterios, plan confirmado: pasa" 0 "$D" "[OK]    Feature 2 (ejemplo_slug): plan confirmado en $PLAN_EJ"
prepara_plan; muta "$D" 'F[2]["touches"] = ["supabase/migrations/"]'
caso "auto, 2 criterios, touches con migrations/: requiere plan" 1 "$D" "requiere plan (toca migraciones)"
prepara_plan; muta "$D" 'F[2]["touches"] = ["db/schema.sql"]'; exclusiva "$D" "db/"
caso "auto, 2 criterios, touches bajo exclusive_paths: requiere plan" 1 "$D" "requiere plan (toca migraciones)"
prepara_plan; plan_cfg "$D" true
caso "plan_requerido true, 2 criterios, sin plan: bloquea" 1 "$D" "requiere plan (plan_requerido: true)"
prepara_plan; plan_cfg "$D" false; muta "$D" "$cinco"'; F[2]["touches"] = ["supabase/migrations/"]'
caso "plan_requerido false, 5 criterios y migraciones: no exige" 0 "$D" "plan opcional (plan_requerido: false)" "requiere plan"
prepara_plan; plan_cfg "$D" borra; muta "$D" "$cinco"
caso "sin la clave (instancia 1.1.0), 5 criterios: auto" 1 "$D" "requiere plan (5 criterios)"
prepara_plan; muta "$D" "$cinco"'; F[2]["status"] = "pending"'
caso "5 criterios pero pending: no aplica" 0 "$D" "Sin features en curso que planificar" "requiere plan"

# Siguiente paso
prepara_plan; configura "$D"; resuelve_todos "$D"; muta "$D" "$cinco"
caso "siguiente paso: plan requerido sin confirmar → /planear 2" 1 "$D" "corre /planear 2"
plan "$D" ejemplo_slug
caso "siguiente paso: plan confirmado → sin bloque" 0 "$D" "" "Siguiente paso"

# ── Descubrimiento (init.sh 3g) ──
# Una entrevista es un .md de docs/descubrimiento/ que no empieza por «_» ni es
# README.md; está incorporada si _sintesis.md nombra su archivo. Solo avisa:
# el exit no cambia en ningún caso.
echo ""
echo "── Descubrimiento (init.sh 3g) ─────────────────────────"

ENT_A="2026-10-02-dueno-tienda.md"; ENT_B="2026-10-03-autoentrevista.md"
# entrevista <dir> <archivo>: escribe una entrevista mínima.
entrevista()     { printf '# Entrevista — rol · 2026-10-02\n\n**Quién:** rol · **Canal:** llamada · **Entrevistó:** yo\n\n## 1. Quién es y qué intenta conseguir\n' > "$1/docs/descubrimiento/$2"; }
# sintesis <dir> <archivos…>: escribe _sintesis.md nombrando esos archivos.
sintesis()       { local dir="$1"; shift; local lista=""; for a in "$@"; do lista="${lista:+$lista, }\`$a\`"; done; printf '# Síntesis de descubrimiento — tienda\n\n**Fecha:** 2026-10-04 · **Entrevistas:** %s (%s)\n\n## Problema\n' "$#" "$lista" > "$dir/docs/descubrimiento/_sintesis.md"; }

copia_limpia "$D"; configura "$D"
caso "plantilla (solo _guion.md): sin entrevistas" 0 "$D" "Sin entrevistas en docs/descubrimiento/" "[WARN]  docs/descubrimiento"
entrevista "$D" "$ENT_A"; entrevista "$D" "$ENT_B"
caso "2 entrevistas sin síntesis: avisa" 0 "$D" "docs/descubrimiento/: 2 entrevista(s) sin síntesis — corre /descubrir sintesis"
sintesis "$D" "$ENT_A" "$ENT_B"
caso "síntesis que nombra las dos: al día" 0 "$D" "_sintesis.md incorpora las 2 entrevistas" "[WARN]  docs/descubrimiento"
sintesis "$D" "$ENT_A"
caso "síntesis que nombra una: avisa cuál falta" 0 "$D" "1 entrevista(s) que _sintesis.md no incorpora ($ENT_B) — corre /descubrir sintesis"
copia_limpia "$D"; configura "$D"
printf 'x\n' > "$D/docs/descubrimiento/README.md"; printf 'x\n' > "$D/docs/descubrimiento/_borrador.md"
caso "README.md y _borrador.md no cuentan como entrevistas" 0 "$D" "Sin entrevistas en docs/descubrimiento/"

# ── Validación (init.sh 3h) ──
# Una done con evento sin fila F<id> en docs/validacion.md avisa cuando lleva
# validar_tras_dias (14) según la fecha de progress/history/YYYY-MM-DD-f<id>-*.md;
# sin entrada, avisa ya. «cortar» con features de ese objeto sin cerrar avisa.
# Solo avisa: el exit no cambia en ningún caso.
echo ""
echo "── Validación (init.sh 3h) ─────────────────────────────"

W_VAL="sin validar ("
# validacion <dir> <n> <objeto> <decision>: crea docs/validacion.md si falta y añade una fila.
validacion()     { [ -f "$1/docs/validacion.md" ] || printf '# Validación\n\n| # | Fecha | Objeto | Métrica | Meta y fecha | Medido | Fuente | Decisión | Siguiente |\n|---|---|---|---|---|---|---|---|---|\n' > "$1/docs/validacion.md"; printf '| %s | 2026-10-03 | %s | m | 60 %% | 42 %% | panel | %s | — |\n' "$2" "$3" "$4" >> "$1/docs/validacion.md"; }
# historia <dir> <id> <slug> <dias atrás>: entrada de history fechada hace N días.
historia()       { mkdir -p "$1/progress/history"; printf '## [%s] feature #%s | %s\n\n**Resultado:** done\n' "$(date -d "-$4 days" +%F)" "$2" "$3" > "$1/progress/history/$(date -d "-$4 days" +%F)-f$2-$3.md"; }
# dias_cfg <dir> <n|borra>: fija validar_tras_dias o quita la clave.
dias_cfg()       { if [ "$2" = "borra" ]; then sed -i '/"validar_tras_dias":/d' "$1/harness.config.json"; else sed -i "s/\"validar_tras_dias\": *[0-9]*/\"validar_tras_dias\": $2/" "$1/harness.config.json"; fi; }
# prod2 <dir>: F1 (infra) y F2 (evento) done y completas — el estado de L120-123.
prod2()          { copia_limpia "$1"; muta "$1" "$base2"; review_ok "$1" despliegue_inicial; impl_ok "$1" despliegue_inicial; review_ok "$1" ejemplo_slug; impl_ok "$1" ejemplo_slug; tests_con "$1" F1-C1 F1-C2 F1-C3 F2-C1 F2-C2; }

copia_limpia "$D"
caso "plantilla: nada en producción que validar" 0 "$D" "Sin features en producción pendientes de validar" "$W_VAL"
prod2 "$D"
caso "F2 done con evento, sin history: avisa ya" 0 "$D" "1 feature(s) en producción sin validar (F2: sin progress/history/) — corre /validar <id>"
historia "$D" 2 ejemplo_slug 3
caso "history de hace 3 días (<14): en gracia, sin aviso" 0 "$D" "1 feature(s) en producción con menos de 14 días (F2)" "$W_VAL"
rm -f "$D/progress/history/"*-f2-*.md; historia "$D" 2 ejemplo_slug 20
caso "history de hace 20 días (≥14): avisa con los días" 0 "$D" "1 feature(s) en producción sin validar (F2: 20 días done)"
dias_cfg "$D" 30
caso "validar_tras_dias: 30 → 20 días vuelve a ser gracia" 0 "$D" "con menos de 30 días (F2)" "$W_VAL"
dias_cfg "$D" borra
caso "sin la clave: 14 por defecto, avisa" 0 "$D" "1 feature(s) en producción sin validar (F2: 20 días done)"
rm -f "$D/progress/history/"*-f2-*.md; historia "$D" 2 ejemplo_slug 40; historia "$D" 2 ejemplo_slug 5
caso "dos entradas de F2: cuenta la última (5 días)" 0 "$D" "con menos de 14 días (F2)" "$W_VAL"
historia "$D" 12 otra 40
caso "f12 no cuenta como f1 ni f2" 0 "$D" "con menos de 14 días (F2)" "$W_VAL"
validacion "$D" 1 F2 seguir
caso "fila F2 · seguir: nada pendiente" 0 "$D" "docs/validacion.md: 1 validación(es), nada pendiente" "$W_VAL"
rm -f "$D/progress/history/"*-f2-*.md
caso "validada sin history: la fila basta" 0 "$D" "nada pendiente" "$W_VAL"

# cortar: KR1 con F2 abierta (kr: KR1, pending); la última fila manda.
copia_limpia "$D"; muta "$D" 'F[1]["status"] = "done"'
review_ok "$D" despliegue_inicial; impl_ok "$D" despliegue_inicial; tests_con "$D" F1-C1 F1-C2 F1-C3
validacion "$D" 1 KR1 cortar
caso "KR1 · cortar con F2 pending (kr KR1): avisa" 0 "$D" "validación #1 cortó KR1 pero F2 siguen sin cerrar — muévelas a docs/futuro/ o cámbiales el kr"
validacion "$D" 2 KR1 seguir
caso "  ...una fila posterior KR1 · seguir lo levanta" 0 "$D" "" "cortó KR1"
copia_limpia "$D"; muta "$D" 'F[1]["status"] = "done"; F[2]["corrige"] = 1'
review_ok "$D" despliegue_inicial; impl_ok "$D" despliegue_inicial; tests_con "$D" F1-C1 F1-C2 F1-C3
validacion "$D" 1 F1 cortar
caso "F1 · cortar con F2 (corrige 1) pending: avisa" 0 "$D" "validación #1 cortó F1 pero F2 siguen sin cerrar"
validacion "$D" 2 f1 ajustar
caso "objeto en minúsculas (f1) · ajustar: se parsea y levanta el corte" 0 "$D" "" "cortó F1 pero"
printf '| 3 | 2026-10-03 | KR1 | m | 60 %% | 42 %% | panel | **cortar** — razón | — |\n' >> "$D/docs/validacion.md"
caso "Decisión en negrita con cola: se parsea igual" 0 "$D" "validación #3 cortó KR1 pero F2 siguen sin cerrar"

echo ""
if [ "$fallos" -eq 0 ]; then
  echo "[OK]    Gate de cierre: $total casos, todos pasan"
else
  echo "[FAIL]  Gate de cierre: $fallos de $total casos fallan"
  exit 1
fi
