#!/usr/bin/env bash
# instalar.sh — Instala el molde en la RAÍZ de un proyecto.
#
# Uso (desde el clon del molde):
#   bash harness-base/scripts/instalar.sh /ruta/a/mi-proyecto [--si] [--forzar]
#
#   --si      responde «sí» a las confirmaciones (tests, CI, sin terminal)
#   --forzar  en la instalación limpia, sobrescribe los archivos del proyecto
#             que colisionen con el molde (nunca se usa al mover un anidado)
#
# Qué hace, en orden:
#   1. Detecta el error habitual: el arnés copiado como SUBCARPETA
#      (mi-proyecto/harness-base/ o cualquier carpeta con harness.config.json
#      e init.sh dentro, hasta 2 niveles). Desde ahí Claude nunca carga
#      CLAUDE.md ni los hooks de .claude/settings.json. Entonces:
#        - si la copia no está configurada (project en TODO y constitución
#          con TODOs, sin features en curso): ofrece REINSTALAR LIMPIO,
#          instala el molde en la raíz y borra la carpeta anidada;
#        - si tiene trabajo: ofrece MOVERLA a la raíz tal cual. Si algún
#          archivo del proyecto ya existe en la raíz, los lista y se detiene
#          sin mover nada. Después remite al flujo de actualización.
#   2. Si el destino ya tiene harness.config.json en la raíz, aborta: eso es
#      una instancia, y los cambios del molde llegan por «Actualizar una
#      instancia» (README).
#   3. Copia el molde a la raíz del destino excluyendo .git, .harness,
#      .worktrees, README.md (se guarda como HARNESS.md), docs/futuro/,
#      docs-molde/, node_modules, __pycache__ y .claude/settings.local.json.
#      Colisiones con archivos del proyecto: se listan y se detiene, salvo
#      --forzar. .gitignore y .gitattributes no se sobrescriben: se les
#      añaden las líneas del molde que falten.
#   4. git init si el destino no es un repo, remoto `molde` apuntando al
#      repo del molde (si no existe), ./init.sh --quick y el siguiente paso.
#
# Sale con el código de init.sh --quick (0 en un molde limpio), 1 si abortó.
set -u
export PYTHONIOENCODING=utf-8

MOLDE_URL="https://github.com/apatinuribe/harness-base.git"
RAIZ=$(cd "$(dirname "$0")/.." && pwd)

uso() {
  echo "Uso: bash $0 <destino> [--si] [--forzar]" >&2
  echo "  --si      confirma sin preguntar   --forzar  sobrescribe colisiones (solo instalación limpia)" >&2
}

DEST=""; SI=0; FORZAR=0; LISTA=""; BORRAR_ANIDADO=""
if [ ! -f "$RAIZ/harness.config.json" ] || [ ! -f "$RAIZ/init.sh" ]; then
  echo "[harness] No encuentro el molde en $RAIZ (falta harness.config.json o init.sh). Corre este script desde un clon de harness-base." >&2
  exit 1
fi
for arg in "$@"; do
  case "$arg" in
    --si) SI=1 ;;
    --forzar) FORZAR=1 ;;
    -*) echo "[harness] Opción desconocida: $arg" >&2; uso; exit 1 ;;
    *) if [ -n "$DEST" ]; then echo "[harness] Solo se admite un destino." >&2; uso; exit 1; fi; DEST="$arg" ;;
  esac
done
[ -z "$DEST" ] && { uso; exit 1; }

PY=""
for candidate in "python" "python3" "py -3"; do
  resolved=$(command -v ${candidate%% *} 2>/dev/null || true)
  case "$resolved" in *WindowsApps*) continue ;; esac
  if $candidate -c "import sys" >/dev/null 2>&1; then PY="$candidate"; break; fi
done
[ -z "$PY" ] && { echo "[harness] No se encontró Python (el arnés lo usa como herramienta; instala python3)." >&2; exit 1; }

mkdir -p "$DEST" || exit 1
DEST=$(cd "$DEST" && pwd)
[ "$DEST" = "$RAIZ" ] && { echo "[harness] El destino es el propio molde. Indica la raíz de tu proyecto." >&2; exit 1; }

# confirmar <pregunta>: --si responde solo; sin terminal no se adivina.
confirmar() {
  if [ "$SI" = 1 ]; then echo "[harness] --si: confirmado."; return 0; fi
  if [ ! -t 0 ]; then
    echo "[harness] Hace falta confirmación y no hay terminal. Vuelve a correr con --si para aceptar." >&2
    return 1
  fi
  printf '%s [s/N] ' "$1"
  read -r resp
  case "$resp" in s|S|si|sí|Si|SI|y|Y|yes) return 0 ;; *) echo "[harness] Cancelado. No se tocó nada."; return 1 ;; esac
}

