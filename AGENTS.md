# AGENTS.md — Mapa de navegación para agentes de IA

> Punto de entrada del repositorio. NO es una biblia de reglas: es un **mapa**.
> Lee solo lo que necesites, cuando lo necesites (divulgación progresiva).

---

## 1. Antes de empezar (obligatorio)

1. Ejecuta `./init.sh`. Si falla, **para** y resuelve el entorno.
2. Lee `docs/index.md` — qué es este producto hoy, en una página.
3. Lee `harness.config.json` — define qué se verifica y qué rutas están protegidas.
4. Averigua **quién eres**: `git config user.email` → búscalo en `team` de
   `harness.config.json`. Ese alias es tu `owner`. Tu sesión se escribe en
   `progress/current_<owner>.md` (copia de `progress/current.md`).
5. Lee `feature_list.json` y elige **una** feature `pending` **sin `owner`**.
   Una a la vez. Si ya tiene dueño, es de otra persona: no la toques.
6. Lee el `spec` de esa feature. **Si no tiene, no se arranca**: se especifica
   primero con `/especificar`.

## 2. Mapa del repositorio

| Archivo / carpeta            | Qué contiene                                           | Cuándo leerlo |
|------------------------------|--------------------------------------------------------|---------------|
| `docs/index.md`              | Qué existe hoy: módulos, entidades, decisiones           | Siempre, lo primero |
| `harness.config.json`        | Comandos de verificación, rutas protegidas y exclusivas | Siempre |
| `feature_list.json`          | Backlog con estado, dependencias y rutas afectadas      | Siempre |
| `progress/current_<owner>.md`| Estado de la sesión activa de cada persona               | Siempre |
| `progress/history/`          | Bitácora append-only (un archivo por sesión)            | Si necesitas contexto histórico |
| `docs/architecture.md`       | **Constitución**: políticas transversales + rúbrica      | Antes de implementar |
| `docs/specs/<modulo>.md`     | Qué hace un módulo, sus reglas y sus casos borde         | Antes de implementar |
| `docs/futuro/`               | Decisiones aplazadas y con qué señal se retoman          | Al plantear algo nuevo |
| `docs/conventions.md`        | Estilo, nombres, estructura, errores                    | Antes de producir |
| `docs/verification.md`       | Cómo demostrar que el trabajo funciona                  | Antes de declarar `done` |
| `CHECKPOINTS.md`             | Criterios objetivos de estado final correcto            | Para auto-evaluarte |
| `.claude/agents/`            | Líder, implementador, revisor, explorador, analista, bibliotecario | Si orquestas |
| `.claude/commands/`          | `/configurar`, `/constitucion` y `/especificar` (entrevistas) | Al instanciar y antes de construir algo nuevo |
| `scripts/plan_parallel.py`   | Qué features pueden correr en paralelo sin colisionar   | Al planear una ola |

## 3. Reglas duras (no negociables)

- **No se arranca una feature sin spec resuelto.** `./init.sh` rechaza pasar a
  `in_progress` sin `spec`, con un `spec` inexistente, o con
  `[NEEDS CLARIFICATION]` sin responder. Construir a ciegas es lo que produce
  «otro producto hecho con IA».
- **La constitución (`docs/architecture.md` §5-§6) no se negocia desde una
  feature.** Si estorba, se enmienda con `/constitucion`; no se ignora.
- **Una sola feature en `in_progress` por persona.** `./init.sh` lo rechaza, y
  con `team` de 2+ también rechaza una feature `in_progress` sin `owner`.
- **Se reclama en `main`, antes de abrir el worktree.** Poner tu alias en
  `owner` y commitear es lo único que impide que dos personas construyan lo
  mismo. Reclamar después de trabajar no sirve de nada.
- **No declares `done` sin verificación verde.** Los comandos salen de
  `harness.config.json`, no de tu criterio.
- **Documenta mientras trabajas** en `progress/current_<owner>.md`, no al final.
- **Rutas exclusivas, una a la vez.** Lo declarado en `exclusive_paths`
  (migraciones, schema, tipos compartidos) no se toca desde dos worktrees.
- **En `feature_list.json` toca solo la línea `status` de TU feature.** Sin
  reformatear ni reordenar: es lo que hace que los merges de worktrees
  paralelos sean automáticos.
- **Si no sabes algo, búscalo en `docs/`** antes de inventarlo.

## 4. Cómo elegir una tarea

**Si te asignaron una feature** (prompt del líder, o tarea de emdash con rama
`feat/<id>-<slug>`): esa es tu feature. No elijas otra aunque tenga id menor.
En paralelo, la selección la hace el planner en `main`, no cada worktree.

**Si nadie te asignó nada:**

```
1. Abre feature_list.json
2. Filtra por status == "pending", sin "owner", y depends_on todas en "done"
3. Coge la de menor "id"
```

En ambos casos, **en `main` y antes de abrir el worktree**:

```
4. Pon tu alias en "owner" y el status en "in_progress" — toca SOLO esas dos
   líneas de TU feature — guarda y commitea a main
5. Recién ahí abre el worktree: git worktree add ../proy-feat-<id> -b feat/<id>-<slug>
6. Anota en progress/current_<owner>.md: feature, hora de inicio, plan breve
```

Reclamar en `main` primero es lo que hace que el otro vea la feature tomada
antes de empezarla él.

## 5. Cierre de sesión

1. `./init.sh` — todo verde.
2. Si la feature está aprobada por el reviewer: `status: "done"`.
3. Copia el resumen de `progress/current_<owner>.md` a una entrada nueva
   `progress/history/YYYY-MM-DD-f<id>-<slug>.md` (formato en `progress/history.md`;
   respeta el prefijo `## [fecha] feature #id | slug`, se consulta con `grep`).
   Incluye tu `owner` y quién hizo la revisión cruzada.
4. Deja `progress/current_<owner>.md` en `idle`. No hace falta vaciarlo por
   miedo a conflictos —es tuyo y de nadie más—, pero sí para que el otro no
   crea que sigues en esa feature.
5. Si `require_peer_review` está en `true`: **no mergees tú**. Abre el PR y
   pide el cruce (checkpoint C7).
6. Sin archivos temporales, sin debug suelto, sin TODOs sin contexto.

## 6. Si te bloqueas

Relee la sección relevante de `docs/`. Si una herramienta no hace lo esperado,
**no inventes un workaround**: marca `blocked` en `feature_list.json`, documenta
en `progress/current_<owner>.md` y termina la sesión.
