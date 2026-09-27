#!/usr/bin/env python3
"""defmetrics -- measure a placed DEF, whichever tool wrote it.

    defmetrics.py --lef tech.lef [--lef cells.lef ...] design.def
                  [--ref other.def] [--max_degree N] [--json out.json]

Written so electron and OpenROAD can be compared on the same terms: neither
tool's own summary is used, only the DEF each one writes and the LEF both
read.  CLAUDE.md says not to trust a command's own report, and this is the
thing to check it with.

WHAT IT REPORTS

  size         components by status and LEF class, cell area, die area, and
               utilisation (cell area over die area)
  wirelength   half-perimeter wirelength over every net with two or more
               located terminals, using the real pin offsets from the LEF and
               the component's orientation, in microns.  --max_degree drops
               nets with more terminals than that, the usual way to keep a
               clock or reset net from dominating the total.
  legality     computed in integer DBU, never in microns: a float check invents
               an overlap at every row boundary (see CLAUDE.md, legalize_flat).
                 off_row    cells whose y is not the y of a ROW
                 off_site   cells on a row whose x is not on the site grid
                 overlaps   cells that overlap the cell before them in the
                            same row, counted per row a cell spans
                 outside    cells not wholly inside the DIEAREA
               overlaps is only exact when off_row is zero.  An unlegalised
               placement has cells between rows, and grouping by exact y would
               silently undercount them, so the overlap figure is then marked
               as a lower bound.
  connectivity from the LEF pin directions: nets with sinks but no driver,
               nets with more than one driver, and INPUT signal pins of placed
               cells that are on no net at all (floating inputs).  These are
               netlist errors whichever tool wrote the DEF.
  pin density  signal pins per --pin_grid (default 5um) tile, from the real
               pin positions: the worst tile, the 99th percentile of occupied
               tiles, and the count over 80.  What a router runs out of first.
  displacement with --ref, the manhattan distance each component moved between
               the two DEFs (matched by instance name), mean and worst.  Two
               DEFs of one design from electron are in different record orders
               every run; matching by name is what makes them comparable.

WHAT IT DOES NOT DO

  Timing, congestion, routing.  A routed DEF is read fine (the ROUTED
  sections are skipped) but the wires are not measured.

Pure Python, streaming, no dependencies.  Measured on a synthetic 855,424
component, 950,000 net DEF: 11 seconds and 0.8GB, so about a kilobyte a
component with its nets.
"""

import argparse
import json
import sys
import time
from collections import defaultdict


# ---------------------------------------------------------------------------
# LEF: macro sizes, classes and pin centres, in microns
# ---------------------------------------------------------------------------
def read_lef(path, macros):
    """Adds {name: {"w", "h", "cls", "pins": {pin: (x, y)}}} to macros."""
    cur = None          # macro being read
    pin = None          # pin being read, inside cur
    rects = []          # rects of the current pin
    in_obs = False
    with open(path, errors="replace") as fh:
        for line in fh:
            t = line.split()
            if not t:
                continue
            k = t[0]
            if cur is None:
                if k == "MACRO" and len(t) > 1:
                    cur = {"name": t[1], "w": 0.0, "h": 0.0, "cls": "", "pins": {}, "dir": {}, "use": {}}
                continue
            if pin is not None:
                if k == "RECT" and len(t) >= 5:
                    x1, y1, x2, y2 = (float(v) for v in t[1:5])
                    rects.append((min(x1, x2), min(y1, y2), max(x1, x2), max(y1, y2)))
                elif k == "POLYGON" and len(t) >= 7:
                    # the Nangate LEF draws its pins as polygons; the bounding
                    # box is what a pin centre means here
                    v = [float(s) for s in t[1:] if s != ";"]
                    xs = v[0::2]; ys = v[1::2]
                    rects.append((min(xs), min(ys), max(xs), max(ys)))
                elif k == "DIRECTION" and len(t) > 1:
                    cur["dir"][pin] = t[1].rstrip(";").upper()
                elif k == "USE" and len(t) > 1:
                    cur["use"][pin] = t[1].rstrip(";").upper()
                elif k == "END" and len(t) > 1 and t[1] == pin:
                    if rects:
                        lx = min(r[0] for r in rects); ly = min(r[1] for r in rects)
                        ux = max(r[2] for r in rects); uy = max(r[3] for r in rects)
                        cur["pins"][pin] = ((lx + ux) / 2.0, (ly + uy) / 2.0)
                    pin = None
                continue
            if in_obs:
                if k == "END" and len(t) == 1:
                    in_obs = False
                continue
            if k == "CLASS" and len(t) > 1:
                cur["cls"] = t[1].rstrip(";").upper()
            elif k == "SIZE" and len(t) >= 4:
                cur["w"] = float(t[1]); cur["h"] = float(t[3])
            elif k == "PIN" and len(t) > 1:
                pin = t[1]; rects = []
            elif k == "OBS":
                in_obs = True
            elif k == "END" and len(t) > 1 and t[1] == cur["name"]:
                macros[cur["name"]] = cur
                cur = None
    return macros


