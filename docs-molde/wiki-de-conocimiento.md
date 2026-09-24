# Aplazado — wiki de conocimiento compuesto

**Decidido:** 2026-08-25
**Estado:** parcialmente adoptado. El resto espera señal.
**Origen:** patrón *LLM Wiki* de Andrej Karpathy
(`gist.github.com/karpathy` — copia en `gist.github.com/apatinuribe/c661df5fb5e29134af33454de8776a49`)

> Este archivo existe para que, cuando el producto crezca, no haya que
> redescubrir esta decisión ni volver a razonarla desde cero. Dice **qué
> tomamos, qué dejamos fuera, con qué señal se activa cada pieza pendiente, y
> cómo implementarla.**

---

## 1. El patrón, en corto

En vez de RAG (redescubrir el conocimiento en cada consulta), un LLM
**construye y mantiene incrementalmente** una wiki de markdown interconectada.
El conocimiento **se compone**: cada exploración deja el repositorio mejor que
antes, en lugar de evaporarse al cerrar la sesión.

**Tres capas**

| Capa | Qué es | Nuestro equivalente |
|---|---|---|
| Fuentes crudas | Documentos originales, inmutables | *(no aplica — nuestras fuentes son las entrevistas, que ya se vuelven specs)* |
| La wiki | Markdown que el LLM posee y mantiene | `docs/specs/` + `docs/index.md` |
| El esquema | El archivo que convierte al LLM en bibliotecario disciplinado en vez de chatbot genérico | `AGENTS.md` + `CLAUDE.md` + la constitución |

**Tres operaciones**

| Operación | Qué hace | Nuestro equivalente |
|---|---|---|
| Ingest | Absorber una fuente nueva; puede tocar 10-15 páginas a la vez | `/especificar` |
| Query | Responder, y **archivar la respuesta** para que la próxima consulta parta de ahí | *(parcial — `progress/explore_*.md` no se archiva en la wiki)* |
| Lint | Chequeo de salud: contradicciones, afirmaciones caducas, páginas huérfanas, huecos | `bibliotecario` |

**Dos archivos especiales**

- `index.md` — catálogo **por contenido**. Se lee primero, luego se profundiza.
  Funciona sin embeddings hasta ~100 fuentes / cientos de páginas.
- `log.md` — cronológico, append-only, con prefijo parseable.

**Por qué funciona:** los humanos abandonan las wikis porque la carga de
mantenimiento crece más rápido que el valor. Un LLM no se aburre.

---

## 2. Qué adoptamos ya (2026-08-25)

| Pieza | Dónde quedó | Por qué ahora |
|---|---|---|
| `index.md` como catálogo por contenido | `docs/index.md` | Coste casi cero y cada sesión arranca sabiendo qué existe |
| La operación **Lint** | `.claude/agents/bibliotecario.md` | Es la única defensa contra que dos módulos se contradigan; corre entre olas, no por feature, así que no encarece el trabajo diario |
| Prefijo grepeable en la bitácora | `progress/history/` | Trivial, y hace la historia consultable con `grep` |
| La capa «esquema» | Ya existía sin querer: `AGENTS.md` | — |

**Criterio que usamos para cortar:** el arnés ya tenía 2 de las 3 capas. Tomamos
lo que cubría un hueco real (nadie cruzaba los specs entre sí) y dejamos fuera
todo lo que solo añadía ceremonia.

---

## 3. Qué dejamos fuera, y con qué señal se activa

### 3.1 Páginas de entidad compartida — `docs/dominio/<entidad>.md`

**Qué sería:** una página por entidad de negocio (`cliente.md`, `pedido.md`),
propiedad del LLM, con campos, ciclo de vida, dueño y retención. Los specs la
referencian en vez de redefinirla.

**Señal para activarlo:** cuando **un segundo módulo reutilice una entidad del
primero**. Antes de eso no hay nada que sintetizar y la tabla de entidades de
`docs/index.md` basta.

**Cómo implementarlo llegado el momento:**
1. Crear `docs/dominio/` y mover ahí la tabla de entidades de `docs/index.md`,
   una página por entidad.
2. En `docs/specs/_plantilla.md` §4.3, cambiar la tabla por: «Entidades propias
   (definidas aquí)» + «Entidades usadas (enlace a `docs/dominio/`)».
3. Añadir al `bibliotecario` una comprobación: entidad definida en dos sitios.
4. Añadir a `/especificar` el paso: antes de definir una entidad, buscar en
   `docs/dominio/`.

**Coste estimado:** 1 carpeta, 3 archivos tocados. Bajo. Lo caro es hacerlo
antes de tiempo, no después.

### 3.2 Query que se archiva

**Qué sería:** cuando un `explorer` responde algo que sirve más allá de su
feature, esa respuesta se convierte en una página de la wiki en vez de morir en
`progress/explore_*.md`.

**Señal:** cuando notemos que estamos preguntando lo mismo dos veces en olas
distintas, o cuando `progress/` pase de ~30 informes de exploración.

**Cómo:** dar al `explorer` un paso final — «si el hallazgo aplica más allá de
esta feature, propón su entrada en `docs/index.md`» — y que el `bibliotecario`
lo consolide en el lint.

### 3.3 Capa de fuentes crudas

**Qué sería:** `sources/` con documentos originales inmutables (contratos,
regulación, investigación de mercado, transcripciones de clientes).

**Señal:** cuando el producto dependa de documentos externos que haya que citar
con precisión — normativa, contratos con proveedores, entrevistas a usuarios.
Hoy nuestras fuentes son conversaciones y ya se destilan en specs.

**Cómo:** `sources/` con un archivo por fuente + cabecera (origen, fecha, quién
la trajo); `/especificar` la lee y cita `sources/<archivo>#<sección>`;
el `bibliotecario` verifica que ninguna cita apunte a una fuente borrada.

### 3.4 Búsqueda semántica (qmd, BM25, embeddings)

**Señal:** por encima de ~100 documentos en `docs/`, cuando `grep` + `index.md`
dejen de encontrar las cosas.

**Nota:** el propio Karpathy la marca como opcional. No la necesitamos hasta ser
un orden de magnitud más grandes.

### 3.5 Obsidian, graph view, Marp, Dataview

**Descartado, no aplazado.** Son herramientas de trabajo intelectual personal.
Nuestro contenido lo consumen agentes y dos socios; el markdown plano en git
cubre el caso. Reevaluar solo si entra al equipo alguien que trabaje la
documentación a mano a diario.

---

## 4. El riesgo que hay que vigilar

Vamos por tres sistemas apilados: **arnés** (ejecución) + **spec-driven**
(planeación) + **wiki** (conocimiento). Cada capa sube el costo fijo de cada
feature.

La defensa de Karpathy —«el LLM no se aburre»— es cierta para el trabajo de
escritura, pero **el trabajo que no se puede delegar es el de revisar**, y ese
sí se satura. Dos personas no técnicas revisando specs, auditorías y lints es el
cuello de botella real.

**Señal de alarma:** si en algún momento se está saltando el `/especificar` o
ignorando los informes del `bibliotecario` «para avanzar más rápido», la capa
sobra o está mal calibrada. Entonces se recorta, no se refuerza.

**Regla que nos dimos:** cada pieza nueva entra solo cuando el dolor que resuelve
ya es visible. Nada de andamiaje especulativo.
