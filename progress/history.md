# Historial de sesiones

> Las entradas viven en `progress/history/`, **un archivo por sesión**:
> `YYYY-MM-DD-f<id>-<slug>.md`. Nunca se edita ni se borra una entrada ajena.
>
> ¿Por qué archivos separados y no una lista aquí? Porque los worktrees
> paralelos hacen merge a main: si todos apendearan al final de un mismo
> archivo, cada ola terminaría en conflicto. Un archivo por sesión = merges
> siempre limpios.

## Formato de cada entrada

```markdown
# 2026-08-24 — feature #3 nombre_slug

**Resultado:** done | blocked
**Rama/worktree:** feat/3-nombre
**Resumen:** 2-4 líneas de qué se hizo y qué decisiones se tomaron.
**Informes:** progress/impl_<name>.md · progress/review_<name>.md
```
