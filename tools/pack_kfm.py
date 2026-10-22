#!/usr/bin/env python3
"""Corta a folha do Kung Fu Man e grava os quadros do lutador.

O Ryu e o Ken deixam de usar os PNG da Capcom. Os dois jogam com este
desenho: o segundo recebe o quimono vermelho para os lados nao se misturarem.
"""

import shutil
import subprocess
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "Assets" / "kfm" / "kungfu.png"
OUT = ROOT / "media" / "img"
LUA = ROOT / "src" / "kfm.lua"

# (clip, row, start, end) end exclusivo. None vai ate o fim da fileira.
CLIPS = [
    # O quadro 6 vira o tronco. A respiracao fica nos seis primeiros.
    ("stand", 0, 0, 6),
    ("walk_f", 1, 0, None),
    ("walk_b", 2, 0, None),
    ("dash", 3, 0, None),
    ("dash_b", 2, 0, None),
    ("jump", 4, 0, None),
    ("jump_f", 5, 0, None),
    ("jump_b", 6, 0, None),
    ("land", 7, 0, None),
    ("jab", 8, 0, None),
    ("strong", 10, 0, None),
    ("fierce", 11, 0, None),
    ("dp", 11, 0, None),
    ("crouch", 12, 0, None),
    ("c_jab", 13, 0, None),
    ("c_strong", 14, 0, None),
    ("c_fierce", 14, 0, None),
    ("roundhouse", 15, 0, None),
    ("forward", 16, 0, None),
    ("short", 17, 0, None),
    ("air_kick", 19, 0, None),
    ("block", 20, 0, None),
    ("c_block", 21, 0, None),
    ("hit", 22, 0, None),
    ("low_hit", 23, 0, None),
    ("c_short", 24, 0, None),
    ("c_forward", 24, 0, None),
    ("sweep", 25, 0, None),
    ("hadou", 26, 0, None),
    ("win", 27, 0, None),
    ("crouch_hit", 29, 0, None),
    ("air_punch", 30, 0, None),
    ("throw", 31, 0, None),
    ("fall", 32, 0, None),
    ("air_hit", 34, 0, None),
    ("rise", 33, 0, None),
]


def is_green(r, g, b):
    return g > 180 and r < 40 and b < 160 and g > r + 80


def cells(raw, w, h):
    seen = bytearray(w * h)
    boxes = []
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if seen[i]:
                continue
            r, g, b = raw[i * 3], raw[i * 3 + 1], raw[i * 3 + 2]
            if is_green(r, g, b):
                seen[i] = 1
                continue
            q = deque([(x, y)])
            seen[i] = 1
            minx = maxx = x
            miny = maxy = y
            count = 0
            while q:
                cx, cy = q.popleft()
                count += 1
                minx, maxx = min(minx, cx), max(maxx, cx)
                miny, maxy = min(miny, cy), max(maxy, cy)
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if nx < 0 or ny < 0 or nx >= w or ny >= h:
                        continue
                    j = ny * w + nx
                    if seen[j]:
                        continue
                    rr, gg, bb = raw[j * 3], raw[j * 3 + 1], raw[j * 3 + 2]
                    if is_green(rr, gg, bb):
                        seen[j] = 1
                        continue
                    seen[j] = 1
                    q.append((nx, ny))
            bw, bh = maxx - minx + 1, maxy - miny + 1
            if count >= 400 and bw >= 20 and bh >= 30:
                boxes.append((minx, miny, bw, bh))
    boxes.sort(key=lambda b: (b[1], b[0]))
    rows = []
    for box in boxes:
        if not rows or box[1] > rows[-1][0][1] + max(20, rows[-1][0][3] * 0.4):
            rows.append([box])
        else:
            rows[-1].append(box)
    for row in rows:
        row.sort(key=lambda b: b[0])
    return rows


def run(args):
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL)


def trim_cell(src, box, dest):
    x, y, bw, bh = box
    dest.parent.mkdir(parents=True, exist_ok=True)
    run([
        "magick", str(src), "-crop", f"{bw}x{bh}+{x}+{y}", "+repage",
        "-transparent", "#FF00FF", "-trim", "+repage",
        f"PNG32:{dest}",
    ])