# Un solo programa python; argv[1] elige la operación. Rutas: el primer
# argumento siempre es el origen y el segundo el destino, absolutos.
read -r -d '' INSTALAR_PY <<'PYCODE'
import json, os, shutil, stat, sys

op = sys.argv[1]
sys.stdout.reconfigure(newline="\n")  # en Windows python escribiria \r\n y bash leeria rutas con \r
MERGE = (".gitignore", ".gitattributes")

def excluido(rel):
    partes = rel.split("/")
    if partes[0] in (".git", ".harness", ".worktrees", "node_modules", "docs-molde"):
        return True
    if rel.startswith("docs/futuro/") or rel == ".claude/settings.local.json":
        return True
    if "__pycache__" in partes or rel.endswith(".pyc"):
        return True
    return False

def archivos(origen):
    # [(rel_origen, rel_destino)] con barras "/". README.md del molde -> HARNESS.md.
    salida = []
    for carpeta, dirs, ficheros in os.walk(origen):
        dirs.sort(); ficheros.sort()
        base = os.path.relpath(carpeta, origen).replace("\\", "/")
        base = "" if base == "." else base + "/"
        dirs[:] = [d for d in dirs if not excluido(base + d + "/x")]
        for f in ficheros:
            rel = base + f
            if excluido(rel):
                continue
            salida.append((rel, "HARNESS.md" if rel == "README.md" else rel))
    return salida

def colisiones(origen, destino):
    return [dst for _, dst in archivos(origen)
            if os.path.lexists(os.path.join(destino, dst)) and dst not in MERGE]

def fusionar(src, dst):
    # Añade a dst las líneas de src que no tenga. Nunca borra nada.
    con = open(dst, encoding="utf-8", errors="replace").read()
    tiene = {l.strip() for l in con.splitlines()}
    nuevas = [l for l in open(src, encoding="utf-8").read().splitlines()
              if l.strip() and not l.strip().startswith("#") and l.strip() not in tiene]
    if not nuevas:
        return 0
    with open(dst, "a", encoding="utf-8") as f:
        if con and not con.endswith("\n"):
            f.write("\n")
        f.write("\n# --- añadido por harness-base/scripts/instalar.sh ---\n")
        f.write("\n".join(nuevas) + "\n")
    return len(nuevas)

def transferir(origen, destino, mover, forzar):
    n = 0
    for src_rel, dst_rel in archivos(origen):
        src = os.path.join(origen, src_rel); dst = os.path.join(destino, dst_rel)
        if os.path.lexists(dst):
            if dst_rel in MERGE:
                k = fusionar(src, dst)
                print("  fusionado  %s (+%d líneas)" % (dst_rel, k))
                if mover: os.remove(src)
                continue
            if not forzar:
                raise SystemExit("[harness] BUG: colisión no detectada en " + dst_rel)
            print("  sobrescrito %s" % dst_rel)
        os.makedirs(os.path.dirname(dst) or destino, exist_ok=True)
        if mover:
            os.replace(src, dst)
        else:
            shutil.copy2(src, dst)
        n += 1
    return n

def _forzar_borrado(func, path, exc):
    os.chmod(path, stat.S_IWRITE); func(path)

def limpiar_anidado(anidado):
    # Lo que queda tras mover es del molde (.git del clon, docs/futuro, cachés)
    # o carpetas vacías. Si queda otra cosa, se conserva y se avisa.
    for rel in (".git", ".harness", ".worktrees", "node_modules", "docs/futuro", "docs-molde"):
        p = os.path.join(anidado, rel)
        if os.path.isdir(p):
            shutil.rmtree(p, onerror=_forzar_borrado)
    for carpeta, dirs, ficheros in os.walk(anidado, topdown=False):
        for d in dirs:
            if d == "__pycache__":
                shutil.rmtree(os.path.join(carpeta, d), onerror=_forzar_borrado)
        for f in ficheros:
            if f.endswith(".pyc"):
                os.remove(os.path.join(carpeta, f))
        try:
            os.rmdir(carpeta)
        except OSError:
            pass
    if os.path.isdir(anidado):
        restos = []
        for carpeta, _, ficheros in os.walk(anidado):
            for f in ficheros:
                restos.append(os.path.relpath(os.path.join(carpeta, f), anidado).replace("\\", "/"))
        return restos
    return None

def version(config):
    try:
        return json.load(open(config, encoding="utf-8")).get("harness_version") or ""
    except Exception:
        return ""

