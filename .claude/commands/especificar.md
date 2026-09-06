---
description: Entrevista por módulo. Convierte "quiero un módulo de X" en un spec ejecutable en docs/specs/<modulo>.md y propone las features.
argument-hint: <nombre-del-modulo>
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

# /especificar — Convertir una idea en un spec ejecutable

Módulo a especificar: **$ARGUMENTS**

Este comando existe porque decir *«quiero un módulo de suscripciones con planes
y cobros»* no es una especificación: es un titular. Aquí se convierte en algo
que un implementador puede construir sin adivinar, y un revisor puede juzgar
sin opinar.

**Se corre en la sesión principal, no como subagente**: un subagente no puede
hacerte preguntas.

## Qué resuelve este comando y qué no

| Capa | Dónde se decide |
|---|---|
| **Vertical** — journey, pantallas, entidades, reglas de negocio, contratos de ESTE módulo | **Aquí** |
| **Temporal** — estados, repetición, eventos, jobs, datos existentes de ESTE módulo | **Aquí** |
| **Transversal** — auth, errores, logs, PII, idioma, rendimiento | En `/constitucion`. Aquí solo **desviaciones** |
| **Alrededor** — entornos, despliegue, terceros, soporte | En `/constitucion`. Aquí solo lo propio del módulo |
| **Ejecución** — quién construye qué, en qué orden, sin colisiones, con evidencia | En el arnés (`feature_list.json`, `init.sh`, `reviewer`) |

Si te descubres decidiendo algo que aplica igual a todos los módulos, **para** y
dilo: eso va a la constitución, no a este spec.

## Protocolo

### 1. Requisito previo

Lee `docs/architecture.md`. Si §5 (Políticas transversales) o §6 (Alrededor del
sistema) todavía tienen `TODO`, **detente** y responde:

> La constitución no está definida. Corre `/constitucion` primero: sin ella este
> spec tendría que decidir por su cuenta cosas que afectan a todo el producto.

### 2. Estado actual

- Si `docs/specs/$ARGUMENTS.md` ya existe → modo continuación: léelo, identifica
  qué falta y qué `[NEEDS CLARIFICATION]` siguen abiertos. No empieces de cero.
- Si no existe → copia `docs/specs/_plantilla.md`, **borra el bloque de
  instrucciones de la cabecera** (el que empieza con «Plantilla usada por
  `/especificar`»: si se queda, `init.sh` leerá su mención del marcador de
  pendiente como un pendiente real) y rellena todo lo que ya puedas deducir de
  lo que el usuario dijo, del resto de `docs/specs/` y del código existente.

### 3. Escaneo de cobertura

Recorre la taxonomía y marca cada casilla **Clara / Parcial / Ausente**. Es tu
insumo para priorizar; no se la muestres al usuario.

**Vertical (este módulo, de cara al usuario)**

| Casilla | Qué tiene que quedar resuelto |
|---|---|
| Journey | Qué hace el usuario paso a paso, desde dónde entra y con qué se va |
| Pantallas y estados | Qué ve: vacío, cargando, con datos, error, sin permiso |
| Entidades y datos | Qué objetos existen, sus campos, cuáles obligatorios, cómo se relacionan |
| Reglas de negocio | Qué está permitido y qué no, y quién decide — lo que el código no puede inventar |
| Contratos | Qué operaciones expone al resto del sistema y qué devuelve cada una |
| Permisos | Qué puede hacer cada rol dentro de este módulo |

**Temporal (qué pasa con el tiempo)**

| Casilla | Qué tiene que quedar resuelto |
|---|---|
| Estados y transiciones | Ciclo de vida de la entidad principal: de qué estado a cuál, y quién lo mueve |
| Repetición | Qué pasa si la misma acción llega dos veces: doble clic, reintento, red caída |
| Eventos | Qué avisa este módulo al resto, y a qué reacciona |
| Programado | Qué corre solo (recordatorios, cobros, cierres) y cada cuánto |
| Datos existentes | Qué pasa con lo ya guardado cuando esto entre en producción |

