# PROYECTO — <nombre del proyecto>

> **El OS del proyecto**: para qué existe, para quién y qué resultado persigue.
> Un spec dice *qué* construir; esto dice *por qué*. Lo rellena una persona:
> `/descubrir sintesis` ofrece rellenar «Problema» y «Usuario» con lo que
> dijeron las entrevistas, `/constitucion` ofrece hacerlo con lo que se dijo
> en la suya, y `/especificar` lo exige antes de proponer features si la
> constitución o el spec nombran un resultado clave.
>
> **Cuándo «declara KRs».** Cuando alguna línea que no es una cita (`>`) nombra
> un resultado clave con su número —`KR` seguido del número— fuera de
> backticks. Tal como llega, esta plantilla no declara ninguno: sus ejemplos
> están en citas. Desde el primero, toda feature en curso o cerrada lleva `kr`
> (`./init.sh` lo exige), el `estratega` señala las que no sirven a ninguno y
> el `implementer` mantiene la tabla «Trazabilidad».
>
> Al rellenar, sustituye cada `<…>` y borra los ejemplos.

## Problema

<Qué duele hoy, a quién, y cómo se resuelve ahora sin este producto. Dos o
tres frases: si no caben, el problema todavía no está claro.>

## Usuario

<Quién lo usa: su rol, su contexto y qué intenta conseguir. Si hay más de un
tipo de usuario, uno por línea, empezando por el primero al que se sirve. Si
corriste `/descubrir`, son las Personas de `docs/descubrimiento/_sintesis.md`.>

## Resultados clave

Cada resultado clave es un cambio **medible** con fecha, no una tarea. La
última columna lo ata al criterio de éxito (`CE-*`, §8 del spec) que lo mide:
sin él, nadie puede decir si se cumplió.

| KR | Resultado | Métrica | Meta y fecha | Criterio que lo mide (CE-*) |
|---|---|---|---|---|

> Ejemplo de fila:
> `| KR1 | Los pedidos entran sin llamar por teléfono | % de pedidos creados desde la app | 60 % a fin de trimestre | CE-001 · docs/specs/pedidos.md |`

## Trazabilidad

Una fila por feature: qué resultado mueve y en qué estado está. La mantiene el
`implementer` al cerrar cada feature (paso 7b de `.claude/agents/implementer.md`,
que fija los estados válidos). Nadie más la edita.

| KR | Actividad | Feature / spec | Estado | Evidencia |
|---|---|---|---|---|
