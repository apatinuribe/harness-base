# harness-base — Plantilla de Harness Engineering

Andamiaje agnóstico de stack derivado de `betta-tech/ejemplo-harness-subagentes`.
Aquí no hay aplicación de ejemplo: solo el arnés, listo para envolver cualquier
proyecto (software, contenido, research, campañas).

## Qué cambia respecto al repo original

| Original | Aquí |
|---|---|
| `init.sh` corre `unittest` hardcodeado | Corre los comandos de `harness.config.json` |
| Reglas atadas a `src/` y `tests/` | Rutas configurables (`protected_paths`) |
| Features sin dependencias ni rutas | `depends_on` y `touches` en cada feature |
| Paralelismo a ojo | `./init.sh --plan` agrupa features en olas seguras |
| Reviewer solo con checkpoints | Reviewer con acceptance citable + rúbrica 1-5 bloqueante |
| — | `exclusive_paths`: rutas que solo una feature puede tocar (migraciones, schema) |

## Instanciar el arnés (10 minutos)

```bash
# 1. Copia el andamiaje dentro de tu repo real (NO al revés)
#    Ojo: sobreescribe CLAUDE.md y README.md si el destino ya los tiene.
cp -r harness-base/. /ruta/a/mi-proyecto/
cd /ruta/a/mi-proyecto

# 2. Configura
#    - harness.config.json: project, verify[], protected_paths, exclusive_paths
#    - docs/*.md: resuelve todos los TODO (esto es el 80% del valor)
#    - CHECKPOINTS.md: añade la sección de tu dominio

# 3. Comprueba que el arnés arranca en rojo por la razón correcta
./init.sh

# 4. Vacía el backlog de ejemplo y mete features reales
```

**El paso 2 no es opcional.** Un `docs/architecture.md` con TODOs produce un
reviewer que aprueba cualquier cosa. La rúbrica de §4 es lo que le da criterio.

## Antes de lanzar agentes: haz una feature a mano

Necesitas al menos un ejemplo de "así se ve bien" en el repo antes de que el
reviewer tenga contra qué comparar. Sin referencia concreta, aprueba todo.

## Correr una feature

```bash
./init.sh              # verde antes de empezar
claude                 # CLAUDE.md te pone en rol leader automáticamente
```

Pídele: **«implementa la siguiente feature pendiente»**.

Por chat no pasa el entregable, solo referencias:
`done -> progress/impl_<name>.md`. Abre `progress/` en el editor mientras
trabaja para auditar paso a paso.

## Correr varias en paralelo

```bash
./init.sh --plan       # imprime las olas seguras
```

Cada feature de una ola va en su propio worktree:

```bash
git worktree add ../proyecto-feat-3 -b feat/3-nombre
```

Reglas: una feature `in_progress` por worktree, y nunca dos features de la misma
ola tocando la misma ruta. Una ruta de `exclusive_paths` (migraciones, schema,
tipos compartidos) solo puede estar en una feature por ola; el planner difiere
las demás.

## Flujo con emdash

Cada tarea de emdash = **una feature**, en su propio worktree y rama.

1. En `main`: `./init.sh --plan` y elige una ola.
2. Crea una tarea de emdash por feature de la ola, con rama `feat/<id>-<slug>`.
3. Prompt de la tarea — el id **siempre explícito**:

   > Implementa la feature #<id> de feature_list.json. Actúa como leader
   > (CLAUDE.md): lanza implementer y reviewer. No elijas otra feature.

4. Con `APPROVED` del reviewer, mergea a `main` una rama a la vez.
5. Mergeada la ola completa: `./init.sh --plan` para planear la siguiente.

Por qué los merges salen limpios (si se respetan las reglas):

- Cada rama toca solo la línea `status` de **su** feature en `feature_list.json`.
- `progress/current.md` vuelve a la plantilla antes del merge.
- La bitácora es un archivo **por sesión** en `progress/history/`, nunca un
  archivo compartido.
- Los informes van a `progress/impl_<name>.md` / `progress/review_<name>.md`,
  únicos por feature.

## Ejemplos de configuración

**Producto software (Supabase + Vercel)**
```json
"verify": [
  {"name": "tests", "command": "npm test -- --run", "required": true},
  {"name": "typecheck", "command": "npx tsc --noEmit", "required": true},
  {"name": "lint", "command": "npm run lint", "required": false}
],
"protected_paths": ["src/", "tests/", "supabase/"],
"exclusive_paths": ["supabase/migrations/", "src/types/database.ts"]
```

**Contenido**
```json
"verify": [
  {"name": "estructura", "command": "python3 scripts/check_package.py", "required": true},
  {"name": "claims", "command": "python3 scripts/check_claims.py", "required": true}
],
"protected_paths": ["packages/"],
"exclusive_paths": ["brand/voice.md"]
```

**Research**
```json
"verify": [
  {"name": "fuentes", "command": "python3 scripts/check_sources.py", "required": true}
],
"protected_paths": ["findings/"],
"exclusive_paths": ["findings/_sintesis.md"]
```

## Estructura

```
.
├── harness.config.json     # Qué se verifica, qué rutas se protegen
├── AGENTS.md               # Mapa para agentes (divulgación progresiva)
├── CLAUDE.md               # Fuerza el rol de leader
├── CHECKPOINTS.md          # Criterios de estado final correcto
├── feature_list.json       # Backlog con depends_on / touches
├── init.sh                 # Verificación (--plan, --quick)
├── scripts/                # plan_parallel.py + hooks.sh
├── docs/                   # architecture / conventions / verification
├── progress/               # current.md (vivo) + history/ (1 entrada/sesión)
└── .claude/
    ├── agents/             # leader, implementer, reviewer, explorer
    └── settings.json       # Hooks de verificación automática
```
