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
  warn "harness.config.json sin harness_version (instancia anterior a 1.0.0): sigue HARNESS.md §Actualizar una instancia"
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
import json, os, re, sys
cfg = json.load(open("harness.config.json", encoding="utf-8"))
missing = [f for f in cfg.get("required_files", []) if not os.path.exists(f)]
for f in cfg.get("required_files", []):
    print(("[FAIL]  Falta " if f in missing else "[OK]    Existe ") + f)

# El marcador de hueco es 'TODO:' (con dos puntos) como token propio: al inicio
# de linea, en una cita '>', en una celda '|' o tras una etiqueta '**x:**'.
# Fuera de codigo: ni bloques ``` ni inline `...`. Un 'TODO(#12)' en prosa
# (la convencion de comentarios con id) no es un hueco de la plantilla.
MARCA_TODO = re.compile(r"(?:^|[\s>|*])TODO:", re.M)
def sin_codigo(texto):
    texto = re.sub(r"```.*?```", "", texto, flags=re.S)
    return re.sub(r"`[^`\n]*`", "", texto)

todos = []
if "TODO" in cfg.get("project", ""):
    todos.append("harness.config.json: campo 'project' sin configurar")
for p in ("docs/architecture.md", "docs/conventions.md", "docs/verification.md"):
    if os.path.exists(p) and MARCA_TODO.search(
            sin_codigo(open(p, encoding="utf-8", errors="replace").read())):
        todos.append(f"{p} contiene 'TODO:' sin resolver")
for t in todos:
    print("[WARN]  " + t)
sys.exit(1 if missing else 0)
PYCODE
[ $? -ne 0 ] && EXIT_CODE=1

echo ""
echo "── 3. Estado del backlog ───────────────────────────────"

HARNESS_GIT_EMAIL="$(git config user.email 2>/dev/null)" $PY - <<'PYCODE'
import json, os, re, sys
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
def declara_krs(ruta="PROYECTO.md"):
    # La plantilla existe siempre; cuenta cuando declara un KR: alguna linea
    # que no es cita (>) nombra KR<n> fuera de backticks (la regla esta en la
    # cabecera de PROYECTO.md).
    if not os.path.exists(ruta):
        return False
    texto = re.sub(r"```.*?```", "", open(ruta, encoding="utf-8", errors="replace").read(), flags=re.S)
    return any(re.search(r"\bKR\d", re.sub(r"`[^`\n]*`", "", l))
               for l in texto.splitlines() if not l.lstrip().startswith(">"))

proyecto = declara_krs()
for f in in_progress + [f for f in feats if f["status"] == "done"]:
    estado = "en in_progress" if f["status"] == "in_progress" else "done"
    tiene_evento, tiene_infra = bool(f.get("evento")), bool(f.get("infra"))
    if tiene_evento == tiene_infra:
        errors.append(f"Feature {f['id']} ({f['name']}) {estado} "
                      f"{'declara evento e infra a la vez' if tiene_evento else 'no declara evento ni infra'}"
                      " — exactamente uno (ver docs/verification.md)")
    if proyecto and not f.get("kr"):
        errors.append(f"Feature {f['id']} ({f['name']}) {estado} sin 'kr' — "
                      "PROYECTO.md declara KRs: ¿a qué resultado clave sirve?")

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
import json, os, re, sys
try:
    feats = json.load(open("feature_list.json", encoding="utf-8"))["features"]
except Exception as e:
    print("[FAIL]  feature_list.json ilegible: %s" % e); sys.exit(1)

