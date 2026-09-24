#!/usr/bin/env bash
# test_guard.sh — Pruebas del guard de scripts/hooks.sh (PreToolUse
# Edit|Write|MultiEdit|NotebookEdit via `guard`, y Bash via `guard-bash`).
#
# Simula el JSON que Claude Code manda al hook y comprueba el codigo de salida:
#   0 = deja pasar, 1 = deja pasar con WARN visible, 2 = BLOQUEADO.
# No toca el repo: trabaja sobre copias en un directorio temporal.
#
# Uso:  bash scripts/test_guard.sh        (desde la raiz del proyecto)
# Sale con 1 si algun caso falla.
set -u

RAIZ=$(cd "$(dirname "$0")/.." && pwd)
GUARD="$RAIZ/scripts/hooks.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PY=""
for candidate in "python" "python3" "py -3"; do
  resolved=$(command -v ${candidate%% *} 2>/dev/null || true)
  case "$resolved" in *WindowsApps*) continue ;; esac
  if $candidate -c "import sys" >/dev/null 2>&1; then PY="$candidate"; break; fi
done
if [ -z "$PY" ]; then echo "[FAIL]  Sin Python no se puede probar el guard"; exit 1; fi

fallos=0
total=0

# caso_con <subcomando> <descripcion> <esperado> <dir de trabajo> <json>
caso_con() {
  local sub="$1" desc="$2" esperado="$3" dir="$4" json="$5"
  total=$((total + 1))
  local err
  err=$(cd "$dir" && printf '%s' "$json" | bash "$GUARD" "$sub" 2>&1 >/dev/null)
  local rc=$?
  if [ "$rc" -eq "$esperado" ]; then
    printf '[OK]    %-58s exit=%s\n' "$desc" "$rc"
  else
    fallos=$((fallos + 1))
    printf '[FAIL]  %-58s exit=%s (esperado %s)\n' "$desc" "$rc" "$esperado"
  fi
  case "$desc" in
    *WARN*) printf '%s\n' "$err" | grep -q "WARN" || { fallos=$((fallos + 1)); echo "[FAIL]  ... no imprimio WARN"; } ;;
  esac
  [ "$rc" -eq 2 ] && printf '%s\n' "$err" | grep -q "BLOQUEADO" || true
}
# caso <descripcion> <esperado> <dir> <json>           -> guard (Edit/Write/...)
caso() { caso_con guard "$@"; }
# caso_bash <descripcion> <esperado> <dir> <prefijo json> <comando>  -> guard-bash
# El comando se pasa tal cual; aqui se escapa a JSON.
caso_bash() {
  local desc="$1" esperado="$2" dir="$3" pre="$4" cmd="$5"
  local cmdjson
  cmdjson=$($PY -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$cmd")
  caso_con guard-bash "$desc" "$esperado" "$dir" "{$pre\"tool_name\":\"Bash\",\"tool_input\":{\"command\":$cmdjson}}"
}

# Escenario A: backlog de la plantilla (0 in_progress). Copia limpia.
A="$TMP/a"; mkdir -p "$A/docs/specs"
cp "$RAIZ/harness.config.json" "$RAIZ/feature_list.json" "$A/"

# Escenario B: feature 1 done, feature 2 in_progress con spec docs/specs/ejemplo.md.
B="$TMP/b"; mkdir -p "$B/docs/specs"
cp "$RAIZ/harness.config.json" "$B/"
$PY - "$RAIZ/feature_list.json" "$B/feature_list.json" <<'PYCODE'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
fs = d["features"]
fs[0]["status"] = "done"
fs[1]["status"] = "in_progress"; fs[1]["spec"] = "docs/specs/ejemplo.md"
json.dump(d, open(sys.argv[2], "w", encoding="utf-8"), indent=2)
PYCODE

# Escenario C: harness.config.json corrupto.
C="$TMP/c"; mkdir -p "$C"
cp "$RAIZ/feature_list.json" "$C/"; echo "{corrupto" > "$C/harness.config.json"

SUB='"agent_id":"a1","agent_type":"implementer",'
# Ruta absoluta del escenario A, en formato Windows (C:/...) si estamos en Git Bash.
ABS=$(cd "$A" && (pwd -W 2>/dev/null || pwd))
# En JSON cada barra invertida va doblada: C:\Users\...
ABSWIN=$(printf '%s' "$ABS" | sed 's#/#\\\\#g')
# Y con una sola barra invertida, para meterla entre comillas en un comando.
ABSBS=$(printf '%s' "$ABS" | sed 's#/#\\#g')

echo "── Escenario A: 0 in_progress ──────────────────────────"
caso "R4 subagente edita feature_list.json (relativa)"      2 "$A" "{$SUB\"tool_input\":{\"file_path\":\"feature_list.json\"}}"
caso "R4 subagente edita feature_list.json (absoluta win)"  2 "$A" "{$SUB\"cwd\":\"$ABSWIN\",\"tool_input\":{\"file_path\":\"$ABSWIN\\\\feature_list.json\"}}"
caso "principal edita feature_list.json"                    0 "$A" "{\"tool_input\":{\"file_path\":\"feature_list.json\"}}"
caso "R3 principal edita src/a.ts (relativa)"               2 "$A" "{\"tool_input\":{\"file_path\":\"src/a.ts\"}}"
caso "R3 principal edita ./tests/x.py"                      2 "$A" "{\"tool_input\":{\"file_path\":\"./tests/x.py\"}}"
caso "R3 principal edita src/a.ts (absoluta posix)"         2 "$A" "{\"cwd\":\"$ABS\",\"tool_input\":{\"file_path\":\"$ABS/src/a.ts\"}}"
caso "R3 principal edita src/a.ts (absoluta win)"           2 "$A" "{\"cwd\":\"$ABSWIN\",\"tool_input\":{\"file_path\":\"$ABSWIN\\\\src\\\\a.ts\"}}"
caso "principal edita srcx/a.ts (no confunde prefijo)"      0 "$A" "{\"tool_input\":{\"file_path\":\"srcx/a.ts\"}}"
caso "implementer edita src/a.ts"                           0 "$A" "{$SUB\"tool_input\":{\"file_path\":\"src/a.ts\"}}"
caso "principal edita docs/architecture.md sin in_progress" 0 "$A" "{\"tool_input\":{\"file_path\":\"docs/architecture.md\"}}"
caso "principal edita .claude/agents/x.md"                  0 "$A" "{\"tool_input\":{\"file_path\":\".claude/agents/x.md\"}}"
caso "principal edita progress/current.md"                  0 "$A" "{\"tool_input\":{\"file_path\":\"progress/current.md\"}}"
caso "archivo fuera del proyecto"                           0 "$A" "{\"cwd\":\"$ABS\",\"tool_input\":{\"file_path\":\"/otro/src/a.ts\"}}"
caso "sin file_path"                                        0 "$A" "{\"tool_input\":{}}"
caso "R3 NotebookEdit principal sobre src/nb.ipynb"          2 "$A" "{\"tool_name\":\"NotebookEdit\",\"tool_input\":{\"notebook_path\":\"src/nb.ipynb\"}}"
caso "MultiEdit principal sobre progress/x.md"              0 "$A" "{\"tool_name\":\"MultiEdit\",\"tool_input\":{\"file_path\":\"progress/x.md\",\"edits\":[]}}"

echo "── Escenario B: feature 2 in_progress ──────────────────"
caso "R1 cualquiera edita docs/architecture.md"             2 "$B" "{\"tool_input\":{\"file_path\":\"docs/architecture.md\"}}"
caso "R1 subagente edita harness.config.json"               2 "$B" "{$SUB\"tool_input\":{\"file_path\":\"harness.config.json\"}}"
caso "R2 spec activo docs/specs/ejemplo.md"                 2 "$B" "{\"tool_input\":{\"file_path\":\"docs/specs/ejemplo.md\"}}"
caso "otro spec docs/specs/otro.md"                         0 "$B" "{\"tool_input\":{\"file_path\":\"docs/specs/otro.md\"}}"
caso "implementer edita src/a.ts con in_progress"           0 "$B" "{$SUB\"tool_input\":{\"file_path\":\"src/a.ts\"}}"
caso "principal edita feature_list.json con in_progress"    0 "$B" "{\"tool_input\":{\"file_path\":\"feature_list.json\"}}"
caso "R2 MultiEdit sobre el spec activo"                    2 "$B" "{\"tool_name\":\"MultiEdit\",\"tool_input\":{\"file_path\":\"docs/specs/ejemplo.md\",\"edits\":[{\"old_string\":\"a\",\"new_string\":\"b\"}]}}"
caso "R1 NotebookEdit sobre docs/index.md"                  2 "$B" "{\"tool_name\":\"NotebookEdit\",\"tool_input\":{\"notebook_path\":\"docs/index.md\"}}"

echo "── Escenario C: harness.config.json corrupto ───────────"
caso "WARN visible: principal edita src/a.ts, pasa con aviso" 1 "$C" "{\"tool_input\":{\"file_path\":\"src/a.ts\"}}"
caso "R4 sigue: subagente edita feature_list.json"          2 "$C" "{$SUB\"tool_input\":{\"file_path\":\"feature_list.json\"}}"

echo "── Bash, escenario A: 0 in_progress ────────────────────"
caso_bash "R3 bash: echo x > src/a.ts"                        2 "$A" "" 'echo x > src/a.ts'
caso_bash "R3 bash: printf x >> src/a.ts"                     2 "$A" "" 'printf x >> src/a.ts'
caso_bash "R3 bash: pegado >src/a.ts"                         2 "$A" "" 'echo x >src/a.ts'
caso_bash "R3 bash: sed -i sobre src/a.ts"                    2 "$A" "" "sed -i 's/a/b/' src/a.ts"
caso_bash "R3 bash: sed -i.bak -e sobre src/a.ts"             2 "$A" "" "sed -i.bak -e 's/a/b/' src/a.ts"
caso_bash "R3 bash: cat x | tee src/a.ts"                     2 "$A" "" 'cat x | tee src/a.ts'
caso_bash "R3 bash: heredoc > src/a.ts"                       2 "$A" "" $'cat <<EOF > src/a.ts\nhola\nEOF'
caso_bash "R3 bash: ruta absoluta win entre comillas"         2 "$A" "\"cwd\":\"$ABSWIN\"," "echo x > \"$ABSBS\\src\\a.ts\""
caso_bash "R4 bash: subagente sed -i feature_list.json"       2 "$A" "$SUB" "sed -i 's/pending/done/' feature_list.json"
caso_bash "implementer: echo x > src/a.ts"                    0 "$A" "$SUB" 'echo x > src/a.ts'
caso_bash "leer no es escribir: grep ... src/a.ts > out.txt"  0 "$A" "" 'grep foo src/a.ts > out.txt'
caso_bash "cat src/a.ts"                                      0 "$A" "" 'cat src/a.ts'
caso_bash "git diff src/"                                     0 "$A" "" 'git diff src/'
caso_bash "ls > /dev/null 2>&1"                               0 "$A" "" 'ls > /dev/null 2>&1'
caso_bash "> entre comillas: git commit -m \"fix a > b\""     0 "$A" "" 'git commit -m "fix a > b"'
caso_bash "comando del Stop hook: ./init.sh --quick > .harness/init.log" 0 "$A" "" './init.sh --quick > .harness/init.log'
caso_bash "echo x > srcx/a.ts (no confunde prefijo)"          0 "$A" "" 'echo x > srcx/a.ts'
caso_bash "echo x > /otro/src/a.ts (fuera del proyecto)"      0 "$A" "\"cwd\":\"$ABS\"," 'echo x > /otro/src/a.ts'
caso_bash "echo x > docs/architecture.md sin in_progress"     0 "$A" "" 'echo x > docs/architecture.md'
caso_bash "sed sin -i sobre src/a.ts"                         0 "$A" "" "sed 's/a/b/' src/a.ts"
caso_con guard-bash "sin command"                             0 "$A" "{\"tool_input\":{}}"

echo "── Bash, escenario B: feature 2 in_progress ────────────"
caso_bash "R1 bash: echo x >> docs/architecture.md"           2 "$B" "" 'echo x >> docs/architecture.md'
caso_bash "R2 bash: tee -a docs/specs/ejemplo.md"             2 "$B" "" 'echo x | tee -a docs/specs/ejemplo.md'
caso_bash "R1 bash: subagente sed -i harness.config.json"     2 "$B" "$SUB" "sed -i 's/a/b/' harness.config.json"
caso_bash "otro spec: echo x > docs/specs/otro.md"            0 "$B" "" 'echo x > docs/specs/otro.md'

echo "── Bash, escenario C: harness.config.json corrupto ─────"
caso_bash "WARN visible: echo x > src/a.ts, pasa con aviso"   1 "$C" "" 'echo x > src/a.ts'
caso_bash "R4 sigue: subagente > feature_list.json"           2 "$C" "$SUB" 'echo x > feature_list.json'

echo ""
if [ "$fallos" -eq 0 ]; then
  echo "[OK]    Guard: $total casos, todos pasan"
else
  echo "[FAIL]  Guard: $fallos de $total casos fallan"
  exit 1
fi
