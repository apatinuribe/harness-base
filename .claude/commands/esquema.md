---
description: Consolida entidades, relaciones, estados y permisos de TODOS los specs en docs/esquema.md, detecta conflictos entre specs y propone la migración (inicial o incremental) para el stack declarado.
argument-hint: (sin argumentos)
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

# /esquema — El modelo de datos antes de la primera feature

Argumentos recibidos: **$ARGUMENTS** (este comando no usa ninguno)

Cada spec describe **sus** entidades, **sus** permisos y **su** ciclo de vida, y
cada uno tiene razón por separado. El problema aparece al juntarlos: el módulo
de pedidos dice que un `Cliente` tiene `email` obligatorio, el de reservas dice
que no, y la primera feature que cree la tabla decide por los dos — sin que
nadie lo haya decidido. La segunda feature descubre el conflicto con código ya
escrito y datos ya guardados.

Este comando junta §4.3, §4.6 y §5.1 de todos los specs en **un solo modelo**
antes de que exista la primera tabla, y convierte cada choque entre specs en una
pregunta visible en vez de en una migración correctiva.

**Se corre en la sesión principal, no como subagente**: puede necesitar
preguntarte por el stack, y los conflictos se deciden contigo.

## Dónde encaja

| Paso | Comando | Produce |
|---|---|---|
| 1 | `/configurar` | Cómo se verifica |
| 2 | `/constitucion` | Las reglas transversales — incluida quién es quién (§5.1) |
| 3 | `/especificar <modulo>` | Un spec por módulo, con sus entidades y permisos |
| **4** | **`/esquema`** ← estás aquí | `docs/esquema.md` + el borrador de migración |
| 5 | features | La primera de ellas aplica la migración |

Se vuelve a correr **cada vez que entra un spec nuevo** o cambia §4.3/§4.6/§5.1
de uno existente. La segunda vez no reescribe: propone solo la diferencia.

## Qué hace y qué no

| Hace | No hace |
|---|---|
| Consolida entidades, relaciones, estados y permisos de todos los specs | Inventar campos, relaciones o permisos que ningún spec declara |
| Señala conflictos entre specs como `[NEEDS CLARIFICATION]` | Resolverlos eligiendo una de las dos versiones |
| Escribe un **borrador** de migración en `docs/esquema/migraciones/` | Escribir en la ruta real de migraciones (es código: la aplica una feature) |
| Propone la feature de infraestructura que aplica la migración | Meterla en `feature_list.json` sin tu confirmación |

La migración real vive en una ruta protegida o exclusiva (`protected_paths`,
`exclusive_paths`), y quien la escribe tiene que demostrar que aplica y que los
permisos funcionan. Eso es una feature con su `implementer` y su `reviewer`, no
un efecto secundario de un comando de documentación.

## Protocolo

### 1. Requisitos previos

- **Constitución ratificada.** Si `docs/architecture.md` §5 o §8 tienen `TODO`,
  **detente**: sin §5.1 (identidad y roles) no hay contra qué validar los
  permisos de los specs. Propón `/constitucion`.
- **Al menos un spec.** Si `docs/specs/` solo tiene `_plantilla.md`,
  **detente** y propón `/especificar <modulo>`.

### 2. Detectar el stack

El modelo de datos es agnóstico; la migración no. Deduce el stack **sin
preguntar**, en este orden:

1. `docs/architecture.md` §7 (Decisiones cerradas) y §6.1 (Entornos).
2. `harness.config.json` → los comandos de `verify` y las rutas de
   `exclusive_paths` / `protected_paths` (ahí suele estar declarada la carpeta
   de migraciones).
3. El repo: `supabase/`, `prisma/schema.prisma`, `migrations/`, `alembic/`,
   `db/migrate/`, `drizzle.config.*`, `firestore.rules`...

| Señal | Formato del borrador | Dónde viven los permisos de §4.6 |
|---|---|---|
| Supabase / Postgres con RLS | `.sql`: tablas + `enable row level security` + una policy por fila de §4.6 | En la base: RLS |
| ORM con migraciones (Prisma, Drizzle, Alembic, Django, Rails...) | El formato de migración de ese ORM | En la capa que §5.1 declare (middleware, policies, guards): el borrador incluye su tabla de reglas |
| Base de documentos (Firestore, Mongo...) | Reglas de seguridad o validadores del motor + índices | En las reglas del motor, si las tiene; si no, en la capa de servidor |
| Sin persistencia (contenido, research) | — | **Detente**: este comando no aplica. Dilo y no escribas nada |

Si las señales se contradicen o no hay ninguna, haz **una** pregunta —con la
forma de siempre: `Por qué importa:`, recomendación, tabla de opciones— y sigue.

### 3. Extraer

De **cada** `docs/specs/<modulo>.md` (salvo `_plantilla.md`), extrae:

