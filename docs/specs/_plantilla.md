# Spec — <Nombre del módulo>

**Estado:** borrador | auditado | listo
**Constitución:** v<X.Y.Z> (la de `docs/architecture.md` cuando se escribió esto)
**Última actualización:** YYYY-MM-DD

> Plantilla usada por `/especificar`. No la edites a mano para un módulo:
> copia este archivo a `docs/specs/<modulo>.md` y **borra este bloque de
> instrucciones** — si se queda, el marcador de pendiente que menciona hace que
> `init.sh` considere el spec eternamente sin resolver.
>
> **Si ya escribiste el módulo por tu cuenta, no lo pegues aquí:** guárdalo en
> `docs/borradores/<modulo>.md` y corre
> `/especificar <modulo> --desde docs/borradores/<modulo>.md`. La entrevista
> mapea lo que ya cubriste y pregunta solo por los huecos.
>
> Todo lo que no se sepa se marca como pendiente: la etiqueta NEEDS
> CLARIFICATION entre corchetes, seguida de dos puntos y la pregunta concreta.
> **No se inventa.** Mientras quede uno sin resolver, `./init.sh` bloquea el
> arranque de las features que referencien este spec.

---

## 1. En una frase

Qué le permite hacer este módulo a quién, y por qué le importa al negocio.

## 2. Historias de usuario

> Ordenadas por prioridad. Cada una debe poder construirse y probarse **sola**:
> si P1 se entrega y P2 nunca llega, P1 sigue teniendo valor.

### H1 — <título> (P1)

**Como** <rol>, **quiero** <acción>, **para** <resultado que le importa>.

**Por qué es P1:** <qué se cae si esto no existe>

**Prueba independiente:** <cómo se comprueba esta historia sola, sin el resto>

**Criterios de aceptación**

1. **DADO** <situación de partida> **CUANDO** <acción> **ENTONCES** <resultado observable>
2. **DADO** ... **CUANDO** ... **ENTONCES** ...

### H2 — <título> (P2)

*(misma estructura)*

## 3. Casos borde

> Lo que rompe los productos en producción. Uno por línea, con la respuesta
> decidida — no con la pregunta abierta.

- ¿Qué pasa si <el dato no existe / el usuario no tiene permiso / el tercero no responde>? → <respuesta>
- ...

---

## 4. Vertical — el módulo de cara al usuario

### 4.1 Journey

Paso a paso: desde dónde entra el usuario, qué hace, con qué se va.
Incluye de dónde llega (¿un email? ¿el menú? ¿un enlace compartido?).

### 4.2 Pantallas y estados

| Pantalla | Vacío | Cargando | Con datos | Error | Sin permiso |
|---|---|---|---|---|---|
| | | | | | |

### 4.3 Entidades y datos

| Entidad | Campos clave | Obligatorios | Se relaciona con | Quién la crea |
|---|---|---|---|---|
| | | | | |

### 4.4 Reglas de negocio

> Lo que el código **no puede deducir solo**. Numeradas para poder citarlas.

- **RN-001:** El sistema DEBE <regla observable>.
- **RN-002:** El sistema NO DEBE <prohibición>.

### 4.5 Contratos

Qué operaciones expone este módulo al resto del sistema, qué recibe y qué
devuelve cada una — incluido qué devuelve cuando falla.

| Operación | Entrada | Salida | Falla con |
|---|---|---|---|
| | | | |

### 4.6 Permisos

| Rol | Puede | No puede |
|---|---|---|
| | | |

---

## 5. Temporal — qué pasa con el tiempo

### 5.1 Estados y transiciones

Ciclo de vida de la entidad principal: de qué estado a cuál, quién lo mueve y
qué lo dispara.

| Desde | Hasta | Lo dispara | Quién puede |
|---|---|---|---|
| | | | |

### 5.2 Repetición

Qué pasa si la misma acción llega dos veces (doble clic, reintento automático,
red caída a mitad). Por operación: ¿se ignora la segunda, se rechaza, o se
ejecuta otra vez?

### 5.3 Eventos

| Este módulo avisa | Cuándo | Quién escucha |
|---|---|---|
| | | |

| Este módulo reacciona a | Qué hace |
|---|---|

### 5.4 Programado

Qué corre solo, cada cuánto, y qué pasa si un día no corre.

### 5.5 Datos existentes

Qué pasa con lo que ya está guardado cuando esto entre en producción:
¿hay que migrar algo?, ¿conviven formatos viejo y nuevo?, ¿se puede revertir?

---

## 6. Transversal — desviaciones de la constitución

> Por defecto: **sigue `docs/architecture.md` §5 sin excepciones.**
> Aquí solo lo que este módulo hace distinto, y por qué. Una desviación sin
> razón escrita es un hallazgo CRITICAL en la auditoría.

| Política | Desviación | Razón |
|---|---|---|
| | | |

## 7. Alrededor del sistema — lo propio de este módulo

> Por defecto: **sigue `docs/architecture.md` §6.**
> Aquí solo: terceros nuevos, costos que este módulo introduce, quién lo opera,
> qué hace soporte cuando un cliente reclama por esto.

---

## 8. Criterios de éxito

> **Medibles y sin tecnología.** «La API responde en 200ms» no vale aquí;
> «el cliente completa el alta en menos de 2 minutos» sí. Si no se puede medir,
> no es un criterio de éxito: es un deseo.

- **CE-001:** <métrica observable con su número>
- **CE-002:** ...

## 9. Fuera de alcance

Lo que este módulo **no** hace, para que nadie lo asuma. Tan importante como
lo que sí hace.

## 10. Supuestos

Lo que se dio por cierto sin confirmar. Cada supuesto que se rompa es una
feature nueva, no un bug.

---

## Clarificaciones

> Log de `/especificar`. Append-only: nunca se reescribe una respuesta pasada;
> si se cambia de opinión, se añade una entrada nueva en la sesión de hoy.

### Sesión YYYY-MM-DD

- P: <pregunta> → R: <respuesta>