def anidados(destino, max_niveles=2):
    # Carpetas con harness.config.json + init.sh, relativas al destino.
    hallados = []
    for carpeta, dirs, ficheros in os.walk(destino):
        rel = os.path.relpath(carpeta, destino).replace("\\", "/")
        nivel = 0 if rel == "." else rel.count("/") + 1
        dirs[:] = sorted(d for d in dirs if d not in (".git", "node_modules", ".worktrees", ".harness"))
        if nivel > 0 and "harness.config.json" in ficheros and "init.sh" in ficheros:
            hallados.append(rel); dirs[:] = []
        if nivel >= max_niveles:
            dirs[:] = []
    return hallados

def estado(anidado):
    # "sin_configurar" si no hay nada que conservar: project en TODO,
    # constitución con TODOs (o ausente) y ninguna feature empezada.
    try:
        cfg = json.load(open(os.path.join(anidado, "harness.config.json"), encoding="utf-8"))
    except Exception:
        return "con_trabajo"
    if not str(cfg.get("project", "")).startswith("TODO"):
        return "con_trabajo"
    arq = os.path.join(anidado, "docs", "architecture.md")
    if os.path.exists(arq) and "TODO" not in open(arq, encoding="utf-8", errors="replace").read():
        return "con_trabajo"
    try:
        feats = json.load(open(os.path.join(anidado, "feature_list.json"), encoding="utf-8")).get("features", [])
        if any(f.get("status") in ("in_progress", "done", "blocked") for f in feats):
            return "con_trabajo"
    except Exception:
        pass
    return "sin_configurar"

a = sys.argv[2:]
if op == "anidados":
    print("\n".join(anidados(a[0])))
elif op == "estado":
    print(estado(a[0]))
elif op == "version":
    print(version(a[0]))
elif op == "lista":
    print("\n".join(dst for _, dst in archivos(a[0])))
elif op == "colisiones":
    print("\n".join(colisiones(a[0], a[1])))
elif op == "copiar":
    print("[harness] Copiados %d archivos." % transferir(a[0], a[1], mover=False, forzar=(len(a) > 2 and a[2] == "forzar")))
elif op == "mover":
    n = transferir(a[0], a[1], mover=True, forzar=False)
    restos = limpiar_anidado(a[0])
    print("[harness] Movidos %d archivos a la raíz." % n)
    if restos is None:
        print("[harness] Carpeta anidada eliminada.")
    else:
        print("[harness] La carpeta anidada NO se borró: quedan archivos que no son del molde:")
        for r in restos: print("    " + r)
else:
    raise SystemExit("op desconocida: " + op)
PYCODE

py() { $PY -c "$INSTALAR_PY" "$@"; }

