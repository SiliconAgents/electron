#!/usr/bin/env python3
"""Compare two DEFs of one design, before and after its top level was placed
again, and check the children moved as rigid pieces.

  check_rigid.py before.def after.def [instance path ...]

Cells are grouped by their first hierarchy segment (the top's child instance
they sit in).  Every group must have moved by one offset, and no two groups'
cell extents may overlap after the move.  Exits non-zero, saying which, if not.

Given instance paths (hier_place_all -only: every instance of the module
re-placed), the groups are the children under each of them instead, the
module's own cells may go anywhere, and every cell outside them must not have
moved at all.  --free A,B: children of those names were dissolved into the
module (ungroup), so their cells are its own and may go anywhere too.
"""
import collections
import re
import sys


def load(path):
    comps, in_comps, buf = {}, False, ""
    for line in open(path):
        if line.startswith("COMPONENTS"):
            in_comps = True
            continue
        if line.startswith("END COMPONENTS"):
            break
        if not in_comps:
            continue
        buf += " " + line.strip()
        if buf.rstrip().endswith(";"):
            m = re.search(r"-\s+(\S+)\s+\S+.*?\+\s+(?:PLACED|FIXED)\s+\(\s*(-?\d+)\s+(-?\d+)\s*\)", buf)
            if m:
                comps[m.group(1)] = (int(m.group(2)), int(m.group(3)))
            buf = ""
    return comps


args = sys.argv[1:]
free = set()
if "--free" in args:
    k = args.index("--free"); free = set(args[k + 1].split(",")); del args[k:k + 2]
before, after = load(args[0]), load(args[1])
under = args[2:]
groups = collections.defaultdict(list)
bad, boxes, moved = [], {}, 0
outside = 0
for name in before:
    if name not in after:
        continue
    if not under:
        if "/" in name:
            groups[name.split("/")[0]].append(name)
        continue
    p = next((u for u in under if name.startswith(u + "/")), None)
    if p is None:
        outside += 1
        if before[name] != after[name]:
            bad.append(f"{name} is outside {' '.join(under)} and moved")
        continue
    rest = name[len(p) + 1:]
    if "/" in rest and rest.split("/")[0] not in free:
        groups[p + "/" + rest.split("/")[0]].append(name)

for g, names in sorted(groups.items()):
    shifts = collections.Counter((after[n][0] - before[n][0], after[n][1] - before[n][1]) for n in names)
    shift, count = shifts.most_common(1)[0]
    if count != len(names):
        bad.append(f"{g}: {len(names) - count} of {len(names)} cells did not move with the block")
    if shift != (0, 0):
        moved += 1
    xs = [after[n][0] for n in names]
    ys = [after[n][1] for n in names]
    boxes[g] = (min(xs), min(ys), max(xs), max(ys))

for p in boxes:
    for q in boxes:
        a, b = boxes[p], boxes[q]
        if p < q and a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]:
            bad.append(f"{p} and {q} overlap")
if moved == 0:
    bad.append("no block moved: the top was not placed again")

if bad:
    print("check_rigid: " + "; ".join(bad))
    sys.exit(1)
print(f"check_rigid: {len(groups)} blocks, {moved} moved, every one rigidly, none overlapping"
      + (f"; {outside} cells outside them unmoved" if under else ""))
