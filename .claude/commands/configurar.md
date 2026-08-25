---
description: Configura la mecánica del arnés. Detecta el stack, prueba los comandos de verificación y escribe harness.config.json y docs/conventions.md.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# /configurar — Poner el arnés en verde

Se corre **una vez al instanciar el arnés** en un proyecto, y luego solo cuando
cambie la forma de verificar.

Resuelve la parte mecánica: **qué comando demuestra que algo funciona**, qué
rutas se protegen y qué convenciones hace cumplir el reviewer. Es lo que hace
que `./init.sh` pase de rojo a verde.

## Las tres piezas del arranque

| Comando | Resuelve | Produce |
|---|---|---|
| **`/configurar`** ← estás aquí | Cómo se verifica | `harness.config.json`, `docs/conventions.md`, `docs/verification.md` §Nivel 1 |
| `/constitucion` | Qué reglas rigen el producto | `docs/architecture.md` |
| `/especificar <modulo>` | Qué se construye | `docs/specs/<modulo>.md` + features |

Corre este **primero**: sin verificación determinista, la rúbrica del reviewer
es un LLM aprobando a otro LLM.

## Protocolo

### 1. Detectar antes de preguntar

**No preguntes lo que puedes averiguar.** Inspecciona el repo y deduce todo lo
posible:

```bash
ls -a                     # estructura general
cat package.json 2>/dev/null | head -40
cat pyproject.toml requirements.txt Cargo.toml go.mod composer.json 2>/dev/null
ls .github/workflows/ Makefile justfile 2>/dev/null
```

De ahí sale casi todo:

| Señal | Qué deduces |
|---|---|
| `package.json` → `scripts.test`, `scripts.build`, `scripts.lint` | Comandos de verificación candidatos |
| `tsconfig.json` | Hay typecheck: `npx tsc --noEmit` |
| `pyproject.toml` / `pytest.ini` | `pytest` |
| `.github/workflows/*.yml` | **La mejor fuente**: lo que ya se ejecuta en CI es exactamente lo que debe verificar el arnés |
| Carpetas `src/`, `tests/`, `supabase/migrations/` | `protected_paths` y `exclusive_paths` |
| No hay código: `.md`, `.csv`, activos | Dominio contenido o research — ver §4 |

Si el repo está vacío (proyecto nuevo), dilo y pasa directo a las preguntas.

### 2. Probar antes de escribir

**Regla dura: no escribas en `verify[]` ningún comando que no hayas ejecutado.**
Un comando que no corre es peor que ninguno — pinta verde algo que nunca se
comprobó, o deja el arnés rojo para siempre por un error de tipeo.

Por cada comando candidato:

```bash
<comando>; echo "exit=$?"
```

Y clasifícalo con lo que viste:

- **exit 0** → va como `"required": true`.
- **exit ≠ 0 porque no hay tests todavía** → va como `"required": false` con una
  nota, y se lo dices al usuario: el arnés no tiene dientes hasta que existan.
- **exit ≠ 0 porque el proyecto está roto ahora mismo** → va como `required: true`
  igualmente. El arnés debe arrancar en rojo por la razón correcta.
- **El comando no existe / falta una dependencia** → **no lo escribas**. Repórtalo.

### 3. Preguntas

**Máximo 4 preguntas. Una a la vez. Solo lo que no pudiste deducir.**

Mismas reglas que el resto de comandos del arnés: interrogación completa que
termina en `?`, línea `Por qué importa:` en lenguaje llano, recomendación
explícita con su razón, tabla de opciones con consecuencias, y cierre con
`Responde con la letra, o descríbeme la tuya.`

**Traduce siempre a resultado, nunca a herramienta.** Quien responde no es
técnico:

- ❌ «¿Qué test runner usas?»
- ✅ «¿Cómo sabemos hoy que algo dejó de funcionar antes de que lo vea un cliente?»

Ejemplo:

