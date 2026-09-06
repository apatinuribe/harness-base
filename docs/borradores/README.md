# Borradores

Aquí van **tus notas antes de la entrevista**: la lógica, las features y los casos que escribiste por tu cuenta, en el formato que sea — prosa, viñetas, Given/When/Then en inglés, capturas de una conversación. No hay estructura obligatoria.

Se usan así: `/especificar <modulo> --desde docs/borradores/<modulo>.md`. El comando mapea lo que ya cubriste contra las secciones de `docs/specs/_plantilla.md` y te pregunta **solo por los huecos**, en vez de empezar en blanco.

**Aquí no van los specs ya generados**: esos viven en `docs/specs/`, los escribe `/especificar` y son la fuente de verdad. Un borrador es material de entrada, y una vez volcado al spec deja de mandar.

`init.sh` **no valida ni protege** esta carpeta: no revisa su formato, no bloquea features por lo que diga, y nada de aquí es citable como spec. Puedes borrar un borrador en cuanto su spec exista — la procedencia queda anotada en `## Clarificaciones`.