**Transversal y Alrededor**: solo anota las **desviaciones** de la constitución,
con su razón. Sin desviaciones se escribe «Sigue la constitución sin excepciones».

### 4. Preguntas

**Máximo 5 preguntas. Una a la vez. Nunca reveles la cola de preguntas.**

Prioriza por **impacto × incertidumbre**. Impacto alto = si se decide mal,
obliga a rehacer código, migrar datos o rediseñar pantallas.

Cada pregunta cumple **todas** estas reglas:

- Es una **interrogación completa que termina en `?`**, nunca una etiqueta.
- Trae una línea **`Por qué importa:`** en lenguaje llano.
- Trae una **recomendación explícita** antes de la tabla, con su razón.
- Trae una **tabla de opciones** con la consecuencia real de cada una.
- Cierra con `Responde con la letra, o descríbeme la tuya.`
- **Autocomprobación:** ¿alguien no técnico que no ha leído este repo puede
  responderla con lo que hay en pantalla? Si no, reescríbela.

Ejemplo:

```markdown
**P2.** Cuando un cliente cancela su plan, ¿hasta cuándo debe conservar el acceso?

Por qué importa: define si hay que cobrar proporcional, si el sistema necesita
recordar una fecha de corte, y qué ve el cliente el día que se le vence.

**Recomendado:** Opción B — es lo que el cliente espera al haber pagado el mes.

| Opción | Qué pasa | Consecuencia |
|---|---|---|
| A | Pierde el acceso al instante | Simple; genera reclamos por el tiempo pagado |
| B | Conserva el acceso hasta el fin del periodo pagado | Justo; hay que guardar fecha de corte y algo que la revise a diario |
| C | Conserva el acceso y se le devuelve la parte no usada | Lo más generoso; obliga a integrar devoluciones con la pasarela |

Responde con la letra, o descríbeme la tuya.
```

### 5. Escritura incremental

**Después de CADA respuesta aceptada**, actualiza `docs/specs/$ARGUMENTS.md`
antes de preguntar lo siguiente. Añade la entrada al log:

```markdown
## Clarificaciones
### Sesión 2026-08-25
- P: ¿Hasta cuándo conserva el acceso un cliente que cancela? → R: Opción B
```

Lo que el usuario no sepa responder **no se inventa**: queda como
`[NEEDS CLARIFICATION: <pregunta concreta>]` en su sección.

### 6. Auditoría

Agotadas las preguntas, el spec pasa por **dos auditorías, en este orden**:

| | Agente | Pregunta que responde | Informe |
|---|---|---|---|
| 6a | `estratega` | ¿Debería existir cada feature, en este orden, con este alcance? | `progress/estrategia_$ARGUMENTS.md` |
| 6b | `analista` | ¿Se puede construir sin adivinar, y respeta la constitución? | `progress/audit_$ARGUMENTS.md` |

**El orden no es negociable, y la razón es económica:** no vale la pena auditar
la consistencia de una feature que se va a cortar. Si el `analista` corriera
primero, gastaría sus siete pasadas —y tu tiempo resolviendo sus hallazgos— en
historias que el `estratega` va a mandar a `docs/futuro/` diez minutos después.

#### 6a. El porqué

Lanza el subagente `estratega`:

> Audita `docs/specs/$ARGUMENTS.md`: si cada feature propuesta debería existir,
> en este orden y con este alcance. Escribe el informe en
> `progress/estrategia_$ARGUMENTS.md`. Respóndeme solo con la línea de veredicto.

Antes de seguir, **el usuario decide** sobre cada hallazgo **CRITICAL** y
**HIGH**: cortar, diferir, recortar, reordenar o mantener. Pregúntaselos uno a
uno, con la misma forma del paso 4 —recomendación y tabla de consecuencias.

