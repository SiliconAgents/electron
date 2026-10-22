#!/usr/bin/env python3
"""Check a DEF that apply_advice repeated against the DEF it started from.

    check_repeat.py <placed.def> <applied.def> <cells.lef>

Independent of electron: reads both DEFs and the LEF and checks that

  * every net of the placed DEF still reaches exactly the pins it reached --
    from the net of the same name, through any NEW instance's input to its
    output's net -- so no sink was lost, duplicated or sent to another net;
  * every new instance is a one-in one-out cell with both pins connected;
  * no two cells overlap, in integer DBU (a float check invents overlaps at
    row boundaries).

Prints a summary; exits 1 on any failure.
"""
import re
import sys
from collections import defaultdict


def read_lef(path):
    size, dirs, cur, pin = {}, defaultdict(dict), None, None
    for line in open(path):
        t = line.split()
        if not t:
            continue
        if t[0] == "MACRO":
            cur = t[1]
        elif t[0] == "SIZE" and cur:
            size[cur] = (float(t[1]), float(t[3]))
        elif t[0] == "PIN" and cur:
            pin = t[1]
        elif t[0] == "DIRECTION" and cur and pin:
            dirs[cur][pin] = t[1].rstrip(";").upper()
        elif t[0] == "USE" and cur and pin and t[1].rstrip(";").upper() in ("POWER", "GROUND"):
            dirs[cur].pop(pin, None)
        elif t[0] == "END" and len(t) > 1 and t[1] == pin:
            pin = None
        elif t[0] == "END" and len(t) > 1 and t[1] == cur:
            cur = None
    return size, dirs


def read_def(path):
    text = open(path).read()
    dbu = int(re.search(r"UNITS\s+DISTANCE\s+MICRONS\s+(\d+)", text).group(1))
    comps = {}
    sec = re.search(r"^COMPONENTS\s+\d+\s*;(.*?)^END COMPONENTS", text, re.S | re.M).group(1)
    for rec in sec.split(";"):
        m = re.search(r"-\s+(\S+)\s+(\S+).*?\+\s+(?:PLACED|FIXED)\s+\(\s*(-?\d+)\s+(-?\d+)\s*\)\s*(\S+)", rec, re.S)
        if m:
            comps[m.group(1)] = (m.group(2), int(m.group(3)), int(m.group(4)), m.group(5))
        else:
            m = re.search(r"-\s+(\S+)\s+(\S+)", rec)
            if m:
                comps[m.group(1)] = (m.group(2), None, None, None)
    nets = {}
    sec = re.search(r"^NETS\s+\d+\s*;(.*?)^END NETS", text, re.S | re.M).group(1)
    for rec in re.split(r";\s*\n", sec):
        m = re.match(r"\s*-\s+(\S+)", rec)
        if not m:
            continue
        body = re.split(r"\+\s*(?:ROUTED|FIXED|COVER|NOSHIELD|USE|SOURCE)", rec[m.end():])[0]
        nets[m.group(1)] = [(a, b) for a, b in re.findall(r"\(\s*(\S+)\s+(\S+)\s*\)", body)]
    return dbu, comps, nets


def main(placed, applied, lef):
    size, dirs = read_lef(lef)
    dbu0, comps0, nets0 = read_def(placed)
    dbu, comps, nets = read_def(applied)
    fails = []
    new = set(comps) - set(comps0)
    gone = set(comps0) - set(comps)
    if gone:
        fails.append(f"{len(gone)} instance(s) of the placed DEF are missing, e.g. {sorted(gone)[0]}")

    netOf = {}
    for n, pins in nets.items():
        for p in pins:
            netOf[p] = n
    ioOf = {}
    for b in new:
        cell = comps[b][0]
        ins = [p for p, d in dirs.get(cell, {}).items() if d == "INPUT"]
        outs = [p for p, d in dirs.get(cell, {}).items() if d == "OUTPUT"]
        if len(ins) != 1 or len(outs) != 1:
            fails.append(f"new instance {b} ({cell}) is not one-in one-out")
            continue
        if (b, ins[0]) not in netOf or (b, outs[0]) not in netOf:
            fails.append(f"new instance {b} has an unconnected pin")
            continue
        ioOf[b] = (ins[0], outs[0])

    def reach(net, seen):
        out = []
        for inst, pin in nets.get(net, []):
            if inst in ioOf:
                i, o = ioOf[inst]
                if pin == i:
                    on = netOf[(inst, o)]
                    if on in seen:
                        return None
                    seen.add(on)
                    r = reach(on, seen)
                    if r is None:
                        return None
                    out += r
                continue
            out.append((inst, pin))
        return out

    repeated, bad = 0, 0
    for n, pins in nets0.items():
        got = reach(n, {n})
        if got is None or sorted(got) != sorted(pins):
            bad += 1
            if bad <= 5:
                fails.append(f"net {n}: reaches {len(got) if got else 0} pin(s), had {len(pins)}")
        elif len(nets.get(n, [])) != len(pins):
            repeated += 1
    if bad:
        fails.append(f"{bad} net(s) no longer reach exactly their original pins")

    # overlaps, integer DBU, on a grid of 10x10 um tiles
    tile = 10 * dbu
    grid = defaultdict(list)
    rects = []
    for name, (cell, x, y, _o) in comps.items():
        if x is None or cell not in size:
            continue
        w, h = round(size[cell][0] * dbu), round(size[cell][1] * dbu)
        k = len(rects)
        rects.append((x, y, x + w, y + h, name))
        for tx in range(x // tile, (x + w - 1) // tile + 1):
            for ty in range(y // tile, (y + h - 1) // tile + 1):
                grid[(tx, ty)].append(k)
    ov = set()
    for ks in grid.values():
        for a in range(len(ks)):
            ra = rects[ks[a]]
            for b in range(a + 1, len(ks)):
                rb = rects[ks[b]]
                if ra[0] < rb[2] and rb[0] < ra[2] and ra[1] < rb[3] and rb[1] < ra[3]:
                    ov.add((min(ks[a], ks[b]), max(ks[a], ks[b])))
    if ov:
        a, b = next(iter(ov))
        fails.append(f"{len(ov)} overlapping pair(s), e.g. {rects[a][4]} / {rects[b][4]}")

    print(f"check_repeat: {len(new)} new instance(s), {repeated} net(s) repeated, "
          f"{len(nets0) - bad} of {len(nets0)} net(s) reach exactly their original pins, {len(ov)} overlap(s)")
    for f in fails:
        print("check_repeat: FAIL: " + f)
    return 1 if fails else 0


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    sys.exit(main(*sys.argv[1:]))