# A DEF location is the lower left of the placed (possibly rotated) box.
# Map a pin offset (px, py) in an unrotated w x h cell to that frame.
def orient_xy(o, px, py, w, h):
    if o == "N":  return px, py
    if o == "S":  return w - px, h - py
    if o == "FN": return w - px, py
    if o == "FS": return px, h - py
    if o == "E":  return py, w - px
    if o == "W":  return h - py, px
    if o == "FE": return py, px
    if o == "FW": return h - py, w - px
    return px, py


def orient_wh(o, w, h):
    return (h, w) if o in ("E", "W", "FE", "FW") else (w, h)


# ---------------------------------------------------------------------------
# DEF: streamed statement by statement
# ---------------------------------------------------------------------------
def statements(fh):
    """Yield (section, tokens) for each ';'-terminated statement.

    section is the enclosing COMPONENTS / PINS / NETS / SPECIALNETS / ... name,
    or None at the top level.  Keeps memory flat on a multi-GB file."""
    section = None
    buf = []
    for line in fh:
        t = line.split()
        if not t:
            continue
        if not buf:
            if t[0] == "END" and len(t) > 1 and t[1] == section:
                section = None
                continue
            if section is None and t[0] in ("COMPONENTS", "PINS", "NETS",
                                             "SPECIALNETS", "BLOCKAGES", "VIAS",
                                             "GROUPS", "REGIONS", "FILLS",
                                             "NONDEFAULTRULES", "PROPERTYDEFINITIONS"):
                section = t[0]
                continue
        buf.extend(t)
        if buf[-1] == ";" or buf[-1].endswith(";"):
            if buf[-1] != ";":
                buf[-1] = buf[-1][:-1]
                buf.append(";")
            yield section, buf
            buf = []
    if buf:
        yield section, buf


def placement_of(tok):
    """(status, x, y, orient) from a component or pin statement, or None."""
    for i, v in enumerate(tok):
        if v in ("PLACED", "FIXED", "COVER") and i + 5 < len(tok) and tok[i + 1] == "(":
            return v, int(round(float(tok[i + 2]))), int(round(float(tok[i + 3]))), tok[i + 5]
    return None


