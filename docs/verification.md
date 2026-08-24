# Verificación — Cómo demostrar que el trabajo funciona

> Regla de oro: **el agente no dice "funciona", lo demuestra.**
> Toda feature termina con evidencia, no con afirmaciones.

## Los dos niveles

### Nivel 1 — Determinista (obligatorio)

Un script que devuelve 0 o 1, sin opinión de por medio. Se declara en
`harness.config.json` → `verify`. Es lo que corre `./init.sh`.

TODO: define aquí tus comprobaciones deterministas. Ejemplos por dominio:

- **Software**: tests unitarios, typecheck, lint, build, migraciones aplicables.
- **Contenido**: el paquete tiene los N archivos requeridos; `meta.json` valida
  contra schema; ningún hook supera X palabras; ninguna claim prohibida aparece.
- **Research**: toda cifra tiene fuente con URL y fecha; existe el bloque de
  contradicciones; ningún findings.md sin sección de metodología.

### Nivel 2 — Rúbrica (obligatorio si el entregable no es binario)

El reviewer puntúa 1-5 contra `docs/architecture.md` §4. Cualquier criterio
< 3 bloquea el cierre. La puntuación debe venir con archivo, línea y razón.

> Sin Nivel 1, el Nivel 2 es teatro: un LLM aprobando a otro LLM.
> Construye el determinista primero, aunque sea mínimo.

## Cómo se presenta la evidencia

Cada criterio de `acceptance` se responde en `progress/impl_<name>.md` así:

```
- criterio: "<texto literal del acceptance>"
  evidencia: <ruta:línea o comando + salida>
```

## Anti-patrones

- ❌ "Lo implementé, debería funcionar." → falta evidencia ejecutable.
- ❌ Evidencia que solo prueba que no hubo error → tiene que probar el resultado.
- ❌ Ajustar `CHECKPOINTS.md` o `docs/` para que el trabajo pase.
- ❌ Marcar `done` sin `./init.sh` en verde.

## Antes de cerrar

```bash
./init.sh    # debe terminar con [OK] Entorno listo
```
