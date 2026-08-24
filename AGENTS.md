# AGENTS.md — Mapa de navegación para agentes de IA

> Punto de entrada del repositorio. NO es una biblia de reglas: es un **mapa**.
> Lee solo lo que necesites, cuando lo necesites (divulgación progresiva).

---

## 1. Antes de empezar (obligatorio)

1. Ejecuta `./init.sh`. Si falla, **para** y resuelve el entorno.
2. Lee `harness.config.json` — define qué se verifica y qué rutas están protegidas.
3. Lee `progress/current.md` para saber en qué estado quedó la última sesión.
4. Lee `feature_list.json` y elige **una** feature `pending`. Una a la vez.

## 2. Mapa del repositorio

| Archivo / carpeta            | Qué contiene                                           | Cuándo leerlo |
|------------------------------|--------------------------------------------------------|---------------|
| `harness.config.json`        | Comandos de verificación, rutas protegidas y exclusivas | Siempre |
| `feature_list.json`          | Backlog con estado, dependencias y rutas afectadas      | Siempre |
| `progress/current.md`        | Estado de la sesión activa                              | Siempre |
| `progress/history.md`        | Bitácora append-only                                    | Si necesitas contexto histórico |
| `docs/architecture.md`       | Qué significa "hacer un buen trabajo" aquí              | Antes de implementar |
| `docs/conventions.md`        | Estilo, nombres, estructura, errores                    | Antes de producir |
| `docs/verification.md`       | Cómo demostrar que el trabajo funciona                  | Antes de declarar `done` |
| `CHECKPOINTS.md`             | Criterios objetivos de estado final correcto            | Para auto-evaluarte |
| `.claude/agents/`            | Definiciones de líder, implementador y revisor          | Si orquestas |
| `scripts/plan_parallel.py`   | Qué features pueden correr en paralelo sin colisionar   | Al planear una ola |

## 3. Reglas duras (no negociables)

- **Una sola feature en `in_progress` por worktree.** `./init.sh` lo rechaza.
- **No declares `done` sin verificación verde.** Los comandos salen de
  `harness.config.json`, no de tu criterio.
- **Documenta mientras trabajas** en `progress/current.md`, no al final.
- **Rutas exclusivas, una a la vez.** Lo declarado en `exclusive_paths`
  (migraciones, schema, tipos compartidos) no se toca desde dos worktrees.
- **Si no sabes algo, búscalo en `docs/`** antes de inventarlo.

## 4. Cómo elegir una tarea

```
1. Abre feature_list.json
2. Filtra por status == "pending" y depends_on todas en "done"
3. Coge la de menor "id"
4. Cambia su status a "in_progress" y guarda
5. Anota en progress/current.md: feature, hora de inicio, plan breve
```

## 5. Cierre de sesión

1. `./init.sh` — todo verde.
2. Si la feature está aprobada por el reviewer: `status: "done"`.
3. Mueve el resumen de `progress/current.md` al final de `progress/history.md`.
4. Vacía `progress/current.md` dejando la plantilla.
5. Sin archivos temporales, sin debug suelto, sin TODOs sin contexto.

## 6. Si te bloqueas

Relee la sección relevante de `docs/`. Si una herramienta no hace lo esperado,
**no inventes un workaround**: marca `blocked` en `feature_list.json`, documenta
en `progress/current.md` y termina la sesión.