def measure(path):
    raw = subprocess.check_output(["magick", str(path), "-depth", "8", "rgba:-"])
    info = subprocess.check_output(["magick", "identify", "-format", "%w %h", str(path)], text=True)
    w, h = (int(n) for n in info.split())
    if w < 8 or h < 36 or w > 220:
        return None
    foot_xs = []
    band = max(4, h // 8)
    for y in range(h - band, h):
        for x in range(w):
            a = raw[((y * w + x) * 4) + 3]
            if a > 40:
                foot_xs.append(x)
    if not foot_xs:
        return None
    foot = sum(foot_xs) / len(foot_xs)
    # ax e a distancia da ancora ate a borda direita, como na celula do Reencor.
    ax = max(1, min(w - 1, round(w - foot)))
    return w, h, ax, h


def tint_ken(src, dest):
    info = subprocess.check_output(["magick", "identify", "-format", "%w %h", str(src)], text=True)
    w, h = (int(n) for n in info.split())
    raw = bytearray(subprocess.check_output(["magick", str(src), "-depth", "8", "rgba:-"]))
    for i in range(0, len(raw), 4):
        r, g, b, a = raw[i], raw[i + 1], raw[i + 2], raw[i + 3]
        if a < 10:
            continue
        if r > 200 and g > 190 and b > 180 and abs(int(r) - int(g)) < 35 and abs(int(g) - int(b)) < 45:
            raw[i] = min(255, int(r * 0.95))
            raw[i + 1] = int(g * 0.42)
            raw[i + 2] = int(b * 0.38)
    dest.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["magick", "-size", f"{w}x{h}", "-depth", "8", "rgba:-", f"PNG32:{dest}"],
        input=bytes(raw),
        check=True,
        stdout=subprocess.DEVNULL,
    )


def hip_of(path):
    raw = subprocess.check_output(["magick", str(path), "-depth", "8", "rgba:-"])
    w, h = (int(n) for n in subprocess.check_output(
        ["magick", "identify", "-format", "%w %h", str(path)], text=True
    ).split())
    xs, ys = [], []
    for y in range(int(h * 0.28), int(h * 0.70)):
        for x in range(int(w * 0.20), int(w * 0.58)):
            if raw[((y * w + x) * 4) + 3] > 80:
                xs.append(x)
                ys.append(y)
    if not xs:
        return w / 2, h / 2
    return sum(xs) / len(xs), sum(ys) / len(ys)


def spin_sheet(src, dest):
    """Deixa o quadril no centro para o giro nao orbitar a cabeca."""
    hipx, hipy = hip_of(src)
    info = subprocess.check_output(["magick", "identify", "-format", "%w %h", str(src)], text=True)
    w, h = (int(n) for n in info.split())
    side = int(max(w, h) * 2.4)
    center = side // 2
    subprocess.run([
        "magick", "-size", f"{side}x{side}", "xc:none",
        str(src), "-geometry", f"+{int(center - hipx)}+{int(center - hipy)}", "-composite",
        f"PNG32:{dest}",
    ], check=True)
    return center


def spin_frame(base, angle, dest):
    """Gira o chute em torno do quadril. Devolve w, h e o quadril no quadro cortado."""
    info = subprocess.check_output([
        "magick", str(base), "-filter", "Point", "-background", "none", "-rotate", str(angle),
        "-channel", "A", "-threshold", "50%", "+channel",
        "-format", "%w %h %@", "info:",
    ], text=True)
    rw_s, rh_s, box = info.split()
    rw, rh = int(rw_s), int(rh_s)
    size, off = box.split("+", 1)
    tw, th = (int(n) for n in size.split("x"))
    ox, oy = (int(n) for n in off.split("+"))
    subprocess.run([
        "magick", str(base), "-filter", "Point", "-background", "none", "-rotate", str(angle),
        "-channel", "A", "-threshold", "50%", "+channel",
        "-trim", "+repage", f"PNG32:{dest}",
    ], check=True)
    return tw, th, rw / 2 - ox, rh / 2 - oy


def build_tatsu(clips, seq):
    """O chute giratorio do Kung Fu Man fica em pe. O Tatsumaki deita e gira."""
    kicks = clips.get("roundhouse") or []
    if not kicks:
        print("sem chute para o tatsumaki", file=sys.stderr)
        return
    src_id = max(kicks, key=lambda fr: fr[3])[0]
    src = OUT / "kfm" / f"{src_id}.png"
    work = ROOT / ".build" / "kfm-work"
    work.mkdir(parents=True, exist_ok=True)
    base = work / "tatsu-base.png"
    spin_sheet(src, base)
    # Entrada inclinada, depois uma volta completa em passos iguais.
    angles = [12, 32, 60, 120, 180, 240, 300, 0]
    rendered = []
    for angle in angles:
        fid = f"{seq:03d}"
        seq += 1
        path = work / f"{fid}.png"
        w, h, hx, hy = spin_frame(base, angle, path)
        # O giro mistura cores. Volta para a paleta do desenho, senao o cartucho descarta o quadro.
        subprocess.run([
            "magick", str(path), "-remap", str(src),
            "-channel", "A", "-threshold", "50%", "+channel",
            f"PNG32:{path}",
        ], check=True)
        final = OUT / "kfm" / f"{fid}.png"
        shutil.copy(path, final)
        tint_ken(path, OUT / "kfm2" / f"{fid}.png")
        rendered.append((fid, w, h, hx, hy))
    lowest = max(h - hy for _, _, h, _, hy in rendered)
    hover = max(0, round(lowest) - 2)
    clips["tatsu"] = [
        (fid, max(1, min(w - 1, round(w - hx))), round(hy + hover), w)
        for fid, w, h, hx, hy in rendered
    ]
    print(f"tatsumaki: {len(rendered)} quadros, quadril a {hover}px do chao")


