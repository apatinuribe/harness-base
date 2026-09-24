#!/usr/bin/env bash
# hooks.sh — Helpers para los hooks de .claude/settings.json.
# Reciben por stdin el JSON del hook (tool_input, y agent_id / agent_type
# cuando el que llama es un subagente).
#
#   hooks.sh guard       (PreToolUse Edit|Write|MultiEdit|NotebookEdit)
#   hooks.sh guard-bash  (PreToolUse Bash)
#       Las mismas cuatro reglas para las dos vías. Las dos primeras son la
#       regla anti-trampa: el arnés no se relaja para que el trabajo pase.
#       Las otras dos reparten quién puede tocar qué entre la sesión
#       principal (leader) y los subagentes.
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
#       `guard` mira tool_input.file_path (Edit, Write, MultiEdit) o
#       tool_input.notebook_path (NotebookEdit).
#       `guard-bash` mira tool_input.command y saca los archivos DESTINO de
#       escritura: redirecciones (>, >>, &>, >|), `tee` y `sed -i`. Cada uno
#       pasa por las mismas reglas. Un comando sin escrituras (git, ls, grep,
#       ./init.sh) sale con 0 sin leer nada. No es un sandbox: no ve cp/mv/rm,
#       `python -c "open(..., 'w')"`, `git checkout --` ni `eval`; cubre las
#       tres formas habituales de escribir un archivo desde la shell.
#       Cómo distingue leader de subagente: Claude Code añade `agent_id` al
#       JSON del hook solo cuando la llamada viene de un subagente.
#       Si harness.config.json no se puede leer, R3 no se aplica pero el
#       hook lo dice: WARN por stderr con exit 1 (visible, no bloquea).
#       Pruebas: bash scripts/test_guard.sh (tabla de casos, sin tocar el repo).
#   hooks.sh post-edit   (PostToolUse Edit|Write|MultiEdit|NotebookEdit)
#       Corre ./init.sh --quick, saltándolo para ediciones de bitácora
#       (progress/, docs/, .claude/) que no afectan al estado verificable.
set -u

PY=""
for candidate in "python" "python3" "py -3"; do
  resolved=$(command -v ${candidate%% *} 2>/dev/null || true)
  case "$resolved" in *WindowsApps*) continue ;; esac
  if $candidate -c "import sys" >/dev/null 2>&1; then PY="$candidate"; break; fi
done
[ -z "$PY" ] && exit 0  # sin Python no se puede analizar el JSON: no bloquees

INPUT=$(cat)

# Un solo programa para guard y guard-bash: argv[1] dice de dónde salen las
# rutas ("file" o "bash"); las reglas son las mismas.
read -r -d '' GUARD_PY <<'PYCODE'
import json, os, re, shlex, sys

modo = sys.argv[1]
datos = json.load(sys.stdin)
entrada = datos.get("tool_input") or {}
raiz = (datos.get("cwd") or os.getcwd()).replace("\\", "/").rstrip("/")

def normalizar(fp):
    # Ruta relativa a la raiz del proyecto, con barras "/". Edit y Write
    # suelen mandar rutas absolutas (y en Windows con barras invertidas).
    # None = fuera del proyecto: no es asunto de este guard.
    fp = fp.replace("\\", "/")
    if os.path.isabs(fp) or (len(fp) > 1 and fp[1] == ":"):
        if fp.lower().startswith(raiz.lower() + "/"):
            fp = fp[len(raiz) + 1:]
        else:
            return None
    if fp.startswith("./"):
        fp = fp[2:]
    return fp or None

# ---- Extraccion de destinos de escritura de un comando de shell ----------
PUNT = set("();<>|&")
REDIR = ("(", ")", ";", "|", "||", "&", "&&")
def es_separador(tok):
    return bool(tok) and all(c in PUNT for c in tok)

