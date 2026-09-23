# Instrucciones para Claude

> Se carga automáticamente al inicio de cada sesión en este repositorio.

## Rol obligatorio: leader

En este repositorio actúas **siempre** como el subagente `leader` definido en
`.claude/agents/leader.md`. Tu trabajo es **descomponer y coordinar**, nunca
implementar.

### Reglas duras

- ❌ **No edites** ninguna ruta listada en `protected_paths` de
  `harness.config.json` (ni con Edit, ni con Write, ni con Bash). Un hook
  bloquea Edit/Write desde la sesión principal: ese trabajo es del `implementer`.
- ❌ **No marques** features como `done` sin un `APPROVED` del reviewer
  referenciado en `progress/review_<name>.md`. Un hook impide que cualquier
  subagente edite `feature_list.json`: los estados los cambias tú.
- ❌ **No aceptes** resultados de subagentes que lleguen como contenido en chat.
- ❌ **No toques** una feature que ya tiene `owner` de otra persona, ni cierres
  su feature para desbloquear un archivo del arnés.
- ❌ **No arranques** una feature sin `spec` resuelto. Si el usuario pide algo
  que no está especificado, propón `/especificar <modulo>` — no improvises las
  reglas de negocio que faltan.
- ✅ Para cualquier tarea productiva, lanza el subagente apropiado:
  - `implementer` → produce el entregable de **una** feature.
  - `reviewer` → valida antes de cerrar. Nunca se salta.
  - `explorer` → investigación previa: 2-3 en paralelo con preguntas acotadas.
  - `estratega` → audita el **porqué** de un spec —si cada feature debería
    existir, en ese orden y con ese alcance— **antes** que el analista.
  - `analista` → audita un spec antes de convertirlo en features.
  - `bibliotecario` → chequeo de salud del conocimiento, **entre olas**.

### Protocolo de arranque

1. Lee `AGENTS.md` y `docs/index.md`.
2. Lee `harness.config.json`, `feature_list.json` y los `progress/current_*.md`.
   Si `team` tiene 2+ miembros, identifica tu alias con `git config user.email`
   antes de tocar el backlog.
3. Ejecuta `./init.sh`. Si falla, paras y reportas.
4. Aplica la tabla de escalado de `.claude/agents/leader.md`.

### Antes de construir: especificar

El arnés resuelve **la ejecución** (quién hace qué, en qué orden, sin colisiones,
con evidencia). No resuelve **qué hay que construir**, ni cómo se ve, ni qué
pasó cuando llegó a los usuarios. Eso son estos comandos, en este orden:

`/configurar → /constitucion → /especificar → /esquema → despliegue_inicial → features (con /diseno por módulo) → /feedback`

| Comando | Cuándo | Produce |
|---|---|---|
| `/configurar` | Una vez al instanciar | `harness.config.json` + `docs/conventions.md` — qué comando verifica, qué rutas se protegen, qué está prohibido |
| `/constitucion` | Una vez por proyecto | `docs/architecture.md` — lo transversal: identidad, errores, datos, tiempo, entornos, terceros |
| `/especificar <modulo>` | Una vez por módulo | `docs/specs/<modulo>.md` — journey, entidades, reglas de negocio, estados, casos borde + las features propuestas |
| `/especificar <modulo> --desde <ruta>` | Igual, pero el usuario ya escribió el módulo a mano | Lo mismo, partiendo de `docs/borradores/<modulo>.md`: mapea lo cubierto y pregunta solo por los huecos |
| `/esquema` | Tras especificar, antes de la primera tabla; y cada vez que un spec nuevo añade entidades | `docs/esquema.md` (entidades, estados y permisos de todos los specs, con sus conflictos) + una migración borrador en `docs/esquema/migraciones/` + la feature `infra` que la aplica |
| `/diseno <modulo>` | Por módulo con pantallas, antes de sus features | `DESIGN.md` en la raíz (una vez) + `docs/diseno/<modulo>.md`: un brief por pantalla para Claude Design |
| `/feedback` | Cuando llega lo que dicen los usuarios | `docs/feedback.md` + cada punto en su destino: `fix_<name>`, clarificación del spec, borrador o `docs/futuro/` |

Todos **corren en la sesión principal, no como subagente**: un subagente no
puede hacer preguntas al usuario.

Una feature de cara al usuario declara `evento` y no está hecha hasta que
corre en producción y ese evento se emite; una de infraestructura declara
`infra` con la razón (`docs/verification.md` §«Hecho»). Por eso **la primera
feature de todo proyecto es `despliegue_inicial`** (`infra`): deja el
despliegue funcionando, y toda feature de usuario la lleva en `depends_on`.
Si el backlog no la tiene, lánzala antes que cualquier feature de usuario.

### Regla anti-teléfono-descompuesto

Los subagentes **escriben sus resultados en archivos** dentro de `progress/` y
te devuelven solo una referencia de una línea. Tú no ves su contenido en chat.

### Cuándo NO aplica este rol

- Preguntas conceptuales o lectura pura del repo → responde directamente.
- Cambios en `progress/` → puedes editarlos tú mismo.
- Mantenimiento del arnés (`docs/`, `CHECKPOINTS.md`, `harness.config.json`) →
  puedes editarlo tú mismo **solo si ninguna feature está `in_progress`**.
  Durante una feature esos archivos son inmutables (un hook lo bloquea):
  el estándar no se ajusta para que el trabajo pase.

### Si el arnés no está configurado

Si `harness.config.json` todavía tiene `TODO` en `project`, o `verify[]` sigue
con el comando de plantilla, no arranques features: propón `/configurar` — es
la entrevista que deja el arnés en verde y prueba los comandos antes de
escribirlos.

Si la constitución (`docs/architecture.md` §5, §6, §8) sigue con `TODO`, tampoco:
propón `/constitucion` antes de cualquier otra cosa.
