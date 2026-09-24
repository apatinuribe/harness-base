# Índice — qué es este producto hoy

> **Lo primero que lee un agente antes de trabajar.** Es un catálogo **por
> contenido**, no por fecha: responde «qué existe y dónde está», no «qué pasó».
> Para lo cronológico está `progress/history/`.
>
> Lo mantiene el subagente `bibliotecario` entre olas. Si lo editas a mano,
> deja la línea en su sitio: es la única forma de que siga siendo grepeable.

**Proyecto:** TODO
**Constitución vigente:** `docs/architecture.md` v0.0.0
**Último lint:** ninguno todavía

---

## Módulos

> Una línea por módulo. `spec` es la fuente de verdad; el estado sale de
> `feature_list.json`.

| Módulo | Spec | Qué resuelve | Features (done/total) |
|---|---|---|---|
| _(ninguno todavía — corre `/especificar <modulo>`)_ | | | |

## Entidades

> Los objetos que cruzan módulos. Cuando una entidad aparece en un segundo
> spec, esta tabla es lo que evita que se defina de dos formas distintas.

| Entidad | Definida en | La crea | Ciclo de vida | Retención |
|---|---|---|---|---|
| _(ninguna todavía)_ | | | |

## Decisiones cerradas

> Lo que ya no se rediscute. El detalle vive en la constitución §7; aquí solo
> el titular y dónde buscarlo.

| Decisión | Dónde | Desde |
|---|---|---|
| _(ninguna todavía — corre `/constitucion`)_ | | |

## Integraciones y terceros

| Servicio | Para qué | Qué pasa si se cae | Definido en |
|---|---|---|---|
| _(ninguno todavía)_ | | | |

---

## Cómo navegar este repo

| Quiero saber... | Voy a |
|---|---|
| Qué reglas aplican a todo el producto | `docs/architecture.md` |
| Qué hace un módulo y por qué | `docs/specs/<modulo>.md` |
| Qué se está construyendo ahora | `feature_list.json` + `progress/current_*.md` (uno por persona) |
| Qué pasó en una sesión concreta | `progress/history/` |
| Si el conocimiento está sano | el último `progress/lint_*.md` |
| Qué decidimos aplazar y por qué | `docs/futuro/` |
| Qué entidades, estados y permisos existen en total | `docs/esquema.md` |
| Cómo se ve el producto | `DESIGN.md` + `docs/diseno/<modulo>.md` |
| Qué dijeron los usuarios y qué se hizo con ello | `docs/feedback.md` |

## Orden de trabajo

`/configurar → /constitucion → /especificar → /esquema → despliegue_inicial → features (con /diseno por módulo) → /feedback`

| Comando | Cuándo | Produce |
|---|---|---|
| `/configurar` | Una vez al instanciar | `harness.config.json` + `docs/conventions.md` — qué comando verifica, qué rutas se protegen, qué está prohibido |
| `/constitucion` | Una vez por proyecto | `docs/architecture.md` — lo transversal: identidad, errores, datos, tiempo, entornos, terceros |
| `/especificar <modulo>` | Una vez por módulo | `docs/specs/<modulo>.md` — journey, entidades, reglas de negocio, estados, casos borde + las features propuestas |
| `/especificar <modulo> --desde <ruta>` | Igual, pero el usuario ya escribió el módulo a mano | Lo mismo, partiendo de `docs/borradores/<modulo>.md`: mapea lo cubierto y pregunta solo por los huecos |
| `/esquema` | Tras especificar, antes de la primera tabla; y cada vez que un spec nuevo añade entidades | `docs/esquema.md` (entidades, estados y permisos de todos los specs, con sus conflictos) + una migración borrador en `docs/esquema/migraciones/` + la feature `infra` que la aplica |
| `despliegue_inicial` | Primera feature de todo proyecto | El camino a producción funcionando; toda feature de usuario la lleva en `depends_on` |
| `/diseno <modulo>` | Por módulo con pantallas, antes de sus features | `DESIGN.md` en la raíz (una vez) + `docs/diseno/<modulo>.md`: un brief por pantalla para Claude Design |
| `/feedback` | Cuando llega lo que dicen los usuarios | `docs/feedback.md` + cada punto en su destino: `fix_<name>`, clarificación del spec, borrador o `docs/futuro/` |

Todos **corren en la sesión principal, no como subagente**: un subagente no
puede hacer preguntas al usuario. Cómo preguntan: `.claude/formato-preguntas.md`.
