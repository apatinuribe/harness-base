#!/usr/bin/env bash
# init.sh — Verificación e inicialización del arnés (agnóstico de stack)
#
# Se ejecuta al COMENZAR una sesión y antes de declarar cualquier tarea `done`.
# Si falla, la sesión no avanza.
#
# Los comandos de verificación NO están hardcodeados: salen de harness.config.json.
#
# Uso:
#   ./init.sh          verificación completa
#   ./init.sh --plan   además, imprime qué features pueden correr en paralelo
#   ./init.sh --quick  salta el bloque de verificación (solo estructura y estado)

set -u
export PYTHONIOENCODING=utf-8

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
ok()   { printf "${GREEN}[OK]${NC}    %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
fail() { printf "${RED}[FAIL]${NC}  %s\n" "$1"; }

EXIT_CODE=0
MODE="${1:-}"

echo "── 1. Entorno ──────────────────────────────────────────"

PY=""
for candidate in "python" "python3" "py -3"; do
  resolved=$(command -v ${candidate%% *} 2>/dev/null || true)
  case "$resolved" in *WindowsApps*) continue ;; esac
  if $candidate -c "import sys" >/dev/null 2>&1; then PY="$candidate"; break; fi
done
if [ -z "$PY" ]; then
  fail "No se encontró Python (solo se usa como herramienta del arnés, no del proyecto)"
  exit 1
fi
ok "$PY -> $($PY --version 2>&1)"

if [ ! -f harness.config.json ]; then
  fail "Falta harness.config.json — este arnés no está configurado"
  exit 1
fi
ok "harness.config.json presente"

echo ""
echo "── 2. Archivos base del arnés ──────────────────────────"

$PY - <<'PYCODE'
import json, os, sys
cfg = json.load(open("harness.config.json", encoding="utf-8"))
missing = [f for f in cfg.get("required_files", []) if not os.path.exists(f)]
for f in cfg.get("required_files", []):
    print(("[FAIL]  Falta " if f in missing else "[OK]    Existe ") + f)
todos = []
if "TODO" in cfg.get("project", ""):
    todos.append("harness.config.json: campo 'project' sin configurar")
for p in ("docs/architecture.md", "docs/conventions.md", "docs/verification.md"):
    if os.path.exists(p) and "TODO" in open(p, encoding="utf-8").read():
        todos.append(f"{p} contiene TODOs sin resolver")
for t in todos:
    print("[WARN]  " + t)
sys.exit(1 if missing else 0)
PYCODE
[ $? -ne 0 ] && EXIT_CODE=1

echo ""
echo "── 3. Estado del backlog ───────────────────────────────"

$PY - <<'PYCODE'
import json, sys
try:
    data = json.load(open("feature_list.json", encoding="utf-8"))
except Exception as e:
    print(f"[FAIL]  feature_list.json inválido: {e}"); sys.exit(1)

feats = data["features"]
valid = set(data.get("rules", {}).get("valid_status",
            ["pending", "in_progress", "done", "blocked"]))
errors = []

ids = [f["id"] for f in feats]
if len(ids) != len(set(ids)):
    errors.append("Hay ids duplicados en feature_list.json")

in_progress = [f for f in feats if f["status"] == "in_progress"]
if len(in_progress) > 1:
    errors.append(f"Hay {len(in_progress)} features en in_progress (máximo 1 por worktree)")

by_id = {f["id"]: f for f in feats}
for f in feats:
    if f["status"] not in valid:
        errors.append(f"Estado inválido en feature {f['id']}: {f['status']}")
    if not f.get("acceptance"):
        errors.append(f"Feature {f['id']} ({f['name']}) no tiene criterios de acceptance")
    if not f.get("touches"):
        errors.append(f"Feature {f['id']} ({f['name']}) no declara 'touches' — imposible paralelizar con seguridad")
    for dep in f.get("depends_on", []):
        if dep not in by_id:
            errors.append(f"Feature {f['id']} depende de {dep}, que no existe")
        elif f["status"] in ("in_progress", "done") and by_id[dep]["status"] != "done":
            errors.append(f"Feature {f['id']} avanzó pero su dependencia {dep} no está done")

