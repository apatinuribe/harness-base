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
| Sin capa de especificación | `/configurar`, `/constitucion` y `/especificar`: entrevistan y producen configuración y specs auditables |
| Se construía sobre un titular | `init.sh` bloquea arrancar una feature sin spec resuelto |
| Conocimiento que no se acumula | `docs/index.md` + `bibliotecario` cruzan los specs entre sí |
| — | `exclusive_paths`: rutas que solo una feature puede tocar (migraciones, schema) |

## Instanciar el arnés (10 minutos)

```bash
# 1. Copia el andamiaje dentro de tu repo real (NO al revés)
#    Ojo: sobreescribe CLAUDE.md y README.md si el destino ya los tiene.
cp -r harness-base/. /ruta/a/mi-proyecto/
cd /ruta/a/mi-proyecto

# 2. Abre Claude y corre las tres entrevistas, en este orden
claude
#    /configurar                → detecta tu stack, prueba los comandos de test,
#                                 escribe harness.config.json y conventions.md
#    /constitucion              → llena docs/architecture.md entrevistándote
#    /especificar <modulo>      → llena docs/specs/<modulo>.md y propone features

# 3. Comprueba que el arnés está en verde
./init.sh

# 4. Vacía el backlog de ejemplo y mete las features que salieron del paso 2
```

**Ninguno de los tres comandos es opcional.** Sin `/configurar` el arnés no
tiene verificación determinista, y el reviewer queda aprobando por opinión. Sin
`/constitucion` cada módulo inventa sus propias reglas transversales. Sin
`/especificar` el implementador rellena los huecos del negocio a su criterio.

También puedes editar `harness.config.json`, `docs/conventions.md` y
`docs/verification.md` a mano si prefieres: `/configurar` solo automatiza eso y
comprueba que los comandos que escribe realmente corren.

## Varias personas en el mismo proyecto

Declara el equipo en `harness.config.json` (`/configurar` te lo pregunta):

```json
"team": [
  { "id": "arley", "git_email": "arley@ejemplo.com" },
  { "id": "socio", "git_email": "socio@ejemplo.com" }
],
"require_peer_review": true
```

Con **0 o 1 miembros** el arnés corre en modo solitario y nada cambia. Con **2 o
más** se activan cuatro cosas:

| | Qué pasa |
|---|---|
| **Reparto** | Cada feature declara `owner`. Se reclama en `main` **antes** de abrir el worktree — es lo único que evita que dos construyan lo mismo |
| **Paralelo** | `./init.sh` permite una `in_progress` **por persona**, no una en total |
| **Sesiones** | Cada quien escribe en `progress/current_<alias>.md`; nunca chocan en el merge |
| **Cruce** | Con `require_peer_review`, ninguna rama entra a `main` sin que el otro lea la evidencia (checkpoint C7) |

El cruce humano importa más de lo que parece: el `reviewer` es un LLM, así que
sin él la aprobación es IA aprobando a IA. La segunda persona es la única
verificación que no comparte los sesgos de la primera. Si los frena más de lo
que los protege, `require_peer_review: false` y queda como recomendación.

## Antes de lanzar agentes: haz una feature a mano

Necesitas al menos un ejemplo de "así se ve bien" en el repo antes de que el
reviewer tenga contra qué comparar. Sin referencia concreta, aprueba todo.

## Antes de construir: especificar

El arnés resuelve **la ejecución**. No resuelve **qué construir**. Sin esta capa,
un «quiero un módulo de suscripciones con planes y cobros» llega al implementador
como un titular, y el implementador rellena los huecos inventando reglas de
negocio. Eso es lo que hace que un producto se sienta «hecho con IA».

Tres comandos, los tres en la sesión principal (un subagente no puede
preguntarte):

```bash
/configurar              # una vez al instanciar el arnés
/constitucion            # una vez por proyecto
/especificar suscripciones   # una vez por módulo
```

**Qué resuelve cada capa**

| Capa | Preguntas que responde | Dónde vive |
|---|---|---|
| **Transversal** | ¿Quién entra? ¿Qué pasa cuando algo falla? ¿Qué se loguea? ¿En qué zona horaria? ¿Qué dato es sensible? | `/constitucion` → `docs/architecture.md` §5 |
| **Alrededor** | ¿Qué entornos hay? ¿Cómo se revierte? ¿De qué terceros dependemos? ¿Quién lo opera? | `/constitucion` → `docs/architecture.md` §6 |
| **Vertical** | ¿Cuál es el journey? ¿Qué entidades hay? ¿Qué reglas de negocio? ¿Qué ve cada rol? | `/especificar` → `docs/specs/<modulo>.md` §4 |
| **Temporal** | ¿Qué estados tiene? ¿Qué pasa si la acción llega dos veces? ¿Qué corre solo? ¿Y los datos que ya existen? | `/especificar` → `docs/specs/<modulo>.md` §5 |
| **Ejecución** | ¿Quién construye qué, en qué orden, sin pisarse, y cómo se demuestra? | El arnés (`feature_list.json`, `init.sh`, `reviewer`) |
| **Verificación** | ¿Qué comando demuestra que esto funciona? ¿Qué rutas no se tocan? ¿Qué causa rechazo automático? | `/configurar` → `harness.config.json`, `docs/conventions.md` |

