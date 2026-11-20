#!/usr/bin/env python3
"""netcompare.py -- is the netlist in a placed DEF the netlist synthesis produced?

    netcompare.py <flat.json> <placed.def> [--lef cells.lef] [--json out.json]

<flat.json> is yosys's view of the synthesised netlist, flattened:

    yosys -p "read_verilog <netlist.v>; hierarchy -top <top>; flatten; write_json flat.json"

Every leaf cell of that flat netlist is expected in the DEF under the same
hierarchical name (yosys joins levels with ".", DEF with "/"), with the same
cell type, and every net -- one yosys bit -- is expected to connect exactly
the same cell pins and ports in the DEF.

Electron turns each "assign" into a buffer cell, bt_assign_buf_N, and may add
tie cells, bt_assign_tie_N.  Neither is in the synthesised netlist, so each
assign buffer is collapsed back into a wire (its A and Z nets are merged)
before comparing, and a tie cell's net counts as a constant.

Reported per yosys net:
  exact       the same terminals, on one DEF net, and nothing else on it
  split       its terminals are spread over more than one DEF net
  merged      one DEF net also carries terminals of another yosys net
  missing     a terminal is on no DEF net at all
and for the constant bits (yosys "0"/"1"): how many cell inputs that should
see a constant are on a DEF net with no driver.
"""
import argparse
import json
import sys
from collections import defaultdict

sys.path.insert(0, __file__.rsplit("/", 3)[0])      # TESTS, for defmetrics
import defmetrics as dm


class DSU:
    def __init__(self):
        self.p = {}

    def find(self, x):
        p = self.p
        p.setdefault(x, x)
        while p[x] != x:
            p[x] = p[p[x]]
            x = p[x]
        return x

    def union(self, a, b):
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            self.p[ra] = rb


def load_yosys(path):
    y = json.load(open(path))
    top = [n for n, m in y["modules"].items() if m.get("attributes", {}).get("top")]
    if not top:
        if len(y["modules"]) != 1:
            raise SystemExit("cannot tell which module is the flattened top")
        top = list(y["modules"])
    mod = y["modules"][top[0]]
    bits = defaultdict(list)          # bit -> [(inst, pin)]
    const = defaultdict(list)         # "0"/"1" -> [(inst, pin)]
    cells = {}
    for cname, c in mod["cells"].items():
        name = cname.lstrip("\\").replace(".", "/")
        cells[name] = c["type"].lstrip("\\")
        for pin, bl in c["connections"].items():
            for k, b in enumerate(bl):
                p = pin if len(bl) == 1 else f"{pin}[{k}]"
                if isinstance(b, str):
                    const[b].append((name, p))
                else:
                    bits[b].append((name, p))
    for pname, p in mod["ports"].items():
        bl = p["bits"]
        for k, b in enumerate(bl):
            n = pname if len(bl) == 1 else f"{pname}[{k}]"
            if not isinstance(b, str):
                bits[b].append(("PIN", n))
    return top[0], cells, bits, const


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("flat_json")
    ap.add_argument("def_file")
    ap.add_argument("--lef", action="append", default=[])
    ap.add_argument("--json")
    a = ap.parse_args()

    top, ycells, ybits, yconst = load_yosys(a.flat_json)
    d = dm.read_def(a.def_file)
    comps = d["comps"]

    # DEF nets as groups of terminals, assign buffers collapsed into wires
    dsu = DSU()
    term_net = {}
    for i, terms in enumerate(d["nets"]):
        for t in terms:
            if t in term_net:
                dsu.union(("net", i), ("net", term_net[t]))
            term_net[t] = i
            dsu.find(("net", i))
    bufs = [n for n in comps if n.rsplit("/", 1)[-1].startswith("bt_assign_buf")]
    ties = {n for n in comps if n.rsplit("/", 1)[-1].startswith("bt_assign_tie")}
    for b in bufs:
        na = term_net.get((b, "A")); nz = term_net.get((b, "Z"))
        if na is not None and nz is not None:
            dsu.union(("net", na), ("net", nz))
    added = set(bufs) | ties

    def group(t):
        i = term_net.get(t)
        return None if i is None else dsu.find(("net", i))

    members = defaultdict(set)
    for t, i in term_net.items():
        if t[0] in added:
            continue
        members[dsu.find(("net", i))].add(t)

    res = {"top": top, "yosys_cells": len(ycells), "def_components": len(comps),
           "assign_buffers": len(bufs), "tie_cells": len(ties)}

    # cells
    missing_cells = [n for n in ycells if n not in comps]
    wrong_type = [n for n in ycells if n in comps and comps[n][0] != ycells[n]]
    extra = [n for n in comps if n not in ycells and n not in added]
    res["cells_missing_from_def"] = len(missing_cells)
    res["cells_wrong_type"] = len(wrong_type)
    res["def_cells_not_in_netlist"] = len(extra)
    if missing_cells: res["example_missing_cells"] = missing_cells[:3]
    if wrong_type: res["example_wrong_type"] = [(n, ycells[n], comps[n][0]) for n in wrong_type[:3]]
    if extra: res["example_extra_cells"] = extra[:3]

    # nets
    exact = split = merged = missing = 0
    ex = defaultdict(list)
    claimed = defaultdict(int)
    for b, terms in ybits.items():
        gs = set()
        miss = False
        for t in terms:
            g = group(t)
            if g is None:
                miss = True
            else:
                gs.add(g)
        if miss:
            missing += 1
            if len(ex["missing"]) < 3: ex["missing"].append(terms[:3])
            continue
        if len(gs) > 1:
            split += 1
            if len(ex["split"]) < 3: ex["split"].append(terms[:3])
            continue
        if not gs:
            continue
        g = gs.pop()
        claimed[g] += 1
        if members[g] == set(terms):
            exact += 1
        else:
            merged += 1
            if len(ex["merged"]) < 3: ex["merged"].append(terms[:3])
    res["yosys_nets"] = len(ybits)
    res["nets_exact"] = exact
    res["nets_split"] = split
    res["nets_merged"] = merged
    res["nets_missing_terminal"] = missing

    # constants
    macros = {}
    for f in a.lef:
        dm.read_lef(f, macros)
    const_terms = sum(len(v) for v in yconst.values())
    undriven = 0
    # a constant input is driven when its DEF net has a driver: a tie cell,
    # or any cell output (a DEF net's drivers are its cells' OUTPUT pins)
    drivers = defaultdict(bool)
    for t, i in term_net.items():
        inst, pin = t
        if inst in ties:
            drivers[dsu.find(("net", i))] = True
        elif inst != "PIN" and inst in comps and macros:
            if macros.get(comps[inst][0], {}).get("dir", {}).get(pin) == "OUTPUT":
                drivers[dsu.find(("net", i))] = True
    for v, terms in yconst.items():
        for t in terms:
            g = group(t)
            if g is None or not drivers.get(g):
                undriven += 1
    res["constant_inputs"] = const_terms
    res["constant_inputs_undriven"] = undriven if macros else None
    res["netlist_preserved"] = (exact == len(ybits) and not missing_cells and not wrong_type
                                and (undriven == 0 if macros else True))
    for k, v in ex.items():
        res[f"example_{k}"] = v

    w = max(len(k) for k in res)
    for k, v in res.items():
        print(f"{k:<{w}}  {v}")
    if a.json:
        json.dump(res, open(a.json, "w"), indent=1, default=str)


if __name__ == "__main__":
    main()
