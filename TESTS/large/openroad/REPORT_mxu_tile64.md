# Electron against OpenROAD: mxu_tile64

Measured on 27 September 2026. Design: `mxu_tile64`, the 8x8 systolic matrix unit in
`TESTS/large/rtls/mxu`, on Nangate45, at 50% utilisation, a square die and a 10 ns clock.

## Summary

- **Correctness is where electron falls short.** Its placement is legal and reproducible,
  and every synthesised cell and net survives placement exactly. But 32,128 cell inputs
  that should be tied to logic 0 are left undriven, and its ports cannot be routed as
  written. OpenROAD's result has neither problem.
- **Quality: OpenROAD is clearly better on the same netlist.** Placing electron's own
  netlist, OpenROAD gets half the wirelength, 43% less global-route wire, half the routing
  usage and lower pin density. Both route without overflow and both meet 10 ns easily.
- **Performance: electron finishes first end to end, OpenROAD places faster.** Electron
  runs synthesis to detailed placement in 200 to 269 s on one core; ORFS takes 512 s on up
  to 12 threads. Placing the same netlist, OpenROAD's placers take 94 s against electron's
  174 to 241 s.
- **Electron's detailed placement is essential.** Without `improve_congestion`, electron's
  legalised placement is heavily congested (112% of routing capacity) and has twice the
  wirelength.

## What was compared

Two experiments, all results measured by the same independent checks, never by either
tool's own report.

1. **End to end.** Each tool synthesises the same RTL its own way and places the result.
   Electron: `synthesize`, `set_floorplan`, `hier_place_all`, `legalize_flat`,
   `improve_congestion`. OpenROAD: the ORFS flow through the `place` stage, with timing-
   and routability-driven placement off to match electron's wirelength-only placers.
2. **Same netlist.** OpenROAD's global and detailed placers run on electron's exact
   netlist (213,568 instances), with electron's die, rows and port locations. This isolates
   placement quality from synthesis.

Each placement is scored three ways:

- `TESTS/defmetrics.py` reads the DEF and LEF only: legality in integer DBU, HPWL from
  real pin positions, pin density per 5 µm tile, and connectivity from LEF pin directions.
- `netcompare.py` checks electron's placed netlist connection by connection against the
  netlist yosys produced.
- `judge.tcl` runs one OpenROAD engine on every DEF: OpenSTA with placement-estimated
  parasitics, then FastRoute global routing with the ORFS Nangate45 settings, then timing
  again from the routes.

## Performance

| | electron | OpenROAD (ORFS) |
|---|---|---|
| Synthesis and read-in | about 20 s | 105 s |
| Floorplan | 1 s | 28 s (with tap cells and power grid) |
| Placement | 174 s and 241 s | 380 s |
| **Total wall time** | **200 s and 269 s** (two runs) | **512 s** (569 s with container start and DEF export) |
| CPU time | 201 s | 1,082 s |
| Peak memory | 1.31 GB | 0.95 GB |

Electron's placement time breaks down as `hier_place_all` 60 to 67 s, `legalize_flat`
7 to 8 s and `improve_congestion` 106 to 167 s over the two runs, which is the run-to-run
noise on this machine. ORFS's breaks down as global placement 114 s, resizing 118 s and
detailed placement 147 s. ORFS was run once, so it has no such range. Electron's synthesis is fast because yosys handles each of
the 14 distinct modules once; ORFS flattens and optimises the whole design.

Placement alone, on the same netlist:

| | electron | OpenROAD |
|---|---|---|
| Global placement | 60 to 67 s (`hier_place_all`) | 85 s |
| Legalisation and detailed placement | 114 to 174 s | 9 s |
| Wall time | 174 to 241 s | 94 s |
| CPU time | same as wall, one thread | 305 s on 12 threads |
| Peak memory | 1.31 GB | 0.70 GB |

Electron's global placement is competitive thanks to its hierarchy; its detailed placement
is where the time goes.

## Quality