for e in errors:
    print("[FAIL]  " + e)
if not errors:
    counts = {}
    for f in feats:
        counts[f["status"]] = counts.get(f["status"], 0) + 1
    print(f"[OK]    Backlog válido ({len(feats)} features: " +
          ", ".join(f"{k}={v}" for k, v in sorted(counts.items())) + ")")
    if in_progress:
        f = in_progress[0]
        print(f"[OK]    En curso: #{f['id']} {f['name']} -> {', '.join(f['touches'])}")
sys.exit(1 if errors else 0)
PYCODE
[ $? -ne 0 ] && EXIT_CODE=1

echo ""
echo "── 3b. Especificación ────────────────────────────────"

$PY - <<'PYCODE'
import json, os, sys
try:
    feats = json.load(open("feature_list.json", encoding="utf-8"))["features"]
except Exception as e:
    print("[FAIL]  feature_list.json ilegible: %s" % e); sys.exit(1)

MARK = "[NEEDS CLARIFICATION"
errors, warns, oks = [], [], 0

# Una feature no puede ARRANCAR sin spec resuelto. Mientras esta 'pending'
# solo se avisa: el backlog puede tener ideas todavia sin especificar.
for f in feats:
    fid, name, status = f.get("id"), f.get("name", "?"), f.get("status")
    started = status in ("in_progress", "done")
    bucket = errors if started else warns
    spec = f.get("spec")
    if not spec:
        bucket.append("Feature %s (%s) no declara 'spec'%s"
                      % (fid, name, " y ya esta %s" % status if started
                         else " todavia -- corre /especificar"))
        continue
    if not os.path.exists(spec):
        bucket.append("Feature %s (%s): no existe %s" % (fid, name, spec))
        continue
    pend = open(spec, encoding="utf-8").read().count(MARK)
    if pend:
        bucket.append("Feature %s (%s): %s tiene %d '%s ...]' sin resolver"
                      % (fid, name, spec, pend, MARK))
        continue
    oks += 1

for e in errors:
    print("[FAIL]  " + e)
for w in warns:
    print("[WARN]  " + w)
if oks:
    print("[OK]    %d feature(s) con spec resuelto" % oks)
if not errors and not warns and not oks:
    print("[OK]    Sin features que especificar")
sys.exit(1 if errors else 0)
PYCODE
[ $? -ne 0 ] && EXIT_CODE=1

if [ "$MODE" = "--quick" ]; then
  echo ""
  echo "── Resumen (modo quick) ────────────────────────────────"
  [ $EXIT_CODE -eq 0 ] && ok "Estructura y estado OK (verificación omitida)" || fail "Revisa los errores"
  exit $EXIT_CODE
fi

echo ""
echo "── 4. Verificación del proyecto ────────────────────────"

VERIFY_PLAN=$($PY -c "
import json
cfg = json.load(open('harness.config.json', encoding='utf-8'))
for c in cfg.get('verify', []):
    print('%s\t%s\t%s' % (c['name'], int(c.get('required', True)), c['command']))
")

if [ -z "$VERIFY_PLAN" ]; then
  warn "No hay comandos de verificación en harness.config.json"
else
  while IFS=$'\t' read -r name required command; do
    [ -z "$name" ] && continue
    echo "  → $name: $command"
    out=$(eval "$command" 2>&1); rc=$?
    printf '%s\n' "$out" | sed 's/^/    /'
    if [ $rc -eq 0 ]; then
      ok "$name"
    else
      if [ "$required" = "1" ]; then fail "$name (obligatorio)"; EXIT_CODE=1
      else warn "$name (opcional) falló"; fi
    fi
  done <<< "$VERIFY_PLAN"
fi

if [ "$MODE" = "--plan" ]; then
  echo ""
  echo "── 5. Plan de paralelización ───────────────────────────"
  $PY scripts/plan_parallel.py
fi

echo ""
echo "── Resumen ─────────────────────────────────────────────"
if [ $EXIT_CODE -eq 0 ]; then
  ok "Entorno listo. Puedes empezar a trabajar."
else
  fail "Entorno NO está listo. Resuelve los errores antes de avanzar."
fi
exit $EXIT_CODE
