#!/usr/bin/env python3
"""Agrupa las features pendientes en olas seguras de ejecución paralela.

Regla: dos features pueden correr en worktrees paralelos si (a) sus dependencias
ya están done, (b) sus rutas en `touches` no se solapan, y (c) no compiten por
una ruta declarada como exclusive_paths en harness.config.json.

Las features `in_progress` se tratan como ocupadas: sus rutas quedan reservadas
y ninguna ola nueva puede tocarlas.
"""
import json
import os
from pathlib import PurePosixPath


def norm(p):
    """Normaliza una ruta a componentes comparables.

    Maneja separadores de Windows, './' inicial y '/' final, y compara por
    componente para que 'src/app' no colisione con 'src/apps'.
    """
    p = str(p).replace("\\", "/").strip()
    parts = [c for c in PurePosixPath(p).parts if c not in (".", "/", "")]
    return tuple(parts)


def collide(a, b):
    """True si dos rutas normalizadas se solapan (una contiene a la otra)."""
    n = min(len(a), len(b))
    return a[:n] == b[:n]


def any_collision(paths_a, paths_b):
    return any(collide(x, y) for x in paths_a for y in paths_b)


def touches_of(f):
    return [norm(t) for t in f.get("touches", [])]


def main():
    cfg = json.load(open("harness.config.json", encoding="utf-8"))
    feats = json.load(open("feature_list.json", encoding="utf-8"))["features"]
    exclusive = [norm(e) for e in cfg.get("exclusive_paths", [])]

    done = {f["id"] for f in feats if f["status"] == "done"}
    running = [f for f in feats if f["status"] == "in_progress"]
    pending = [f for f in feats if f["status"] == "pending"]

    reserved = [t for f in running for t in touches_of(f)]
    exclusive_taken = any(
        collide(t, e) for t in reserved for e in exclusive
    )

    if running:
        print("  Ocupado ahora mismo (in_progress):")
        for f in running:
            print("    #%-3s %-28s -> %s" % (f["id"], f["name"], ", ".join(f.get("touches", []))))

    if not pending:
        print("  (no hay features pending)")
        return

    ready, blocked = [], []
    for f in pending:
        if not all(d in done for d in f.get("depends_on", [])):
            blocked.append(f)
        elif any_collision(touches_of(f), reserved):
            blocked.append(f)
        else:
            ready.append(f)

    waves, remaining = [], list(ready)
    while remaining:
        wave, deferred = [], []
        used_exclusive = exclusive_taken if not waves else False
        for f in remaining:
            t = touches_of(f)
            wants_exclusive = any(collide(x, e) for x in t for e in exclusive)
            if wants_exclusive and used_exclusive:
                deferred.append(f)
                continue
            if any(any_collision(t, touches_of(g)) for g in wave):
                deferred.append(f)
                continue
            wave.append(f)
            if wants_exclusive:
                used_exclusive = True
        if not wave:
            waves.append(deferred[:1])
            remaining = deferred[1:]
            continue
        waves.append(wave)
        remaining = deferred

    for i, wave in enumerate(waves, 1):
        tag = " (secuencial)" if len(wave) == 1 else " (%d worktrees en paralelo)" % len(wave)
        print("  Ola %d%s:" % (i, tag))
        for f in wave:
            print("    #%-3s %-28s -> %s" % (f["id"], f["name"], ", ".join(f.get("touches", []))))

    if blocked:
        print("  Bloqueadas:")
        for f in blocked:
            pend = [d for d in f.get("depends_on", []) if d not in done]
            if pend:
                razon = "espera %s" % pend
            else:
                razon = "choca con una feature in_progress"
            print("    #%-3s %-28s %s" % (f["id"], f["name"], razon))


if __name__ == "__main__":
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    main()
