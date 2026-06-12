import re, sys

def parse(path):
    apertures = {}   # num -> (shape, w, h)
    segs = []        # (x1,y1,x2,y2,width)
    flashes = []     # (x,y,w,h,shape)
    cur_ap = None
    x = y = 0
    op = 2  # 1 draw, 2 move, 3 flash (modal)
    for raw in open(path):
        line = raw.strip()
        if not line or line.startswith("G04"):
            continue
        m = re.match(r"%ADD(\d+)([A-Z]+)\s*,?\s*([0-9.X]*)", line)
        if m:
            num, shape, params = int(m.group(1)), m.group(2), m.group(3)
            vals = [float(v) for v in params.replace("X", " ").split()] if params else []
            if shape == "C":
                apertures[num] = ("C", vals[0], vals[0])
            elif shape in ("R", "O"):
                apertures[num] = (shape, vals[0], vals[1] if len(vals) > 1 else vals[0])
            else:  # macro: treat as circle/oval with first params
                w = vals[0] if vals else 0.05
                h = vals[1] if len(vals) > 1 else w
                apertures[num] = ("M", w, h)
            continue
        if line.startswith("%"):
            continue
        m = re.fullmatch(r"(?:G54)?D(\d+)\*", line)
        if m:
            n = int(m.group(1))
            if n >= 10:
                cur_ap = n
            else:
                op = n
            continue
        m = re.fullmatch(r"(?:G0?[123])?X?(-?\d+)?Y?(-?\d+)?(?:D(\d))?\*", line)
        if m and (m.group(1) is not None or m.group(2) is not None):
            nx = int(m.group(1)) / 10000 if m.group(1) is not None else x
            ny = int(m.group(2)) / 10000 if m.group(2) is not None else y
            if m.group(3):
                op = int(m.group(3))
            if op == 1 and cur_ap in apertures:
                segs.append((x, y, nx, ny, apertures[cur_ap][1]))
            elif op == 3 and cur_ap in apertures:
                sh, w, h = apertures[cur_ap]
                flashes.append((nx, ny, w, h, sh))
            x, y = nx, ny
    return segs, flashes


def parse_drl(path):
    holes = []  # (x, y, dia)
    dia = 0.035
    tools = {}
    x = y = 0.0
    import re as _re
    for raw in open(path):
        line = raw.strip()
        m = _re.match(r"T(\d+)C([\d.]+)", line)
        if m:
            tools[int(m.group(1))] = float(m.group(2))
            continue
        m = _re.fullmatch(r"T(\d+)", line)
        if m:
            dia = tools.get(int(m.group(1)), 0.035)
            continue
        m = _re.fullmatch(r"X([+-]?\d+)?Y?([+-]?\d+)?", line.replace("Y", "Y ").replace(" ", "")) if False else None
        m = _re.fullmatch(r"(?:X([+-]\d+))?(?:Y([+-]\d+))?", line)
        if m and (m.group(1) or m.group(2)):
            if m.group(1): x = int(m.group(1)) / 10000
            if m.group(2): y = int(m.group(2)) / 10000
            holes.append((x, y, dia))
    return holes

def emit(layers, out, color_map, bg=None, box=None, holes=None):
    if box:
        x0, x1, y0, y1 = box
    else:
        allx, ally = [], []
        for segs, flashes in layers.values():
            for s in segs:
                allx += [s[0], s[2]]; ally += [s[1], s[3]]
            for f in flashes:
                allx.append(f[0]); ally.append(f[1])
        x0, x1 = min(allx), max(allx)
        y0, y1 = min(ally), max(ally)
    W = x1 - x0 + 0.2
    H = y1 - y0 + 0.2
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W:.3f} {H:.3f}" '
             f'width="{int(W*140)}" height="{int(H*140)}">']
    if bg:
        parts.append(f'<rect width="100%" height="100%" fill="{bg}"/>')
    def tx(v): return v - x0 + 0.1
    def ty(v): return (y1 - v) + 0.1   # flip Y: gerber origin bottom-left
    for name, (segs, flashes) in layers.items():
        color = color_map[name]
        pad_color = color_map.get(name + "_pads", color)
        parts.append(f'<g stroke="{color}" fill="{pad_color}" stroke-linecap="round">')
        for (ax, ay, bx, by, w) in segs:
            parts.append(f'<line x1="{tx(ax):.3f}" y1="{ty(ay):.3f}" '
                         f'x2="{tx(bx):.3f}" y2="{ty(by):.3f}" stroke-width="{max(w, 0.014):.4f}"/>')
        for (fx, fy, w, h, sh) in flashes:
            if sh == "R":
                parts.append(f'<rect x="{tx(fx)-w/2:.3f}" y="{ty(fy)-h/2:.3f}" '
                             f'width="{w:.4f}" height="{h:.4f}" stroke="none"/>')
            else:
                parts.append(f'<ellipse cx="{tx(fx):.3f}" cy="{ty(fy):.3f}" '
                             f'rx="{w/2:.4f}" ry="{h/2:.4f}" stroke="none"/>')
        parts.append('</g>')
    for (hx, hy, hd) in (holes or []):
        parts.append(f'<circle cx="{tx(hx):.3f}" cy="{ty(hy):.3f}" '
                     f'r="{hd/2:.4f}" fill="#16211A"/>')
    parts.append('</svg>')
    open(out, "w").write("\n".join(parts))
    print(f"{out}: extents {W:.2f} x {H:.2f} in, "
          + ", ".join(f"{k}:{len(v[0])}segs/{len(v[1])}flashes" for k, v in layers.items()))

top = parse("/tmp/a1gerber/PCB-11.gtl")
silk = parse("/tmp/a1gerber/PCB-11.gto")
ax, ay = [], []
for segs, flashes in (top, silk):
    for s in segs: ax += [s[0], s[2]]; ay += [s[1], s[3]]
    for f in flashes: ax.append(f[0]); ay.append(f[1])
box = (min(ax), max(ax), min(ay), max(ay))
print("shared box:", box)
emit({"copper": top}, "/tmp/a1_copper.svg",
     {"copper": "#57705B", "copper_pads": "#9DAF9E"}, box=box,
     holes=parse_drl("/tmp/a1gerber/PCB-11.DRL"))
emit({"silk": silk}, "/tmp/a1_silk.svg", {"silk": "#FFFFFF"}, box=box)