# ---- Fase final común: git, remoto, init.sh --quick, siguiente paso ---------
cerrar() {
  if ! git -C "$DEST" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$DEST" init -q && echo "[harness] git init en $DEST"
  fi
  # Los archivos del arnés quedan en el índice con su bit ejecutable. Sin
  # esto, en Windows git los registra como 644 y el primer `git merge molde`
  # da conflicto add/add en init.sh, los hooks y los tests aunque el
  # contenido sea idéntico. Solo se añade lo que instaló este script.
  (
    cd "$DEST" || exit 1
    printf '%s\n' "$LISTA" | while IFS= read -r f; do
      [ -f "$f" ] || continue
      git add -- "$f"
      case "$f" in scripts/*.sh|.githooks/*) git update-index --chmod=+x -- "$f" ;; esac
    done
  ) >/dev/null 2>&1
  echo "[harness] Archivos del arnés añadidos al índice (git add); haz commit cuando quieras."
  if ! git -C "$DEST" remote get-url molde >/dev/null 2>&1; then
    git -C "$DEST" remote add molde "$MOLDE_URL" && echo "[harness] Remoto 'molde' -> $MOLDE_URL (para actualizar el arnés después)"
  fi
  echo ""
  (cd "$DEST" && bash ./init.sh --quick); rc=$?
  echo ""
  echo "Siguiente paso:"
  echo "  cd \"$DEST\" && claude   →   /configurar"
  return $rc
}

# ---- 1. Arnés anidado ------------------------------------------------------
if [ -f "$DEST/harness.config.json" ] && [ -n "$(py anidados "$DEST")" ]; then
  echo "[harness] La raíz de $DEST ya tiene el arnés y además hay una copia anidada en:" >&2
  py anidados "$DEST" | sed 's/^/    /' >&2
  echo "[harness] Borra la copia anidada a mano (es la que sobra) y, para traer cambios del molde, sigue README §Actualizar una instancia." >&2
  exit 1
fi

ANIDADO_REL=$(py anidados "$DEST" | head -1)
if [ -n "$ANIDADO_REL" ]; then
  ANIDADO="$DEST/$ANIDADO_REL"
  echo "[harness] El arnés está en $ANIDADO_REL/, no en la raíz de $DEST."
  echo "          Así no funciona: Claude solo carga CLAUDE.md y los hooks de .claude/settings.json"
  echo "          desde la raíz del repo donde se abre, y ./init.sh no encuentra el proyecto."
  ESTADO=$(py estado "$ANIDADO")
  if [ "$ESTADO" = "sin_configurar" ]; then
    echo "[harness] La copia no está configurada (project en TODO, constitución con TODOs, sin features"
    echo "          empezadas): no hay trabajo que conservar. Propongo REINSTALAR LIMPIO:"
    echo "            1. instalar el molde actual (v$(py version "$RAIZ/harness.config.json")) en la raíz"
    echo "            2. borrar $ANIDADO_REL/ (incluido su .git, que es el clon del molde)"
    confirmar "¿Reinstalar limpio y borrar $ANIDADO_REL/?" || exit 1
    # Primero copiar, después borrar: la copia anidada suele ser el mismo clon
    # desde el que corre este script (bash harness-base/scripts/instalar.sh .),
    # y borrarla antes dejaría el molde sin origen.
    BORRAR_ANIDADO="$ANIDADO"
    # cae a la instalación limpia de abajo
  else
    COL=$(py colisiones "$ANIDADO" "$DEST")
    if [ -n "$COL" ]; then
      echo "[harness] La copia tiene trabajo, pero al moverla a la raíz pisaría archivos del proyecto:" >&2
      printf '%s\n' "$COL" | sed 's/^/    /' >&2
      echo "[harness] No se movió nada. Resuélvelos a mano (renombra o fusiona) y vuelve a correr." >&2
      exit 1
    fi
    echo "[harness] La copia tiene trabajo (configuración, constitución o features). Propongo MOVERLA a la raíz:"
    echo "            - cada archivo de $ANIDADO_REL/ pasa a la misma ruta en la raíz (README.md -> HARNESS.md)"
    echo "            - se descartan .git, .harness, .worktrees y docs/futuro/ de la copia (son del molde)"
    echo "            - ningún archivo del proyecto se sobrescribe (ya comprobado: sin colisiones)"
    confirmar "¿Mover $ANIDADO_REL/ a la raíz?" || exit 1
    V_MOLDE=$(py version "$RAIZ/harness.config.json")  # antes de mover: la copia puede ser este mismo clon
    LISTA=$(py lista "$ANIDADO")
    py mover "$ANIDADO" "$DEST" || exit 1
    V_MOVIDA=$(py version "$DEST/harness.config.json")
    if [ -z "$V_MOVIDA" ]; then
      echo "[harness] La copia movida no tiene harness_version (anterior a 1.0.0); el molde va en v$V_MOLDE."
      echo "          Tráete los cambios con README §Actualizar una instancia."
    elif [ "$V_MOVIDA" != "$V_MOLDE" ]; then
      echo "[harness] La copia movida es v$V_MOVIDA y el molde v$V_MOLDE: sigue README §Actualizar una instancia."
    fi
    cerrar; exit $?
  fi
fi

# ---- 2. Ya instanciado -----------------------------------------------------
if [ -f "$DEST/harness.config.json" ]; then
  V=$(py version "$DEST/harness.config.json")
  echo "[harness] $DEST ya tiene el arnés (v${V:-anterior a 1.0.0}). No se instala encima." >&2
  echo "[harness] Para traer los cambios del molde (v$(py version "$RAIZ/harness.config.json")) sigue README §Actualizar una instancia." >&2
  exit 1
fi

# ---- 3. Instalación limpia -------------------------------------------------
COL=$(py colisiones "$RAIZ" "$DEST")
if [ -n "$COL" ] && [ "$FORZAR" != 1 ]; then
  echo "[harness] Estos archivos del proyecto colisionan con el molde:" >&2
  printf '%s\n' "$COL" | sed 's/^/    /' >&2
  echo "[harness] No se escribió nada. Renómbralos o fusiónalos a mano, o corre con --forzar para sobrescribirlos." >&2
  exit 1
fi
echo "[harness] Instalando el molde v$(py version "$RAIZ/harness.config.json") en $DEST"
LISTA=$(py lista "$RAIZ")
if [ "$FORZAR" = 1 ]; then py copiar "$RAIZ" "$DEST" forzar; else py copiar "$RAIZ" "$DEST"; fi || exit 1
echo "[harness] El README del molde quedó como HARNESS.md."
if [ -n "$BORRAR_ANIDADO" ]; then
  rm -rf "$BORRAR_ANIDADO" || { echo "[harness] No se pudo borrar $BORRAR_ANIDADO: bórralo a mano." >&2; exit 1; }
  echo "[harness] $ANIDADO_REL/ eliminado (era la copia anidada sin trabajo)."
fi
cerrar; exit $?
