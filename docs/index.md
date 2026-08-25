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