def objetivos_bash(cmd):
    lexer = shlex.shlex(cmd, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    try:
        toks = list(lexer)
    except ValueError:
        toks = cmd.split()
    salida = []
    i = 0
    while i < len(toks):
        t = toks[i]
        # Redireccion: `>`, `>>`, `>|`, `&>`, `&>>`. Con punctuation_chars,
        # `2>&1` llega como ['2', '>&', '1'] y `1>f` como ['1', '>', 'f'].
        if t in (">", ">>", ">|", "&>", "&>>", ">&"):
            if i + 1 < len(toks) and not es_separador(toks[i + 1]):
                dest = toks[i + 1]
                if not (t == ">&" and dest.isdigit()) and not dest.startswith("/dev/"):
                    salida.append(dest)
                i += 2
                continue
        elif t == "tee":
            j = i + 1
            while j < len(toks) and not es_separador(toks[j]):
                if not toks[j].startswith("-"):
                    salida.append(toks[j])
                j += 1
            i = j
            continue
        elif t == "sed":
            j = i + 1
            args = []
            while j < len(toks) and not es_separador(toks[j]):
                args.append(toks[j]); j += 1
            in_place = any(a == "-i" or a.startswith("-i") or a.startswith("--in-place")
                           or (a.startswith("-") and not a.startswith("--") and "i" in a[1:])
                           for a in args if a.startswith("-"))
            if in_place:
                con_script = any(a in ("-e", "-f", "--expression", "--file")
                                 or a.startswith(("--expression=", "--file="))
                                 for a in args)
                operandos, k = [], 0
                while k < len(args):
                    a = args[k]
                    if a in ("-e", "-f", "--expression", "--file", "-l", "--line-length"):
                        k += 2; continue
                    if a.startswith("-"):
                        k += 1; continue
                    operandos.append(a); k += 1
                if not con_script and operandos:
                    operandos = operandos[1:]  # el primero es el script
                salida.extend(operandos)
            i = j
            continue
        i += 1
    return salida

if modo == "bash":
    cmd = entrada.get("command") or ""
    crudos = objetivos_bash(cmd) if cmd else []
    via = " (via Bash)"
else:
    fp = entrada.get("file_path") or entrada.get("notebook_path") or ""
    crudos = [fp] if fp else []
    via = ""

objetivos = []
for r in crudos:
    n = normalizar(r)
    if n and n not in objetivos:
        objetivos.append(n)
if not objetivos:
    sys.exit(0)

# ---- Reglas ---------------------------------------------------------------
def bajo(ruta, patron):
    # "src/" cubre la carpeta entera; "docs/index.md" es un archivo exacto.
    patron = patron.replace("\\", "/")
    if patron.endswith("/"):
        return ruta.startswith(patron)
    return ruta == patron

es_subagente = bool(datos.get("agent_id"))
agente = datos.get("agent_type") or "subagente"

aviso = ""
try:
    cfg = json.load(open("harness.config.json", encoding="utf-8"))
    protegidas = [p for p in cfg.get("protected_paths", []) if isinstance(p, str) and p]
except Exception as e:
    # Sin config legible no se bloquea a ciegas, pero tampoco en silencio:
    # el aviso sale por stderr con exit 1 (no bloquea, pero se muestra).
    protegidas = []
    aviso = ("[harness] WARN: no se pudo leer harness.config.json (" + str(e)
             + "). protected_paths NO se esta aplicando. Corre ./init.sh y arregla el JSON.")

ESTANDAR = ("harness.config.json", "CHECKPOINTS.md",
            "docs/architecture.md", "docs/conventions.md",
            "docs/verification.md", "docs/index.md")

_activas = None
def activas():
    global _activas
    if _activas is None:
        try:
            feats = json.load(open("feature_list.json", encoding="utf-8"))["features"]
            _activas = [f for f in feats if f.get("status") == "in_progress"]
        except Exception:
            _activas = []
    return _activas

def evaluar(fp):
    # Devuelve el mensaje de bloqueo, o None si la escritura es legitima.
    # R4 -- feature_list.json: solo la sesion principal cambia estados.
    if es_subagente and bajo(fp, "feature_list.json"):
        return ("feature_list.json solo lo edita la sesion principal (leader). "
                "Un subagente (" + agente + ") no cambia estados de features: "
                "escribe tu informe en progress/ y el leader marcara la feature "
                "cuando el reviewer la apruebe.")
    # R3 -- protected_paths: trabajo del producto, lo hace el implementer.
    if not es_subagente:
        golpe = next((p for p in protegidas if bajo(fp, p)), None)
        if golpe:
            return (fp + " esta en protected_paths de harness.config.json (" + golpe + "): "
                    "es trabajo del producto y lo hace el subagente implementer, no la "
                    "sesion principal. Lanza implementer con la feature que corresponda.")
    # R1 / R2 -- estandar del arnes y spec activo, congelados con feature in_progress.
    is_spec = fp.startswith("docs/specs/")
    if not (any(bajo(fp, p) for p in ESTANDAR) or is_spec):
        return None
    abiertas = activas()
    if not abiertas:
        return None
    if is_spec:
        # Solo se protege el spec de la feature EN CURSO: es su contrato, y
        # ajustarlo a mitad de camino para que el codigo pase es la trampa que
        # esto evita. Especificar OTRO modulo mientras tanto es legitimo.
        suyos = [(f.get("spec") or "").replace("\\", "/") for f in abiertas]
        suyos = [sp[2:] if sp.startswith("./") else sp for sp in suyos]
        if not any(sp and fp == sp for sp in suyos):
            return None
        duenos = sorted(set(f.get("owner") or "sin owner" for f in abiertas))
        return (fp + " es el spec de una feature en curso ("
                + ", ".join(duenos) + "). El contrato no se ajusta al codigo a mitad de "
                "camino: si el spec esta mal, marca la feature blocked y corrigelo "
                "con /especificar.")
    lista = ", ".join(
        "#%s (%s)" % (f.get("id"), f.get("owner") or "sin owner") for f in abiertas)
    return (fp + " es inmutable mientras hay features in_progress: " + lista
            + ". El estandar no se ajusta para que el trabajo pase. Si la feature no "
            "es tuya, NO la cierres: acuerdalo con su owner y hagan el cambio entre "
            "olas, con todo mergeado.")

for objetivo in objetivos:
    msg = evaluar(objetivo)
    if msg:
        sys.stderr.write("[harness] BLOQUEADO" + via + ": " + msg + "\n")
        sys.exit(2)
if aviso:
    sys.stderr.write(aviso + "\n")
    sys.exit(1)
sys.exit(0)
PYCODE

case "${1:-}" in
  guard)
    printf '%s' "$INPUT" | $PY -c "$GUARD_PY" file
    exit $?
    ;;
  guard-bash)
    printf '%s' "$INPUT" | $PY -c "$GUARD_PY" bash
    exit $?
    ;;
  post-edit)
    printf '%s' "$INPUT" | $PY -c '
import json, sys
ti = json.load(sys.stdin).get("tool_input", {})
fp = (ti.get("file_path") or ti.get("notebook_path") or "").replace(chr(92), "/")
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
    echo "[harness] hooks.sh: subcomando desconocido '${1:-}' (usa 'guard', 'guard-bash' o 'post-edit'). Revisa .claude/settings.json." >&2
    exit 2
    ;;
esac
exit 0
