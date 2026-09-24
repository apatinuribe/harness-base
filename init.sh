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
#   ./init.sh --merge  todo lo anterior + exige la revisión cruzada (antes de
#                      mergear a main; es lo que comprueba el hook de pre-push)
#
# En todos los modos, §3d audita las features `done`: review APPROVED, informe
# del implementer, un test por criterio (F<id>-C<n>) y evento/infra coherente.

set -u
export PYTHONIOENCODING=utf-8

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
ok()   { printf "${GREEN}[OK]${NC}    %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
fail() { printf "${RED}[FAIL]${NC}  %s\n" "$1"; }

EXIT_CODE=0
MODE="${1:-}"

# Un modo mal escrito ('--mrge') correria la verificacion normal y se saltaria
# el gate sin decir nada. Mejor parar y decirlo.
case "$MODE" in
  ""|--plan|--quick|--merge) ;;
  *) printf "${RED}[FAIL]${NC}  Modo desconocido: %s (usa --plan, --quick o --merge)
" "$MODE"; exit 1 ;;
esac

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

# La versión del molde: es lo que se compara con la plantilla al actualizar.
HARNESS_VERSION=$($PY -c "import json; print(json.load(open('harness.config.json', encoding='utf-8')).get('harness_version') or '')" 2>/dev/null)
if [ -n "$HARNESS_VERSION" ]; then
  ok "Arnés v$HARNESS_VERSION"
else
  warn "harness.config.json sin harness_version (instancia anterior a 1.0.0): sigue README §Actualizar una instancia"
fi

# El gate de revisión cruzada vive en .githooks/pre-push, y git no mira ahí
# hasta que se le dice. Se activa una vez, y nunca por encima de hooks ajenos.
if [ -d .githooks ] && git rev-parse --git-dir >/dev/null 2>&1; then
  hooks_actual=$(git config --get core.hooksPath 2>/dev/null || true)
  if [ -z "$hooks_actual" ]; then
    git_comun=$(git rev-parse --git-common-dir 2>/dev/null || echo ".git")
    hooks_propios=$(ls "$git_comun/hooks" 2>/dev/null | grep -v '\.sample$' | head -1)
    if [ -z "$hooks_propios" ]; then
      git config core.hooksPath .githooks && ok "Hooks de git activados (.githooks)"
    else
      warn "Ya hay hooks propios en $git_comun/hooks — no toco core.hooksPath; copia .githooks/pre-push a mano si quieres el gate de revisión cruzada"
    fi
  elif [ "$hooks_actual" != ".githooks" ]; then
    warn "core.hooksPath apunta a '$hooks_actual' — el gate de revisión cruzada (.githooks/pre-push) no está activo"
  fi
fi

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

HARNESS_GIT_EMAIL="$(git config user.email 2>/dev/null)" $PY - <<'PYCODE'
import json, os, sys
try:
    data = json.load(open("feature_list.json", encoding="utf-8"))
except Exception as e:
    print(f"[FAIL]  feature_list.json inválido: {e}"); sys.exit(1)

feats = data["features"]
valid = set(data.get("rules", {}).get("valid_status",
            ["pending", "in_progress", "done", "blocked"]))
errors = []
warns = []

try:
    cfg = json.load(open("harness.config.json", encoding="utf-8"))
except Exception:
    cfg = {}
# Miembros reales del equipo: los TODO de la plantilla no cuentan.
team = [t for t in cfg.get("team", [])
        if t.get("id") and not str(t["id"]).startswith("TODO")]
team_ids = set(t["id"] for t in team)
# Con 0-1 personas el arnés corre en modo solitario y 'owner' es opcional:
# nadie tiene con quién colisionar. Con 2+ la propiedad pasa a ser obligatoria.
multi = len(team) > 1

# Quien eres. Resolverlo aqui evita que cada agente cruce a mano su
# 'git config user.email' contra el team -- y se equivoque en silencio.
if not multi:
    print("[OK]    Modo solitario: 'owner' es opcional (declara 'team' para repartir)")
else:
    correo = (os.environ.get("HARNESS_GIT_EMAIL") or "").strip().lower()
    yo = next((t["id"] for t in team
               if correo and str(t.get("git_email", "")).strip().lower() == correo), None)
    if yo:
        print("[OK]    Eres: %s (una feature in_progress por persona)" % yo)
    else:
        print("[WARN]  No sé quién eres: '%s' no está en 'team' de "
              "harness.config.json. Añádete antes de reclamar una feature."
              % (correo or "sin git user.email"))

ids = [f["id"] for f in feats]
if len(ids) != len(set(ids)):
    errors.append("Hay ids duplicados en feature_list.json")

in_progress = [f for f in feats if f["status"] == "in_progress"]
if not multi:
    if len(in_progress) > 1:
        errors.append(f"Hay {len(in_progress)} features en in_progress (máximo 1; declara tu 'team' en harness.config.json para trabajar en paralelo)")