Regla de oro: si la respuesta es igual para todos los módulos, va a la
constitución. Si cambia módulo a módulo, va al spec. Si es «quién lo hace y
cuándo», va al backlog.

**Cómo son las entrevistas.** Máximo 5 preguntas por módulo (8 para la
constitución), **una a la vez**, cada una con su recomendación y una tabla de
opciones con las consecuencias. Puedes responder solo con la letra. Lo que no
sepas queda marcado como `[NEEDS CLARIFICATION]` — y `./init.sh` **bloquea
arrancar** esa feature hasta resolverlo. Nada se inventa por ti.

**Después de la entrevista** corre el subagente `analista`: audita el spec
contra la constitución y clasifica los hallazgos (CRITICAL / HIGH / MEDIUM /
LOW). Un CRITICAL impide crear las features.

## Correr una feature

```bash
./init.sh              # verde antes de empezar
claude                 # CLAUDE.md te pone en rol leader automáticamente
```

Pídele: **«implementa la feature #N»** — siempre con el id explícito, nunca
«la siguiente pendiente». El líder lanza `implementer` y luego `reviewer`.

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

Reglas: una feature `in_progress` por persona, y nunca dos features de la misma
ola tocando la misma ruta. Una ruta de `exclusive_paths` (migraciones, schema,
tipos compartidos) solo puede estar en una feature por ola; el planner difiere
las demás.

## Flujo con emdash

Cada tarea de emdash = **una feature**, en su propio worktree y rama.

1. En `main`: `./init.sh --plan` y elige una ola.
1b. **Reparte la ola**: pon el `owner` de cada feature y commitea a `main`
   *antes* de abrir ningún worktree. Sin esto, dos personas pueden arrancar la
   misma feature y no enterarse hasta el merge.
2. Crea una tarea de emdash por feature de la ola, con rama `feat/<id>-<slug>`.
3. Prompt de la tarea — el id **siempre explícito**:

   > Implementa la feature #<id> de feature_list.json. Actúa como leader
   > (CLAUDE.md): lanza implementer y reviewer. No elijas otra feature.

4. Con `APPROVED` del reviewer, mergea a `main` una rama a la vez. Si
   `require_peer_review` es `true`, el merge lo aprueba **otra persona** del
   `team`, que lee la evidencia y no solo el veredicto (checkpoint C7).
5. Mergeada la ola completa: lanza `bibliotecario` (chequeo de salud del
   conocimiento) y luego `./init.sh --plan` para planear la siguiente.

Por qué los merges salen limpios (si se respetan las reglas):

- Cada rama toca solo las líneas `owner` y `status` de **su** feature en
  `feature_list.json`.
- Cada persona escribe en su propio `progress/current_<alias>.md`.
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
├── feature_list.json       # Backlog con spec / depends_on / touches
├── init.sh                 # Verificación (--plan, --quick)
├── scripts/                # plan_parallel.py + hooks.sh
├── docs/
│   ├── index.md            # Qué es el producto hoy (lo primero que se lee)
│   ├── architecture.md     # LA CONSTITUCIÓN: políticas transversales + rúbrica
│   ├── conventions.md      # Estilo, nombres, estructura
│   ├── verification.md     # Cómo se demuestra que algo funciona
│   ├── specs/              # Un spec por módulo (+ _plantilla.md)
│   └── futuro/             # Decisiones aplazadas y su señal de activación
├── progress/               # current.md (vivo) + history/ (1 entrada/sesión)
└── .claude/
    ├── agents/             # leader, implementer, reviewer, explorer,
    │                       #   analista, bibliotecario
    ├── commands/           # /configurar, /constitucion, /especificar
    └── settings.json       # Hooks de verificación automática
```

## Los seis subagentes

| Agente | Qué hace | Cuándo |
|---|---|---|
| `leader` | Descompone y coordina. Nunca implementa | Siempre (rol por defecto) |
| `implementer` | Construye **una** feature y su evidencia | Por feature |
| `reviewer` | Aprueba o rechaza contra spec, constitución y checkpoints | Por feature, nunca se salta |
| `explorer` | Responde **una** pregunta acotada sobre el repo | Cuando hace falta investigar |
| `analista` | Audita **un** spec antes de volverlo features | Al final de `/especificar` |
| `bibliotecario` | Cruza **todos** los specs, detecta contradicciones, mantiene el índice | Entre olas — no es un gate |