# Pendiente real: '[NEEDS CLARIFICATION: <pregunta>]' con contenido, fuera de
# codigo (ni bloques ``` ni inline `...`). Citar el marcador en backticks, o
# '[NEEDS CLARIFICATION]' a secas como lo nombran los docs, no es un pendiente.
MARK = "[NEEDS CLARIFICATION: ...]"
PEND = re.compile(r"\[NEEDS CLARIFICATION:\s*[^\]\s][^\]]*\]")
def sin_codigo(texto):
    texto = re.sub(r"```.*?```", "", texto, flags=re.S)
    return re.sub(r"`[^`\n]*`", "", texto)

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
    pend = len(PEND.findall(sin_codigo(
        open(spec, encoding="utf-8", errors="replace").read())))
    if pend:
        bucket.append("Feature %s (%s): %s tiene %d '%s' sin resolver"
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

# Diseño y «Siguiente paso» comparten lógica (audiencia de la constitución,
# pantallas de un spec), así que viven en un solo heredoc con dos entradas:
#   diseno_py bloque     → imprime §3e; exit 1 si bloquea
#   diseno_py siguiente  → imprime el comando que toca correr, o nada
diseno_py() {
$PY - "$1" <<'PYCODE'
import json, os, re, sys
modo = sys.argv[1]

def sin_codigo(texto):
    texto = re.sub(r"```.*?```", "", texto, flags=re.S)
    return re.sub(r"`[^`\n]*`", "", texto)

def leer(p):
    try:
        return open(p, encoding="utf-8", errors="replace").read()
    except Exception:
        return ""

# Audiencia: la linea '**Audiencia:** publico | interno' de §1 de la
# constitucion. Con 'TODO:' u otra cosa se trata como desconocida (solo avisa).
def audiencia():
    m = re.search(r"\*\*Audiencia:\*\*\s*(\S+)", leer("docs/architecture.md"))
    v = (m.group(1) if m else "").lower()
    if v.startswith(("públic", "public")):
        return "público"
    if v.startswith("interno"):
        return "interno"
    return "desconocida"

# Pantallas: alguna fila con datos en la tabla de '### 4.2' del spec. La
# cabecera, el separador y la fila vacia de la plantilla no cuentan.
def tiene_pantallas(spec):
    m = re.search(r"^###\s*4\.2\b[^\n]*\n(.*?)(?=^#{1,3}\s|\Z)", leer(spec), re.M | re.S)
    if not m:
        return False
    filas = [l.strip() for l in m.group(1).splitlines() if l.strip().startswith("|")]
    for fila in filas[1:]:
        if re.fullmatch(r"[\s|:\-]*", fila):
            continue
        if any(c.strip() for c in fila.strip("|").split("|")):
            return True
    return False

# [(feature, modulo)] de las in_progress con pantallas: con diseno y sin el.
def pantallas_en_curso():
    try:
        feats = json.load(open("feature_list.json", encoding="utf-8"))["features"]
    except Exception:
        return [], []
    con, sin = [], []
    for f in feats:
        spec = f.get("spec") or ""
        if f.get("status") != "in_progress" or not os.path.exists(spec):
            continue
        if not tiene_pantallas(spec):
            continue
        modulo = os.path.splitext(os.path.basename(spec))[0]
        (con if os.path.exists("docs/diseno/%s.md" % modulo) else sin).append((f, modulo))
    return con, sin

if modo == "bloque":
    con, sin = pantallas_en_curso()
    aud = audiencia()
    for f, modulo in con:
        print("[OK]    Feature %s (%s): diseño en docs/diseno/%s.md"
              % (f.get("id"), f.get("name", "?"), modulo))
    for f, modulo in sin:
        base = ("Feature %s (%s): el spec tiene pantallas (§4.2) y no existe docs/diseno/%s.md"
                % (f.get("id"), f.get("name", "?"), modulo))
        if aud == "público":
            print("[FAIL]  %s — producto público: corre /diseno %s antes de construir" % (base, modulo))
        else:
            print("[WARN]  %s — corre /diseno %s, o la pantalla se decide en el código" % (base, modulo))
    if not con and not sin:
        print("[OK]    Sin pantallas que diseñar")
    sys.exit(1 if (sin and aud == "público") else 0)

# modo == "siguiente": por precedencia, lo primero que falta.
try:
    proyecto = json.load(open("harness.config.json", encoding="utf-8")).get("project") or ""
except Exception:
    proyecto = ""
if str(proyecto).startswith("TODO"):
    print("El arnés todavía no está configurado. Abre Claude y corre /configurar.")
elif re.search(r"(?:^|[\s>|*])TODO:", sin_codigo(leer("docs/architecture.md")), re.M):
    print("La constitución tiene huecos. Abre Claude y corre /constitucion.")
else:
    con, sin = pantallas_en_curso()
    if sin:
        f, modulo = sin[0]
        print("Feature %s (%s) tiene pantallas sin diseño. Abre Claude y corre /diseno %s."
              % (f.get("id"), f.get("name", "?"), modulo))
PYCODE
}

# Plan técnico (/planear). Misma forma que diseno_py:
#   plan_py bloque     → imprime §3f; exit 1 si bloquea
#   plan_py siguiente  → imprime el comando que toca correr, o nada
plan_py() {
$PY - "$1" <<'PYCODE'
import json, os, re, sys
modo = sys.argv[1]

try:
    cfg = json.load(open("harness.config.json", encoding="utf-8"))
except Exception:
    cfg = {}
try:
    feats = json.load(open("feature_list.json", encoding="utf-8"))["features"]
except Exception:
    feats = []

def norm(p):
    return re.sub(r"^(\./)+", "", str(p).replace("\\", "/"))

# Toca migraciones: alguna ruta de touches nombra migraciones (migrations/,
# migraciones/, el placeholder que escribe /esquema) o cae bajo exclusive_paths.
def toca_migraciones(f):
    exclusivas = [norm(e) for e in cfg.get("exclusive_paths", []) if e]
    for ruta in f.get("touches", []):
        r = norm(ruta)
        if "migra" in r.lower() or any(r.startswith(e) for e in exclusivas):
            return True
    return False

# plan_requerido: true = siempre, false = nunca, 'auto' (o clave ausente) =
# migraciones o mas de 4 criterios. Devuelve (requerido, razon).
def requerido(f):
    pr = cfg.get("plan_requerido", "auto")
    if pr is True:
        return True, "plan_requerido: true"
    if pr is False:
        return False, "plan_requerido: false"
    n = len(f.get("acceptance") or [])
    if toca_migraciones(f):
        return True, "toca migraciones"
    if n > 4:
        return True, "%d criterios" % n
    return False, "%d criterios, sin migraciones" % n

def estado_plan(name):
    ruta = "progress/plan_%s.md" % name
    if not os.path.exists(ruta):
        return "falta"
    try:
        texto = open(ruta, encoding="utf-8", errors="replace").read()
    except Exception:
        return "falta"
    return "confirmado" if re.search(r"\*\*Estado:\*\*\s*confirmado", texto) else "borrador"

# [(feature, razon, estado)] de las in_progress que requieren plan y no lo
# tienen confirmado.
def sin_plan():
    faltan = []
    for f in feats:
        if f.get("status") != "in_progress":
            continue
        req, razon = requerido(f)
        estado = estado_plan(f.get("name", ""))
        if req and estado != "confirmado":
            faltan.append((f, razon, estado))
    return faltan

if modo == "bloque":
    en_curso = [f for f in feats if f.get("status") == "in_progress"]
    fails = 0
    for f in en_curso:
        fid, name = f.get("id"), f.get("name", "?")
        ruta = "progress/plan_%s.md" % name
        req, razon = requerido(f)
        estado = estado_plan(name)
        if req and estado == "falta":
            print("[FAIL]  Feature %s (%s): requiere plan (%s) y no existe %s — corre /planear %s y confírmalo antes de construir"
                  % (fid, name, razon, ruta, fid)); fails += 1
        elif req and estado == "borrador":
            print("[FAIL]  Feature %s (%s): %s sin confirmar — corre /planear %s y confírmalo"
                  % (fid, name, ruta, fid)); fails += 1
        elif req:
            print("[OK]    Feature %s (%s): plan confirmado en %s" % (fid, name, ruta))
        elif estado == "confirmado":
            print("[OK]    Feature %s (%s): plan confirmado en %s (opcional)" % (fid, name, ruta))
        else:
            print("[OK]    Feature %s (%s): plan opcional (%s)" % (fid, name, razon))
    if not en_curso:
        print("[OK]    Sin features en curso que planificar")
    sys.exit(1 if fails else 0)

# modo == "siguiente"
faltan = sin_plan()
if faltan:
    f, razon, estado = faltan[0]
    print("Feature %s (%s) requiere plan y no lo tiene confirmado. Abre Claude y corre /planear %s."
          % (f.get("id"), f.get("name", "?"), f.get("id")))
PYCODE
}

# Descubrimiento (/descubrir). Solo avisa, nunca bloquea: entrevistar es
# opcional. Una entrevista es un .md de docs/descubrimiento/ que no empieza por
# «_» ni es README.md; está incorporada si _sintesis.md nombra su archivo.
descubrimiento_py() {
$PY - <<'PYCODE'
import os

carpeta = "docs/descubrimiento"
try:
    ents = sorted(n for n in os.listdir(carpeta)
                  if n.endswith(".md") and not n.startswith("_") and n != "README.md")
except OSError:
    ents = []

if not ents:
    print("[OK]    Sin entrevistas en docs/descubrimiento/ (opcional: /descubrir)")
    raise SystemExit(0)

ruta = os.path.join(carpeta, "_sintesis.md")
if not os.path.exists(ruta):
    print("[WARN]  docs/descubrimiento/: %d entrevista(s) sin síntesis — corre /descubrir sintesis" % len(ents))
    raise SystemExit(0)

try:
    texto = open(ruta, encoding="utf-8", errors="replace").read()
except Exception:
    texto = ""
faltan = [e for e in ents if e not in texto]
if faltan:
    print("[WARN]  docs/descubrimiento/: %d entrevista(s) que _sintesis.md no incorpora (%s) — corre /descubrir sintesis"
          % (len(faltan), ", ".join(faltan)))
else:
    print("[OK]    docs/descubrimiento/_sintesis.md incorpora las %d entrevistas" % len(ents))
PYCODE
}

siguiente_paso() {
  local paso
  paso=$(diseno_py siguiente 2>/dev/null)
  [ -z "$paso" ] && paso=$(plan_py siguiente 2>/dev/null)
  if [ -n "$paso" ]; then
    echo ""
    echo "── Siguiente paso ──────────────────────────────────────"
    printf '        %s\n' "$paso"
  fi
}

echo ""
echo "── 3e. Diseño ────────────────────────────────────────"

# Una feature con pantallas (§4.2 del spec) sin docs/diseno/<modulo>.md deja
# que el diseño lo decida el código. Con producto público bloquea; con interno
# o audiencia sin resolver, avisa. No toca el gate de cierre (§3d).
diseno_py bloque
[ $? -ne 0 ] && EXIT_CODE=1

echo ""
echo "── 3f. Plan ──────────────────────────────────────────"

# Una feature que toca migraciones o tiene más de 4 criterios (o siempre, con
# plan_requerido: true) no arranca sin progress/plan_<name>.md confirmado por
# el usuario (/planear <id>). Solo mira las in_progress; no toca el gate §3d.
plan_py bloque
[ $? -ne 0 ] && EXIT_CODE=1

echo ""
echo "── 3g. Descubrimiento ────────────────────────────────"

# Entrevistas que la síntesis todavía no incorpora alimentan PROYECTO.md y al
# estratega con datos viejos. Avisa; no cambia el exit (entrevistar es opcional).
descubrimiento_py

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
  siguiente_paso
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
# Derivado del estado: /configurar, /constitucion o /diseno <modulo>. Nada si
# no falta ninguno.
siguiente_paso
exit $EXIT_CODE
