#!/usr/bin/env bash
# hooks.sh — Helpers para los hooks de .claude/settings.json.
# Reciben por stdin el JSON del hook (tool_input.file_path, y agent_id /
# agent_type cuando el que llama es un subagente).
#
#   hooks.sh guard      (PreToolUse Edit|Write)
#       Aplica cuatro reglas. Las dos primeras son la regla anti-trampa: el
#       arnés no se relaja para que el trabajo pase. Las otras dos reparten
#       quién puede tocar qué entre la sesión principal (leader) y los
#       subagentes.
#         R1  Los archivos del estándar del arnés (lista fija abajo) son
#             inmutables mientras haya una feature in_progress. Para todos.
#         R2  El spec de la feature in_progress es inmutable. Para todos.
#         R3  Las rutas de `protected_paths` (harness.config.json) son del
#             producto: las edita el subagente implementer, nunca la sesión
#             principal. Se lee de la config porque cada stack tiene sus
#             carpetas.
#         R4  feature_list.json solo lo edita la sesión principal. Ningún
#             subagente cambia estados (el implementer no marca done; el
#             leader lo hace cuando el reviewer aprueba). Lista fija: si
#             fuera configurable, el arnés podría relajarse desde la config.
#       Cómo distingue leader de subagente: Claude Code añade `agent_id` al
#       JSON del hook solo cuando la llamada viene de un subagente.
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
import json, os, sys
datos = json.load(sys.stdin)
fp = datos.get("tool_input", {}).get("file_path", "")
if not fp:
    sys.exit(0)

# Ruta relativa a la raiz del proyecto, con barras "/". Edit y Write suelen
# mandar rutas absolutas (y en Windows con barras invertidas).
raiz = (datos.get("cwd") or os.getcwd()).replace(chr(92), "/").rstrip("/")
fp = fp.replace(chr(92), "/")
if os.path.isabs(fp) or (len(fp) > 1 and fp[1] == ":"):
    if fp.lower().startswith(raiz.lower() + "/"):
        fp = fp[len(raiz) + 1:]
    else:
        sys.exit(0)  # fuera del proyecto: no es asunto de este guard
if fp.startswith("./"):
    fp = fp[2:]

def bajo(ruta, patron):
    # "src/" cubre la carpeta entera; "docs/index.md" es un archivo exacto.
    patron = patron.replace(chr(92), "/")
    if patron.endswith("/"):
        return ruta.startswith(patron)
    return ruta == patron

es_subagente = bool(datos.get("agent_id"))
agente = datos.get("agent_type") or "subagente"

def bloquear(msg):
    sys.stderr.write("[harness] BLOQUEADO: " + msg + chr(10))
    sys.exit(2)

# R4 -- feature_list.json: solo la sesion principal cambia estados.
if es_subagente and bajo(fp, "feature_list.json"):
    bloquear(
        "feature_list.json solo lo edita la sesion principal (leader). "
        "Un subagente (" + agente + ") no cambia estados de features: "
        "escribe tu informe en progress/ y el leader marcara la feature "
        "cuando el reviewer la apruebe.")

# R3 -- protected_paths: trabajo del producto, lo hace el implementer.
try:
    cfg = json.load(open("harness.config.json", encoding="utf-8"))
    protegidas = [p for p in cfg.get("protected_paths", []) if isinstance(p, str) and p]
except Exception:
    protegidas = []  # sin config legible no se bloquea a ciegas; init.sh ya avisa
if not es_subagente:
    golpe = next((p for p in protegidas if bajo(fp, p)), None)
    if golpe:
        bloquear(
            fp + " esta en protected_paths de harness.config.json (" + golpe + "): "
            "es trabajo del producto y lo hace el subagente implementer, no la "
            "sesion principal. Lanza implementer con la feature que corresponda.")

# R1 / R2 -- estandar del arnes y spec activo, congelados con feature in_progress.
estandar = ("harness.config.json", "CHECKPOINTS.md",
            "docs/architecture.md", "docs/conventions.md",
            "docs/verification.md", "docs/index.md")
is_spec = fp.startswith("docs/specs/")
if not (any(bajo(fp, p) for p in estandar) or is_spec):
    sys.exit(0)
try:
    feats = json.load(open("feature_list.json", encoding="utf-8"))["features"]
except Exception:
    sys.exit(0)
activas = [f for f in feats if f.get("status") == "in_progress"]
if not activas:
    sys.exit(0)

if is_spec:
    # Solo se protege el spec de la feature EN CURSO: es su contrato, y
    # ajustarlo a mitad de camino para que el codigo pase es la trampa que
    # esto evita. Especificar OTRO modulo mientras tanto es legitimo.
    suyos = [(f.get("spec") or "").replace(chr(92), "/") for f in activas]
    suyos = [sp[2:] if sp.startswith("./") else sp for sp in suyos]
    if not any(sp and fp == sp for sp in suyos):
        sys.exit(0)
    duenos = sorted(set(f.get("owner") or "sin owner" for f in activas))
    bloquear(
        fp + " es el spec de una feature en curso ("
        + ", ".join(duenos) + "). El contrato no se ajusta al codigo a mitad de "
        "camino: si el spec esta mal, marca la feature blocked y corrigelo "
        "con /especificar.")

abiertas = ", ".join(
    "#%s (%s)" % (f.get("id"), f.get("owner") or "sin owner") for f in activas)
bloquear(
    fp + " es inmutable mientras hay features in_progress: " + abiertas
    + ". El estandar no se ajusta para que el trabajo pase. Si la feature no "
    "es tuya, NO la cierres: acuerdalo con su owner y hagan el cambio entre "
    "olas, con todo mergeado.")
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
  *)
    # Falla cerrado, no abierto. Un subcomando mal escrito en
    # .claude/settings.json haria desaparecer el guard en silencio, y una
    # proteccion que parece instalada y no lo esta es peor que ninguna.
    echo "[harness] hooks.sh: subcomando desconocido '${1:-}' (usa 'guard' o 'post-edit'). Revisa .claude/settings.json." >&2
    exit 2
    ;;
esac
exit 0
