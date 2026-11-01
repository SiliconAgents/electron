#!/usr/bin/env python3
"""check_fixed_fp.py <nodefile> <def> <x0 y0 x1 y1> [--held_only]: a floorplan given rather than made, held in a DEF.

Every INST of the nodefile at its x y and ORIENT=, every PORT where it was held (a DEF pin is the
centre of its shape, a quarter row on a side, so within 0.36 um), and -- unless --held_only, for a
placement not yet legalized -- no other component's box reaching into the blockage x0 y0 x1 y1
(microns) or into a held macro."""
import sys, re, os
nodes, d = sys.argv[1], sys.argv[2]
blk = [float(v) for v in sys.argv[3:7]]
heldOnly = "--held_only" in sys.argv
want_i, want_p = {}, {}
for l in open(nodes):
    t = l.split()
    if len(t) < 8 or not t[0].isdigit(): continue
    if t[2] == "INST": want_i[t[1]] = (float(t[6]), float(t[7]), float(t[3]), float(t[4]), [x[7:] for x in t[8:] if x.startswith("ORIENT=")][0])
    else: want_p[t[1]] = (float(t[6]), float(t[7]))
dbu = 1000; comps = {}; pins = {}; sec = None; cur = None
size = {}
for l in open(d):
    if l.startswith("UNITS DISTANCE MICRONS"): dbu = int(l.split()[3])
    if l.startswith("COMPONENTS"): sec = "C"; continue
    if l.startswith("PINS"): sec = "P"; continue
    if l.startswith("END "): sec = None; continue
    if sec == "C":
        m = re.match(r"\s*-\s+(\S+)\s+(\S+)", l)
        if m: cur = (m.group(1).replace("\\", ""), m.group(2))
        m = re.search(r"\+\s*(PLACED|FIXED)\s*\(\s*(-?\d+)\s+(-?\d+)\s*\)\s*(\S+)", l)
        if m and cur: comps[cur[0]] = (cur[1], int(m.group(2)) / dbu, int(m.group(3)) / dbu, m.group(4)); cur = None
    elif sec == "P":
        m = re.match(r"\s*-\s+(\S+)\s+\+\s*NET", l)
        if m: cur = m.group(1)
        m = re.search(r"\+\s*(PLACED|FIXED)\s*\(\s*(-?\d+)\s+(-?\d+)\s*\)", l)
        if m and cur: pins[cur] = (int(m.group(2)) / dbu, int(m.group(3)) / dbu); cur = None
bad = []
for n, (x, y, w, h, o) in want_i.items():
    c = comps.get(n)
    if not c: bad.append(f"macro {n} not in the DEF"); continue
    if abs(c[1] - x) > 0.01 or abs(c[2] - y) > 0.01 or c[3] != o: bad.append(f"macro {n} at {c[1]} {c[2]} {c[3]}, held at {x} {y} {o}")
for n, (x, y) in want_p.items():
    p = pins.get(n)
    if not p or abs(p[0] - x) > 0.36 or abs(p[1] - y) > 0.36: bad.append(f"pin {n} at {p}, held at {x} {y}")
# cell sizes: a LEF for every master the DEF uses
here = os.path.dirname(os.path.abspath(__file__))
for lf in (f"{here}/library/NangateOpenCellLibrary_PDKv1_2_v2008_10.lef", f"{here}/fixed_fp/testram.lef"):
    cur = None
    for l in open(lf):
        t = l.split()
        if len(t) >= 2 and t[0] == "MACRO": cur = t[1]
        elif cur and len(t) >= 4 and t[0] == "SIZE": size[cur] = (float(t[1]), float(t[3])); cur = None
boxes = [blk] + [[x, y, x + w, y + h] for (x, y, w, h, o) in want_i.values()]
inside = 0
for n, (r, x, y, o) in comps.items():
    if n in want_i or heldOnly: continue
    w, h = size.get(r, (0, 0))
    for b in boxes:
        if min(x + w, b[2]) - max(x, b[0]) > 1e-6 and min(y + h, b[3]) - max(y, b[1]) > 1e-6: inside += 1; break
if inside: bad.append(f"{inside} cell(s) reach into the blockage or a held macro")
print(f"check_fixed_fp: {d}: {len(want_i)} macro(s), {len(want_p)} pin(s) held, {len(comps)} components: " + ("ok" if not bad else "; ".join(bad[:6])))
sys.exit(1 if bad else 0)
