#!/usr/bin/env python3
"""check_block_target.py <def> <instance prefix> <fx> <fy> <tolerance>: the components whose
names start with the prefix (give the "/": "A3/") are centred within tolerance -- a fraction of
the die -- of (fx, fy)"""
import sys, re
d, pre, fx, fy, tol = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5])
die = None; xs = []; ys = []; inC = False; cur = None
for l in open(d):
    if l.startswith("DIEAREA"):
        v = [int(x) for x in re.findall(r"-?\d+", l)]; die = (v[0], v[1], v[2], v[3])
    if l.startswith("COMPONENTS"): inC = True; continue
    if l.startswith("END COMPONENTS"): break
    if not inC: continue
    if l.lstrip().startswith("- "): cur = l.split()[1].replace("\\", "")
    m = re.search(r"\+\s*(?:PLACED|FIXED)\s*\(\s*(-?\d+)\s+(-?\d+)\s*\)", l)
    if m and cur is not None:
        if cur.startswith(pre): xs.append(int(m.group(1))); ys.append(int(m.group(2)))
        cur = None
if not xs: sys.exit(f"check_block_target: no component under {pre} in {d}")
cx = (sum(xs) / len(xs) - die[0]) / (die[2] - die[0]); cy = (sum(ys) / len(ys) - die[1]) / (die[3] - die[1])
ok = abs(cx - fx) <= tol and abs(cy - fy) <= tol
print(f"check_block_target: {pre} ({len(xs)} cells) centred at ({cx:.2f}, {cy:.2f}) of the die, target ({fx}, {fy}): {'ok' if ok else 'MISSED'}")
sys.exit(0 if ok else 1)