else:
    por_owner = {}
    for f in in_progress:
        por_owner.setdefault(f.get("owner"), []).append(f)
    for own, fs in sorted(por_owner.items(), key=lambda kv: str(kv[0])):
        lista = ", ".join("#%s" % f["id"] for f in fs)
        if not own:
            errors.append(f"Feature(s) {lista} en in_progress sin 'owner' — recláma(la)s en main antes de abrir el worktree")
        elif own not in team_ids:
            errors.append(f"Feature(s) {lista}: owner '{own}' no está en 'team' de harness.config.json")
        elif len(fs) > 1:
            errors.append(f"{own} tiene {len(fs)} features en in_progress ({lista}) — una por persona a la vez")

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

# Al arrancar, la feature ya tiene que saber como se va a dar por hecha:
# con un evento emitido en produccion, o exenta por infra. Descubrirlo al
# cerrar es tarde. Se exige a las in_progress y a las done: una done sin
# evento ni infra nunca demostro que llego a produccion.
proyecto = os.path.exists("PROYECTO.md")
for f in in_progress + [f for f in feats if f["status"] == "done"]:
    estado = "en in_progress" if f["status"] == "in_progress" else "done"
    tiene_evento, tiene_infra = bool(f.get("evento")), bool(f.get("infra"))
    if tiene_evento == tiene_infra:
        errors.append(f"Feature {f['id']} ({f['name']}) {estado} "
                      f"{'declara evento e infra a la vez' if tiene_evento else 'no declara evento ni infra'}"
                      " — exactamente uno (ver docs/verification.md)")
    if proyecto and not f.get("kr"):
        errors.append(f"Feature {f['id']} ({f['name']}) {estado} sin 'kr' — "
                      "existe PROYECTO.md: ¿a qué resultado clave sirve?")

for e in errors:
    print("[FAIL]  " + e)
if not errors:
    counts = {}
    for f in feats:
        counts[f["status"]] = counts.get(f["status"], 0) + 1
    print(f"[OK]    Backlog válido ({len(feats)} features: " +
          ", ".join(f"{k}={v}" for k, v in sorted(counts.items())) + ")")
    for f in in_progress:
        quien = (" [" + f["owner"] + "]") if f.get("owner") else ""
        print(f"[OK]    En curso:{quien} #{f['id']} {f['name']} -> {', '.join(f['touches'])}")
for w in warns:
    print("[WARN]  " + w)
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

echo ""
echo "── 3d. Cierre de features (done) ─────────────────────"

# Una feature 'done' tiene que poder demostrarlo: veredicto APPROVED del
# reviewer, informe del implementer, un test por criterio de acceptance y,
# si emite evento, depender de despliegue_inicial. Sin eso, 'done' es una
# palabra en un JSON. Corre en todos los modos: el post-edit hook lanza
# --quick al tocar feature_list.json, y ahi es donde se marca done.
$PY - <<'PYCODE'
import io, os, re, subprocess, sys, json
try:
    feats = json.load(open("feature_list.json", encoding="utf-8"))["features"]
except Exception as e:
    print("[FAIL]  feature_list.json ilegible: %s" % e); sys.exit(1)

cerradas = [f for f in feats if f.get("status") == "done"]
if not cerradas:
    print("[OK]    Sin features done que auditar"); sys.exit(0)

def leer(ruta):
    try:
        with io.open(ruta, encoding="utf-8", errors="ignore") as fh:
            return fh.read()
    except Exception:
        return ""

# Archivos donde puede vivir un test. Se excluye lo que HABLA de los tests
# pero no lo es: progress/ (los informes citan F<id>-C<n>), docs/ (ejemplos),
# .claude/ (agentes), scripts/ e init.sh (este codigo), feature_list.json y
# los .md de la raiz (PROYECTO.md lleva F<id> en su trazabilidad).
EXCL_DIRS = ("progress/", "docs/", ".claude/", ".githooks/", "scripts/")
EXCL_FILES = ("feature_list.json", "init.sh")
SKIP_WALK = {".git", "node_modules", ".worktrees", ".harness", "__pycache__",
             ".venv", "venv", "dist", "build"}
def candidatos():
    try:
        out = subprocess.run(["git", "ls-files", "-co", "--exclude-standard", "-z"],
                             capture_output=True, check=True).stdout
        rutas = [r.decode("utf-8", "ignore") for r in out.split(b"\0") if r]
    except Exception:
        rutas = []
        for raiz, dirs, archivos in os.walk("."):
            dirs[:] = [d for d in dirs if d not in SKIP_WALK]
            for a in archivos:
                rutas.append(os.path.relpath(os.path.join(raiz, a), ".").replace(os.sep, "/"))
    for r in rutas:
        if r.startswith(EXCL_DIRS) or r in EXCL_FILES:
            continue
        if "/" not in r and r.lower().endswith(".md"):
            continue
        try:
            if os.path.getsize(r) > 2 * 1024 * 1024:
                continue
        except OSError:
            continue
        yield r