- **§4.3 Entidades y datos** — campos, obligatorios, relaciones, quién la crea.
- **§4.6 Permisos** — qué puede y qué no puede cada rol.
- **§5.1 Estados y transiciones** — estados de la entidad principal, qué los
  mueve, quién.

Con cinco specs o menos, léelos tú. Con más, lanza un `explorer` por spec, en
paralelo, con esta pregunta acotada:

> Lee `docs/specs/<modulo>.md`. Copia literalmente sus tablas de §4.3, §4.6 y
> §5.1, y lista cualquier `[NEEDS CLARIFICATION]` que haya dentro de ellas.
> Escribe el resultado en `progress/esquema_<modulo>.md`. Devuélveme solo la ruta.

Una sección con `[NEEDS CLARIFICATION]` propio **no se consolida**: la entidad
queda fuera del modelo, anotada como pendiente de su spec. Consolidar un campo
que el spec todavía no decidió es decidirlo aquí.

### 4. Consolidar y detectar conflictos

Une todo por **nombre de entidad**. Hay conflicto cuando dos specs dicen cosas
incompatibles sobre la misma entidad:

| Tipo | Ejemplo |
|---|---|
| Campo | `pedidos` dice `Cliente.email` obligatorio; `reservas` dice opcional |
| Relación | `pedidos`: un `Pedido` tiene un `Cliente`; `facturas`: puede tener varios |
| Estado | `pedidos` usa `cancelado`; `pagos` espera `anulado` para lo mismo |
| Permiso | `admin` puede borrar `Pedido` en un spec y en otro nadie puede |
| Propietario | Dos specs dicen que **su** módulo crea la entidad |
| Sinónimo | `Cliente` y `Comprador` con los mismos campos: ¿son la misma entidad? |
| Constitución | Un rol de §4.6 que no existe en §5.1 de la constitución |

Cada conflicto se escribe así, en la sección `## Conflictos` de
`docs/esquema.md`:

```markdown
- [NEEDS CLARIFICATION: ¿`Cliente.email` es obligatorio? `pedidos` §4.3 dice que
  sí (para enviar el recibo); `reservas` §4.3 dice que no (se reserva por
  teléfono). Se resuelve con /especificar en uno de los dos specs.]
```

**No elijas una versión.** Los dos specs tienen una razón, y la decisión
cambia lo que ve un usuario. La entidad en conflicto **queda fuera del
borrador de migración** hasta que se resuelva.

Y hay una consecuencia deliberada: la feature que aplica la migración declara
`docs/esquema.md` como `spec`, así que `./init.sh` **no la deja arrancar**
mientras quede un conflicto abierto aquí. Es intencional: una tabla creada con
`Cliente` a medio decidir obliga a una migración correctiva en cuanto se decida.

Un conflicto se resuelve **en el spec**, con `/especificar <modulo>`, nunca en
`docs/esquema.md`: el spec es la fuente de verdad y este archivo solo la refleja.
Así, la próxima vez que corra `/esquema` el conflicto ya no aparece.

### 5. Escribir `docs/esquema.md`

Si no existe, créalo con esta estructura. Si existe, **actualiza las secciones
en su sitio** —el archivo es una foto del modelo de hoy— y añade una entrada al
registro.

```markdown
# Esquema — el modelo de datos de hoy

**Stack:** <el detectado en el paso 2>
**Specs consolidados:** pedidos (2026-09-20), reservas (2026-09-22)
**Última migración propuesta:** 002_reservas

## Entidades

| Entidad | Campos (obligatorios en **negrita**) | La crea | Definida en |
|---|---|---|---|
| Cliente | **id**, **nombre**, email, telefono | pedidos | pedidos §4.3, reservas §4.3 |

## Relaciones

| Desde | Hacia | Cardinalidad | Si se borra el origen | Fuente |
|---|---|---|---|---|
| Pedido | Cliente | N:1 | se conserva el pedido (anonimizado, §5.3 constitución) | pedidos §4.3 |

## Estados

| Entidad | Estados | Transición | La dispara | Quién puede | Fuente |
|---|---|---|---|---|---|
| Pedido | borrador → pagado | pago confirmado | pasarela | sistema | pedidos §5.1 |

## Permisos

> Una fila por entidad y rol. Es la tabla de la que sale la política de acceso
> del borrador — cada regla del borrador cita su fila.

| Entidad | Rol | Leer | Crear | Editar | Borrar | Condición | Fuente |
|---|---|---|---|---|---|---|---|
| Pedido | cliente | sí | sí | no | no | solo los suyos | pedidos §4.6 |
| Pedido | admin | sí | no | sí | no | — | pedidos §4.6 |

## Conflictos

(vacío, o los [NEEDS CLARIFICATION] del paso 4)

## Pendientes de su spec

(entidades que no se consolidaron porque su spec tiene preguntas abiertas —
nombra el spec y la sección, sin copiar el marcador: el pendiente vive allí,
y copiarlo aquí bloquearía la migración por algo que no le corresponde)

## Migraciones

| # | Archivo | Specs que cubre | Feature que la aplica | Estado |
|---|---|---|---|---|
| 001 | docs/esquema/migraciones/001_inicial.sql | pedidos | F3 esquema_001 | aplicada |

## Registro

> Append-only.

### 2026-09-22
- Entra `reservas`. 1 entidad nueva, 1 conflicto (`Cliente.email`). Propuesta: 002_reservas.
```

