#!/usr/bin/env bash
# hooks.sh — Helpers para los hooks de .claude/settings.json.
# Reciben por stdin el JSON del hook (tool_input.file_path).
#
#   hooks.sh guard      (PreToolUse Edit|Write)
#       Bloquea la edición de los archivos que definen el estándar de
#       verificación mientras haya una feature in_progress. Es la regla
#       anti-trampa: el arnés no se relaja para que el trabajo pase.
#   hooks.sh post-edit  (PostToolUse Edit|Write)
#       Corre ./init.sh --quick, saltándolo para ediciones de bitácora
#       (progress/, docs/, .claude/) que no afectan al estado verificable.
#
# Limitación conocida: solo intercepta Edit/Write. Un agente podría editar
# via Bash; esa vía la cubren las reglas de los agentes, no este hook.
set -u

PY=""
for candidate in "python" "python3" "py -3"; do
  resolved=$(command -v ${candidate%% *} 2>/dev/null || true)
  case "$resolved" in *WindowsApps*) continue ;; esac
  if $candidate -c "import sys" >/dev/null 2>&1; then PY="$candidate"; break; fi
done
[ -z "$PY" ] && exit 0  # sin Python no se puede analizar el JSON: no bloquees

INPUT=$(cat)

case "${1:-}" in
  guard)
    printf '%s' "$INPUT" | $PY -c '
import json, sys
fp = json.load(sys.stdin).get("tool_input", {}).get("file_path", "")
fp = fp.replace(chr(92), "/")
protected = ("harness.config.json", "CHECKPOINTS.md",
             "docs/architecture.md", "docs/conventions.md", "docs/verification.md")
if not any(fp == p or fp.endswith("/" + p) for p in protected):
    sys.exit(0)
try:
    feats = json.load(open("feature_list.json", encoding="utf-8"))["features"]
except Exception:
    sys.exit(0)
if any(f.get("status") == "in_progress" for f in feats):
    sys.stderr.write(
        "[harness] BLOQUEADO: " + fp + " es inmutable mientras hay una feature "
        "in_progress. El estandar no se ajusta para que el trabajo pase. "
        "Cierra (done/blocked) la feature antes de tocar el arnes.\n")
    sys.exit(2)
'
    exit $?
    ;;
  post-edit)
    printf '%s' "$INPUT" | $PY -c '
import json, sys
fp = json.load(sys.stdin).get("tool_input", {}).get("file_path", "")
fp = fp.replace(chr(92), "/")
noisy = ("/progress/", "/docs/", "/.claude/")
skip = fp.startswith(("progress/", "docs/", ".claude/")) or any(s in fp for s in noisy)
sys.exit(10 if skip else 0)
'
    [ $? -eq 10 ] && exit 0
    bash ./init.sh --quick 2>&1 | tail -5
    ;;
esac
exit 0
