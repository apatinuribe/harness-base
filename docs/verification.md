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

## Un test por criterio

Cada criterio DADO/CUANDO/ENTONCES de `acceptance` tiene **su** test. No «los
tests de la feature cubren los criterios»: uno por criterio, y rastreable.

**Por qué:** una suite en verde dice que lo que se probó funciona, no que se
probó lo que se prometió. Sin un mapeo uno a uno, el criterio más difícil —el
caso borde, el permiso denegado— es justo el que se queda sin test, y nadie lo
nota porque todo está en verde.

**El identificador es `F<id>-C<n>`**: feature `<id>`, criterio número `<n>`
de su `acceptance` (empezando en 1, en el orden en que están escritos). Va en
el nombre o la descripción del test, sea cual sea el framework:

```
test("F7-C2 no crea dos suscripciones si se reintenta el pago", ...)
def test_F7_C2_no_duplica_suscripcion_en_reintento(): ...
```

Así, `grep -rn "F7-C2"` encuentra el test desde el criterio, y el criterio
desde el test. Es el mismo `F<id>` que usa la tabla «Trazabilidad» de
`PROYECTO.md`: un solo `grep` cruza objetivo, feature y prueba. Por eso **el
orden de `acceptance` no se cambia** una vez que la feature arrancó — renumera
todos sus tests.

**Criterios no automatizables.** Algunos no se pueden probar con código: «el
email llega a la bandeja de entrada», «el PDF se imprime legible». Se declaran
como `manual`, con **por qué** no se automatiza —«es difícil» no es una razón;
«depende de un cliente de correo real» sí— y con evidencia que muestre el
resultado: captura, grabación o los pasos seguidos y lo observado.

## Cómo se presenta la evidencia

Cada criterio de `acceptance` se responde en `progress/impl_<name>.md` así:

```
- criterio: "F7-C1 · <texto literal del acceptance>"
  test: tests/suscripciones/alta.test.ts:42 — "F7-C1 alta con plan mensual"
  resultado: <comando + salida que muestra el test pasando>

- criterio: "F7-C3 · <texto literal del acceptance>"
  manual: <por qué no se puede automatizar>
  evidencia: <ruta a la captura / pasos seguidos y resultado observado>
```

El `reviewer` comprueba el mapeo en las dos direcciones: cada criterio tiene su
test (o su `manual` justificado), y cada `F<id>-C<n>` que aparece en los tests
corresponde a un criterio que existe. Si falta uno, no cierra.

## Anti-patrones

- ❌ "Lo implementé, debería funcionar." → falta evidencia ejecutable.
- ❌ Evidencia que solo prueba que no hubo error → tiene que probar el resultado.
- ❌ Un criterio sin test `F<id>-C<n>` ni `manual` justificado → no está verificado,
  aunque la suite esté en verde.
- ❌ Ajustar `CHECKPOINTS.md` o `docs/` para que el trabajo pase.
- ❌ Marcar `done` sin `./init.sh` en verde.

## Antes de cerrar

```bash
./init.sh           # debe terminar con [OK] Entorno listo
./init.sh --merge   # además, exige la revisión cruzada — antes de mergear
```