Un permiso que ningún spec declara es **denegado**. No lo rellenes con lo
«razonable»: la ausencia se ve en la tabla y alguien la decide en el spec.

### 6. Borrador de migración

Escribe `docs/esquema/migraciones/<NNN>_<nombre>.<ext>` en el formato del
paso 2.

**Primera vez** (`docs/esquema.md` no existía): `001_inicial`, con todas las
entidades consolidadas sin conflicto.

**Veces siguientes**: compara el modelo nuevo con el que ya estaba en
`docs/esquema.md` y escribe **solo la diferencia** en `<NNN+1>_<nombre>`.
Una migración ya propuesta **no se edita nunca**: puede estar aplicada en
algún entorno, y reescribirla deja esos entornos mintiendo sobre su estado.

En el borrador:

- **Cada regla de acceso cita su fila de §4.6.** Ejemplo, si el stack es
  Supabase:

  ```sql
  -- pedidos §4.6: cliente | leer | solo los suyos
  create policy "cliente lee sus pedidos" on pedidos
    for select using (cliente_id = auth.uid());
  ```

  En otro stack, lo mismo en su forma: una regla, un comentario con su fuente.
  Sin la cita, el `reviewer` no puede comprobar que la política dice lo que
  decidió el spec.

- **Todo lo destructivo va marcado** —borrar una columna, cambiar un tipo,
  renombrar— con un comentario `DESTRUCTIVO:` y la referencia a §5.5 (Datos
  existentes) del spec que lo pide. Si ese spec no dice qué pasa con los datos
  ya guardados, es un `[NEEDS CLARIFICATION]` más, y el cambio destructivo no
  entra al borrador.

### 7. Proponer la feature que la aplica

Propón —**sin escribirla** hasta que confirmes— una feature de infraestructura:

```json
{
  "name": "esquema_002",
  "title": "Aplicar la migración 002_reservas",
  "spec": "docs/esquema.md",
  "infra": "No tiene cara al usuario: habilita F8 y F9, que son las que emiten evento.",
  "kr": "<el de la primera feature que desbloquea, si existe PROYECTO.md>",
  "acceptance": [
    "DADO una base en la migración 001 CUANDO se aplica 002 ENTONCES existen las tablas de reservas y la 001 sigue intacta",
    "DADO un cliente autenticado CUANDO intenta leer la reserva de otro cliente ENTONCES se le deniega (reservas §4.6)"
  ],
  "touches": ["<la ruta de migraciones del stack>"],
  "depends_on": [],
  "status": "pending"
}
```

- Un criterio de acceptance **por cada «No puede» de §4.6** que la migración
  haga cumplir. Es lo único que demuestra que la política de acceso hace lo que
  dice; que la migración aplique sin error no prueba nada sobre permisos.
- Las features que usan esas entidades pasan a declarar `depends_on` hacia esta.
  Dilo en la propuesta, feature por feature.
- Si la ruta de migraciones no está en `exclusive_paths`, recomiéndalo: dos
  worktrees escribiendo migraciones en paralelo se pisan el número.

### 8. Cierre

Reporta en cuatro líneas:

```
Esquema: docs/esquema.md (N entidades, M relaciones, K reglas de acceso)
Conflictos: X — se resuelven con /especificar en <specs>
Migración propuesta: docs/esquema/migraciones/002_reservas.sql (incremental: 1 tabla, 3 policies, 0 destructivos)
Feature propuesta: esquema_002 (pendiente de tu confirmación)
```

## Reglas duras

- ❌ Nunca resuelvas un conflicto entre specs eligiendo una versión: se señala,
  y se decide en el spec.
- ❌ Nunca inventes un permiso. Lo que ningún spec concede, está denegado.
- ❌ Nunca edites una migración ya propuesta: la siguiente va en un archivo nuevo.
- ❌ Nunca escribas en la ruta real de migraciones ni en `feature_list.json`
  desde este comando.
- ✅ Si un spec no dice algo que la migración necesita (un tipo, una
  cardinalidad), es un `[NEEDS CLARIFICATION]` en `docs/esquema.md` apuntando a
  ese spec, no una suposición en el SQL.
