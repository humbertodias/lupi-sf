#!/usr/bin/env python3
"""Turn the Reencor sprite packs into Lupi frames.

Reencor stretches every character frame onto one cell (def_image_size) and
pins that cell with def_image_offset. Both cells are drawn in the same world
units, so Ryu's 640-tall canvas and Ken's 857-tall canvas share one scale.
Fitting each canvas to the same pixel height would shrink Ken. Fireballs and
sparks are cropped to the opaque pixels.
"""

import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CELL_H = 150
# Mesma escala da celula do Ryu. O Reencor estica o PNG 640x480 do
# hadouken ate def_image_size 1856x1728, o mesmo canvas da explosao.
SCALE = CELL_H / 640
FIRE_SX = (1856 / 640) * SCALE
FIRE_SY = (1728 / 480) * SCALE
SPARK_H = 44
COLORS = 96

CLIPS = {
    "stand": "Stand",
    "walk_f": "Walk Forward",
    "walk_b": "Walk Backward",
    "crouch": "Crouch",
    "jump_n": "Neutral Jump",
    "jump_f": "Front Jump",
    "jump_b": "Back Jump",
    "jab": "Stand Jab",
    "strong": "Stand Strong",
    "fierce": "Stand Fierce",
    "short": "Stand Short",
    "forward": "Stand Forward",
    "roundhouse": "Stand Roundhouse",
    "c_jab": "Crouch Jab",
    "c_strong": "Crouch Strong",
    "c_fierce": "Crouch Fierce",
    "c_short": "Crouch Short",
    "c_forward": "Crouch Forward",
    "c_roundhouse": "Crouch Roundhouse",
    "hadou": "Hadouken Jab",
    "dp": "Shoryuken Jab",
    "tatsu": "Tatsumaki Short",
    "air_jab": "Aerial Jab",
    "air_short": "Aerial Short",
    "block": "Stand Block",
    "c_block": "Crouch Block",
    "hit": "Middle Light Hit",
    "down": "Side Tummble Hit",
    "win": "Victory",
    "land": "Neutral Landing",
}

CHARACTERS = {
    "ryu": "Ryu.json",
    "ken": "Ken.json",
}


def first_dir(paths):
    for path in paths:
        if path.is_dir():
            return path
    return None


def run(args):
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL)


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def frames_of(state):
    out = []
    for frame in state.get("framedata") or []:
        image = frame.get("image")
        if not image:
            continue
        dur = frame.get("dur")
        out.append((image, 1 if not isinstance(dur, int) or dur < 1 else dur))
    return out


def find_png(images, key):
    folder, name = key.split("/", 1)
    direct = images / folder / f"{name}.png"
    if direct.is_file():
        return direct
    matches = list(images.glob(f"*/{folder}/{name}.png"))
    return matches[0] if matches else None


def cell_box(size, offset, scale):
    width, height = size[0], size[1]
    ox, oy = offset[0], offset[1]
    return (
        max(1, round(width * scale)),
        max(1, round(height * scale)),
        round((width - ox) * scale),
        round((height + oy) * scale),
    )


def resize_cell(src, dst, w, h):
    dst.parent.mkdir(parents=True, exist_ok=True)
    run([
        "magick", str(src),
        "-filter", "point", "-resize", f"{w}x{h}!",
        "-channel", "A", "-threshold", "50%", "+channel",
        str(dst),
    ])


def resize_trim_scale(src, dst, scale):
    dst.parent.mkdir(parents=True, exist_ok=True)
    run([
        "magick", str(src),
        "-channel", "A", "-threshold", "50%", "+channel",
        "-trim", "+repage",
        "-filter", "point", "-resize", f"{scale * 100:.4f}%",
        str(dst),
    ])


def resize_trim(src, dst, height):
    dst.parent.mkdir(parents=True, exist_ok=True)
    run([
        "magick", str(src),
        "-channel", "A", "-threshold", "50%", "+channel",
        "-trim", "+repage",
        "-filter", "point", "-resize", f"x{height}",
        str(dst),
    ])


def trim_box(src):
    geo = subprocess.check_output([
        "magick", str(src),
        "-channel", "A", "-threshold", "50%", "+channel",
        "-trim", "-format", "%wx%h%X%Y", "info:",
    ], text=True).strip()
    size, xs, ys = geo.split("+")
    w, h = size.split("x")
    return int(xs), int(ys), int(w), int(h)


def union_trim(paths):
    left, top = 10**9, 10**9
    right, bottom = 0, 0
    for src in paths:
        x, y, w, h = trim_box(src)
        left = min(left, x)
        top = min(top, y)
        right = max(right, x + w)
        bottom = max(bottom, y + h)
    return left, top, max(1, right - left), max(1, bottom - top)


