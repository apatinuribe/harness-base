#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Comprueba que cada feature cerrada pasó por una segunda persona.

Es el Nivel 1 del checkpoint C7. Sin esto, `require_peer_review` era una regla
escrita que nadie ejecutaba: el reviewer es un LLM, así que sin cruce humano la
aprobación es IA aprobando a IA.

La evidencia es la entrada de `progress/history/`, que ya existía por C2:

    **Owner:** arley
    **Revisión cruzada:** socio

Se da por válido también el atajo explícito, porque un socio de viaje no puede
bloquear el proyecto — pero queda escrito:

    **Revisión cruzada:** omitida — socio sin acceso hasta el lunes

Inerte si `require_peer_review` es false o el `team` tiene menos de 2 personas:
en solitario no hay segunda persona que cruzar.
"""
import glob
import io
import json
import os
import re
import sys

# Tolera el título sin tilde: la gente escribe las dos formas.
LINEA_CRUCE = re.compile(r"^\s*\*\*Revisi[óo]n cruzada:\*\*\s*(.*?)\s*$",
                         re.MULTILINE | re.IGNORECASE)
LINEA_OWNER = re.compile(r"^\s*\*\*Owner:\*\*\s*(.*?)\s*$",
                         re.MULTILINE | re.IGNORECASE)
# "## [2026-08-24] feature #3 | slug" — el prefijo fijo de progress/history.md
CABECERA = re.compile(r"^##\s*\[[^\]]*\]\s*feature\s*#(\d+)\s*\|", re.MULTILINE)


def leer(path):
    with io.open(path, encoding="utf-8") as fh:
        return fh.read()


def entradas_por_feature():
    """Mapea id de feature -> [(ruta, texto)] de sus entradas de historial."""
    mapa = {}
    for ruta in sorted(glob.glob(os.path.join("progress", "history", "*.md"))):
        try:
            texto = leer(ruta)
        except Exception:
            continue
        for fid in CABECERA.findall(texto):
            mapa.setdefault(int(fid), []).append((ruta, texto))
    return mapa


def valor(regex, texto):
    m = regex.search(texto)
    if not m:
        return None
    v = m.group(1).strip()
    # Los placeholders de la plantilla no cuentan como respuesta.
    if not v or v.startswith("_") or v.lower().startswith("alias de quien"):
        return None
    return v


def razon_de_omision(v):
    """Devuelve la razón si el cruce se omitió a propósito, o None."""
    if not v.lower().startswith("omitid"):
        return None
    # Todo lo que venga después del separador (— - : ·) es la razón.
    resto = re.sub(r"^omitid[ao]\s*[—\-:·]*\s*", "", v, flags=re.IGNORECASE)
    return resto.strip()


def main():
    # En modo aviso informa pero nunca bloquea: durante la feature el cruce
    # todavía no ha ocurrido, y un rojo permanente se acaba ignorando.
    aviso = "--aviso" in sys.argv
    try:
        cfg = json.loads(leer("harness.config.json"))
        feats = json.loads(leer("feature_list.json"))["features"]
    except Exception as e:
        print("[FAIL]  No pude leer la configuración del arnés: %s" % e)
        return 1

    team = [t for t in cfg.get("team", [])
            if t.get("id") and not str(t["id"]).startswith("TODO")]
    alias = set(t["id"] for t in team)

    inerte = not cfg.get("require_peer_review", False) or len(team) < 2
    if inerte:
        if aviso:
            return 0   # en solitario esta línea sería ruido en cada arranque
        motivo = ("require_peer_review está en false"
                  if not cfg.get("require_peer_review", False)
                  else "no hay un equipo de 2+ en 'team'")
        print("[OK]    Revisión cruzada no aplica: %s" % motivo)
        return 0

    historial = entradas_por_feature()
    errores = []
    avisos = []
    cerradas = [f for f in feats if f.get("status") == "done"]

    for f in cerradas:
        fid, nombre = f["id"], f.get("name", "")
        etiqueta = "Feature #%s (%s)" % (fid, nombre)
        entradas = historial.get(fid)
        if not entradas:
            errores.append("%s está done pero no tiene entrada en "
                           "progress/history/ — sin ella no hay nada que cruzar"
                           % etiqueta)
            continue

        # Basta con que UNA entrada de la feature acredite el cruce: una feature
        # reabierta y vuelta a cerrar deja varias, y la buena es cualquiera.
        acreditada = False
        motivos = []
        for ruta, texto in entradas:
            cruce = valor(LINEA_CRUCE, texto)
            if cruce is None:
                motivos.append("%s no tiene línea '**Revisión cruzada:**'" % ruta)
                continue

            razon = razon_de_omision(cruce)
            if razon is not None:
                if len(razon) < 4:
                    motivos.append("%s dice que se omitió el cruce pero no dice "
                                   "por qué" % ruta)
                    continue
                avisos.append("%s: cruce omitido a propósito — %s" % (etiqueta, razon))
                acreditada = True
                break

            if cruce not in alias:
                motivos.append("%s acredita a '%s', que no está en 'team' de "
                               "harness.config.json" % (ruta, cruce))
                continue

            dueno = f.get("owner") or valor(LINEA_OWNER, texto)
            if dueno and cruce == dueno:
                motivos.append("%s: '%s' se revisó a sí mismo — el cruce lo hace "
                               "otra persona" % (ruta, cruce))
                continue

            acreditada = True
            break

        if not acreditada:
            errores.append("%s se cerró sin revisión cruzada. %s"
                           % (etiqueta, motivos[0] if motivos else ""))

    for a in avisos:
        print("[WARN]  " + a)
    for e in errores:
        print(("[WARN]  " if aviso else "[FAIL]  ") + e)

    if errores:
        if aviso:
            print("        Todavía no bloquea; lo hará al empujar a main. "
                  "Detalle: ./init.sh --merge")
            return 0
        print("")
        print("        Arréglalo así: que la otra persona lea "
              "progress/review_<name>.md y")
        print("        la evidencia que cita, y ponga su alias en la línea "
              "'**Revisión cruzada:**'")
        print("        de la entrada de progress/history/. Si no puede ahora, "
              "escribe")
        print("        'omitida — <razón>'. Lo que no vale es dejarlo en blanco.")
        return 1

    if not aviso:
        print("[OK]    Revisión cruzada acreditada en las %d feature(s) cerradas"
              % len(cerradas))
    return 0


if __name__ == "__main__":
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    sys.exit(main())
