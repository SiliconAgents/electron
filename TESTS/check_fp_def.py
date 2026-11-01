#!/usr/bin/env python3
"""check_fp_def.py <floorplan.def> <placed.def> <x0 y0 x1 y1>: a design placed inside a floorplan DEF.

Every FIXED component of the floorplan is in the placed DEF at the same place and orient, every
pin's shape centred where the floorplan's is (DEF semantics -- the PLACED point plus the shape
under its orient -- for the floorplan; electron's write_def puts the PLACED point at the shape's
centre and leaves the shape unrotated, so for the placed DEF that point), and no other component's box reaches outside the die, into the
blockage x0 y0 x1 y1 (microns) or into a FIXED component.  Cell sizes from the test's LEFs."""
import sys, re, os
here = os.path.dirname(os.path.abspath(__file__))
size = {}
for lef in (os.path.join(here, "library/NangateOpenCellLibrary_PDKv1_2_v2008_10.lef"), os.path.join(here, "fixed_fp/testram.lef")):
    m = None
    for l in open(lef):
        t = l.split()
        if len(t) >= 2 and t[0] == "MACRO": m = t[1]
        elif m and len(t) >= 4 and t[0] == "SIZE": size[m] = (float(t[1]), float(t[3]))

def read(f):
    dbu, comps, pins, sec, cur, die = 1000, {}, {}, None, None, None
    stmt = ""
    for l in open(f):
        if l.startswith("UNITS DISTANCE MICRONS"): dbu = int(l.split()[3])
        if l.startswith("DIEAREA"): die = [int(v) for v in re.findall(r"-?\d+", l)]
        if l.startswith("COMPONENTS"): sec = "C"; continue
        if l.startswith("PINS"): sec = "P"; continue
        if l.startswith("END "): sec = None; continue
        if sec is None: continue
        stmt += " " + l.strip()
        if not stmt.rstrip().endswith(";"): continue
        s, stmt = stmt, ""
        n = re.match(r"\s*-\s+(\S+)\s+(\S+)", s)
        p = re.search(r"\+\s*(PLACED|FIXED)\s*\(\s*(-?\d+)\s+(-?\d+)\s*\)\s*(\S+)", s)
        if not (n and p): continue
        if sec == "C": comps[n.group(1)] = (n.group(2), p.group(1), int(p.group(2)) / dbu, int(p.group(3)) / dbu, p.group(4))
        else:
            x, y, o = int(p.group(2)), int(p.group(3)), p.group(4)
            r = re.search(r"LAYER\s+\S+\s*\(\s*(-?\d+)\s+(-?\d+)\s*\)\s*\(\s*(-?\d+)\s+(-?\d+)\s*\)", s)
            cx, cy = ((int(r.group(1)) + int(r.group(3))) / 2, (int(r.group(2)) + int(r.group(4))) / 2) if r else (0, 0)
            t = {"N": (cx, cy), "S": (-cx, -cy), "E": (cy, -cx), "W": (-cy, cx), "FN": (-cx, cy), "FS": (cx, -cy), "FE": (cy, cx), "FW": (-cy, -cx)}[o]
            pins[n.group(1)] = ((x + t[0]) / dbu, (y + t[1]) / dbu, x / dbu, y / dbu)
    return dbu, comps, pins, [v / dbu for v in die]

dbu, fc, fp, _ = read(sys.argv[1])  # pins compare to a DBU and a half: a centre can fall on half a DBU
_, pc, pp, die = read(sys.argv[2])
blk = [float(v) for v in sys.argv[3:7]]
bad = []
def box(c):
    ref, st, x, y, o = c
    w, h = size.get(ref, (0, 0))
    if o in ("E", "W", "FE", "FW"): w, h = h, w
    return (x, y, x + w, y + h)
fixed = {k: v for k, v in fc.items() if v[1] == "FIXED"}
for k, v in fixed.items():
    c = pc.get(k)
    if not c: bad.append(f"{k} missing"); continue
    if abs(c[2] - v[2]) > 1e-6 or abs(c[3] - v[3]) > 1e-6 or c[4] != v[4]: bad.append(f"{k} at {c[2:]} not {v[2:]}")
for k, v in fp.items():
    if k not in pp or abs(pp[k][2] - v[0]) > 1.5 / dbu or abs(pp[k][3] - v[1]) > 1.5 / dbu: bad.append(f"pin {k} centred at {pp[k][2:] if k in pp else None}, not {v[:2]}")
W, H = max(die[0::2]), max(die[1::2])
hold = [box(pc[k]) for k in fixed if k in pc] + [tuple(blk)]
over = out = 0
cells = [(k, box(c)) for k, c in pc.items() if k not in fixed]
for k, b in cells:
    if b[0] < -1e-6 or b[1] < -1e-6 or b[2] > W + 1e-6 or b[3] > H + 1e-6: out += 1
    for h in hold:
        if b[0] < h[2] - 1e-6 and h[0] < b[2] - 1e-6 and b[1] < h[3] - 1e-6 and h[1] < b[3] - 1e-6: over += 1; break
if out: bad.append(f"{out} cell(s) outside the die")
if over: bad.append(f"{over} cell(s) reach into the blockage or a FIXED component")
print(f"check_fp_def: {sys.argv[2]}: {len(fixed)} FIXED component(s), {len(fp)} pin(s), {len(cells)} placed: " + ("ok" if not bad else "; ".join(bad[:6])))
sys.exit(1 if bad else 0)
