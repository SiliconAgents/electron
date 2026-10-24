#!/usr/bin/env python3
"""Two sgraphs of one design hold the same connections: every NETS row's net,
driver (instance, cell, pin) and sink (instance, cell, pin), positions and
status ignored.  Exits non-zero, with a count of each side's extras, if not.

  same_netlist.py a.sgraph b.sgraph
"""
import sys


def rows(path):
    out = []
    for line in open(path):
        if line.startswith("NETS "):
            f = line.split()
            if len(f) == 14:
                out.append((f[1], f[2], f[3], f[4], f[8], f[9], f[10]))
    return sorted(out)


a, b = rows(sys.argv[1]), rows(sys.argv[2])
if a != b:
    sa, sb = set(a), set(b)
    print(f"same_netlist: differ -- {len(sa - sb)} connection(s) only before, {len(sb - sa)} only after")
    for r in sorted(sa - sb)[:3]: print("  before only:", " ".join(r))
    for r in sorted(sb - sa)[:3]: print("  after only: ", " ".join(r))
    sys.exit(1)
print(f"same_netlist: {len(a)} connection(s), identical")
