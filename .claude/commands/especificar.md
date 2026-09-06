---
description: Entrevista por módulo. Convierte "quiero un módulo de X" en un spec ejecutable en docs/specs/<modulo>.md y propone las features.
argument-hint: <nombre-del-modulo> [--desde <ruta-al-borrador>]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

# /especificar — Convertir una idea en un spec ejecutable

Argumentos recibidos: **$ARGUMENTS**

**Léelos así antes de nada:** el **primer token** es el nombre del módulo —lo
que abajo se escribe `<modulo>`, y lo que va en `docs/specs/<modulo>.md`—. Si
aparece `--desde`, lo que le sigue es la **ruta al borrador**. Nunca uses
`$ARGUMENTS` entero para construir una ruta: con `--desde` incluiría la bandera.

```
/especificar suscripciones                                    → modo entrevista
/especificar suscripciones --desde docs/borradores/subs.md    → modo borrador (§2b)
```

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

- Si `docs/specs/<modulo>.md` ya existe → modo continuación: léelo, identifica
  qué falta y qué `[NEEDS CLARIFICATION]` siguen abiertos. No empieces de cero.
- Si no existe → copia `docs/specs/_plantilla.md`, **borra el bloque de
  instrucciones de la cabecera** (el que empieza con «Plantilla usada por
  `/especificar`»: si se queda, `init.sh` leerá su mención del marcador de
  pendiente como un pendiente real) y rellena todo lo que ya puedas deducir de
  lo que el usuario dijo, del resto de `docs/specs/` y del código existente.

### 2b. Borrador (solo con `--desde <ruta>`)

Existe porque el caso más común no es «quiero un módulo de X»: es que el usuario
**ya escribió** la lógica, los casos y hasta las features, en sus propias notas.
Sin este modo, la entrevista le vuelve a preguntar lo que ya respondió — y la
gente contesta peor la segunda vez.

Si `$ARGUMENTS` **no** incluye `--desde`, sáltate esta sección entera.

**1. Comprueba la ruta.** Si no existe, **para** y responde:

```
blocked -> no existe <ruta>
```

**2. Mapea el borrador.** Lanza el subagente `explorer` con esta pregunta
acotada —una sola, y no le pidas que opine:

> Lee `<ruta>`. Mapea su contenido a las secciones 1-10 de
> `docs/specs/_plantilla.md`. Para cada sección responde: qué frases del borrador
> la cubren (cita literal), qué queda Parcial y qué Ausente. Convierte a
> DADO/CUANDO/ENTONCES cualquier caso o comportamiento que el borrador describa
> en prosa o en otra sintaxis (Given/When/Then, tablas, listas). Cierra con dos
> apartados aparte: **Features declaradas** —si el borrador enumera features,
> cítalas literalmente, una por línea; si no enumera ninguna, escribe que no
> hay— y **Sin sección clara**, para lo que no encaje en 1-10. Escribe el
> resultado en `progress/mapa_<modulo>.md`. Devuélveme solo la ruta.

Los dos apartados del final no son un extra: las features que el usuario ya
escribió **no tienen sección en la plantilla**, y sin recogerlas explícitamente
se pierden entre el mapa y el paso 7, que es justo donde hay que decir qué pasó
con cada una.

**3. Rellena el spec desde el mapa.** Lee `progress/mapa_<modulo>.md` y escribe
`docs/specs/<modulo>.md` con lo que el borrador ya cubre.

**Conserva la redacción del usuario** donde sea precisa: si su frase ya dice qué
pasa y cuándo, reescribirla solo introduce ruido y le obliga a releer para
comprobar que no cambiaste el sentido. Cada fragmento tomado del borrador cierra
con su procedencia:

```markdown
- RN-003: un pedido sin dirección no entra a la cola de reparto. (borrador §Reglas)
```

La marca `(borrador §<referencia>)` no es decorativa: es lo que permite, cuando
algo salga mal en producción, distinguir lo que decidió el usuario de lo que
dedujo la entrevista.