### Same netlist (placement only)

| | electron | OpenROAD | OpenROAD / electron |
|---|---|---|---|
| HPWL | 3,486,164 µm | 1,763,292 µm | 0.51x |
| HPWL per net | 17.7 µm | 8.9 µm | 0.51x |
| Global-route wirelength | 4,688,224 µm | 2,677,771 µm | 0.57x |
| Routing usage | 39.6% | 20.6% | 0.52x |
| Global-route overflow | 0 | 0 | |
| Worst 5 µm tile, signal pins | 87 | 61 | 0.70x |
| 99th percentile tile | 73 | 51 | 0.70x |
| Tiles over 80 pins | 10 | 0 | |
| Worst slack after routing | +7.29 ns | +7.14 ns | |
| Negative slack | 0 | 0 | |

Both meet the 10 ns clock by a wide margin, so timing does not separate them at this clock.
Both critical paths run from an input port to a register. The ports were re-placed by the
judge, as explained under correctness, so timing here is not a strong signal.

Electron's own stages, same netlist:

| | after `hier_place_all` | after `legalize_flat` | after `improve_congestion` |
|---|---|---|---|
| HPWL | 4,349,275 µm (not legal) | 6,660,507 µm | 3,486,164 µm |
| Global-route wirelength | | 13,913,662 µm | 4,688,224 µm |
| Routing usage | | 112.3% | 39.6% |
| Overflow | | 1,198,102 | 0 |
| Routing time | | 72 min, still congested | 56 s |

Legalisation raises wirelength by 53%, and detailed placement then halves it. Without
detailed placement the design is not routable.

### End to end

| | electron | OpenROAD | OpenROAD / electron |
|---|---|---|---|
| Instances | 213,568 | 138,225 | 0.65x |
| Cell area | 279,670 µm² | 225,394 µm² | 0.81x |
| Die area | 559,341 µm² | 450,476 µm² | 0.81x |
| HPWL | 3,486,164 µm | 1,127,459 µm | 0.32x |
| HPWL per net | 17.7 µm | 6.8 µm | 0.39x |
| Global-route wirelength | 4,688,224 µm | 1,863,284 µm | 0.40x |
| Routing usage | 39.6% | 17.2% | |
| Overflow | 0 | 0 | |
| Worst 5 µm tile, signal pins | 87 | 75 | |
| Worst slack after routing | +7.29 ns | +7.66 ns | |

The end-to-end gap is bigger than the placement gap because the netlists differ:

- **Assign buffers.** Electron turns every `assign` into a real buffer cell: 41,152
  `CLKBUF_X1`, 19% of its instances and 32,839 µm² of area. Without them electron's area
  is exactly yosys's 246,831 µm².
- **Synthesis.** ORFS runs yosys 0.68 with its own ABC script and adder extraction, and
  lands at 223,899 µm² before resizing. Electron's container has yosys 0.9.
- **Tap cells.** ORFS adds 2,151 fixed tap cells, which electron does not.

## Correctness

| Check | electron | OpenROAD |
|---|---|---|
| Every cell placed | yes | yes |
| Legal: on rows, on site grid, no overlaps, inside die | yes, 0 violations | yes, 0 violations |
| Synthesised cells present with the right type | yes, 172,416 of 172,416 | not checked |
| Synthesised nets connected identically | yes, 182,721 of 182,721 | not checked |
| Undriven nets | **14,336** | 0 |
| Constant inputs left undriven | **32,128** | 0 |
| Multi-driven nets, floating inputs | 0, 0 | 0, 0 |
| Ports legal for routing | **no** | yes |
| DEF readable by OpenROAD as written | **no**, three fixes needed | yes |
| Same placement on a rerun | yes, 0 of 213,568 cells moved | not rerun |
| Timing met at 10 ns | yes | yes |

OpenROAD's placement netlist was not compared against its synthesis output, because
resizing changes it by design.

### Electron defects found

