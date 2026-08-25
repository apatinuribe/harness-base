# Constitución del proyecto

> **Qué es esto:** las decisiones que NO se rediscuten en cada feature, y el
> estándar contra el que el `reviewer` juzga el trabajo.
>
> Se rellena con `/constitucion`. Si está vacía o genérica, pasan dos cosas
> malas: el reviewer aprueba cualquier cosa, y cada módulo reinventa cómo se
> autentica, cómo falla y en qué zona horaria vive.
>
> **Autoridad:** §5 y §6 son no negociables. Un spec que las contradiga es un
> hallazgo CRITICAL automático en la auditoría. Se cambian enmendando esta
> constitución (§8), nunca desde un spec.

## 1. Qué produce este proyecto

TODO: una o dos frases. El entregable, no la actividad.

## 2. Estructura

TODO: qué carpetas existen, qué vive en cada una, qué NO debe vivir ahí.

| Ruta | Contiene | No contiene |
|------|----------|-------------|
| TODO | TODO     | TODO        |

## 3. Reglas de dependencia

TODO: qué puede importar/depender de qué, y en qué dirección.
Ejemplo (software): la capa de UI puede depender de dominio; dominio nunca de UI.
Ejemplo (contenido): el copy depende del brief; el brief nunca se ajusta al copy.

## 4. Rúbrica de calidad

> El reviewer puntúa 1-5 cada criterio. **Cualquier criterio < 3 bloquea el cierre.**
> Escribe qué significa un 1 y qué significa un 5, o los puntajes serán ruido.

| Criterio | 1 = | 5 = |
|----------|-----|-----|
| TODO     | TODO | TODO |
| TODO     | TODO | TODO |
| TODO     | TODO | TODO |

---

## 5. Políticas transversales

> Atraviesan **todos** los módulos. Si la respuesta cambia módulo a módulo, no
> va aquí: va en el spec del módulo, como desviación con su razón.

### 5.1 Identidad y permisos

TODO: quién entra y cómo. Qué roles existen. Qué puede hacer cada uno.
Qué ve un usuario que intenta algo para lo que no tiene permiso.

### 5.2 Errores y validación

TODO: dónde se valida (cliente, servidor, ambos). Qué ve el usuario cuando algo
falla. Qué se reintenta solo y qué no. Qué nunca se le muestra al usuario.

### 5.3 Datos y privacidad

TODO: qué dato se considera sensible. Quién puede verlo. Cuánto tiempo se
guarda cada tipo de dato. Cómo se borra una cuenta y qué queda después.

### 5.4 Observabilidad

TODO: qué se registra y qué no (nunca datos sensibles en logs). Qué métricas
importan. Cómo se entera una persona de que algo se rompió, y quién es.

### 5.5 Tiempo, moneda e idioma

TODO: zona horaria de referencia y cómo se guardan las fechas. Formato de fecha
que ve el usuario. Monedas soportadas y cómo se guardan los importes. Idiomas.

### 5.6 Rendimiento y límites

TODO: cuánto puede tardar una operación antes de considerarse rota. Cuántos
usuarios y cuánto volumen se esperan en 12 meses. Qué se limita por usuario.

## 6. Alrededor del sistema

> Lo que rodea al producto y no es código. Se olvida siempre, y siempre duele.

### 6.1 Entornos y despliegue

TODO: qué entornos existen. Cómo llega algo a producción. Cómo se revierte.

### 6.2 Terceros y costos

TODO: de qué servicios externos depende el producto. Qué pasa si uno se cae.
Qué cuestan y a partir de qué volumen dejan de ser viables.

### 6.3 Soporte y operación

TODO: quién opera esto a diario. Qué hace cuando un cliente reclama. Qué puede
tocar soporte sin un desarrollador y qué no.

### 6.4 Copias de seguridad

TODO: qué se respalda, cada cuánto, y cómo se comprueba que el respaldo sirve.

---

## 7. Decisiones cerradas

> Decisiones ya tomadas que NO se rediscuten en cada feature (stack, formato de
> datos, tono, naming). Cada una con una línea de porqué.

| Decisión | Por qué | Desde |
|---|---|---|
| TODO | TODO | TODO |

## 8. Gobernanza

**Versión:** 0.0.0 · **Ratificada:** TODO · **Última enmienda:** TODO

Cómo cambia esta constitución:

- **MAJOR** — se elimina o se redefine una política de forma incompatible.
  Obliga a revisar todos los specs existentes.
- **MINOR** — se añade una política o una sección nueva.
- **PATCH** — redacción, ejemplos, correcciones sin cambio de fondo.

Toda enmienda: se sube la versión, se actualiza `Última enmienda`, y se corre el
subagente `bibliotecario` para detectar qué specs quedaron desalineados.

### Bitácora

> Log de `/constitucion`. Append-only.

#### Sesión YYYY-MM-DD

- P: <pregunta> → R: <respuesta>
