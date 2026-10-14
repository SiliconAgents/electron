#!/usr/bin/env python3
"""measure.py -- run a command, record its wall time, CPU time and peak memory as JSON.

    measure.py <out.json> <command> [args...]

Used to time the electron side of the comparison.  The electron container has
no /usr/bin/time, and bash's time builtin gives no memory, so this does it
with getrusage: RUSAGE_CHILDREN's ru_maxrss is the peak resident set of the
largest process in the tree that was waited for -- electron itself, or yosys
if that was bigger -- in kilobytes on Linux.
"""
import json
import resource
import subprocess
import sys
import time


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    out, cmd = sys.argv[1], sys.argv[2:]
    t0 = time.time()
    rc = subprocess.call(cmd)
    wall = time.time() - t0
    ru = resource.getrusage(resource.RUSAGE_CHILDREN)
    res = {"command": " ".join(cmd), "returncode": rc,
           "wall_s": round(wall, 1), "cpu_s": round(ru.ru_utime + ru.ru_stime, 1),
           "peak_mb": round(ru.ru_maxrss / 1024.0, 1)}
    with open(out, "w") as fh:
        json.dump(res, fh, indent=1)
    print(f"measure: {res['wall_s']}s wall, {res['cpu_s']}s cpu, {res['peak_mb']}MB peak, rc {rc} -> {out}")
    return rc


if __name__ == "__main__":
    sys.exit(main())