**4. El escaneo de cobertura arranca del mapa, no de cero.** En el paso 3, todo
lo que el mapa marca como Cubierto ya está resuelto: solo priorizas y preguntas
por lo **Parcial** y lo **Ausente**. Siguen siendo 5 preguntas como máximo, y
ahora se gastan donde hacen falta.

**5. Al cierre (paso 8)**, deja la procedencia registrada en `## Clarificaciones`
del spec:

```markdown
### Sesión 2026-09-06 — spec inicializado desde docs/borradores/<modulo>.md
(7 secciones cubiertas, 2 parciales, 1 ausente)
```

#### El borrador es fuente, no verdad

Lo que el usuario escribió antes de la entrevista es material de entrada, no una
decisión ya tomada. Dos consecuencias, y ninguna es negociable:

- **Si el borrador contradice la constitución, se pregunta.** No se copia, y
  tampoco se corrige por tu cuenta: se lleva al usuario como cualquier otra
  decisión, con su recomendación y su tabla de consecuencias (paso 4). La
  constitución no se enmienda desde un borrador.
- **Si el borrador declara features, son una propuesta.** Entran al paso 6a
  como candidatas y el `estratega` las audita igual que a las demás — puede
  cortarlas, fusionarlas o reordenarlas. Que el usuario ya las haya escrito
  en una lista no las convierte en backlog decidido.

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

**Después de CADA respuesta aceptada**, actualiza `docs/specs/<modulo>.md`
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
| 6a | `estratega` | ¿Debería existir cada feature, en este orden, con este alcance? | `progress/estrategia_<modulo>.md` |
| 6b | `analista` | ¿Se puede construir sin adivinar, y respeta la constitución? | `progress/audit_<modulo>.md` |

**El orden no es negociable, y la razón es económica:** no vale la pena auditar
la consistencia de una feature que se va a cortar. Si el `analista` corriera
primero, gastaría sus siete pasadas —y tu tiempo resolviendo sus hallazgos— en
historias que el `estratega` va a mandar a `docs/futuro/` diez minutos después.

#### 6a. El porqué

Lanza el subagente `estratega`:

> Audita `docs/specs/<modulo>.md`: si cada feature propuesta debería existir,
> en este orden y con este alcance. Escribe el informe en
> `progress/estrategia_<modulo>.md`. Respóndeme solo con la línea de veredicto.

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

> Audita `docs/specs/<modulo>.md` contra la constitución. Escribe el informe
> en `progress/audit_<modulo>.md`. Respóndeme solo con la línea de veredicto.

Si vuelve con hallazgos **CRITICAL**, resuélvelos —preguntando si hace falta—
antes de seguir. No propongas features sobre un spec con CRITICAL abiertos.

### 7. Propuesta de features

Con el spec limpio, **propón** las entradas para `feature_list.json`. No las
escribas sin confirmación del usuario.

**Si vino de un borrador con features declaradas**, la propuesta dice de dónde
sale cada una. El usuario tiene que poder ver qué pasó con su lista sin
compararla a mano:

| Feature | Origen | Qué pasó |
|---|---|---|
| `alta_suscripcion` | borrador | Se mantiene tal cual |
| `cobro_recurrente` | borrador | **Recortada**: sin reintentos, que el estratega mandó a `docs/futuro/` |
| `panel_admin_planes` | borrador | **Cortada** — H-002: nada visible cambia en 90 días |
| `exportar_datos` | borrador + `historial_pagos` | **Fusionadas**: la misma hipótesis y la misma señal |
| `aviso_de_vencimiento` | spec | Añadida: el caso borde §3 no lo cubría ninguna |

Una feature del borrador que se cae **siempre** cita el hallazgo del estratega
que la tumbó. «No la incluí» no es una respuesta: el usuario la escribió por una
razón y merece saber cuál la venció.

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

Si el spec vino de un borrador, escribe **primero** la línea de procedencia en
su sección `## Clarificaciones` (paso 2b.5). Es lo único que queda, meses
después, para saber que ese spec no salió de una entrevista en blanco.

Reporta en cuatro líneas —cinco si hubo borrador:

```
Borrador: docs/borradores/<modulo>.md (7 secciones cubiertas, 2 parciales, 1 ausente)
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
