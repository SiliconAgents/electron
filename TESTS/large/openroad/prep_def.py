#!/usr/bin/env python3
"""prep_def.py -- make an electron DEF readable by OpenROAD, changing nothing else.

    prep_def.py <in.def> <out.def> [--unplace]

Two things in electron's DEF writer stop OpenROAD's parser, and both are
fixed here without touching a coordinate or a connection:

  * DESIGN is written after UNITS.  OpenDB needs the design named before it
    can accept the units ("DESIGN is not defined in DEF", DEFPARS-6010).
  * PINS directions and uses are lower case ("output", "signal").

OpenROAD also refuses a DEF finer than its LEF.  Electron writes 4000 DBU
against the Nangate LEF's 2000, so read it with a copy of the LEF that says
DATABASE MICRONS 4000; LEF geometry is in microns, so nothing else changes.

--unplace turns every component into UNPLACED, keeping die, rows and the
placed ports, for handing electron's exact netlist to another placer.
"""
import re
import sys


def main():
    src, dst = sys.argv[1], sys.argv[2]
    unplace = "--unplace" in sys.argv[3:]
    lines = open(src).read().split("\n")
    head = lines[:40]
    iu = next((i for i, l in enumerate(head) if l.startswith("UNITS")), None)
    idn = next((i for i, l in enumerate(head) if l.startswith("DESIGN ")), None)
    if iu is not None and idn is not None and idn > iu:
        lines.insert(iu, lines.pop(idn))
    sec = None
    n = 0
    out = []
    for line in lines:
        t = line.split()
        if t and t[0] in ("COMPONENTS", "PINS", "NETS"):
            sec = t[0]
        elif t and t[0] == "END":
            sec = None
        if sec == "PINS":
            line = re.sub(r"DIRECTION\s+(\w+)", lambda m: "DIRECTION " + m.group(1).upper(), line)
            line = re.sub(r"USE\s+(\w+)", lambda m: "USE " + m.group(1).upper(), line)
        elif sec == "COMPONENTS" and unplace:
            new = re.sub(r"\+\s*(PLACED|FIXED)\s*\(\s*-?[\d.]+\s+-?[\d.]+\s*\)\s*\w+", "+ UNPLACED", line)
            n += new != line
            line = new
        out.append(line)
    open(dst, "w").write("\n".join(out))
    print(f"prep_def: {src} -> {dst}" + (f", {n} components unplaced" if unplace else ""))


if __name__ == "__main__":
    main()