# Un solo barrido: que ids F<id>-C<n> aparecen en el proyecto.
ID_RE = re.compile(r"\bF(\d+)-C(\d+)\b")
vistos = set()
for ruta in candidatos():
    for m in ID_RE.finditer(leer(ruta)):
        vistos.add((int(m.group(1)), int(m.group(2))))

# El formato del reviewer (.claude/agents/reviewer.md) es una linea
# '**Veredicto:** APPROVED | CHANGES_REQUESTED'. Si no esta, vale la palabra.
VEREDICTO = re.compile(r"^\s*\*\*Veredicto:\*\*\s*(\S+)", re.MULTILINE | re.IGNORECASE)
def veredicto_de(texto):
    m = VEREDICTO.search(texto)
    if m:
        return m.group(1).strip().upper()
    return "APPROVED" if re.search(r"\bAPPROVED\b", texto) else None

despliegue = next((f for f in feats if f.get("name") == "despliegue_inicial"), None)
errors = []
for f in cerradas:
    fid, name = f["id"], f.get("name", "?")
    quien = "Feature #%s (%s) está done pero" % (fid, name)
    review = "progress/review_%s.md" % name
    impl = "progress/impl_%s.md" % name

    # D1 - veredicto del reviewer
    if not os.path.exists(review):
        errors.append("%s no existe %s.\n        Sin un APPROVED del reviewer no se cierra: "
                      "lanza `reviewer` y vuelve a in_progress mientras tanto." % (quien, review))
    else:
        v = veredicto_de(leer(review))
        if v != "APPROVED":
            errors.append("%s el veredicto de %s es %s, no APPROVED.\n        "
                          "Atiende los cambios requeridos y vuelve a pasar `reviewer`."
                          % (quien, review, v or "ilegible (no hay línea '**Veredicto:**')"))

    # D2 - informe del implementer
    texto_impl = ""
    if not os.path.exists(impl):
        errors.append("%s no existe %s.\n        El implementer tiene que dejar ahí su "
                      "informe con la evidencia por criterio." % (quien, impl))
    else:
        texto_impl = leer(impl)

    # D4 - un test por criterio (o 'manual' justificado en el informe)
    criterios = f.get("acceptance") or []
    for n, texto in enumerate(criterios, start=1):
        cid = "F%s-C%s" % (fid, n)
        if (fid, n) in vistos:
            continue
        bloque = re.search(r"criterio:\s*[\"']?%s\b.*?(?=\n\s*-\s*criterio:|\n\s*-\s*producci|\Z)"
                           % re.escape(cid), texto_impl, re.DOTALL | re.IGNORECASE)
        if bloque and re.search(r"^\s*manual:\s*\S", bloque.group(0), re.MULTILINE):
            continue
        resumen = texto if len(texto) <= 70 else texto[:67] + "..."
        errors.append("%s el criterio %d de %d no tiene test: ningún archivo menciona %s y %s "
                      "no lo declara manual.\n        Criterio: \"%s\"\n        Escribe el test "
                      "con %s en su nombre (docs/verification.md)."
                      % (quien, n, len(criterios), cid, impl, resumen, cid))

    # D5 - con evento, depende de despliegue_inicial
    if f.get("evento") and f is not despliegue:
        if despliegue is None:
            errors.append("%s declara evento \"%s\" y el backlog no tiene la feature "
                          "despliegue_inicial.\n        Créala primero: sin despliegue no hay "
                          "evento en producción (CLAUDE.md §Antes de construir)." % (quien, f["evento"]))
        elif despliegue["id"] not in (f.get("depends_on") or []):
            errors.append("%s declara evento \"%s\" y no depende de despliegue_inicial (#%s).\n"
                          "        Sin despliegue no hay evento en producción: añade %s a depends_on."
                          % (quien, f["evento"], despliegue["id"], despliegue["id"]))

for e in errors:
    print("[FAIL]  " + e)
if not errors:
    print("[OK]    %d feature(s) done con review APPROVED, informe, test por criterio y evento/infra"
          % len(cerradas))
sys.exit(1 if errors else 0)
PYCODE
[ $? -ne 0 ] && EXIT_CODE=1

# Checkpoint C7. Durante la feature solo avisa: el cruce ocurre DESPUÉS del
# veredicto del reviewer, así que exigirlo antes sería un rojo permanente — y
# un rojo permanente se acaba ignorando. Bloquea en --merge y en el pre-push.
if [ "$MODE" = "--merge" ]; then
  echo ""
  echo "── 3c. Revisión cruzada ──────────────────────────────"
  $PY scripts/check_peer_review.py || EXIT_CODE=1
else
  aviso_cruce=$($PY scripts/check_peer_review.py --aviso 2>/dev/null)
  [ -n "$aviso_cruce" ] && printf '%s
' "$aviso_cruce"
fi

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
  # Arnes recien instanciado: el comando que lo pone en verde es /configurar.
  if grep -q '"project": *"TODO' harness.config.json 2>/dev/null; then
    echo "        El arnés todavía no está configurado. Abre Claude y corre /configurar."
  fi
fi
exit $EXIT_CODE