def resize_fire(src, dst, box, sx, sy):
    dst.parent.mkdir(parents=True, exist_ok=True)
    x, y, w, h = box
    out_w = max(1, round(w * sx))
    out_h = max(1, round(h * sy))
    run([
        "magick", str(src),
        "-channel", "A", "-threshold", "50%", "+channel",
        "-crop", f"{w}x{h}+{x}+{y}", "+repage",
        "-filter", "point", "-resize", f"{out_w}x{out_h}!",
        str(dst),
    ])


def resize_grid(src, dst, size):
    dst.parent.mkdir(parents=True, exist_ok=True)
    run([
        "magick", str(src),
        "-filter", "point", "-resize", f"{size}x{size}!",
        "-fill", "#181820", "-opaque", "black",
        str(dst),
    ])


def resize_icon(src, dst, size):
    dst.parent.mkdir(parents=True, exist_ok=True)
    run([
        "magick", str(src),
        "-channel", "A", "-threshold", "50%", "+channel",
        "-filter", "Lanczos", "-resize", f"{size}x{size}",
        "-background", "none", "-gravity", "center", "-extent", f"{size}x{size}",
        str(dst),
    ])


def remap_one(src, dst, palette):
    dst.parent.mkdir(parents=True, exist_ok=True)
    mask = src.with_suffix(".mask.png")
    flat = src.with_suffix(".flat.png")
    run(["magick", str(src), "-alpha", "extract", str(mask)])
    run(["magick", str(src), "-alpha", "off", "-dither", "None", "-remap", str(palette), str(flat)])
    run([
        "magick", str(flat), str(mask),
        "-alpha", "off", "-compose", "CopyOpacity", "-composite",
        f"PNG32:{dst}",
    ])
    mask.unlink(missing_ok=True)
    flat.unlink(missing_ok=True)


def lua_clips(clips):
    lines = []
    for name, frames in clips.items():
        body = ", ".join(f'{{"{image}", {dur}}}' for image, dur in frames)
        lines.append(f"    {name} = {{ {body} }},")
    return "\n".join(lines)


