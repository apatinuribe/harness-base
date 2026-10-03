# Guion de entrevista de descubrimiento

> Lo usa `/descubrir`. Es para **hablar con un cliente antes de especificar
> nada**: 30-45 minutos, una persona, sin presentar el producto. Llévate las
> cinco preguntas, toma notas en la plantilla del final y pégalas después con
> `/descubrir <ruta>` (o el texto directamente). Si el usuario del producto
> eres tú, `/descubrir yo` hace la versión corta.
>
> `init.sh` no valida lo que escribes aquí: solo avisa (3g) cuando hay
> entrevistas que la síntesis todavía no incorpora.

## Antes de empezar

- Pregunta por **la última vez que** pasó algo, no por lo que «suele» pasar
  ni por lo que «querría». La gente describe bien lo que hizo ayer y mal lo
  que haría mañana.
- No presentes el producto ni pidas opinión sobre features. Si lo haces, el
  resto de la entrevista es educación, no descubrimiento.
- Cuando dé un número («me lleva dos horas», «se me pierden tres pedidos al
  mes»), apúntalo literal. Es la futura métrica.
- Nombres, emails y teléfonos no van a las notas: solo el rol y el canal
  («dueño de tienda, por llamada»).

## Las cinco preguntas

| # | Pregunta | Por qué se pregunta | Repreguntas |
|---|---|---|---|
| 1 | **¿Quién eres y qué intentas conseguir** cuando haces esto? | Define la persona: su rol, su contexto y el resultado que persigue —no la tarea | ¿Para quién lo haces? ¿Qué pasa si no lo haces? |
| 2 | **¿Qué hiciste la última vez**, paso a paso, de principio a fin? | Es el proceso actual: lo que el producto va a reemplazar. Sin esto, nadie podrá decir después si mejoró algo | ¿Con qué herramienta? ¿Quién más intervino? ¿Cuánto tardó cada paso? |
| 3 | **¿En qué paso se te va el tiempo, el dinero o los errores?** | La fricción concreta —con número si lo hay— es lo que justifica construir | ¿Cuánto? ¿Cada cuánto pasa? ¿Qué es lo peor que ha pasado por eso? |
| 4 | **¿Qué has probado ya** para arreglarlo, y por qué lo dejaste? | Lo que ya falló dice qué no construir y qué sí tiene que ser distinto | ¿Una hoja de cálculo, otra app, una persona? ¿Qué le faltaba? ¿Cuánto costaba? |
| 5 | **¿Cómo sabrías que está resuelto?** ¿Qué número cambiaría, y cuánto? | Es la métrica candidata: sin ella, «hecho» es una opinión | ¿Qué mirarías para comprobarlo? ¿En cuánto tiempo esperarías verlo? |

## Qué no hacer

- Preguntar «¿usarías algo que…?»: todo el mundo dice que sí.
- Proponer una solución a mitad de la entrevista.
- Rellenar en las notas lo que la persona no dijo. Lo que no se preguntó o no
  contestó va a «Sin responder».

## Plantilla de notas

Copia esto, rellénalo durante o justo después de la llamada, y pásalo a
`/descubrir`:

```markdown
# Entrevista — <rol> · YYYY-MM-DD

**Quién:** <rol y contexto, sin nombre> · **Canal:** <llamada | en persona | escrito> · **Entrevistó:** <alias>

## 1. Quién es y qué intenta conseguir

## 2. Qué hace hoy (paso a paso, la última vez que lo hizo)

## 3. Qué le cuesta (tiempo, dinero, errores — con el número si lo dio)

## 4. Qué ha probado (y por qué no le sirvió)

## 5. Cómo sabría que está resuelto (la señal o el número)

## Citas literales
- «…»

## Sin responder
- <pregunta del guion que no se llegó a hacer o no contestó>
```