Lo que se decide se **escribe en el spec antes de pasar a 6b**:

- **CORTAR** → la historia sale del spec; su alternativa va a `docs/futuro/`
  con la señal que la retomaría.
- **DIFERIR** → igual, pero se nombra en el spec como aplazada.
- **RECORTAR** → la historia se reescribe en su versión reducida.
- **REORDENAR** → cambia el orden de las historias, no su contenido.
- **MANTENER** → queda la línea en el spec:
  «se mantiene pese a \<hallazgo\> porque \<razón\>». Sin esa línea, la decisión
  se olvida y el hallazgo vuelve a aparecer en la siguiente auditoría.

#### 6b. El cómo

Con el spec ya recortado, lanza el subagente `analista`:

> Audita `docs/specs/$ARGUMENTS.md` contra la constitución. Escribe el informe
> en `progress/audit_$ARGUMENTS.md`. Respóndeme solo con la línea de veredicto.

Si vuelve con hallazgos **CRITICAL**, resuélvelos —preguntando si hace falta—
antes de seguir. No propongas features sobre un spec con CRITICAL abiertos.

### 7. Propuesta de features

Con el spec limpio, **propón** las entradas para `feature_list.json`. No las
escribas sin confirmación del usuario.

Cada feature propuesta lleva:

```json
{
  "id": 7,
  "name": "suscripciones_alta",
  "title": "Alta de suscripción con plan mensual",
  "description": "Una o dos frases. Si no cabe, la feature es demasiado grande.",
  "spec": "docs/specs/suscripciones.md",
  "acceptance": [
    "DADO un cliente sin plan CUANDO elige el plan mensual y paga ENTONCES queda activo y ve su fecha de renovación",
    "DADO un pago rechazado CUANDO se reintenta ENTONCES no se crean dos suscripciones",
    "Existe test/evidencia que cubre los criterios anteriores"
  ],
  "touches": ["src/suscripciones/"],
  "depends_on": [],
  "status": "pending"
}
```

Reglas de troceo:

- **El orden de las features es el que aprobó el `estratega`** en el paso 6a, no
  el orden en que están escritas en el spec. Si el usuario decidió otro, ese.
- Cada feature corresponde a **una historia de usuario** del spec (P1 antes que
  P2 antes que P3), no a una capa técnica. «El backend de suscripciones» no es
  una feature; «alta de suscripción de punta a punta» sí.
- `touches` lo más estrecho posible: es lo que permite el paralelismo. Dos
  features de la misma ola no pueden compartir ruta.
- `spec` es **obligatorio**: `init.sh` bloquea arrancar una feature sin él.
- La aceptación va en **DADO / CUANDO / ENTONCES** — observable, no una opinión.

### 8. Cierre

Reporta en cuatro líneas:

```
Spec: docs/specs/<modulo>.md (N requisitos, M pendientes de aclarar)
Estrategia: progress/estrategia_<modulo>.md — X CRITICAL, Y HIGH (N cortadas, N diferidas)
Auditoría: progress/audit_<modulo>.md — X CRITICAL, Y HIGH
Features propuestas: N (pendientes de tu confirmación para entrar al backlog)
```

Y recuerda: mientras el spec tenga `[NEEDS CLARIFICATION]` sin resolver,
`./init.sh` **no dejará arrancar** las features que lo referencien.

## Reglas duras

- ❌ Nunca hagas dos preguntas en el mismo mensaje.
- ❌ Nunca uses jerga sin definirla en la misma frase.
- ❌ Nunca escribas una feature en `feature_list.json` sin confirmación explícita.
- ❌ Nunca inventes una regla de negocio para «destrabar» el spec: eso es
  exactamente el producto-hecho-con-IA que este comando existe para evitar.
- ✅ Si el usuario responde «lo que recomiendes», acepta tu recomendación y
  regístrala como decisión suya en el log de clarificaciones.
