#!/usr/bin/env python3
"""compare.py -- electron against OpenROAD, side by side, from their DEFs.

    compare.py --electron metrics.json [--electron_time time.json]
               --openroad metrics.json [--openroad_logs <ORFS logs dir>]

The metrics files are what TESTS/defmetrics.py --json writes, one per tool,
each measured from the DEF that tool wrote.  Nothing either tool says about
itself is used, apart from run time and memory.

Run time for OpenROAD is the sum of the "Elapsed time" lines ORFS prints at
the end of every step, and peak memory is the largest "Peak memory" among
them.  Only the steps up to placement are counted, so the two sides cover the
same work: synthesis, floorplan, placement.
"""
import argparse
import glob
import json
import os
import re

ELAPSED = re.compile(r"Elapsed time:\s*(?:(\d+):)?(\d+):(\d+(?:\.\d+)?)")
PEAK = re.compile(r"Peak memory:\s*(\d+)\s*KB", re.I)


def orfs_time(logdir):
    """(seconds, peak MB, steps) over the synth, floorplan and place logs."""
    if not logdir or not os.path.isdir(logdir):
        return None
    tot = 0.0; peak = 0; steps = 0
    for f in sorted(glob.glob(os.path.join(logdir, "*.log"))):
        base = os.path.basename(f)
        if not base[:1] in "123":          # 1_ synth, 2_ floorplan, 3_ place
            continue
        with open(f, errors="replace") as fh:
            text = fh.read()
        for m in ELAPSED.finditer(text):
            h, mi, s = m.groups()
            tot += (int(h) if h else 0) * 3600 + int(mi) * 60 + float(s)
            steps += 1
        for m in PEAK.finditer(text):
            peak = max(peak, int(m.group(1)))
    return {"wall_s": round(tot, 1), "peak_mb": round(peak / 1024.0, 1), "steps": steps}


def fmt(v):
    if v is None:
        return "-"
    if isinstance(v, bool):
        return "yes" if v else "NO"
    if isinstance(v, float):
        return f"{v:,.3f}" if abs(v) < 1000 else f"{v:,.0f}"
    if isinstance(v, int):
        return f"{v:,}"
    return str(v)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--electron", required=True)
    ap.add_argument("--openroad", required=True)
    ap.add_argument("--electron_time")
    ap.add_argument("--openroad_logs")
    a = ap.parse_args()

    e = json.load(open(a.electron))
    o = json.load(open(a.openroad))
    et = json.load(open(a.electron_time)) if a.electron_time and os.path.exists(a.electron_time) else {}
    ot = orfs_time(a.openroad_logs) or {}

    def per(m, k):
        return (m.get(k) / m["components"]) if m.get(k) is not None and m.get("components") else None

    rows = [
        ("design",                     e.get("design"),          o.get("design")),
        ("components",                 e.get("components"),      o.get("components")),
        ("  of which CORE",            e.get("by_class", {}).get("CORE"), o.get("by_class", {}).get("CORE")),
        ("cell area um2",              e.get("cell_area_um2"),   o.get("cell_area_um2")),
        ("die area um2",               e.get("die_area_um2"),    o.get("die_area_um2")),
        ("utilisation",                e.get("utilisation"),     o.get("utilisation")),
        ("nets",                       e.get("nets"),            o.get("nets")),
        ("HPWL um",                    e.get("hpwl_um"),         o.get("hpwl_um")),
        ("HPWL per net um",            (e["hpwl_um"] / e["hpwl_nets"]) if e.get("hpwl_nets") else None,
                                       (o["hpwl_um"] / o["hpwl_nets"]) if o.get("hpwl_nets") else None),
        ("unplaced components",        e.get("by_status", {}).get("UNPLACED", 0), o.get("by_status", {}).get("UNPLACED", 0)),
        ("off row",                    e.get("off_row"),         o.get("off_row")),
        ("off site",                   e.get("off_site"),        o.get("off_site")),
        ("overlaps",                   e.get("overlaps"),        o.get("overlaps")),
        ("outside die",                e.get("outside_die"),     o.get("outside_die")),
        ("legal",                      e.get("legal"),           o.get("legal")),
        ("wall time s (synth..place)", et.get("wall_s"),         ot.get("wall_s")),
        ("peak memory MB",             et.get("peak_mb"),        ot.get("peak_mb")),
    ]
    w = max(len(r[0]) for r in rows)
    print(f"{'':<{w}}  {'electron':>16}  {'OpenROAD':>16}  {'OpenROAD/electron':>18}")
    for name, ev, ov in rows:
        ratio = ""
        if isinstance(ev, (int, float)) and isinstance(ov, (int, float)) and not isinstance(ev, bool) and ev:
            ratio = f"{ov / ev:.2f}x"
        print(f"{name:<{w}}  {fmt(ev):>16}  {fmt(ov):>16}  {ratio:>18}")
    notes = []
    if e.get("n_cells_missing_from_lef") or o.get("n_cells_missing_from_lef"):
        notes.append("some cells were not in the LEF given to defmetrics; area and legality undercount")
    if not e.get("overlaps_exact", True) or not o.get("overlaps_exact", True):
        notes.append("a placement has cells off the rows, so its overlap count is a lower bound")
    if e.get("components") and o.get("components") and abs(o["components"] - e["components"]) > 0.02 * e["components"]:
        notes.append("instance counts differ by more than 2%: the netlists are not the same, "
                     "compare HPWL per net rather than totals")
    for n in notes:
        print("note:", n)


if __name__ == "__main__":
    main()