def read_def(path, want_nets=True):
    d = {"dbu": None, "design": None, "die": None, "rows": [],
         "comps": {}, "unplaced": 0, "pins": {}, "pin_dir": {}, "nets": []}
    with open(path, errors="replace") as fh:
        for sec, tok in statements(fh):
            if sec is None:
                k = tok[0]
                if k == "DESIGN" and len(tok) > 1:
                    d["design"] = tok[1]
                elif k == "UNITS" and len(tok) >= 4:
                    d["dbu"] = int(float(tok[3]))
                elif k == "DIEAREA":
                    pts = [(int(round(float(tok[i + 1]))), int(round(float(tok[i + 2]))))
                           for i, v in enumerate(tok) if v == "(" and i + 2 < len(tok)]
                    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
                    d["die"] = (min(xs), min(ys), max(xs), max(ys))
                elif k == "ROW" and len(tok) >= 7:
                    # ROW name site x y orient [DO nx BY ny STEP sx sy]
                    x, y = int(round(float(tok[3]))), int(round(float(tok[4])))
                    nx = ny = 1; sx = sy = 0
                    if "DO" in tok:
                        j = tok.index("DO"); nx = int(tok[j + 1]); ny = int(tok[j + 3])
                    if "STEP" in tok:
                        j = tok.index("STEP")
                        sx = int(round(float(tok[j + 1]))); sy = int(round(float(tok[j + 2])))
                    d["rows"].append((x, y, nx, ny, sx, sy, tok[2]))
            elif sec == "COMPONENTS" and tok[0] == "-" and len(tok) >= 3:
                p = placement_of(tok)
                if p is None:
                    d["unplaced"] += 1
                    d["comps"][tok[1]] = (tok[2], "UNPLACED", 0, 0, "N")
                else:
                    d["comps"][tok[1]] = (tok[2], p[0], p[1], p[2], p[3])
            elif sec == "PINS" and tok[0] == "-" and len(tok) >= 2:
                if "DIRECTION" in tok:
                    d["pin_dir"][tok[1]] = tok[tok.index("DIRECTION") + 1].upper()
                p = placement_of(tok)
                if p is not None:
                    cx = cy = 0
                    if "LAYER" in tok:           # centre of the pin shape, N only
                        j = tok.index("LAYER")
                        try:
                            x1 = float(tok[j + 3]); y1 = float(tok[j + 4])
                            x2 = float(tok[j + 7]); y2 = float(tok[j + 8])
                            cx = int(round((x1 + x2) / 2)); cy = int(round((y1 + y2) / 2))
                        except (ValueError, IndexError):
                            pass
                    d["pins"][tok[1]] = (p[1] + cx, p[2] + cy)
            elif want_nets and sec == "NETS" and tok[0] == "-" and len(tok) >= 2:
                terms = []
                i = 2
                n = len(tok)
                while i < n:
                    v = tok[i]
                    if v == "+" or v == ";":
                        break                    # ROUTED and friends follow
                    if v == "(" and i + 3 < n and tok[i + 3] == ")":
                        terms.append((tok[i + 1], tok[i + 2]))
                        i += 4
                        continue
                    i += 1
                d["nets"].append(terms)
    if d["dbu"] is None:
        d["dbu"] = 1000
    return d