def lay_down(clips):
    """A queda para com uma perna no ar. O corpo esticado esta no quadro mais baixo."""
    fall = clips.get("fall") or []
    pool = fall + (clips.get("rise") or [])
    if not pool:
        return
    flat = min(pool, key=lambda fr: (fr[2], -fr[3]))
    settle = [fr for fr in fall if fr[2] <= flat[2] + 25]
    if flat not in settle:
        settle.append(flat)
    clips["down"] = settle
    print(f"derrota deitada no quadro {flat[0]}")


def anchor_torso(clips, name):
    """A corrida muda o pe mais baixo. A ancora fica no tronco para o corpo nao pular."""
    frames = clips.get(name)
    if not frames:
        return
    fixed = []
    for fid, _ax, ay, w in frames:
        path = OUT / "kfm" / f"{fid}.png"
        raw = subprocess.check_output(["magick", str(path), "-depth", "8", "rgba:-"])
        h = ay
        xs = []
        for y in range(int(h * 0.28), int(h * 0.55)):
            for x in range(w):
                if raw[(y * w + x) * 4 + 3] > 80:
                    xs.append(x)
        torso = (sum(xs) / len(xs)) if xs else w / 2
        ax = max(1, min(w - 1, round(w - torso)))
        fixed.append((fid, ax, ay, w))
    clips[name] = fixed


def lua_text(clips):
    lines = [
        "-- Kung Fu Man. Gerado por tools/pack_kfm.py.",
        "-- O Ken usa a mesma folha com o quimono vermelho.",
        "return {",
        '  folder = "kfm",',
        '  ken = "kfm2",',
        "  clips = {",
    ]
    for name, frames in clips.items():
        body = ", ".join(
            f'{{"{fid}", {ax}, {ay}, {w}}}' for fid, ax, ay, w in frames
        )
        lines.append(f"    {name} = {{ {body} }},")
    lines.append("  },")
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def main():
    if not SRC.is_file():
        print(f"Falta {SRC}", file=sys.stderr)
        return 1
    ident = subprocess.check_output(["magick", "identify", "-format", "%w %h", str(SRC)], text=True)
    w, h = (int(n) for n in ident.split())
    raw = subprocess.check_output(["magick", str(SRC), "-depth", "8", "rgb:-"])
    rows = cells(raw, w, h)
    work = ROOT / ".build" / "kfm-work"
    if work.exists():
        shutil.rmtree(work)
    for folder in ("kfm", "kfm2"):
        dest = OUT / folder
        if dest.exists():
            shutil.rmtree(dest)
    kept = {}
    seq = 0
    for row_i, row in enumerate(rows):
        frames = []
        for box in row:
            fid = f"{seq:03d}"
            seq += 1
            path = work / f"{fid}.png"
            trim_cell(SRC, box, path)
            size = measure(path)
            if size is None:
                path.unlink(missing_ok=True)
                continue
            fw, fh, ax, ay = size
            final = OUT / "kfm" / f"{fid}.png"
            final.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(path, final)
            tint_ken(path, OUT / "kfm2" / f"{fid}.png")
            frames.append((fid, ax, ay, fw))
        kept[row_i] = frames
        print(f"fileira {row_i:02d}: {len(frames)} quadros")

    clips = {}
    for name, row, start, end in CLIPS:
        frames = kept.get(row, [])[start:end]
        if not frames:
            print(f"clip {name} vazio", file=sys.stderr)
            continue
        clips[name] = frames
    build_tatsu(clips, seq)
    lay_down(clips)
    anchor_torso(clips, "dash")
    if "stand" not in clips:
        print("A folha nao rendeu a pose em pe.", file=sys.stderr)
        return 1
    LUA.write_text(lua_text(clips), encoding="utf-8")
    print(f"Kung Fu Man em {OUT / 'kfm'} e {LUA}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
