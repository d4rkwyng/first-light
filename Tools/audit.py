#!/usr/bin/env python3
"""F8: verify every drawn chip sits on an extracted silk footprint.

Usage: run a DEBUG build of the app once (it dumps /tmp/firstlight_chips.csv
at startup), then:  python3 Tools/audit.py
"""
import csv, math, re, sys, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
foot = [tuple(map(float, m.groups())) for m in re.finditer(
    r"CGRect\(x: ([\d.]+), y: ([\d.]+), width: ([\d.]+), height: ([\d.]+)\)",
    (root / "Sources/FirstLight/BoardFootprints.swift").read_text())]

# Parts that legitimately have no silk footprint (drill/photo-anchored)
# regs: placed from a direct silk probe (their outlines fall below the
# footprint extractor's size floor and aren't in BoardFootprints)
EXEMPT = {"heatsink", "lm323k", "cap1", "cap2", "cap3", "crystal",
          "reg0", "reg1", "reg2"}

chips = []
try:
    for row in csv.reader(open("/tmp/firstlight_chips.csv")):
        chips.append((row[0], *map(float, row[1:])))
except FileNotFoundError:
    sys.exit("run a debug build of the app first (dumps the csv)")

avail = list(foot)
bad, claimed = [], []
for (cid, x, y, w, h) in chips:
    if cid in EXEMPT or any(cid.startswith(e) for e in EXEMPT):
        continue
    cx, cy = x + w / 2, y + h / 2
    best = min(((math.hypot(f[0]+f[2]/2-cx, f[1]+f[3]/2-cy), i)
                for i, f in enumerate(avail)), default=None)
    if best is None or best[0] > 4.0:
        bad.append((cid, round(cx), round(cy), round(best[0], 1) if best else None))
    else:
        claimed.append(cid)
        avail.pop(best[1])

print(f"{len(chips)} chips, {len(foot)} footprints")
print(f"on-footprint: {len(claimed)}   exempt(drill/photo-anchored): "
      f"{sum(1 for c in chips if c[0] in EXEMPT or any(c[0].startswith(e) for e in EXEMPT))}")
if bad:
    print("OFF-FOOTPRINT (center distance px):")
    for b in bad:
        print("  ", b)
else:
    print("ALL chips verified on their silk footprints ✓")
print(f"unclaimed footprints: {len(avail)} (passives/unmodeled positions)")