# ---------------------------------------------------------------------------
# metrics
# ---------------------------------------------------------------------------
def measure(d, macros, max_degree=0, pin_grid=5.0):
    dbu = d["dbu"]
    um = lambda v: v / float(dbu)
    res = {"design": d["design"], "dbu": dbu}

    # --- size ---
    by_status = defaultdict(int); by_class = defaultdict(int)
    area = 0.0; missing = set()
    for name, (cell, st, x, y, o) in d["comps"].items():
        by_status[st] += 1
        m = macros.get(cell)
        if m is None:
            missing.add(cell); continue
        by_class[m["cls"] or "?"] += 1
        area += m["w"] * m["h"]
    res["components"] = len(d["comps"])
    res["by_status"] = dict(by_status)
    res["by_class"] = dict(by_class)
    res["cells_missing_from_lef"] = sorted(missing)[:20]
    res["n_cells_missing_from_lef"] = len(missing)
    res["cell_area_um2"] = round(area, 3)
    if d["die"]:
        lx, ly, ux, uy = d["die"]
        die_area = um(ux - lx) * um(uy - ly)
        res["die_um"] = [um(lx), um(ly), um(ux), um(uy)]
        res["die_area_um2"] = round(die_area, 3)
        res["utilisation"] = round(area / die_area, 4) if die_area else None
    res["pins_placed"] = len(d["pins"])

    # --- wirelength ---
    hpwl = 0; nets_used = 0; nets_skipped = 0; nets_high = 0; unlocated = 0
    comps = d["comps"]; pins = d["pins"]
    tile = max(1, int(round(pin_grid * dbu)))
    density = defaultdict(int)
    for terms in d["nets"]:
        if max_degree and len(terms) > max_degree:
            nets_high += 1; continue
        lx = ly = None
        cnt = 0
        for inst, pin in terms:
            if inst == "PIN":
                p = pins.get(pin)
                if p is None:
                    unlocated += 1; continue
                x, y = p
            else:
                c = comps.get(inst)
                if c is None or c[1] == "UNPLACED":
                    unlocated += 1; continue
                cell, st, cx, cy, o = c
                m = macros.get(cell)
                if m is None:
                    x, y = cx, cy
                else:
                    off = m["pins"].get(pin)
                    if off is None:
                        w, h = orient_wh(o, m["w"], m["h"])
                        x, y = cx + w * dbu / 2.0, cy + h * dbu / 2.0
                    else:
                        px, py = orient_xy(o, off[0], off[1], m["w"], m["h"])
                        x, y = cx + px * dbu, cy + py * dbu
                    density[(int(x) // tile, int(y) // tile)] += 1
            if lx is None:
                lx = ux = x; ly = uy = y
            else:
                if x < lx: lx = x
                if x > ux: ux = x
                if y < ly: ly = y
                if y > uy: uy = y
            cnt += 1
        if cnt >= 2:
            hpwl += (ux - lx) + (uy - ly); nets_used += 1
        else:
            nets_skipped += 1
    res["nets"] = len(d["nets"])
    res["hpwl_um"] = round(um(hpwl), 3)
    res["hpwl_nets"] = nets_used
    res["nets_under_two_located_terminals"] = nets_skipped
    res["nets_over_max_degree"] = nets_high
    res["terminals_unlocated"] = unlocated

    # --- pin density: signal pins on nets, per tile ---
    if density:
        vals = sorted(density.values())
        res["pin_tile_um"] = pin_grid
        res["pin_tile_worst"] = vals[-1]
        res["pin_tile_p99"] = vals[min(len(vals) - 1, int(0.99 * len(vals)))]
        res["pin_tiles_over_80"] = sum(1 for v in vals if v > 80)

    # --- connectivity, from LEF pin directions ---
    seen = set()
    undriven = multi = dangling = 0
    ex_undriven = []; ex_multi = []
    for terms in d["nets"]:
        drv = snk = 0
        for inst, pin in terms:
            if inst == "PIN":
                pd = d["pin_dir"].get(pin, "")
                if pd == "INPUT": drv += 1
                elif pd == "OUTPUT": snk += 1
                continue
            seen.add((inst, pin))
            c = comps.get(inst)
            m = macros.get(c[0]) if c else None
            if m is None:
                continue
            dr = m["dir"].get(pin, "")
            if dr == "OUTPUT": drv += 1
            elif dr == "INPUT": snk += 1
        if snk and not drv:
            undriven += 1
            if len(ex_undriven) < 3: ex_undriven.append(terms[:3])
        elif drv > 1:
            multi += 1
            if len(ex_multi) < 3: ex_multi.append(terms[:3])
        elif drv and not snk:
            dangling += 1
    floating = 0; ex_float = []
    for name, (cell, st, x, y, o) in comps.items():
        m = macros.get(cell)
        if m is None:
            continue
        for pin, dr in m["dir"].items():
            if dr != "INPUT" or m["use"].get(pin, "SIGNAL") in ("POWER", "GROUND"):
                continue
            if (name, pin) not in seen:
                floating += 1
                if len(ex_float) < 3: ex_float.append(f"{name}/{pin}")
    res["nets_undriven"] = undriven
    res["nets_multi_driven"] = multi
    res["nets_driven_no_sink"] = dangling
    res["inputs_floating"] = floating
    res["connectivity_ok"] = (undriven == 0 and multi == 0 and floating == 0)
    if ex_undriven: res["example_undriven"] = ex_undriven
    if ex_multi: res["example_multi_driven"] = ex_multi
    if ex_float: res["example_floating_inputs"] = ex_float

    # --- legality, integer DBU ---
    row_y = {}                       # y -> (row x, site step, count)
    row_h = None
    for (x, y, nx, ny, sx, sy, site) in d["rows"]:
        for j in range(max(ny, 1)):
            yy = y + j * sy
            row_y[yy] = (x, sx, nx)
    ys = sorted(row_y)
    if len(ys) >= 2:
        row_h = min(b - a for a, b in zip(ys, ys[1:]) if b > a)
    off_row = off_site = outside = 0
    per_row = defaultdict(list)
    die = d["die"]
    for name, (cell, st, x, y, o) in comps.items():
        if st == "UNPLACED":
            continue
        m = macros.get(cell)
        if m is None:
            continue
        w, h = orient_wh(o, m["w"], m["h"])
        wd = int(round(w * dbu)); hd = int(round(h * dbu))
        if die and (x < die[0] or y < die[1] or x + wd > die[2] or y + hd > die[3]):
            outside += 1
        if m["cls"] not in ("CORE", ""):
            continue                     # macros, pads, blocks: not row cells
        r = row_y.get(y)
        if r is None:
            off_row += 1; continue
        rx, step, _ = r
        if step and (x - rx) % step:
            off_site += 1
        span = max(1, int(round(hd / row_h))) if row_h else 1
        for j in range(span):
            per_row[y + j * (row_h or 0)].append((x, x + wd))
    overlaps = 0
    for yy, iv in per_row.items():
        iv.sort()
        end = None
        for a, b in iv:
            if end is not None and a < end:
                overlaps += 1
            if end is None or b > end:
                end = b
    res["rows"] = len(row_y)
    res["off_row"] = off_row
    res["off_site"] = off_site
    res["overlaps"] = overlaps
    res["overlaps_exact"] = (off_row == 0)
    res["outside_die"] = outside
    res["legal"] = (off_row == 0 and off_site == 0 and overlaps == 0 and outside == 0
                    and by_status.get("UNPLACED", 0) == 0)
    return res


def displacement(d, ref):
    n = 0; tot = 0; worst = 0; worst_name = None; moved = 0
    for name, (cell, st, x, y, o) in d["comps"].items():
        r = ref["comps"].get(name)
        if r is None or st == "UNPLACED" or r[1] == "UNPLACED":
            continue
        # the two may use different DBU
        dx = abs(x / d["dbu"] - r[2] / ref["dbu"])
        dy = abs(y / d["dbu"] - r[3] / ref["dbu"])
        m = dx + dy
        n += 1; tot += m
        if m > 1e-9: moved += 1
        if m > worst: worst = m; worst_name = name
    return {"matched": n, "moved": moved,
            "mean_um": round(tot / n, 4) if n else None,
            "worst_um": round(worst, 4), "worst_instance": worst_name}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("def_file")
    ap.add_argument("--lef", action="append", required=True,
                    help="tech and cell LEFs, repeat as needed")
    ap.add_argument("--ref", help="second DEF to measure displacement against")
    ap.add_argument("--max_degree", type=int, default=0,
                    help="leave out nets with more terminals than this (0 keeps all)")
    ap.add_argument("--pin_grid", type=float, default=5.0,
                    help="tile size in um for the pin density map, default 5")
    ap.add_argument("--json", help="also write the results here")
    a = ap.parse_args()

    t0 = time.time()
    macros = {}
    for f in a.lef:
        read_lef(f, macros)
    d = read_def(a.def_file)
    res = measure(d, macros, a.max_degree, a.pin_grid)
    if a.ref:
        res["displacement_vs_ref"] = displacement(d, read_def(a.ref, want_nets=False))
    res["def"] = a.def_file
    res["seconds"] = round(time.time() - t0, 2)

    w = max(len(k) for k in res)
    for k, v in res.items():
        print(f"{k:<{w}}  {v}")
    if a.json:
        with open(a.json, "w") as fh:
            json.dump(res, fh, indent=1)
    return 0 if res["n_cells_missing_from_lef"] == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
