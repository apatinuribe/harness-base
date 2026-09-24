# Formato de las entrevistas

Lo comparten `/configurar`, `/constitucion`, `/especificar`, `/esquema` y
`/diseno`. Cada comando fija **cuántas** preguntas puede hacer y **qué**
prioriza; **cómo** se pregunta es siempre esto.

## Reglas

- **Una pregunta por mensaje.** Nunca dos. Nunca reveles la cola de preguntas.
- **Prioriza por impacto × incertidumbre**: primero lo que, si se decide mal,
  obliga a rehacer trabajo ya construido.
- **No preguntes lo que puedes leer del repo.** Deduce primero; pregunta solo
  lo que quede abierto.
- **Traduce a resultado, nunca a herramienta.** Quien responde no es técnico:
  «¿cómo sabemos hoy que algo dejó de funcionar?» y no «¿qué test runner usas?».
- **Sin jerga sin definir** en la misma frase (`RLS`, `idempotente`, `webhook`,
  `SLA`).
- **Nunca rellenes una decisión con un valor por defecto en silencio.** Si
  recomiendas, se ve la recomendación; si el usuario no sabe, queda
  `[NEEDS CLARIFICATION: <la pregunta concreta>]` en la sección que corresponda.
- **«Lo que recomiendes»** = acepta tu recomendación y regístrala como decisión
  del usuario.
- **Escribe después de cada respuesta aceptada**, en el archivo que produce el
  comando, antes de hacer la siguiente pregunta. Si la sesión se corta, no se
  pierde nada.

## Cada pregunta

- Es una **interrogación completa que termina en `?`**. Nunca una etiqueta
  («Zona horaria:») ni un tema suelto.
- Va seguida de una línea **`Por qué importa:`** en lenguaje llano.
- Trae una **recomendación explícita** antes de las opciones:
  `**Recomendado:** Opción B — <razón en una línea>`
- Trae una **tabla de opciones** con la consecuencia real de cada una.
- Cierra con: `Responde con la letra, o descríbeme la tuya.`
- **Autocomprobación antes de enviarla:** ¿alguien que no es técnico y no ha
  leído este repo puede responderla solo con lo que hay en pantalla? Si no,
  reescríbela.

## Ejemplo

```markdown
**P3.** ¿Qué debe pasar cuando un usuario intenta abrir algo para lo que no tiene permiso?

Por qué importa: define si el producto se siente cerrado y seguro o confuso;
cambiarlo después toca todas las pantallas.

**Recomendado:** Opción B — no revela qué existe y no deja al usuario atascado.

| Opción | Qué ve el usuario | Consecuencia |
|---|---|---|
| A | Error 403 «no autorizado» | Claro, pero revela que ese recurso existe |
| B | Se le redirige a su inicio con un aviso | No filtra información; requiere una pantalla de inicio por rol |
| C | La opción ni siquiera aparece en el menú | Lo más limpio; obliga a que cada menú conozca los permisos |

Responde con la letra, o descríbeme la tuya.
```