def main():
    objects = first_dir([
        ROOT / "Assets" / "objects" / "SF3",
        ROOT.parent / "Reencor" / "Assets" / "objects" / "SF3",
    ])
    images = first_dir([
        ROOT / "Assets" / "images",
        ROOT.parent / "Reencor" / "Assets" / "images",
    ])
    if objects is None or images is None:
        print("Sprites ausentes. Rode `make assets` antes de `make sprites`.", file=sys.stderr)
        return 1

    work = ROOT / ".build" / "sprite-work"
    out_dir = ROOT / "media" / "img"
    if out_dir.exists():
        subprocess.run(["rm", "-rf", str(out_dir)], check=True)
    work.mkdir(parents=True, exist_ok=True)

    jobs = []
    seen = set()
    anim = {"cell": {}, "fire": [], "shinku": [], "spark": [], "burst": []}

    def add_image(key, kind, size, src=None):
        if key in seen:
            return True
        if src is None:
            src = find_png(images, key)
        if src is None:
            print(f"faltou {key}")
            return False
        seen.add(key)
        folder, name = key.split("/", 1)
        dest = work / folder / f"{name}.png"
        final = out_dir / folder / f"{name}.png"
        jobs.append((kind, src, dest, final, size))
        return True

    ryu_cell = load_json(objects / "Ryu.json")["def_image_size"]
    scale = CELL_H / ryu_cell[1]
    for style, filename in CHARACTERS.items():
        data = load_json(objects / filename)
        w, h, ax, ay = cell_box(data["def_image_size"], data["def_image_offset"], scale)
        folder = "02_Ryu" if style == "ryu" else "11_Ken"
        anim["cell"][style] = {"folder": folder, "w": w, "h": h, "ax": ax, "ay": ay}
        anim[style] = {}
        for state in data["states"].values():
            for image, _dur in frames_of(state):
                add_image(image, "cell", (w, h))
        for clip, state_name in CLIPS.items():
            state = data["states"].get(state_name)
            if not state and state_name == "Neutral Landing":
                state = data["states"].get("Neutrallanding")
            if not state:
                print(f"{style} sem {state_name}")
                continue
            frames = []
            for image, dur in frames_of(state):
                if image in seen:
                    frames.append((image.split("/", 1)[1], dur))
            if frames:
                anim[style][clip] = frames

    hadou = load_json(objects / "Hadouken.json")
    fire_keys = []
    for state in hadou["states"].values():
        for image, _dur in frames_of(state):
            if image.startswith("fireballs/") and image not in fire_keys:
                fire_keys.append(image)
    normal_keys, tall_keys = [], []
    for key in fire_keys:
        src = find_png(images, key)
        if src is None:
            continue
        _x, _y, _w, h = trim_box(src)
        if h > 80:
            tall_keys.append(key)
        else:
            normal_keys.append(key)
    stretch = (FIRE_SX, FIRE_SY)

    def pack_fire(keys):
        srcs = [find_png(images, key) for key in keys]
        srcs = [src for src in srcs if src is not None]
        if not srcs:
            return
        box = union_trim(srcs)
        for key in keys:
            add_image(key, "fire", (box, stretch))

    pack_fire(normal_keys)
    pack_fire(tall_keys)
    for key, state_name in (("fire", "Jab"), ("shinku", "Shinku")):
        frames = []
        for image, dur in frames_of(hadou["states"][state_name]):
            if not image.startswith("fireballs/"):
                continue
            if image.split("/", 1)[1] and find_png(images, image):
                frames.append((image.split("/", 1)[1], dur))
        anim[key] = frames

    sparks = load_json(objects / "Sparks.json")
    spark_frames = []
    for image, dur in frames_of(sparks["states"]["Spark1"]):
        if add_image(image, "trim", SPARK_H):
            spark_frames.append((image.split("/", 1)[1], dur))
    anim["spark"] = spark_frames
    burst_keys = []
    burst_frames = []
    for image, dur in frames_of(sparks["states"]["fireballkill1"]):
        if not image.startswith("fireballs/"):
            continue
        burst_keys.append(image)
        burst_frames.append((image.split("/", 1)[1], dur))
    burst_srcs = [src for key in burst_keys if (src := find_png(images, key))]
    if burst_srcs:
        burst_box = union_trim(burst_srcs)
        for key in burst_keys:
            add_image(key, "fire", (burst_box, stretch))
    anim["burst"] = burst_frames

    icon_dir = first_dir([
        images / "reencor",
        ROOT.parent / "Reencor" / "Assets" / "images" / "reencor",
    ])
    if icon_dir is not None:
        for src in sorted(icon_dir.glob("*.png")):
            if src.stem == "grid":
                add_image("stage/grid", "grid", 32, src)
            else:
                add_image(f"inputs/{src.stem}", "icon", 16, src)

    print(f"Convertendo {len(jobs)} imagens")

    def resize(job):
        kind, src, dest, _final, size = job
        if kind == "cell":
            resize_cell(src, dest, size[0], size[1])
        elif kind == "icon":
            resize_icon(src, dest, size)
        elif kind == "grid":
            resize_grid(src, dest, size)
        elif kind == "fire":
            box, stretch = size
            resize_fire(src, dest, box, stretch[0], stretch[1])
        elif kind == "scale":
            resize_trim_scale(src, dest, size)
        else:
            resize_trim(src, dest, size)

    with ThreadPoolExecutor(max_workers=8) as pool:
        list(pool.map(resize, jobs))

    palette = work / "palette.png"
    samples = [str(job[2]) for job in jobs]
    run([
        "magick", *samples,
        "-alpha", "off", "-resize", "16x16!",
        "+append", "-dither", "None", "-colors", str(COLORS),
        str(palette),
    ])

    def finish(job):
        _kind, _src, dest, final, _size = job
        remap_one(dest, final, palette)

    with ThreadPoolExecutor(max_workers=8) as pool:
        list(pool.map(finish, jobs))

    lines = ["return {", "  cell = {"]
    for style, cell in anim["cell"].items():
        lines.append(
            "    {style} = {{ folder = \"{folder}\", w = {w}, h = {h}, ax = {ax}, ay = {ay} }},".format(
                style=style, **cell
            )
        )
    lines.append("  },")
    for style in ("ryu", "ken"):
        lines.append(f"  {style} = {{")
        lines.append(lua_clips(anim[style]))
        lines.append("  },")
    for name in ("fire", "shinku", "spark", "burst"):
        body = ", ".join(f'{{"{image}", {dur}}}' for image, dur in anim[name])
        lines.append(f"  {name} = {{ {body} }},")
    lines.append("}")
    lines.append("")
    (ROOT / "src" / "anims.lua").write_text("\n".join(lines), encoding="utf-8")
    print(f"Frames em {out_dir}")
    print(f"Tabela em {ROOT / 'src' / 'anims.lua'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