```markdown
**P1.** Cuando alguien cambia el código, ¿qué comprobación tiene que pasar sí o sí antes de darlo por bueno?

Por qué importa: es lo único que el arnés puede verificar solo, sin opinión de
por medio. Si no hay ninguna, el revisor solo puede dar su parecer — y un
parecer no detecta que algo se rompió.

**Recomendado:** Opción A — ya tienes `npm test` configurado y pasa en 4 segundos.

| Opción | Qué comprueba | Consecuencia |
|---|---|---|
| A | `npm test` (los tests que ya existen) | El arnés detecta regresiones desde hoy |
| B | Solo que el proyecto compile (`npm run build`) | Más débil: compila pero puede estar roto |
| C | Todavía nada — lo añadimos más adelante | El arnés queda sin dientes; el reviewer aprueba a ojo |

Responde con la letra, o descríbeme la tuya.
```

Las cuatro preguntas, si hicieran falta todas:

1. **Verificación** — qué comprobación es obligatoria (§2).
2. **Nombre y una línea** — para `project` y `description`.
3. **Rutas intocables** — qué carpetas no debe tocar un agente por su cuenta
   (`protected_paths`), y cuáles solo puede tocar una feature a la vez
   (`exclusive_paths`: migraciones, esquema de base de datos, tipos compartidos).
4. **Prohibiciones** — qué causa rechazo automático. Si ya existe la
   constitución, **deriva la lista de ahí** y solo pide confirmación.

### 4. Si no es software

El arnés es agnóstico. Si el dominio es contenido, research o campañas, la
verificación determinista sigue existiendo — solo cambia de forma. Propón un
script mínimo en `scripts/` y **escríbelo tú**:

| Dominio | Comprobación determinista realista |
|---|---|
| Contenido | El paquete tiene los N archivos requeridos · `meta.json` valida contra esquema · ninguna afirmación de la lista de prohibidas aparece |
| Research | Toda cifra tiene fuente con URL y fecha · existe el bloque de contradicciones · ningún hallazgo sin sección de metodología |
| Campañas | Cada pieza declara ángulo, avatar y formato · los activos existen en las medidas pedidas |

Escribe el script, **pruébalo**, y solo entonces lo pones en `verify[]`.

### 5. Escritura

Escribe en este orden, y **después de cada archivo** informa en una línea de qué
cambió:

**`harness.config.json`** — `project`, `description`, `domain`, `verify[]` (solo
comandos probados), `protected_paths`, `exclusive_paths`. No toques
`required_files` salvo que el usuario añada documentos propios.

**`docs/conventions.md`** — resuelve los TODO con reglas **comprobables**. Si una
convención no se puede verificar leyendo el entregable, no es una convención: es
una opinión, y no entra. La «Lista de prohibidos» es la sección que más usa el
reviewer — que sea concreta («credenciales en el código», «`console.log` en
producción», «dependencias nuevas sin aprobar»), no genérica.

**`docs/verification.md`** — reemplaza el TODO del Nivel 1 por los comandos
reales que quedaron en `verify[]`, con una línea de qué demuestra cada uno.

### 6. Comprobación final

```bash
./init.sh
```

Reporta el resultado tal cual, sin maquillar:

- **Verde** → el arnés está listo. Siguiente paso: `/constitucion`.
- **Rojo por `verify`** → correcto si el proyecto está roto de verdad; dilo
  claramente y di qué hay que arreglar.
- **Rojo por TODOs en `docs/architecture.md`** → esperado, lo resuelve
  `/constitucion`. Acláralo para que no parezca un fallo tuyo.

Cierra con tres líneas:

```
Verificación: N comandos, M obligatorios (todos probados)
Convenciones: docs/conventions.md sin TODOs
Siguiente: /constitucion
```

## Reglas duras

- ❌ **Nunca escribas un comando en `verify[]` sin haberlo ejecutado.** Es la
  regla central de este comando.
- ❌ Nunca pongas `"required": true` en algo que sabes que no puede pasar nunca
  (un test que no existe). El arnés en rojo permanente se acaba ignorando, y ahí
  se pierde entero.
- ❌ Nunca preguntes lo que puedes leer del repo.
- ❌ Nunca uses jerga sin definirla en la misma frase.
- ⚠️ Este comando edita `harness.config.json`, que el guard bloquea si hay una
  feature `in_progress`. Si te bloquea, es correcto: cierra la feature antes.
- ✅ Si no hay ninguna verificación determinista posible hoy, **dilo con todas
  las letras** en vez de inventar una: «el arnés queda sin Nivel 1, así que el
  reviewer solo puede juzgar por rúbrica — es el punto débil a cerrar pronto».
