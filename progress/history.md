# Historial de sesiones

> Las entradas viven en `progress/history/`, **un archivo por sesión**:
> `YYYY-MM-DD-f<id>-<slug>.md`. Nunca se edita ni se borra una entrada ajena.
>
> ¿Por qué archivos separados y no una lista aquí? Porque los worktrees
> paralelos hacen merge a main: si todos apendearan al final de un mismo
> archivo, cada ola terminaría en conflicto. Un archivo por sesión = merges
> siempre limpios.

## Formato de cada entrada

La **primera línea es un prefijo fijo y parseable** — no la cambies de formato:

```markdown
## [2026-08-24] feature #3 | nombre_slug

**Resultado:** done | blocked
**Owner:** alias de quien la construyó
**Revisión cruzada:** alias de quien la revisó · o «omitida — razón»
**Rama/worktree:** feat/3-nombre
**Spec:** docs/specs/<modulo>.md
**Resumen:** 2-4 líneas de qué se hizo y qué decisiones se tomaron.
**Informes:** progress/impl_<name>.md · progress/review_<name>.md
```

Gracias al prefijo, la historia se consulta sin abrir archivo por archivo:

```bash
grep -h "^## \[" progress/history/*.md | sort | tail -10   # últimas 10 sesiones
grep -rl "feature #3" progress/history/                     # todo lo de una feature
```
