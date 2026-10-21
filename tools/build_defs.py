#!/usr/bin/env python3
"""Compile the Reencor JSON (Assets/objects/SF3) into src/defs.lua.

The runtime plays these states. Frames, boxes, speeds and projectile
spawns are the JSON values, scaled like the sprite cells: Ryu's 640-tall
canvas becomes 150px. Y in the JSON points up; the Lua tables store that
same up-positive distance above the feet.
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CELL_H = 150
SCALE = CELL_H / 640

CHARACTERS = {
    "ryu": "Ryu.json",
    "ken": "Ken.json",
}


def first_dir(paths):
    for path in paths:
        if path.is_dir():
            return path
    return None


def scl(value):
    return round(float(value) * SCALE, 3)


def num(value):
    value = scl(value)
    if value == int(value):
        return str(int(value))
    return str(value)


def q(text):
    return '"' + str(text).replace("\\", "\\\\").replace('"', '\\"') + '"'


def box_literal(box):
    x, y, w, h = (num(box[0]), num(box[1]), num(box[2]), num(box[3]))
    return "{" + f"{x},{y},{w},{h}" + "}"


def list_literal(items, indent):
    if not items:
        return "{}"
    inner = (",\n" + indent + "  ").join(items)
    return "{\n" + indent + "  " + inner + ",\n" + indent + "}"


def height_of(hittype):
    kinds = hittype or []
    if "low" in kinds:
        return "low"
    if "high" in kinds:
        return "high"
    return "mid"


def bake_hit(baked, hit):
    damage = hit.get("damage") or [0]
    baked["dmg"] = (damage[0] if isinstance(damage, list) else damage) or 0
    if isinstance(damage, list) and len(damage) > 1 and damage[1]:
        baked["bdmg"] = damage[1]
    stun = hit.get("hitstun") or [0]
    baked["stun"] = stun[0] if isinstance(stun, list) else stun
    if isinstance(stun, list) and len(stun) > 1:
        baked["bstun"] = stun[1]
    knock = (hit.get("knockback") or {}).get("grounded") or [0]
    baked["kx"] = scl(knock[0])
    baked["push"] = scl(abs(knock[0]))
    if len(knock) > 1 and knock[1]:
        baked["ky"] = scl(knock[1])
    if hit.get("hitstop"):
        baked["stop"] = hit["hitstop"]
    if hit.get("juggle") is not None:
        baked["juggle"] = int(hit["juggle"])
    baked["h"] = height_of(hit.get("hittype"))
    kinds = list(hit.get("hittype") or [])
    if kinds:
        baked["tags"] = kinds
    if "uptummble" in kinds:
        baked["launch"] = True
    if "triptummble" in kinds:
        baked["sweep"] = True
    gain = hit.get("hit_bar_gain") or []
    if gain and isinstance(gain[0], list) and gain[0]:
        baked["gain"] = gain[0][0]
    if hit.get("cancel"):
        baked["hcancel"] = list(hit["cancel"])


def cell_of(size, offset):
    width, height = size[0], size[1]
    ox, oy = offset[0], offset[1]
    return {
        "w": max(1, round(width * SCALE)),
        "h": max(1, round(height * SCALE)),
        "ax": round((width - ox) * SCALE),
        "ay": round((height + oy) * SCALE),
    }


def bake_states(data):
    default_hurt = data["boxes"]["hurtbox"]["boxes"]
    states = {}
    landings = {}
    for name, state in data["states"].items():
        commands = state.get("command") or []
        for group in commands:
            for token in group:
                parts = [part.strip() for part in str(token).split(",")]
                if "landing" not in parts:
                    continue
                if parts == ["landing"]:
                    landings.setdefault("*", name)
                else:
                    index = parts.index("landing")
                    if index > 0:
                        landings.setdefault(parts[index - 1], name)
        hurt = list(default_hurt)
        hit = None
        con = None
        friction = 0.7
        frames = []
        for frame in state.get("framedata") or []:
            armed = "hitbox" in frame and bool((frame.get("hitbox") or {}).get("damage"))
            if "hurtbox" in frame:
                hurt = frame["hurtbox"].get("boxes") or []
            if "hitbox" in frame:
                hit = frame["hitbox"]
            if "con_speed" in frame:
                con = frame["con_speed"]
            if "boundingbox" in frame and "grounded_friction" in frame["boundingbox"]:
                friction = frame["boundingbox"]["grounded_friction"]
            image = frame.get("image") or ""
            image_id = image.split("/", 1)[1] if "/" in image else image
            baked = {
                "dur": frame["dur"] if isinstance(frame.get("dur"), int) and frame["dur"] > 0 else 1,
            }
            if image_id:
                baked["image"] = image_id
            if hurt:
                baked["hurt"] = hurt
            if hit and hit.get("boxes"):
                baked["hit"] = hit["boxes"]
                bake_hit(baked, hit)
            if armed:
                baked["arm"] = True
            take = frame.get("takebox") or {}
            if take.get("boxes"):
                baked["take"] = take["boxes"]
            if "pos_offset" in frame:
                baked["ox"] = scl(frame["pos_offset"][0])
                baked["oy"] = scl(frame["pos_offset"][1])
            if "add_speed" in frame:
                baked["avx"] = scl(frame["add_speed"][0])
                baked["avy"] = scl(frame["add_speed"][1])
            if "accel" in frame:
                baked["ax"] = scl(frame["accel"][0])
                baked["ay"] = scl(frame["accel"][1])
            box = frame.get("boundingbox") or {}
            if "airborne_friction" in box:
                baked["afx"] = box["airborne_friction"][0]
                baked["afy"] = box["airborne_friction"][1]
            elif "boundingbox" in frame:
                baked["afx"] = 1
                baked["afy"] = 1
            if "repeat_substate" in frame:
                rep = frame["repeat_substate"]
                baked["rep"] = [int(rep[0]), int(rep[1])]
            if con:
                baked["cvx"] = scl(con[0])
                baked["cvy"] = scl(con[1])
            baked["fric"] = friction
            if frame.get("cancel"):
                cancel = frame["cancel"]
                baked["cancel"] = [cancel] if isinstance(cancel, str) else list(cancel)
            if frame.get("trigg_state"):
                baked["go"] = frame["trigg_state"]
            spawn = None
            for created in frame.get("create_object") or []:
                if "Hadouken" in str(created[0]):
                    spawn = {
                        "state": created[3],
                        "x": scl(created[1][0]),
                        "y": scl(created[1][1]),
                    }
                    break
            if spawn:
                baked["spawn"] = spawn
            frames.append(baked)
        loop = commands in ([["5"]], [["6"]], [["4"]])
        hold = commands == [["1"]]
        states[name] = {
            "bar": state.get("bar_use") or 0,
            "air": state.get("state") == "airborne",
            "loop": loop,
            "hold": hold,
            "frames": frames,
        }
    return states, landings


def fresh_hit(hit, update=None):
    merged = dict(hit or {})
    if update:
        merged.update(update)
    boxes = merged.get("boxes")
    if boxes:
        merged["boxes"] = [list(box) for box in boxes]
    return merged


def bake_ball(data):
    states = {}
    for name, state in data["states"].items():
        speed = [0, 0]
        hit = None
        frames = []
        for frame in state.get("framedata") or []:
            if "speed" in frame:
                speed = frame["speed"]
            if "hitbox" in frame:
                hit = fresh_hit(frame["hitbox"])
            update = (frame.get("update_box") or {}).get("hitbox")
            if update:
                hit = fresh_hit(hit, update)
            image = frame.get("image") or ""
            image_id = image.split("/", 1)[1] if "/" in image else image
            baked = {
                "dur": frame["dur"] if isinstance(frame.get("dur"), int) and frame["dur"] > 0 else 1,
                "vx": scl(speed[0]),
            }
            if image_id:
                baked["image"] = image_id
            baked["vx"] = scl(speed[0])
            if "repeat_substate" in frame:
                rep = frame["repeat_substate"]
                baked["rep"] = [int(rep[0]), int(rep[1])]
            if hit and hit.get("boxes"):
                baked["hit"] = hit["boxes"]
                bake_hit(baked, hit)
            if not image_id and frames and frames[-1].get("image"):
                baked["image"] = frames[-1]["image"]
            frames.append(baked)
        states[name] = {"frames": frames}
    return states


def emit_boxes(boxes, indent):
    return list_literal([box_literal(box) for box in boxes], indent)


def emit_strings(values, indent):
    return list_literal([q(value) for value in values], indent)


def emit_frame(frame, indent):
    parts = [f"dur={frame['dur']}"]
    if frame.get("image"):
        parts.append(f"image={q(frame['image'])}")
    if frame.get("vx"):
        parts.append(f"vx={frame['vx']}")
    if frame.get("hurt"):
        parts.append("hurt=" + emit_boxes(frame["hurt"], indent))
    if frame.get("hit"):
        parts.append("hit=" + emit_boxes(frame["hit"], indent))
        for key in ("dmg", "stun", "stop", "gain"):
            if frame.get(key):
                parts.append(f"{key}={frame[key]}")
        if frame.get("push"):
            push = frame["push"]
            parts.append("push=" + (str(int(push)) if push == int(push) else str(push)))
        if frame.get("h"):
            parts.append(f"h={q(frame['h'])}")
        if frame.get("tags"):
            parts.append("tags=" + emit_strings(frame["tags"], indent))
        for key in ("kx", "ky", "bstun", "bdmg", "juggle"):
            if frame.get(key):
                value = frame[key]
                parts.append(f"{key}=" + (str(int(value)) if value == int(value) else str(value)))
        if frame.get("launch"):
            parts.append("launch=true")
        if frame.get("sweep"):
            parts.append("sweep=true")
        if frame.get("arm"):
            parts.append("arm=true")
    if frame.get("hcancel"):
        parts.append("hcancel=" + emit_strings(frame["hcancel"], indent))
    if frame.get("take"):
        parts.append("take=" + emit_boxes(frame["take"], indent))
    for key in ("ox", "oy", "avx", "avy", "cvx", "cvy"):
        if frame.get(key):
            value = frame[key]
            parts.append(f"{key}=" + (str(int(value)) if value == int(value) else str(value)))
    for key in ("ax", "ay", "afx", "afy"):
        if key in frame:
            value = frame[key]
            parts.append(f"{key}=" + (str(int(value)) if value == int(value) else str(value)))
    if frame.get("rep"):
        back, times = frame["rep"]
        parts.append(f"rep={{{back},{times}}}")
    if frame.get("fric") not in (None, 0.7):
        parts.append(f"fric={frame['fric']}")
    if frame.get("cancel"):
        parts.append("cancel=" + emit_strings(frame["cancel"], indent))
    if frame.get("go"):
        parts.append(f"go={q(frame['go'])}")
    if frame.get("spawn"):
        spawn = frame["spawn"]
        parts.append(
            "spawn={" + f"state={q(spawn['state'])},x={spawn['x']},y={spawn['y']}" + "}"
        )
    return "{ " + ", ".join(parts) + " }"


def emit_states(states, indent):
    chunks = []
    for name in states:
        state = states[name]
        frames = ",\n".join(indent + "    " + emit_frame(frame, indent + "    ") for frame in state["frames"])
        flags = []
        if state["bar"]:
            flags.append(f"bar={state['bar']}")
        if state["air"]:
            flags.append("air=true")
        if state["loop"]:
            flags.append("loop=true")
        if state["hold"]:
            flags.append("hold=true")
        flag = (", ".join(flags) + ", ") if flags else ""
        chunks.append(
            f"{indent}  [{q(name)}] = {{ {flag}frames = {{\n{frames},\n{indent}  }} }}"
        )
    return "{\n" + ",\n".join(chunks) + ",\n" + indent + "}"


def emit_ball(states):
    chunks = []
    for name, state in states.items():
        frames = ",\n".join("      " + emit_frame(frame, "      ") for frame in state["frames"])
        chunks.append(f"    [{q(name)}] = {{ frames = {{\n{frames},\n    }} }}")
    return "{\n" + ",\n".join(chunks) + ",\n  }"


def emit_character(style, data):
    folder = data.get("portrait", "02_Ryu/0").split("/", 1)[0]
    cell = cell_of(data["def_image_size"], data["def_image_offset"])
    states, landings = bake_states(data)
    hp = data["gauges"]["health"]["max"]
    meter = data["gauges"]["super"]["max"]
    gravity = num(-data["gravity"])
    land = ", ".join(f"[{q(key)}]={q(value)}" for key, value in landings.items())
    return (
        f"  {style} = {{\n"
        f"    folder = {q(folder)},\n"
        f"    hp = {hp},\n"
        f"    meter_max = {meter},\n"
        f"    gravity = {gravity},\n"
        f"    cell = {{ w = {cell['w']}, h = {cell['h']}, ax = {cell['ax']}, ay = {cell['ay']} }},\n"
        f"    land = {{ {land} }},\n"
        f"    states = {emit_states(states, '    ')},\n"
        f"  }}"
    )


def main():
    objects = first_dir([
        ROOT / "Assets" / "objects" / "SF3",
        ROOT.parent / "Reencor" / "Assets" / "objects" / "SF3",
    ])
    if objects is None:
        print("JSON ausente em Assets/objects/SF3.", file=sys.stderr)
        return 1
    parts = [
        "-- Gerado por tools/build_defs.py a partir de Assets/objects/SF3.",
        f"-- Escala {CELL_H}/640. Nao edite a mao.",
        "return {",
        f"  scale = {SCALE},",
    ]
    for style, filename in CHARACTERS.items():
        data = json.loads((objects / filename).read_text(encoding="utf-8"))
        parts.append(emit_character(style, data) + ",")
    ball = json.loads((objects / "Hadouken.json").read_text(encoding="utf-8"))
    parts.append("  ball = {")
    parts.append('    folder = "fireballs",')
    parts.append("    states = " + emit_ball(bake_ball(ball)) + ",")
    parts.append("  },")
    parts.append("}")
    parts.append("")
    dest = ROOT / "src" / "defs.lua"
    dest.write_text("\n".join(parts), encoding="utf-8")
    print(f"Definicoes em {dest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
