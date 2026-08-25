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

### El cruce humano (solo con equipo)

Los dos niveles anteriores los ejecuta una máquina o un LLM. Con un `team` de 2+
y `require_peer_review: true`, hay un tercero: otra persona lee el veredicto y
**la evidencia que cita** antes del merge (checkpoint C7).

Se acredita en la entrada de `progress/history/`, y esa línea es la que se
comprueba:

```markdown
**Owner:** arley
**Revisión cruzada:** socio
```

`scripts/check_peer_review.py` avisa en cada `./init.sh` y bloquea en
`./init.sh --merge` y al empujar a `main`.

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
./init.sh           # debe terminar con [OK] Entorno listo
./init.sh --merge   # además, exige la revisión cruzada — antes de mergear
```
