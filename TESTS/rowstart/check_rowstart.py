#!/usr/bin/env python3
"""check_rowstart.py <def> <lef>... [--rule site=ORIENT,...] [--shift-out <def>]

Independent of electron: every cell on a row and the site grid, no two
cells overlapping (integer DBU, a sweep per row), and every cell more than
one row tall whose site has a rule starting on a row of that orientation.
--shift-out writes a copy of the DEF with each ruled cell moved up one row
-- onto the other orientation -- for the incremental test."""
import re, sys, collections

args = sys.argv[1:]
rule, shift_out = {}, None
if "--rule" in args:
    i = args.index("--rule"); rule = dict(kv.split("=") for kv in args[i + 1].split(",")); del args[i:i + 2]
if "--shift-out" in args:
    i = args.index("--shift-out"); shift_out = args[i + 1]; del args[i:i + 2]
deff, lefs = args[0], args[1:]

size, site = {}, {}
for lef in lefs:
    m = None
    for l in open(lef):
        t = l.split()
        if not t: continue
        if t[0] == "MACRO": m = t[1]
        elif m and t[0] == "SIZE": size[m] = (float(t[1]), float(t[3]))
        elif m and t[0] == "SITE": site.setdefault(m, t[1])
        elif m and t[0] == "END" and len(t) > 1 and t[1] == m: m = None

text = open(deff).read()
dbu = int(re.search(r"UNITS DISTANCE MICRONS (\d+)", text).group(1))
rows = {}
for m in re.finditer(r"^ROW \S+ \S+ (-?\d+) (-?\d+) (\S+) DO (\d+) BY \d+ STEP (\d+)", text, re.M):
    x0, y, o, n, st = int(m.group(1)), int(m.group(2)), m.group(3), int(m.group(4)), int(m.group(5))
    rows[y] = (o, x0, x0 + n * st, st)
rowys = sorted(rows)
rowh = rowys[1] - rowys[0]
comp = re.search(r"^COMPONENTS.*?^END COMPONENTS", text, re.M | re.S).group(0)
cells = []
for m in re.finditer(r"^\s*- (\S+) (\S+)\s*\n?\s*\+ (?:PLACED|FIXED) \( (-?\d+) (-?\d+) \) (\S+)", comp, re.M):
    cells.append((m.group(1), m.group(2), int(m.group(3)), int(m.group(4))))

bad = collections.Counter(); occ = collections.defaultdict(list); ruled = right = 0
for name, ref, x, y in cells:
    if ref not in size: bad["no size"] += 1; continue
    w, h = round(size[ref][0] * dbu), round(size[ref][1] * dbu)
    nrow = max(1, round(h / rowh))
    if y not in rows: bad["off row"] += 1; continue
    o, x0, x1, st = rows[y]
    if (x - x0) % st: bad["off site"] += 1
    if nrow > 1 and site.get(ref) in rule:
        ruled += 1
        if o == rule[site[ref]]: right += 1
        else: bad["wrong row orientation"] += 1
    for k in range(nrow):
        occ[y + k * rowh].append((x, x + w, name))
over = 0
for y, iv in occ.items():
    iv.sort()
    end = None
    for a, b, n in iv:
        if end is not None and a < end: over += 1
        end = b if end is None else max(end, b)
print(f"check_rowstart: {len(cells)} cell(s), {ruled} with a row-start rule, {right} on the right rows, "
      f"{over} overlap(s)" + "".join(f", {v} {k}" for k, v in sorted(bad.items())))

if shift_out:
    def sh(m):
        name, ref = m.group(1), m.group(2)
        if size.get(ref, (0, 0))[1] * dbu > rowh and site.get(ref) in rule:
            return m.group(0).replace(f"( {m.group(3)} {m.group(4)} )", f"( {m.group(3)} {int(m.group(4)) + rowh} )")
        return m.group(0)
    newcomp = re.sub(r"^\s*- (\S+) (\S+)\s*\n?\s*\+ (?:PLACED|FIXED) \( (-?\d+) (-?\d+) \) (\S+)", sh, comp, flags=re.M)
    open(shift_out, "w").write(text.replace(comp, newcomp))
    print(f"check_rowstart: wrote {shift_out} with the {ruled} ruled cell(s) one row up")
sys.exit(1 if over or bad else 0)