1. **Constant inputs are not tied off.** Yosys zero-extends adder inputs with sized
   constants inside port concatenations, for example `.a({ 2'h0, q2 })`. Electron's
   `elaborate` never connects those bits, so the child's port net has sinks and no driver.
   There are two causes:
   - The tie-cell picker (`dbfLibPickSmallestTieCell` in `UTILS/make_Robi_func`) looks for
     the functions `tie_low` and `tie_high`, while the Nangate function map says `tielow`
     and `tiehigh`. So no tie cell is ever chosen, and the run warns "no tie high cell found".
   - Naming the tie cells explicitly with `set_tie_cells` does not fix it. On the vedic test
     it added 200 tie cells, all connected to nothing, and left the undriven count at 224.

   This affects every flow in `TESTS/` on this design family: the small vedic tests have
   401 undriven constant inputs. In silicon these adder inputs would float.
2. **Ports are not legal for routing.** The MXU scripts never run `hier_place_pins`, so
   `hier_place` leaves all 1,153 ports on metal1 with one orientation. 1,025 of them extend
   outside the die, and they are stacked about three to a spot. FastRoute stops with
   GRT-0080. The judge re-placed them with OpenROAD's `place_pins`, the pin placer ORFS
   itself uses, so that routing could be measured at all.
3. **The DEF needs repair before another tool can read it.**
   - `DESIGN` is written after `UNITS`, which OpenDB rejects.
   - Port directions are lower case.
   - The DEF uses 4,000 DBU against the LEF's 2,000.
   - TRACKS give only one direction per layer, which FastRoute rejects.

   `prep_def.py` fixes the first two and a 4,000-DBU copy of the LEF handles the third. The
   judge replaces tracks with the platform's own for every DEF, which is neutral because
   pitches and offsets agree.

## Caveats

- One design, one size, one machine: 12 cores and 15 GB under WSL2. The ratios should be
  confirmed on `mxu_256` before being generalised.
- Electron ran in a lean Docker image, `electron-lean.Dockerfile`, built from the first
  stages of `INSTALL/UbuntuContainerFile` and `pysparkplusContainerFile`. It has the same yosys 0.9
  and CPAN set, but not the project's official `.sif`.
- ORFS ran from `openroad/orfs:latest` as pulled on 27 September 2026; its version string
  reads "unknown". Pin a dated tag to repeat these numbers.
- The 10 ns clock is loose on purpose, so timing is reported but does not discriminate.
- Placement only. Neither result was detail-routed, so no DRC or final wirelength.

## Reproduce

From `TESTS/large/openroad/`:

```
# electron, in its container
make electron TOP=mxu_tile64
# or with Docker and no Apptainer, as this report was run
make electron-image
make electron-docker TOP=mxu_tile64

# OpenROAD end to end, on a docker host
make openroad TOP=mxu_tile64

# OpenROAD's placers on electron's netlist
python3 prep_def.py ../workarea/mxu_tile64.improved.def work_mxu_tile64/same/unplaced.def --unplace
sed 's/DATABASE MICRONS 2000 ;/DATABASE MICRONS 4000 ;/' \
    ../../library/NangateOpenCellLibrary_PDKv1_2_v2008_10.lef > work_mxu_tile64/same/nangate_4000.lef
# then, in the ORFS image: SAME_LEF=... SAME_DEF=... SAME_OUT=... openroad -no_init -exit same_netlist.tcl

# scoring
python3 ../../defmetrics.py --lef <lef> <placed.def> --json <out.json>
python3 netcompare.py <yosys flat.json> <placed.def> --lef <lef>
# and, in the ORFS image, per DEF:
# JUDGE_LEFS=... JUDGE_DEF=... JUDGE_SDC=constraint.sdc JUDGE_TAG=... JUDGE_OUT=... \
#   JUDGE_PLACE_PINS=1 openroad -no_init -exit judge.tcl
```

Run electron with `PERL_HASH_SEED=0 PERL_PERTURB_KEYS=0` so its DEF record order repeats.
