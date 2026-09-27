# Electron user manual

Electron is a hierarchical ASIC place-and-route suite: it reads LEF, DEF, gate-level
Verilog and Liberty, floorplans, places, routes and writes DEF, Verilog, LEF and GDS. It
runs as a command shell, from a script, or with a Tk GUI. This manual covers installing
it, running it, and the commands that make up the two supported flows. For how the code
is put together see [ARCHITECTURE.md](ARCHITECTURE.md).

Contents

1. Installation
2. Running electron
3. The command shell and scripts
4. Library setup
5. Netlist: synthesis, reading and elaboration
6. Floorplanning
7. Flat placement
8. Routing
9. Power routing
10. Hierarchical flow
11. Writing results
12. Reports and queries
13. The GUI
14. Worked examples (the reference flows)
15. Large designs
16. Comparing with OpenROAD
17. Troubleshooting
Appendix A. Command index

---

## 1. Installation

### 1.1 Get the source and build

```
git clone <electron repo> electron
cd electron
make
```

`make` writes `electron`, `electron_hier` and `electron_proto` into the repository root.
They embed the absolute path of the checkout and the git commit count as the release-ID,
so rebuild after every pull and never copy them elsewhere. Add the checkout to your
PATH and set `ELECTRON_HOME` to it:

```
export ELECTRON_HOME=/path/to/electron
export PATH=$ELECTRON_HOME:$PATH
```

`ELECTRON_HOME` is used to locate `3RDBIN/` drivers and to expand paths in
`CONFIG/library.config`; if unset, the tool falls back to its own location.

### 1.2 Build the container

Electron only runs inside its container image. The host lacks Perl/Tk, scipy, yosys and
qrouter, and every one of those is required by something in a normal flow. The image is
built in three layers with podman and converted to an Apptainer `.sif`:

```
cd INSTALL/podman
make qrouter          # builds pysparkcad -> pysparkplusbuild -> pysparkpp.sif
```

Each parent layer is built only if missing. The result is `INSTALL/podman/pysparkpp.sif`
(a few GB, gitignored). If you keep the image somewhere else, point `ELECTRON_CONTAINER`
at it; `synthesize`, `qroute` and `flat_route` use that variable to find yosys, qrouter
and spark-shell when they are not on PATH.

### 1.3 Start a shell in the container

```
make app              # from the repo root, or from TESTS/
```

This runs `apptainer shell` with `/tech`, `/proj_pd` and your home directory bound in, and
inherits `DISPLAY`, so the GUI can open. Inside that shell, prefix commands with
`PATH=/usr/bin:$PATH`: the container sources your host `~/.bashrc`, and a miniconda in it
would shadow the container's python3 with one that has no scipy.

To run a single flow non-interactively from the host:

```
apptainer exec --bind /tech:/tech --bind /proj_pd:/proj_pd --bind /home/$USER:/home/$USER \
  $ELECTRON_HOME/INSTALL/podman/pysparkpp.sif \
  bash -c 'cd <workarea> && PATH=/usr/bin:$PATH $ELECTRON_HOME/electron --nogui --cleanlog --nolog -f run.tcl'
```

Use `bash -c`, not `bash -lc`; a login shell brings in the same miniconda problem.

### 1.4 Check the installation

```
make check            # loads all three tools and perl -c's every fragment, in the container
```

`check-load` is the one that matters. Six `check-syntax` warnings are known false
positives and are listed in `CLAUDE.md`. If you will push changes, turn on the pre-push
hook once per clone; it builds and load-checks all three tools before every push:

```
git config core.hooksPath INSTALL/hooks
```

---

## 2. Running electron

```
electron [options]
electron_hier [options]      # same tool, hierarchical GUI variant; use it for the hier flow
electron_proto [options]     # same tool, prototyping GUI variant; lacks the config/synthesis commands
```

| Option | Effect |
|---|---|
| `-f <file>`, `-init <file>` | execute the script, then continue with whatever mode follows |
| `--nogui` | do not open the GUI; stay at the shell prompt (or exit if the script ends with `exit`) |
| `--win`, `--gui` | open the GUI (this is the default) |
| `--EOC` | exit after the script instead of entering the shell |
| `--nolog` | do not write `electron.logN` / `electron.cmdN` |
| `--cleanlog` | delete existing `electron.log*` in the working directory first |
| `--overwritelog` | reuse the most recent log pair instead of creating a new one |
| `-log <file>` | write the session log to this file (no separate command log is then written) |
| `--DEBUG` | set `$DEBUG = 1`; many commands print more at higher `$DEBUG` values (`set DEBUG 5`) |
| `--version` | print the release-ID and continue |
| `--help`, `-h` | print the option summary and exit (it omits `--nogui`) |
| `-lic`, `-key`, `-port`, `-cmdlog` | accepted for compatibility; licensing is disabled and the daemon mode does not work |

Modes in practice:

- **Batch**: `electron --nogui --cleanlog --nolog -f run.tcl` with `exit` as the last line
  of the script. This is how the tests run.
- **Interactive shell**: `electron --nogui`. You get the `electron_shell >` prompt.
- **GUI**: `electron` or `electron -f setup.tcl`. The GUI opens after the script runs; the
  tool exits when the window closes. From the shell, type `win` (or `gui`) to open it.

Every session writes two files in the working directory unless `--nolog` is given:
`electron.logN`, a copy of everything printed, and `electron.cmdN`, the commands executed,
one per line, which can be replayed with `-f`. N increments per session.

Press Ctrl-C once to get a prompt back from a running command; twice to exit.

---

## 3. The command shell and scripts

### 3.1 Syntax

One command per line. The first word is the command, the rest are arguments split on
whitespace. Options come in two shapes: `-name value` takes a value, `--name` is a switch.
Lists are written in braces and reach the command as one comma-separated token:

```
report_net -nets {n1 n2 n3}
set_instance_location -instance {u1,u2} -loc {10,20,30,40} -status {PLACED,PLACED}
```

There is no quoting, no line continuation and no variable substitution in arguments.
Where a command wants a list at the prompt, use braces or commas
(`hier_place -kinds INST,PORT`), not quotes.

Every command prints its usage when called with `-h`, and when called with fewer
arguments than its registered minimum. `help` lists all commands; `help <cmd>` is the
same as `<cmd> -h`; `help read_*`, `help *def` and `help *graph*` filter the list.

### 3.2 Scripts

A script is the same lines you would type, with `#` comments and blank lines allowed:

```
# library and netlist
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v top.vg
set TOP_MODULE top
elaborate
exit
```

Run it with `-f`, or from the prompt with `source run.tcl`. Two differences from the
prompt: an unknown command in a script prints `no such command` and is skipped, and a
missing script file is silently ignored. End a batch script with `exit`, otherwise the
tool opens the GUI (or the shell with `--nogui`).

### 3.3 Variables

`set NAME value` sets a global Perl variable; `puts NAME` (or `puts $NAME`) prints it.
`set NAME [cmd args]` stores a command's return value. The variables that matter to the
flow are `TOP_MODULE` (the current design) and `DEBUG`. There is no `expr`; the `.tcl`
suffix is a naming convention, not a Tcl interpreter.

### 3.4 Shell and Perl escapes

At the prompt (not in scripts):

| Typed | Runs |
|---|---|
| `ls -l`, `make`, `grep x f` | any executable on PATH runs in the unix shell |
| `sys <cmd>` | force the unix shell |
| `peval <perl>` | force Perl eval, e.g. `peval print scalar(keys %CADB)` |
| anything else unknown | Perl eval (the historical behaviour) |

`cd` works in-process. `memusage` reports the process memory; `report_runtime` and
`date` are also available.

---

## 4. Library setup

### 4.1 From a library config

`CONFIG/library.config` is a JSON file mapping foundry → node → layer count → LEF and
Liberty files. Paths may use `$ELECTRON_HOME` or any environment variable.

```
read_config_file -config CONFIG/library.config -foundary nangate -technode 45nm -layer 6
```

This reads the technology LEF with `-tech only`, the cell LEFs with `-tech dont`, records
the Liberty paths without opening them, and then chooses an assign buffer and tie-high /
tie-low cells from the loaded library. The last step matters: with it, `assign`
statements in a netlist become real buffers; with a bare `read_lef` they are dropped.
Optional switches `--read_macro_lefs` and `--read_io_lefs` also read the `macro-lefs` and
`io-cell-lefs` entries.

```
read_library_config -config <library.config> -foundary <fab> -technode <node> [-layer <n>] [--append]
get_std_cell_libs [-vt <flavour>] [-corner <pattern>] [-max <n>] [--first] [--set]
```

`read_library_config` records only the Liberty paths; `get_std_cell_libs --first --set`
picks one and parks it for `synthesize`.

### 4.2 By hand

```
read_lef -lef <file> [-tech only|also|dont] [--file_list]
read_lib -lib <dotlib>
set_buffer_for_assign -cell_name <cell> -buf_in <pin> -buf_out <pin> -power <pin> -gnd <pin>
set_tie_cells [-tie_high <cell>] [-tie_low <cell>]        # with neither, the smallest of each is chosen
combine_lef -lef <lef1,lef2,...> | -path <dir>  -out <file>
write_lef -output <file> [-tech only|also|dont] [-macros <list>] [--simple]
```

Read the technology LEF first (`-tech only`), then cell LEFs (`-tech dont`), or one file
with both (`-tech also`). `--file_list` makes `-lef` name a file listing LEFs. `read_lib`
loads Liberty into the timing database and is only needed for timing or when the config
has no `cell-func-map`.

---

## 5. Netlist: synthesis, reading and elaboration

### 5.1 Synthesis (yosys)

```
synthesize -rtl <filelist> [-top <module>] [-liberty <lib>[,<lib>...]]
           [-out <dir>] [-script <file>] [--no_run] [--keep_attributes] [--read]
```

`-rtl` is a file with one RTL path per line (a `.v` or `.sv` given directly counts as a
one-file list). Liberty defaults to what `get_std_cell_libs --set` left. The command
writes `<out>/synth.ys`, runs yosys (in the container if it is not on PATH), filters the
`(* src *)` attributes out of the netlist unless `--keep_attributes`, reports cell count
and area from the log, and with `--read` reads the result back and elaborates it. The
work directory defaults to `synthesis`.

### 5.2 Reading a gate-level netlist

```
read_verilog -v <file> [-modify none|buffers_only|inverters_only|all] [-list <cell names>]
             [-sanity true|false] [-output <file>]
set TOP_MODULE <module>            # or: set_top_module <module>
elaborate
report_design
```

`read_verilog` builds one logical module per Verilog module. It cannot parse yosys's
`(* src = ... *)` attributes; strip them first (`egrep -v '\(\*' in.vg > out.vg`) or use
`synthesize`, which does it for you. `set TOP_MODULE` names the design; `elaborate`
walks the hierarchy from it and creates the flat instance, net and port tables that
every physical command works on. Re-run `elaborate` after changing the netlist.

Other netlist commands:

| Command | Purpose |
|---|---|
| `flatten_design` | flatten the hierarchy under `TOP_MODULE` into one module |
| `uniquify_module -module <m>` | give each instance of a module its own copy |
| `set_module_as_bbox`, `set_module_flattening_parameter`, `set_module_flattening_selective` | control what is flattened or treated as a black box |
| `read_hdl -hdl <rtl files> [-I <dirs>]` | read RTL for estimation and browsing (not for placement) |
| `read_edif`, `read_cdl`, `read_spice` | other netlist formats |
| `write_verilog -output <f> [--overwrite] [--hier | --flat] [--notWriteEmptyModule] [-no_of_level n] [-start_module m]` | write the netlist back (flat is the default) |
| `set_write_assign_as_buffer`, `set_write_assign_as_assign` | how `assign` is written |
| `report_verilog_design`, `report_verilog_area`, `print_design_hierarchy` | netlist reports |

### 5.3 Reading a DEF

```
read_def -def <file>[.gz] [--floorplan] [--pins] [--components] [--nets] [--specialNets]
         [--routing] [--blkgs] [--all] [--logical]
```

With no section switches the DEF's floorplan, components and pins are read into the
current design; `--all` reads everything including routing. `--logical` also builds the
logical module from the DEF's connectivity, for DEF-only flows. `read_def_eco` updates
components and nets of an existing design; `read_def_hierarchy` populates the logical
model from a hierarchical DEF.

---

## 6. Floorplanning

```
set_floorplan_parameters -UTILIZATION <percent> | -ASPECT_RATIO <h/w> | -WIDTH <um> -HEIGHT <um>
                         [-SITE_WIDTH <um>] [-SITE_HEIGHT <um>] [-ADVNC_UTILIZATION <percent>]
                         [-IO2KORL <um>] [-IO2KORR <um>] [-IO2KORU <um>] [-IO2KORB <um>]
set_floorplan [-partition <module>] [-floorplan <name>] [--force]
```

`set_floorplan_parameters` records the targets; `set_floorplan` computes the die from the
placed cell area of `TOP_MODULE` and creates the floorplan, rows and die box. Give either
a utilisation and aspect ratio (the die is sized to fit), or a fixed width and height (the
utilisation is reported). Utilisation defaults to 70 percent. `IO2KOR*` are the left,
right, upper and bottom keep-out distances from the die edge for I/O. A second
`set_floorplan` on the same module needs `--force`.

Related commands:

| Command | Purpose |
|---|---|
| `create_rows` | (re)create standard cell rows from the die and site |
| `set_std_row_height`, `set_chipdimension_site_multiple`, `set_chip_height_width_x_y_grid` | row and grid constraints |
| `place_io_ports -f <json> -minLayer <l> -maxLayer <l>` | place top-level ports from a JSON description |
| `placePorts`, `create_pin_guide`, `guide_pin` | port placement and pin guides |
| `set_instance_location -instance {i,...} -loc {x,y,...} -status {st,...} -orient {o,...}` | place or fix instances by hand (microns) |
| `set_blocks_as_fixed`, `unplace_instance`, `do_change_placement_status` | status edits |
| `arrange_macros -space <um> -margin <um> [-macro_area <um2>]` | tidy already-placed macros (see 7.2) |
| `create_pad_ring`, `create_bumps`, `flip_chip` | pad frame and bump utilities |
| `write_flat_floorplan`, `read_hier_floorplan`, `write_hier_floorplan` | floorplan-only DEF (`fpdef`) |

---

## 7. Flat placement

All flat placers share one mechanism: write a nodefile and edge list, run a driver from
`3RDBIN/`, read the `<node> <x> <y>` result back. Cells come back with continuous,
possibly overlapping positions; `legalize_flat` is not optional before routing.

### 7.1 Placers

```
place_flat_design [-placer <driver>] [-fanout_limit <n>] [--legalize] [--write_only] [--keep]
```

The default flat placer: a graph-embedding placer whose result is stretched onto the die.
Good first placement for a few thousand cells.

```
eplacer [-placer <driver>] [-iters <n>] [-target_density <f>] [-max_displacement <um>]
        [-fix none|ports|macros|ports+macros|status|placed] [-fanout_limit <n>] [--write_only] [--keep]
```

ePlace-style electrostatic global placer. Starts from the current placement and spreads
density. `-fix placed` holds everything that already has a location and places only the
UNPLACED cells.

```
mincut_placer [-placer <driver>] [-leaf <n>] [-passes <n>] [-tolerance <f>] [-macro_area <um2>]
              [-fix ...] [-fanout_limit <n>] [--write_only] [--keep]
```

Recursive min-cut bisection seeded from the current coordinates; gives uniform density by
construction. Meant to run after a global placement, not instead of one.

```
seedPlace [-placer <driver>]
          -split equal|flow  -min_edge <n> -max_edge <n> -max_cone <n> -block_area <um2>
          -seq_regex <re> -mem_regex <re> -break_loops greedy|dfs|none -port_area skip|absorb
          --no_port_anchors --trust_types | --ignore_types
          --no_mincut -mc_leaf <n> -mc_passes <n> -mc_tolerance <f> -mc_partitioner auto|metis|fm|none
          -mc_jobs <n> -mc_macro_area <um2>
          -iters <n> -target_density <f> -fix block+port|block|port|status|none -margin <f>
          -max_degree <n> -grid <GXxGY|auto> -workers <n> -ports require|free|perimeter --no_fillers
          -fanout_limit <n> --write_only --keep
```

Anchor-hypergraph placer: collapses combinational logic onto the flops, memories, blocks
and ports it connects, bisects those anchors, then solves them analytically. Use it to
get the sequential skeleton of a large design in place before `eplacer`.

The lower-level pieces are available individually:

```
write_flat_graph [-nodefile <f>] [-graph <f>] [-fanout_limit <n>] [--placed_as_fixed] [--nodefile_only]
read_flat_graph_placement -input <xy.out> -nodefile <f>
read_flat_nodefile -input <nodefile> [-reference <original nodefile>]
```

### 7.2 Macros

```
arrange_macros [-arranger <driver>] [-space <um>] [-macro_area <um2>] [-margin <um>] [--write_only] [--keep]
```

Moves macros that already have a location so they are spaced and clear of the edge; it
does not place unplaced macros. Set macro locations first with `set_instance_location`
or a floorplan DEF, and mark them FIXED so the cell placers hold them
(`set_blocks_as_fixed`).

### 7.3 Legalisation and finishing

```
legalize_flat [-rows <n>] [-max_disp <um>] [--no_snap_x] [--report_only] [-debug]
              [-dbin <um>] [-dbin_rows <n>] [--no_dbin]
              [--pin_spread [-pin_grid <um>] [-pin_pctl <n> | -pin_target <n>] [-pin_max <r>]]
              [--spread [-grid <um>] [-iters <n>] [-spread_order small|large]]
```

Snaps every standard cell to a row and the site grid with no overlaps (Abacus), trying up
to `-rows` rows either side (default 6). It is deterministic from run to run, gives each
cell the orientation its row requires, and handles cells taller than one row.
`--report_only` reports without moving anything; `-max_disp` lists cells moved further
than that.

- **Local density cap**, on by default. A cell takes the nearest row that still has room
  near its x, not just anywhere along the row, which keeps cells from being pushed far
  sideways. `-dbin` sets the bin width (default 100 mean cell widths), `-dbin_rows` how
  many rows away it may push a cell (default 2), and `--no_dbin` turns it off.
- **`--pin_spread`**, off by default. Use it when the problem is routability: it finds
  the 5 µm tiles with the most signal pins (above the 95th percentile, `-pin_pctl`) and
  pads the cells in them so the legaliser opens gaps there. It costs a few percent of
  wirelength and one extra legalisation pass.
- **`--spread`**, the older area-density pass, is off by default because it made routing
  much worse on the flat test. Use it only when the report says cells found no row.

`-placer` hands the job to `3RDBIN/legalize_flat`, a NumPy legaliser. Do not use it: it
lacks the density cap and pin spreading, it overlaps multi-row cells, and it is slower end
to end.

### 7.4 Detailed placement

```
improve_congestion [-iters <n>] [-rows <n>] [-window <n>] [-fanout_limit <n>] [-min_gain <percent>]
                   [--no_swap] [--no_slide] [--report_only]
```

Run it after `legalize_flat`; it refuses a placement that is not legal. It moves cells
towards the middle of their nets, by swapping or by sliding along rows, keeping a move
only if it shortens the nets it touches. Overlaps stay at zero and wirelength only falls.
On the test designs it cut HPWL by 24% (nangate_flat) to about 50% (matmul_4x4 and
mxu_256), and on nangate_flat qrouter's unrouted nets fell from about 130 to about 35. It
takes 78 seconds on 204,816 cells and under six minutes on 855,424. `--report_only`
measures without moving anything. `-iters` sets the rounds (default 2) and it stops early
when a round gains less than `-min_gain` percent.

### 7.5 Finishing

After legalisation and detailed placement:

| Command | Purpose |
|---|---|
| `add_filler_cells_in_gaps` | fill row gaps with filler cells |
| `delete_fillers` | remove them again |
| `add_endcap`, `add_wellties` | end caps and well ties |
| `report_place`, `get_inst --placed|--unplaced|--fixed` | placement status |
| `check_cell_on_grid`, `remove_overlap`, `remove_overlap_block`, `remove_congestion` | older Perl checks and fixes |

Older Perl placers (`place_design`, `placeSA`, `placeGrid`, `make_seed_place`,
`place_graph_*`, `place_graywolf`) remain registered. Some depend on binaries (`plan_4`,
`graywolf`) that are not shipped; prefer the commands above.

---

## 8. Routing

### 8.1 Detail routing with qrouter

```
qroute [-out <dir>] [-lef <file>[,<file>...]] [-def <file>] [-effort <n>] [-vdd <net>] [-gnd <net>]
       [--no_stage3] [--no_run] [--no_read] [--force_routable]
```

Writes a placed DEF (unless `-def` is given), writes a qrouter script, runs qrouter (in the
container if needed), then reads the routed DEF back with `read_def --all` so the
database carries the routing. Output lands in `-out` (default `route`): `route.log`,
`failed.nets`, and `<def>_route.def`. Pass the PDK LEF with `-lef`; a LEF written from the
database drops layer OFFSET and the second PITCH, which puts pins between tracks and
roughly doubles the failed-net count. `--no_read` leaves the routed DEF on disk.

### 8.2 A* router on Spark

```
flat_route [-out <dir>] [-layers <lo>:<hi>] [-mode auto|flat|dc|gd] [-gcell <um>] [-flat_limit <nodes>]
           [-chunks <k>] [-parts <n>] [-driver_mem <size>] [-cores <n>] [-local_top <n>] [-order <mode>]
           [-pitch <um>] [-scala_dir <dir>] [-via_cost <um>] [-ports_on <layer>] [-max_expand <n>]
           [-bbox_margin <n>] [-wrong_dir <x>] [--no_run] [--no_read]
```

Writes tech and design files, runs `route.sh` from the `pyspark_cad/scala` repository
(`ELECTRON_ASTAR_DIR` or `-scala_dir`) under spark-shell, and reads the segments back.
`-mode gd` (global on gcells, then detail per gcell region, one Spark task each) is the
one that scales; `auto` picks it when the flat grid exceeds `-flat_limit` nodes.
`run_jroute` forwards here.

### 8.3 Other routing commands

| Command | Purpose |
|---|---|
| `route_p2p`, `route_p2p_inpair`, `route_p2p_3pin_inpair` | point-to-point Perl router for individual nets |
| `write_flat_router_graph`, `write_router_graph`, `read_flat_router` | router graph files |
| `report_routing`, `analyze_routing`, `report_net_wl`, `routing_percentage`, `get_routing_resource` | routing reports |
| `display_congestion_map`, `read_congestion_map`, `create_gcell` | gcell congestion |
| `generate_tracks` | registered but unimplemented; qrouter derives tracks from the LEF |

---

## 9. Power routing

```
addPowerRing  -offset {x,y} -spacing <um> -width <um> -layerH <layer> -layerV <layer> -nets {VDD,VSS}
addStripes    -instance <inst> -offset {..} -spacing {..} -dir {..} -side {..} -net {..} -layer {..}
              -width {..} -repeat {..} -extend {a:b,...}
```

Further commands: `addPowerRows`, `addPowerGridStripes`, `addHardMacroPowerRing`,
`addPowerVias`, `add_power_via`, `create_stripe`, `create_via`, `create_array_via`,
`add_power_route`, `power_escape_router`, `tracePowerConnection`, `write_pg_net`. Special
nets are written by `write_def --spnets` and `--sproutes`.

---

## 10. Hierarchical flow

The hierarchical flow works on a *pseudo model* of one module at a time: its child
blocks, its ports, and the connectivity between them, with each block sized from the
cells under it. Blocks and ports are placed, then the result is committed to the module's
floorplan and pushed down into the flat database. Use `electron_hier`.

```
edit_module [-module <m> | --top] [-floorplan <name>] [-util <percent>] [--physical_only]
```

Builds the pseudo model of the module (default `TOP_MODULE` with `--top`). `-util` sizes
the module from the area of its cells when it has no floorplan yet.

```
hier_place [-module <m>] [-placer <path>] [-kinds INST,PORT|INST] [-input <nodefile>] [-layer <layer>]
           [-origin lower_left|center] [-fanout_limit <n>] [-args <extra>] [-batch <steps>]
           [--report_only] [--write_only] [--no_size] [--no_ports] [--hier_only] [--keep]
```

Writes the anchor hypergraph of the module (blocks and ports as nodes, each cone of
combinational logic between them as one hyperedge), opens the PyQt5 block placer, and
reads the saved nodefile back. In the window: drag blocks, wheel to zoom, right-drag to
pan, FIXED nodes are hatched; **Save** writes the nodefile and closes. `-batch 400` runs
the same physics for 400 steps with no window, which is how scripts and tests drive it.
`-kinds INST,PORT` (the default) places ports as well; a port with no location is one
`hier2flat` cannot place.

```
hier_place_pins [-topLayer <l>] [-bottomLayer <l>] [-layers <lo:hi>] [-spaceTracks <n>] [-module <m>]
                [--honorBus] [--honorPinGuide] [-debug]
```

After `hier_place`, which places pins but assigns no layer: `-layers lo:hi` deals the
horizontal layers of the range round-robin to east and west pins and the vertical ones to
north and south, and `-spaceTracks` spaces pins that share a layer on an edge.

```
commit_module [-module <m>] [-floorplan <name>] [--physical_only]
hier2flat [--physical] [--logical]
```

`commit_module --physical_only` writes the block sizes, block locations and pin rects
into the module's floorplan. Without `--physical_only` it also rebuilds the module's
netlist connectivity from the pseudo net tables, which is a deliberate logical edit.
`hier2flat --physical` then walks the whole hierarchy and rebuilds the flat instance and
port tables from the committed floorplans; nothing else carries a hierarchical placement
across to `write_def`, the flat view and the routers.

After one level, the blocks and ports of the module have locations and the leaf cells
inside the blocks do not. Two commands fill them in.

```
hier_place_cells -module <m> [-batch <steps>] [-placer <path>] [-fanout_limit <n>] [-args <extra>]
                 [--no_blockage] [--write_only] [--keep]
```

Places the combinational cells of one module that `hier_place` left out, holding the
blocks, flops and ports it placed FIXED. Run it after `hier_place` on the same module.

```
hier_place_all [-module <top>] [-batch <steps>] [-cells_batch <steps>] [-depth <levels>] [-util <percent>]
               [-placer <path>] [-fanout_limit <n>] [-args <extra>]
               [--skip_placed] [--no_cells] [--no_flatten] [--report_only] [--keep]
```

Places the whole tree. For each distinct module, parents first, it runs `edit_module`,
`hier_place`, `hier_place_cells` and `commit_module --physical_only`, then runs
`hier2flat` once at the end. Order matters: a module takes its size from its instance box
in the parent's committed floorplan, so a child opened before its parent has no area.
Each distinct module is placed once and all its instances share that arrangement, so
the cost follows the number of distinct modules, not instances. `-batch` and
`-cells_batch` are the placer steps per module (default 400); `--report_only` prints the
walk without placing. `-depth 0` places only the top.

To floorplan the top by hand and let the tool do the rest, place and commit the top with
the `hier_place` window, then run `hier_place_all --skip_placed`. Modules that already
have a placement keep it and only get their cells filled in.

`hier_place_all` does not legalise: finish with `legalize_flat`, which needs the rows
that `set_floorplan` creates. So the complete hierarchical flow is:

```
set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan
edit_module --top
hier_place_all -batch 300 -cells_batch 300
legalize_flat
improve_congestion                       # optional; roughly halves wirelength
write_def -output design.legal.def --overwrite
```

If you walk the hierarchy yourself with `edit_module`, put `TOP_MODULE` back afterwards
(`set TOP_MODULE <top>`). `edit_module` changes it, and `write_def` writes whatever module
it names, which looks like a placement bug: a block-sized die, no pins, and every cell
outside the boundary.

Other hierarchical commands: `write_pseudo_graph` / `read_pseudo_nodefile` (the pieces
`hier_place` is built from), `up_hier`, `down_hier`, `edit_module_hierarchy`,
`createPseudoModule`, `createPseudoInstance`, `createPseudoNet`,
`createPseudoRoutingBlockage`, `updatePseudoNet`, `reshape_hier_inst`,
`set_pseudo_floorplan`, `remove_hier_pins_overlap`, `hier_connectivity`,
`print_design_hierarchy`, `report_design_hierarchy`, `write_hier_json`,
`write_hier_floorplan`, `read_hier_floorplan`, `create_hier_image`.

---

## 11. Writing results

```
write_def -output <file> [--overwrite] [--flplan] [--comp] [--nets] [--fills] [--spnets] [--pins]
          [--sproutes] [--routes] [--tracks] [--norows] [--no_special_net_connectivity]
          [--write_unconnected_instances] [--regular_net_conn_route] [-max_net_degree <n>] [-debug <n>]
```

All sections are written by default; name sections to write only those. Without
`--overwrite` an existing file is not replaced.

```
write_verilog -output <file> [--overwrite] [--hier | --flat] ...
write_lef -output <file> [-tech only|also|dont] [-macros <list>] [--simple]
def2lef -output <file> [--detailed]
def2gds [-output <file>] [-boundary_layer <n>] [-boundary_data_type <n>] [-userUnits <f>] [-dbUnit <f>]
        [--pin] [--inst] [--net] [--spnet] [--pin_text] [--inst_text] [--net_text] [--spnet_text]
        [--include_cell] [--cell_pin_text] [--include_gds_cells] [-gds_file_path <dir>] [-layer_map_file <f>]
export_all
```

`def2gds` writes the design as GDS with the GDS2 Perl module; `--include_gds_cells` with
`-gds_file_path` merges cell GDS. `export_all` writes `<TOP_MODULE>.def`,
`<TOP_MODULE>.lef` and a GDS with pins, instances, nets and special nets, merging cell
GDS from `$ELECTRON_CELL_GDS` and using `$ELECTRON_LAYER_MAP` if set.

```
save_design -name <dir>
restore_design -name <dir>
```

Save the physical library, technology, instances, ports, nets, floorplans, rows, tracks
and routing to a directory of Storable files, and load them back into a fresh session.
The pseudo (hierarchical) model is not saved.

Other writers: `write_xml_def`, `write_xml_lef`, `write_flat_json`, `write_excel`,
`write_html`, `write_sdc`, `write_lib`, `create_flat_image`, `create_flat_svg`,
`create_def2png_all`, `create_lef_image`.

---

## 12. Reports and queries

| Command | What it prints |
|---|---|
| `report_design [--summary]` | instance, net, port and module counts of the current design |
| `report_area` | total standard-cell area in um² |
| `report_instance -output <f> [--inst {..}] [--cell {..}] [--placed] [--fixed] [--unplaced]` | instance table |
| `report_net [-nets {..}] [-noOfPins n:m] [-output <f>] [--summary] [--reportWireLength <f>] [--reportCumWireLength <f>]` | net table and wirelength |
| `report_net_wl`, `get_net_wl`, `netwl_routing` | wirelength |
| `report_place`, `get_inst [--fixed|--placed|--unplaced]` | placement status |
| `find_inst -inst <name> [-attribute true|false]`, `find_net -pin <p> -inst <i>`, `find_port` | look up objects |
| `find_conn`, `check_connection`, `getNetDriver`, `getNetSink` | connectivity |
| `query` | instance, net and register counts |
| `report_design_hierarchy`, `print_design_hierarchy` | hierarchy tree |
| `report_timing -outFile <f> -reg2reg <pin>`, `report_worst_timing_path`, `read_sdc -sdc <f>` | timing (needs `read_lib`) |
| `report_lef_qor`, `analyse_library`, `report_pin_access`, `analyze_pin_access` | library analysis |
| `report_mem`, `memusage`, `report_runtime` | process |

---

## 13. The GUI

Start it with `electron` (default) or type `win` at the prompt. The window shows the
current top module in its title, a menubar and a tabbed area.

**Tabs.** *FlatView* draws the die, rows, instances, ports, flylines and routes of the
current design; left-click selects, right-drag pans, the toolbar zooms, and the RoutingLayer
and CutLayer menus toggle layer visibility. *Library* has tech, lef-view and gds-view
pages for browsing the loaded LEF and GDS. *Specify* holds constraint dialogs. *Raster*
draws the whole design as one image, colouring each pixel by the fraction covered by
cells, with the die and rows on top; the wheel zooms at the cursor. Use Raster rather
than FlatView above a few hundred thousand instances, where drawing one item per cell
becomes unusable. The `raster_view` command opens the same view in its own window, and
`raster_view -def <file> -lef <file>` draws a DEF that is not loaded.

**Menus.** File (New, Import, Export, Export All, Run A Script, Save, Screenshot, Exit),
Library (select technology, load, view), Simulate (iverilog, gtkwave), Synthesis
(yosys, Qflow-Yosys), Power (Add PG Ring, Add PG Stripes, Add StdCell PG Rails, Add Vias,
Add Filler), Place (SetFlplan Parameters, SetFlplan, Flat Place, ePlacer, Min-cut
Placer, seedPlace, Arrange Macros, Legalize, Hier Place, Edit Module, Commit Module, and
the Fractal placer in the hier variant), Route (Q-Route, Flat Route, J-Route, Escape
Route), Timing (Vesta, Worst Path, TimingBrowser), Output (Write Verilog, Write Excel,
Write HTML), Util, CreateDesign (Create Top Module, Create Module, Create Pin2Pin
connection, blockages), and KB. Each item pops up a dialog for the options and runs the
same command the prompt would; the command is echoed to the log, so a GUI session can be
replayed from `electron.cmdN`.

The GUI runs in a forked child of the shell process. It reads the database when it
draws; after placing from the prompt, use Refresh or reopen the window.

---

## 14. Worked examples (the reference flows)

Both examples use only what is in the repository: the Nangate45 library in
`TESTS/library/` and a pre-synthesised vedic multiplier netlist in `TESTS/rtls/vedic/`
(4,233 instances, 4,489 nets, 7 hierarchical blocks). Run them from a container shell:

```
make app                # from the repo root
cd TESTS
PATH=/usr/bin:$PATH make nangate_flat      # flat place and route
PATH=/usr/bin:$PATH make nangate_hier      # one level of hierarchical placement
PATH=/usr/bin:$PATH make nangate_recurse   # the whole hierarchy with hier_place_all
PATH=/usr/bin:$PATH make nangate_rtl_hier  # from registered RTL through synthesize
PATH=/usr/bin:$PATH make nangate_all       # all four
```

Results land in `TESTS/workarea/`. `make nangate_flat-gui` runs the same flow with the
window open; `make nangate_flat-place` stops after legalisation.

### 14.1 Flat place and route (`TESTS/nangate_flat.tcl`)

```
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v vedic_filter.vg          # vedic.vg with the (* src *) attributes removed
set TOP_MODULE vedic_16x16
elaborate
report_design

set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan

place_flat_design
write_def -output vedic_16x16.placed.def --overwrite

legalize_flat
write_def -output vedic_16x16.legal.def --overwrite

qroute -out route -lef ../library/NangateOpenCellLibrary_PDKv1_2_v2008_10.lef
write_def -output vedic_16x16.routed.def --overwrite
report_design
exit
```

Points to note: `read_config_file` rather than `read_lef`, so the netlist's `assign`
statements become buffers; utilisation rather than a fixed die; `legalize_flat` before
routing; the PDK LEF passed to `qroute`. `route/route.log` and `route/failed.nets` show
how the router did.

### 14.2 Hierarchical placement (`TESTS/nangate_hier.tcl`, run with `electron_hier`)

```
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v vedic_filter.vg
set TOP_MODULE vedic_16x16
elaborate

edit_module --top -util 50
hier_place -kinds INST,PORT -batch 400
commit_module --physical_only
hier2flat --physical

report_design
write_def -output vedic_16x16.hier.def --overwrite
exit
```

After this the seven blocks and sixty-four ports of the top module have locations and the
DEF's PINS are placed; the leaf COMPONENTS are unplaced until each block is filled.
`make nangate_recurse` does that with `hier_place_all` (section 10) and produces a fully
placed, legalised DEF. `make nangate_recurse-interactive` stops at the prompt with the
unlegalised placement in memory, so you can open the GUI and run `legalize_flat` yourself.
Drop `-batch 400` to place the blocks interactively.

### 14.3 Checking the result independently

Do not rely on a command's own summary. `TESTS/defmetrics.py` measures any placed DEF,
from electron or any other tool, using only the DEF and the LEF:

```
python3 TESTS/defmetrics.py --lef TESTS/library/NangateOpenCellLibrary_PDKv1_2_v2008_10.lef \
        TESTS/workarea/vedic_16x16.legal.def [--ref other.def] [--max_degree 50] [--json out.json]
```

It reports components by status and class, cell and die area, utilisation, HPWL computed
from the real pin positions and orientations, and legality in integer DBU: cells off a
row, off the site grid, overlapping in a row, or outside the die. When cells are off the
rows the overlap count is marked as a lower bound, since grouping by row cannot see them
all. `--ref` adds the displacement of every instance against a second DEF, matched by
name, which is the way to compare two runs: `write_def` emits records in a different order
every run, so the files never match byte for byte. It needs no packages beyond Python 3
and runs outside the container. An 855,424-component DEF takes about 11 seconds and
0.8 GB.

---

## 15. Large designs

`TESTS/large/` holds four designs built from the same multiplier, synthesised from RTL and
placed with the whole hierarchical flow. They are separate from `nangate_all` because they
take minutes rather than seconds.

| Target | Design | Instances | Distinct modules | Wall | Peak memory |
|---|---|---|---|---|---|
| `matmul_hier` | 4x4 matrix product, 64 multipliers | 204,816 | 13 | 1m30 | 1.2 GB |
| `mxu_64` | 8x8 systolic array | 213,568 | 14 | 1m29 | 1.2 GB |
| `mxu_256` | 16x16 systolic array | 855,424 | 15 | 5m23 | 4.2 GB |
| `mxu_1024` | 32x32 systolic array | 3,424,000 | 16 | 25m47 | 16.1 GB |

The times were measured before `legalize_flat` was sped up, so current runs are somewhat
faster. The three MXUs are the same sources with a different `-top`, so each step is four
times the instances and one more distinct module.

### 15.1 The easiest way to run one

You need the electron container image, `pysparkpp.sif`, and Apptainer. With those in
place it is two commands:

```
cd $ELECTRON_HOME && make && make app       # build, then a shell in the container
cd TESTS/large && PATH=/usr/bin:$PATH make mxu_64
```

`mxu_64` is the one to start with: it exercises every code path of the large set in
about a minute and a half and 1.2 GB. Each script synthesises the RTL with yosys,
floorplans at 50% utilisation, runs `hier_place_all`, writes the unlegalised placement,
legalises and writes the result:

```
TESTS/large/workarea/mxu_tile64.recurse.def    after hier_place_all
TESTS/large/workarea/mxu_tile64.legal.def      after legalize_flat
TESTS/large/workarea/synth64/                  yosys script, log and netlist
```

Then check the result independently:

```
python3 TESTS/defmetrics.py --lef TESTS/library/NangateOpenCellLibrary_PDKv1_2_v2008_10.lef \
        TESTS/large/workarea/mxu_tile64.legal.def
```

`legal` should say `True` and `overlaps` should be 0.

The stock scripts stop at `legalize_flat`. To add detailed placement, run
`improve_congestion` at the prompt of an `-interactive` run and write the DEF again. It
roughly halves HPWL on these designs and adds about 80 seconds on matmul and six minutes
on mxu_256. `make matmul_hier-interactive` already does this, and writes
`matmul_4x4.recurse_interactive.def`, `.legal_interactive.def` and
`.improved_interactive.def` before stopping at the prompt.

To look at a result, run the `-interactive` variant (`make mxu_256-interactive`). It
stops at the prompt with the placement in memory and unlegalised; type `gui`, raise the
Raster tab, then run `legalize_flat` and watch the cells snap into rows. At these sizes
use Raster, not FlatView.

Plan for memory. `mxu_1024` needs about 16 GB, so it does not fit on a 16 GB machine once
the operating system is counted, and opening the GUI forks a second copy of the database.
`mxu_256` fits comfortably in 8 GB.

If you do not have the image: it is built in three layers with podman and converted with
Apptainer (`cd INSTALL/podman && make qrouter`, section 1.2). That build compiles OpenSTA
and cudd and takes a long time, so if someone on your team already has a `pysparkpp.sif`,
copying it is much faster. Point `ELECTRON_CONTAINER` at it wherever it lives.

### 15.2 What to expect from the results

Every block lands exactly inside its box at every level, and all instances of a module
are identical because they share one floorplan. What the placer does not do is order a
systolic array into its mesh: on `mxu_256`, only 5 of 24 nearest-neighbour links inside
a 4x4 PE tile end up physically adjacent, and running the placer ten times longer does not
change that. The header of `TESTS/large/mxu_hier.tcl` has the full measurements.

---

## 16. Comparing with OpenROAD

OpenROAD, through OpenROAD-flow-scripts (ORFS), is the natural reference: it is the
standard open-source flow and ships a `nangate45` platform built on the same Nangate
FreePDK45 cell library electron's tests use, with the same cell names and the same
0.19 x 1.4 µm site. `TESTS/large/openroad/` sets up a like-for-like run on the MXU
designs:

| File | Purpose |
|---|---|
| `config.mk` | ORFS design configuration: the same RTL files as `mxu.f`, hierarchy kept, 50% utilisation, square die, timing- and routability-driven placement off |
| `constraint.sdc` | one loose 10 ns clock, so ORFS does not spend its time on timing repair |
| `Makefile` | `electron`, `openroad` and `compare` targets |
| `measure.py` | records electron's wall time and peak memory |
| `compare.py` | prints both tools side by side from `defmetrics.py` output |
| `prep_def.py` | fixes the two things in electron's DEF that stop OpenROAD's reader; `--unplace` hands electron's netlist to another placer |
| `same_netlist.tcl` | OpenROAD's placers on electron's exact netlist |
| `judge.tcl` | one OpenROAD engine scoring any DEF: timing, then global routing |
| `netcompare.py` | checks a placed netlist connection by connection against yosys's |
| `REPORT_mxu_tile64.md` | the results of the first full comparison |

### 16.1 Running it

The two halves run in different places. Electron runs in its Apptainer container. ORFS
runs in the public `openroad/orfs` Docker image, which is several GB to pull. On a machine
with Docker and no Apptainer, `make electron-image` builds a lean electron image with only
what the MXU flow needs, and `make electron-docker TOP=...` runs the electron half in it.

```
# 1. electron, in the container shell from make app
cd TESTS/large/openroad && PATH=/usr/bin:$PATH make electron TOP=mxu_tile64

# 2. OpenROAD, on a host with docker
cd TESTS/large/openroad && make openroad TOP=mxu_tile64

# 3. the comparison, anywhere with python3
cd TESTS/large/openroad && make compare TOP=mxu_tile64
```

`TOP` is `mxu_tile64` (the default), `mxu_256` or `mxu_1024`. Results go to
`TESTS/large/openroad/work_<TOP>/`. `compare.txt` is the side-by-side table; the metrics
files for each tool sit beside it. `make openroad OPENROAD_FULL=1` turns OpenROAD's timing-
and routability-driven placement back on, for comparison against what OpenROAD does by
default rather than like for like.

ORFS's place stage ends with detailed placement, so by default the electron side also
runs `improve_congestion` after `legalize_flat` and compares `<TOP>.improved.def`. Pass
`ELECTRON_DP=0` to `make electron` and `make compare` to compare the legalised placement
alone.

### 16.2 What is compared, and what is not

Both tools stop at a legal placement, because electron has no clock tree synthesis or
timing repair. The table reports, for each tool:

- instances, cell area, die area and utilisation, which show whether the two netlists and
  floorplans really match;
- HPWL, total and per net, which is the quality measure both placers optimise;
- legality: unplaced, off-row, off-site, overlapping and out-of-die cells;
- wall time and peak memory for synthesis through placement.

Differences to keep in mind when reading it:

- **Different synthesis.** Each tool runs yosys its own way. ORFS keeps the hierarchy here
  (`SYNTH_HIERARCHICAL=1`) to match electron, but the cell counts will still differ a
  little, and ORFS resizes and buffers during placement. Compare HPWL per net if instance
  counts differ; `compare.py` warns when they differ by more than 2%.
- **Hierarchical against flat.** Electron places each distinct module once and reuses it;
  OpenROAD places the whole flattened netlist. On regular designs such as the MXU that
  should favour electron on run time and OpenROAD on wirelength. The comparison measures
  how large each effect is.
- **Placement only.** Routability, timing and power are not compared. Taking both
  placements through the same router is the natural next step. If you do, run electron
  with `PERL_HASH_SEED=0 PERL_PERTURB_KEYS=0`. Otherwise its DEF record order changes
  every run and qrouter's result changes with it.

### 16.3 Results

The first full comparison, on `mxu_tile64`, is in `TESTS/large/openroad/REPORT_mxu_tile64.md`.
In short:

- **Performance.** Electron runs synthesis to detailed placement in 200 to 269 s on one
  core. ORFS takes 512 s on up to 12 threads. On the same netlist, OpenROAD's placers take
  94 s against electron's 174 to 241 s.
- **Quality.** On the same netlist OpenROAD gets half the wirelength, 43% less
  global-route wire and lower pin density. Both route without overflow and meet 10 ns.
- **Correctness.** Electron's placement is legal and reproducible, and every synthesised
  cell and net survives exactly. But it leaves 32,128 constant inputs undriven, its ports
  are not legal for a router, and its DEF needs repair before OpenROAD can read it.

For deeper checks than `make compare`: `netcompare.py` for netlist preservation,
`same_netlist.tcl` for a placement-only comparison, and `judge.tcl` for timing and
routability measured by one engine. The report's last section lists the commands. Pin
`ORFS_IMAGE` to a dated tag so later comparisons use the same OpenROAD.

---

## 17. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `Can't locate Tk.pm` or `Tk::WorldCanvas` at start | running on the host; run inside the container (section 1.3) |
| `did not return a true value` at start | a fragment is missing its trailing `1;`; `make check-load` names it |
| `Undefined subroutine &main::...` when a command runs | the command is registered but its sub is not loaded; see Appendix A for the 57 such commands, or (in `electron_proto`) the config and synthesis commands |
| `ERROR-PAR-VERI : 017 : something is wrong with the verilog file` | yosys `(* src *)` attributes; filter them or use `synthesize` |
| `No module named scipy` from a placer | the host's miniconda shadows the container python; prefix `PATH=/usr/bin:$PATH`, and use `bash -c` not `bash -lc` |
| `ERROR-RTR-QROUTE : 013 : no qrouter on PATH and no container image` | build `pysparkpp.sif` (`cd INSTALL/podman && make qrouter`) or set `ELECTRON_CONTAINER` |
| `ERROR-PAR-SYNTH : 006 : no liberty given` | pass `-liberty`, or `read_library_config` then `get_std_cell_libs --first --set` |
| many failed nets, "has no taps" in `route.log` | qroute was left to write its own LEF; pass the PDK LEF with `-lef` |
| routed DEF has far more failures than expected | placement not legalised; run `legalize_flat` first |
| ports all on the left edge at (0,0) | unplaced ports report themselves on the west side; place them (`place_io_ports`, `hier_place -kinds INST,PORT`, or a DEF) |
| hierarchical placement not visible in `write_def` or the flat view | run `commit_module --physical_only` then `hier2flat --physical` |
| `hier_place` exits at once with no placement | no display; use `-batch <steps>` |
| `set_floorplan` says parameters already set | add `--force` |
| DEF after walking the hierarchy has a block-sized die, no pins, every cell outside | `TOP_MODULE` still names the last module `edit_module` opened; `set TOP_MODULE <top>` before `write_def` |
| a child module placed with everything on one point | it was opened before its parent was placed and committed; use `hier_place_all`, which walks parents first |
| `legalize_flat` says it needs rows | floorplan with `set_floorplan`, not `edit_module -util` alone |
| your own overlap check finds one overlap per row boundary | it compares in floating-point microns; compare in integer DBU, or use `TESTS/defmetrics.py` |
| two runs' DEFs differ although nothing changed | `write_def` record order differs per process; compare with `defmetrics.py --ref` |
| qrouter's unrouted count changes between identical runs | qrouter routes in DEF order, which follows Perl hash order; set `PERL_HASH_SEED=0 PERL_PERTURB_KEYS=0` |
| `improve_congestion` refuses to run | the placement is not legal; run `legalize_flat` first |
| `legalize_flat --pin_spread -placer ...` refuses | pin spreading exists only in the built-in legaliser; drop `-placer` |
| `defmetrics.py` reports undriven nets on an electron DEF | constant bits in hierarchical port connections are not tied off; a known defect, see `TESTS/large/openroad/REPORT_mxu_tile64.md` |
| OpenROAD rejects an electron DEF at the `UNITS` line | electron writes `DESIGN` after `UNITS`; run it through `TESTS/large/openroad/prep_def.py`, and read it with a LEF that declares the DEF's DBU |
| FastRoute stops with GRT-0080 on an electron placement | the ports are stacked on metal1 and outside the die; run `hier_place_pins -layers`, or re-place them with OpenROAD's `place_pins` |
| `mxu_1024` is killed or the machine swaps | it needs about 16 GB, more with the GUI open; use `mxu_256` |
| FlatView unusable on a large design | use the Raster tab or `raster_view` |
| a `sys` or `ls` line in a script prints `no such command` | shell passthrough works only at the prompt, not in `-f` scripts |
| instance coordinates in the DEF look like `22421.2` | mixed DBU and micron writes; report it, and never hardcode a DBU (`$GLOBAL->dbfGlobalGetDBU` is authoritative) |

---

## Appendix A. Command index

All 709 commands registered in `commandsFile`, with the sub that implements each, the
fragment that defines it (the last definition loaded wins), and the one-line description
from `DOCS/proton_cmd_desc.xlsx` where one exists. The table is generated by
`python3 DOCS/gen_command_index.py`, which keeps the descriptions already here; run it
after adding or removing a command and fill in the new row. Commands whose sub is not defined in
any required fragment fail with "Undefined subroutine" and are marked as such; most are
leftovers from earlier development. Many others are experiments or GUI helpers that are
not part of the two supported flows; the sections above name the ones that are.

| Command | Sub | File (last definition wins) | Description |
|---|---|---|---|
| `addHardMacroPowerRing` | `addHardMacroPowerRing` | POWER/make_sroute |  |
| `addPowerGridStripes` | `addPowerGridStripes` | POWER/make_sroute |  |
| `addPowerRing` | `addPowerRing` | POWER/make_sroute |  |
| `addPowerRows` | `addPowerRows` | POWER/make_sroute |  |
| `addPowerVias` | `addPowerVias` | POWER/make_sroute |  |
| `addStripes` | `addStripes` | POWER/make_sroute | add power stripe |
| `add_buffer` | `add_buffer` | ALGO/PREPLACE/make_place_supportFunc |  |
| `add_customer_stripe` | `add_customer_stripe` | POWER/make_sroute | add stripe for power routing |
| `add_data` | `add_data` | KNOWLEDGEBASE/make_manage_testcase | testcase data add |
| `add_endcap` | `add_endcap` | ALGO/PREPLACE/make_place_supportFunc |  |
| `add_filler_cells_in_gaps` | `add_filler_cells_in_gaps` | ALGO/PLACE_NEW/make_place_out_fine_tuned |  |
| `add_power_route` | `add_power_route` | POWER/make_sroute | power routing |
| `add_power_via` | `add_power_via` | POWER/make_sroute | add vias in overlapping region |
| `add_spice_cells_in_PLDB` | `add_spice_cells_in_PLDB` | UTILS/make_spice_place | adding spice elemrnt in pldb |
| `add_spice_input_output_in_VNOM` | `add_spice_input_output_in_VNOM` | UTILS/make_spice_place |  |
| `add_wellties` | `add_wellties` | ALGO/PREPLACE/make_place_supportFunc |  |
| `allowRlogin` | `allowRlogin` | PARSER/make_rw_ipc | for remote login |
| `allow_remote_login` | `allow_remote_login` | GUI_SERVER/make_server_rpc | allow to remote login |
| `analyse_library` | `analyse_library` | LIBANALYSIS/make_cell_footprint | analyse library |
| `analyze_pin_access` | `analyze_pin_access_II` | LIBANALYSIS/make_pinAccessII | cell pin analyze |
| `analyze_routing` | `analyze_routing` | DESANALYSIS/make_droute_analysis | analyze routing |
| `appendPG_to_lib` | `appendPG_to_lib` | PARSER/make_rw_lib | append library file |
| `arrange_datamatrix` | `arrange_datamatrix` | ALGO/PREPLACE/make_place_order_Smatrix | read the preplaced database and reorders the S-matrix row/column in the inc/dec order as specified by the user |
| `arrange_macros` | `arrange_macros` | PLACER/DATAPREP/make_rw_flat_graph |  |
| `bd_router` | `bd_router` | ROUTER/make_z_router | read input file of router and generate output file |
| `boundary_checker` | `boundary_checker` | TSTGEN/make_wx_netlist |  |
| `boundary_checker_pseudo` | `boundary_checker_pseudo` | TSTGEN/make_wx_netlist |  |
| `build_timing_graph` | `dbBuildTimingGraph` | TE/make_rw_sta | build timing graph |
| `calc_bbox_of_pType_and_nType_inst` | `calc_bbox_of_pType_and_nType_inst` | GUI/PROTO/make_write_layout_of_spice | calc bbox for p and n type transistor |
| `calc_loc_of_layout_trans` | `calc_loc_of_layout_trans` | (no sub defined in any required file) |  |
| `calc_loc_of_without_run_placement` | `calc_loc_of_without_run_placement` | GUI/PROTO/make_write_edp | calculate location of without run placer |
| `calculate_delay` | `calculate_delay` | (no sub defined in any required file) |  |
| `checkIf` | `checkIf` | TCL/make_tcl_commands | this command checks if the vaiable is set to something and pring Pass or Fail accordingly |
| `check_cell_on_grid` | `check_cell_on_grid` | (no sub defined in any required file) |  |
| `check_connection` | `check_connection` | (no sub defined in any required file) |  |
| `check_file_is_sp` | `check_file_is_sp` | TE/make_rw_spice | check file sp file |
| `check_location_exists_in_spice` | `check_location_exists_in_spice` | TE/make_rw_spice | check location of placed spice |
| `check_pin_in_design` | `check_pin_in_design` | UTILS/make_Robi_func |  |
| `check_routing_coord` | `check_routing_coord` | UTILS/make_Robi_func | check routing coord is routed or not |
| `combiPlace` | `combiPlace` | ALGO/PREPLACE/tempSeedPlace | combiPlace function is temporary code to place the flops of the design |
| `combine_lef` | `combine_lef` | PARSER/make_rw_lef | combine all .lef |
| `combine_lib` | `combine_lib` | PARSER/make_rw_lib | combine lib file |
| `combine_uniq_sp_files` | `combine_uniq_sp_files_sub` | (no sub defined in any required file) | binary of combine uniq sp file |
| `commitModuleLocOnly` | `commitModuleLocOnly` | TSTGEN/make_PseudoHierModel | commit location of pseudo module |
| `commit_module` | `commitModule` | TSTGEN/make_PseudoHierModel | commit pesudo module |
| `comp_rowStat_log` | `comp_rowStat_log` | UTILS/make_del_tmp_placer_files | check file difference |
| `compact_place` | `dbPlaceBlockCompactor` | ALGO/BLOCKPLACE/make_blockPlacer | place block in the chip and it tries minimize the area also |
| `compare_def_gui` | `compare_def_gui` | GUI/make_compare_def_gui | differnece between two def file in gui |
| `compare_models` | `compare_models` | LIBQA/make_libqa_design |  |
| `copy_moduleName_to_newName` | `copy_moduleName_to_newName` | UTILS/make_Robi_func | unique module create |
| `count_number_of_instance_to_be_placed_globally` | `count_number_of_instance_to_be_placed_globally` | UTILS/make_hierarchical_placement | count number of instance to be placed globally |
| `createPseudoHierModuleInst` | `createPseudoHierModuleInst` | TSTGEN/make_PseudoHierModel | create pseudo hier inst |
| `createPseudoInstance` | `createPseudoInstance` | TSTGEN/make_PseudoHierModel | create pseudo inst |
| `createPseudoModule` | `createPseudoModule` | TSTGEN/make_PseudoHierModel | create pseudo module |
| `createPseudoNet` | `createPseudoNet` | TSTGEN/make_PseudoHierModel | create pseudo net |
| `createPseudoRoutingBlockage` | `createPseudoRoutingBlockage` | TSTGEN/make_PseudoHierModel | pseudo routing blockage |
| `createPseudoTopModule` | `createPseudoTopModule` | TSTGEN/make_PseudoHierModel | create top module |
| `create_activity_heat_map_gcells` | `create_activity_heat_map_gcells` | GUI/make_heatMap_gui |  |
| `create_all_cell_image` | `create_all_cell_image` | GUI/make_lefView_image | create cell image |
| `create_array_via` | `create_array_via` | POWER/make_sroute | creating an array of via |
| `create_black_box_frm_pldb` | `create_black_box_frm_pldb` | UTILS/make_Robi_func | create black box |
| `create_bumps` | `create_bumps` | DESANALYSIS/make_FlipChip | create bump |
| `create_cell_info_frm_lib` | `create_cell_info_frm_lib` | PARSER/make_rw_lib | cell infor from lib |
| `create_chipbuilder_library` | `create_chipbuilder_library` | LIBANALYSIS/make_cell_footprint |  |
| `create_cmd_file_from_spice` | `create_cmd_file_from_spice` | TE/make_rw_spice | create cmd file from spice |
| `create_cmd_file_from_vcd` | `create_cmd_file_from_vcd` | TE/make_rw_spice | create cmd file from vcd |
| `create_def2png_all` | `create_def2png_all` | GUI/make_def2png_layers | create png |
| `create_def2png_layers` | `create_def2png_layers` | GUI/make_def2png_layers | crearte png foreach layer |
| `create_flat_design_pick_random_lef_cell` | `create_flat_design_pick_random_lef_cell` | TSTGEN/make_wx_netlist | create flat design for random lef cell |
| `create_flat_image` | `create_flat_image` | GUI/make_flatView_image | create image of flat |
| `create_flat_svg` | `create_flat_svg` | GUI/make_flatView_svg | create svg file |
| `create_gcell` | `create_gcell_db` | GUI/make_worldCan_def_gui | create gcell db |
| `create_gcell_frm_chip` | `create_gcell_frm_chip` | (no sub defined in any required file) |  |
| `create_gcells_flat_image` | `create_gcells_flat_image` | GUI/make_flatView_image | create gcell image for flat |
| `create_gcells_flat_svg` | `create_gcells_flat_svg` | GUI/make_flatView_svg | create svg for gcell |
| `create_gds_image` | `create_gds_image` | GUI/make_gds_image | create gds image |
| `create_hier_image` | `create_hier_image` | GUI/PROTO/make_hierView_image | create hier image from edp database |
| `create_leakage_power_heat_map_gcells` | `create_leakage_power_heat_map_gcells` | GUI/make_heatMap_gui |  |
| `create_lef_cell` | `create_lef_cell` | TSTGEN/make_PseudoPhysicalModel | create lef cell and populated macrodb database |
| `create_lef_image` | `create_lef_image` | GUI/make_lefView_image | create lef cell image |
| `create_lef_trans_from_given_data` | `create_lef_trans_from_given_data` | GUI/PROTO/make_write_layout_of_spice | update lef information and design information according to user |
| `create_net` | `create_net` | POWER/make_pg_connections |  |
| `create_netslen_array` | `create_netslen_array` | GUI/make_histogram_gui | to create an array of net's length |
| `create_new_field` | `create_new_field` | KNOWLEDGEBASE/make_manage_testcase | create new field |
| `create_new_model_file` | `create_new_model_file` | TE/make_rw_spice | create model file |
| `create_pad_cell_info_frm_lef` | `create_pad_cell_info_frm_lef` | UTILS/make_Robi_func | generate .txt for only pad cell and their size |
| `create_pad_info` | `create_pad_info` | UTILS/make_Robi_func | create pad info |
| `create_pad_ring` | `create_pad_ring` | PADFRAME/make_padframe |  |
| `create_pad_ring_cobalt` | `create_pad_ring_cobalt` | PADFRAME/make_padframe |  |
| `create_pad_ring_old` | `create_pad_ring_old` | PADFRAME/make_padframe |  |
| `create_pin_guide` | `createPinGuide` | TSTGEN/make_PseudoPhysicalModel | create guide pin |
| `create_placement_command_file_hierarchically` | `create_placement_command_file_hierarchically` | UTILS/make_hierarchical_placement | generated hier_place_command.tcl |
| `create_route` | `create_route` | POWER/make_sroute | net route(metal stripe) is created |
| `create_rows` | `create_rows` | PARSER/make_rw_def | command to add rows |
| `create_ruler` | `create_ruler` | GUI/make_ruler | to create ruler for distance measurement |
| `create_shape` | `create_shape` | POWER/make_sroute | creating net stripe |
| `create_sstv_frm_vcd` | `create_sstv_frm_vcd` | TE/make_rw_spice | create sstv frm vcd |
| `create_stripe` | `create_stripe` | POWER/make_sroute | create stripe |
| `create_stripe_from_given_loc` | `create_stripe_from_given_loc` | POWER/make_sroute | create stripe from given loc |
| `create_subdesign` | `create_subdesign` | TSTGEN/GEOMETRYENG/make_subdesign | Create a subdesign to include only the nets and their connectivity cells or pins for easy debugging |
| `create_timing_path_image` | `create_timing_path_image` | FLEX_COMMANDS/make_timing_browser | create timing path image |
| `create_via` | `create_via` | POWER/make_sroute | create via |
| `csv2sql` | `csv2sql` | KNOWLEDGEBASE/make_manage_testcase | csv2sql |
| `date` | `date` | executables | date command |
| `dbAnalyzeDesign` | `dbAnalyzeDesign` | TSTGEN/make_r_netlist | analyze design |
| `dbBlockPlacer_Shift` | `dbBlockPlacer_Shift` | ALGO/BLOCKPLACE/make_blockPlacer_Shift | also place the hard macro it also uses grid |
| `dbCheckInstTiming` | `dbCheckInstTiming` | TE/make_x_characterize | check inst timing |
| `dbDebugPlaceDB` | `dbDebugPlaceDB` | ALGO/SEEDPLACE/make_ankur_identify_seed | generate the info about the placer |
| `dbDisplaySMatrix3DPlot` | `dbDisplaySMatrix3DPlot` | PARSER/make_rw_lib | plotting the placement analysis gui |
| `dbGetBestMachine` | `dbGetBestMachine` | EFARM/make_manage_machines | connect machine |
| `dbGetModuleArea` | `dbGetModuleArea` | UTILS/make_verilog_utils | module area |
| `dbGuiDisplayLef` | `dbGuiDisplayLef` | GUI/make_lef_gui_II | display cell in gui |
| `dbGuiDisplayPlacement` | `dbGuiDisplayPlacement` | GUI/make_def_gui | it display placement of all the placed std cell and hard macro |
| `dbHier2Flat` | `dbHier2Flat` | DBA/make_dbXforms | hier2flat |
| `dbIsInstBlock` | `dbIsInstBlock` | PARSER/make_querry |  |
| `dbIsInstStdCell` | `dbIsInstStdCell` | PARSER/make_querry |  |
| `dbPlaceAnkurGetSeedFlops` | `dbPlaceAnkurGetSeedFlops` | ALGO/SEEDPLACE/make_ankur_identify_seed | generate seed placement by using flops |
| `dbPlaceBackTrace` | `dbPlaceBackTrace` | ALGO/PREPLACE/make_place_supportFunc | place back trace |
| `dbPlaceCreatePinBySide` | `dbPlaceCreatePinBySide` | ALGO/PREPLACE/make_PinBySide_db | PinInstDB |
| `dbPlaceCreateRowInstDB` | `dbPlaceCreateRowInstDB` | ALGO/PLACE_NEW/make_InstByRow_db | RowInstDB |
| `dbPlaceGenSlackRpt` | `dbPlaceGenSlackRpt` | ALGO/PREPLACE/make_place_supportFunc | Writing the report_timing tcl file to be sourced in FE |
| `dbPlacePortsAssignLayers` | `dbPlacePortsAssignLayers` | (no sub defined in any required file) |  |
| `dbPlaceReadSlackRpt` | `dbPlaceReadSlackRpt` | ALGO/PREPLACE/make_place_supportFunc | read timing report file |
| `dbPlaceShowDFM` | `dbPlaceShowDFM` | GUI/make_place_gui_supportFunc | print information of instance |
| `dbPlaceTraceBFS` | `dbPlaceTraceBFS` | (no sub defined in any required file) |  |
| `dbRouteCellInSingleLayer` | `dbRouteCellInSingleLayer` | LIBANALYSIS/make_pinAccessII | populate RouteCellDB database |
| `dbSetModuleArea` | `dbSetModuleArea` | UTILS/make_verilog_utils | set module area |
| `dbSqlGetNoOfDaysByLastRun` | `dbSqlGetNoOfDaysByLastRun` | DBA/SQL/make_testcase_package |  |
| `db_set_register_cell_cts` | `db_set_register_cell_cts` | PARSER/make_rwt_clock_tree |  |
| `db_set_tracable_cell_cts` | `db_set_tracable_cell_cts` | PARSER/make_rwt_clock_tree |  |
| `dbaGetInstPinRects` | `dbaGetInstPinRects` | DBA/make_dbAccess_func | database access command |
| `dbaGetMacroPins` | `dbaGetMacroPins` | DB/make_MacroDB_access_package |  |
| `dbaQueryInst` | `dbaQueryInst` | LIBANALYSIS/make_report_inst_and_net | inst query |
| `dbaReportNetWithNPins` | `dbaReportNetWithNPins` | LIBANALYSIS/make_report_inst_and_net | report generates when user gives a no of pins or summary of nets when give <--summary> |
| `dbfPlacementDB` | `dbfPlacementDB` | DESANALYSIS/make_design_analysis_gui | plotting the placement analysis gui |
| `dbgNetsNeedNoRouting` | `dbgNetsNeedNoRouting` | PARSER/make_def_analysis | net routing |
| `dbgPlaceInstFD` | `dbgPlaceInstFD` | (no sub defined in any required file) |  |
| `dbgPlaceMoveFInst` | `dbgPlaceMoveFInst` | (no sub defined in any required file) |  |
| `dbgPlaceShowForce` | `dbgPlaceShowForce` | (no sub defined in any required file) |  |
| `dbgPlaceUpdatePlace` | `dbgPlaceUpdatePlace` | (no sub defined in any required file) |  |
| `dbgPrePlace` | `dbgPrePlace` | (no sub defined in any required file) |  |
| `dbgetTracksFromDef` | `dbgetTracksFromDef` | PARSER/make_def_analysis |  |
| `def2cterm` | `def2cterm` | PARSER/make_rw_def | write top pin information in output file |
| `def2gds` | `def2gds` | UTILS/make_def_2_gds | convert def file into gds format |
| `def2lef` | `def2lef` | PARSER/make_rw_lef | convert def file into lef format |
| `defAnalysis` | `defAnalysis` | DESANALYSIS/make_report_design | def analysis in xml format |
| `defCompChange` | `defCompChange` | PARSER/make_querry | change component section |
| `defIn` | `defIn` | PARSER/make_rw_def | defIn command is used when already existing design has to be updated with the def file. It does not build a new database |
| `def_split_and_return_in_xml` | `def_split_and_return_in_xml` | DESANALYSIS/make_report_design | write design information in xml format |
| `delete_buffer` | `delete_buffer` | ALGO/PREPLACE/make_place_supportFunc |  |
| `delete_buffer_tree` | `delete_buffer_tree` | ALGO/PREPLACE/make_place_supportFunc | delete buffer |
| `delete_fillers` | `delete_fillers` | DBA/make_dbMod_func | delete filler |
| `delete_machine` | `delete_machine` | EFARM/make_manage_machines | delete machine |
| `delete_placer_files` | `delete_placer_files` | (no sub defined in any required file) |  |
| `delete_tmp_placer_files` | `delete_tmp_placer_files` | UTILS/make_del_tmp_placer_files | delete tmp placement file |
| `designAnalysisReport` | `designAnalysisReportSub` | UTILS/make_run_app_only | report generate in xml format but if user give iirpt then report generate in txt format |
| `design_display` | `design_display` | GUI/make_worldCan_def_gui | display the design |
| `design_rpt_in_xml` | `design_rpt_in_xml` | DESANALYSIS/make_report_design | generate report repot of design in xml format |
| `displacement_distribution` | `displacement_distribution` | UTILS/make_Robi_func | change instance location |
| `display_congestion_map` | `display_congestion_map` | DESANALYSIS/make_route_analysis | display the boxes in gui with different colours  according to no. of routing nets in boxes |
| `display_flat_bump` | `display_flat_bump` | GUI/make_worldCan_def_gui | display bump if stored in floorplan DB |
| `display_hier_inst_pin` | `display_hier_inst_pin` | GUI/PROTO/make_display_pseudo_hierarchy | display hier inst pin |
| `display_histogram` | `display_histogram` | GUI/make_histogram_gui | plot histogram for length of nets |
| `do_analyze` | `do_analyze` | PARSER/make_def_analysis | analyze |
| `do_analyze_routability` | `do_analyze_routability` | PARSER/make_def_analysis |  |
| `do_build_generic` | `do_build_generic` | PARSER/make_get_nets | build database for component and net |
| `do_change_placement_status` | `do_change_placement_status` | PARSER/make_def_analysis | change status of placement |
| `do_characterize_inst` | `do_characterize_inst` | PARSER/make_rw_lib | characterize of inst |
| `do_place` | `do_place` | (no sub defined in any required file) |  |
| `do_trace_clocks` | `do_trace_clocks` | PARSER/make_build_clock | tracing clock net |
| `down_hier` | `downHier` | TSTGEN/make_PseudoHierModel | down level hier instancce |
| `down_size` | `downSize` | PARSER/make_rw_def |  |
| `dstrbt_inst_unfrmly_in_row_btwn_row` | `dstrbt_inst_unfrmly_in_row_btwn_row` | ALGO/PLACE_NEW/make_place_out_fine_tuned | distribute inst uniformaly in row |
| `dumpFlopLocation` | `dumpFlopLocation` | (no sub defined in any required file) |  |
| `dump_placement` | `dump_placement` | UTILS/make_Robi_func | INST_LOC_DATA_2 file |
| `edit_module` | `editModule` | TSTGEN/make_PseudoHierModel | edit pseudo module |
| `edit_module_hierarchy` | `edit_module_hierarchy` | TSTGEN/make_PseudoHierModel | edit hier module |
| `elaborate` | `elaborate` | PARSER/make_elaborate | populate flat database |
| `eplacer` | `eplacer` | PLACER/DATAPREP/make_rw_flat_graph |  |
| `escape_router` | `escape_router` | POWER/make_sroute | set routing co-ordiante |
| `evaluate_of_parameter_expression` | `evaluate_of_parameter_expression` | TE/make_rw_spice | calc parameter expression |
| `evaluate_of_parameter_expression_for_hier` | `evaluate_of_parameter_expression_for_hier` | TE/make_rw_spice | calc parameter expression |
| `exit` | `exit_call` | executables | for exit |
| `export_all` | `export_all` | PARSER/make_w_export |  |
| `export_inst_loc` | `export_inst_loc` | PARSER/make_rw_def |  |
| `export_io_ports` | `export_io_ports` | PARSER/make_rw_def |  |
| `export_project` | `export_project` | PARSER/make_rw_electric |  |
| `extractDesign` | `extractDesign` | TSTGEN/GEOMETRYENG/make_cookie_def | This function extracts a part of a design within a given (x0,y0) and (x1,y1) coordinates |
| `extract_bumps` | `extract_bumps` | LIBANALYSIS/make_identifyBumps | extract bumps |
| `extract_def_bumps` | `extract_def_bumps` | DESANALYSIS/make_FlipChip | extract def bumps |
| `find_cell_crossover` | `find_cell_crossover` | (no sub defined in any required file) |  |
| `find_conn` | `find_conn` | PARSER/make_querry | find conn |
| `find_conn_no_reg` | `find_conn_no_reg` | PARSER/make_querry | find conn of reg |
| `find_gcell_size` | `find_gcell_size` | (no sub defined in any required file) |  |
| `find_inst` | `find_inst` | PARSER/make_querry | find inst info |
| `find_net` | `find_net` | PARSER/make_querry | find net info |
| `find_pinDensity` | `find_pinDensity` | LIBANALYSIS/make_find_pinDensity | find pin density |
| `find_pinFactor` | `find_pinFactor` | LIBANALYSIS/make_lef_analysis | find pin factor |
| `find_port` | `find_port` | PARSER/make_querry | find port |
| `fixExternalDef` | `fixExternalDef` | ALGO/POSTPLACE/make_postPlace_func | info message is orientation change from FW to R90 |
| `fix_mpl_output` | `fix_mpl_output` | UTILS/make_Robi_func | fix xml output |
| `flat2VNOM` | `flat2VNOM` | UTILS/make_Robi_func | adding logical and physical in vnom |
| `flat_route` | `flat_route` | ROUTER/make_astar_router |  |
| `flatten_design` | `flatten_design` | PARSER/make_flatten_hier | flatting design |
| `flip` | `flip_inst` | DESANALYSIS/make_droute_analysis |  |
| `flip_chip` | `flip_chip` | PARSER/make_rw_def | flip chip |
| `floorplan` | `set_floorplan` | PARSER/make_floorplan |  |
| `flplan_align_inst` | `flplan_align_inst` | ALGO/FLPLAN/make_floorplan_engine | line up instances in horizontal or vertical dir |
| `fpdef2gds` | `fpdef2gds` | UTILS/make_def_2_gds | convert fdef into gds format |
| `fracture_netlist` | `fracture_netlist` | TE/make_rw_spice | write timing report file |
| `genLVSData` | `genLVSDataSub` | UTILS/make_run_app_only | gen lvs data |
| `gen_design_connection_analysis_report` | `gen_design_connection_analysis_report` | UTILS/gen_vertex_file | connection analysis report file |
| `gen_fanout_file` | `gen_fanout_file` | UTILS/gen_fanout_file | degree vs number of net |
| `gen_fanout_file_fast` | `gen_fanout_file_fast` | UTILS/gen_fanout_file | degree vs number of net |
| `gen_final_degree_for_all_nodes` | `gen_final_degree_for_all_nodes` | UTILS/gen_vertex_file | generate degree vs node after puring |
| `gen_footprint` | `gen_footprint` | UTILS/make_liberty_utils | generate footprint file |
| `gen_initial_degree_for_all_nodes` | `gen_initial_degree_for_all_nodes` | UTILS/gen_vertex_file | generate degree vs node before puring |
| `gen_libqa_design` | `gen_libqa_design` | LIBQA/make_libqa_design | generate design database |
| `gen_vertex_file` | `gen_vertex_file` | UTILS/gen_vertex_file | gen vertex file |
| `gen_vertex_file_fast` | `gen_vertex_file_fast` | UTILS/gen_vertex_file | degreee vs node |
| `gen_vertex_file_plan` | `gen_vertex_file_plan` | UTILS/gen_vertex_file | degreee vs node |
| `gen_vertex_file_plan_fast` | `gen_vertex_file_plan_fast` | UTILS/gen_vertex_file | degreee vs node |
| `generate_LVS_data_for_given_module` | `generate_LVS_data_for_given_module` | UTILS/make_Robi_func | generate lvs data for given module |
| `generate_NR_tracks` | `generate_NR_tracks` | (no sub defined in any required file) | generate tracks |
| `generate_ctgen_struct_file` | `generate_ctgen_struct_file` | PARSER/make_rwt_clock_tree | tracing net connection |
| `generate_design_area_PLV` | `generate_design_area_PLV` | (no sub defined in any required file) |  |
| `generate_fe_selectInst` | `generate_fe_selectInst` | TE/make_r_extSTA | write information of timing report |
| `generate_netlist` | `generate_netlist` | TSTGEN/make_wx_netlist | generate netlist |
| `generate_netlist_new` | `generate_netlist_new` | TSTGEN/make_wx_netlist |  |
| `generate_pads_label_file` | `generate_pads_label_file` | PADFRAME/make_padframe |  |
| `generate_tracks` | `generate_tracks` | (no sub defined in any required file) |  |
| `getCellPinRect` | `getCellPinRect` | TCL/make_tcl_commands | write cell pin rect information |
| `getCrossoverPoints` | `getCrossoverPoints` | LIBANALYSIS/make_pinAccess | calculate cross over point |
| `getFlopPairDist` | `getFlopPairDist` | PARSER/make_def_analysis | calaculate distance between flop |
| `getInfo` | `getInfo` | make_global_commands | get info |
| `getInstPairDist` | `getInstPairDist` | PARSER/make_def_analysis | calaculate distance between inst |
| `getLefCellList` | `getLefCellList` | PARSER/make_rw_lef | write cell list in xml format |
| `getNetDriver` | `getNetDriver` | UTILS/gen_net_func |  |
| `getNetSink` | `getNetSink` | UTILS/gen_net_func |  |
| `get_area` | `get_area` | executables | get area |
| `get_best_machine` | `get_best_machine` | EFARM/make_services | it select the most lightly loaded machine in our network |
| `get_cell` | `get_cell` | (no sub defined in any required file) |  |
| `get_cell_definition` | `get_cell_definition` | PARSER/make_w_rtl | cell information |
| `get_centroid` | `get_centroid` | UTILS/make_Robi_func | to find centroid of Octagon |
| `get_children_area` | `get_children_area` | FLEX_COMMANDS/make_rtl_estimation | calc instance area |
| `get_conn_chiprect` | `get_conn_chiprect` | ALGO/PLACE_NEW/make_leastpath_resistance | conn chiprect |
| `get_conn_rect` | `get_conn_rect` | ALGO/PLACE_NEW/make_leastpath_resistance | conn rect |
| `get_conn_sprect` | `get_conn_sprect` | ALGO/PLACE_NEW/make_leastpath_resistance | conn sprect |
| `get_data_of_hier_inst` | `get_data_of_hier_inst` | TE/make_rw_spice | data of hier inst |
| `get_def_checker` | `get_def_checker` | DESANALYSIS/make_report_design | report for def |
| `get_design` | `get_design` | UTILS/perl_dump | design information |
| `get_histogram_data` | `get_histogram_data` | FLEX_COMMANDS/make_timing_browser | histogram data in xml format |
| `get_input_output_port_frm_spice_vnom` | `get_input_output_port_frm_spice_vnom` | (no sub defined in any required file) |  |
| `get_inst` | `get_inst` | PARSER/make_querry | return an array placed,unplaced and fixed inst |
| `get_inst_pins_offset` | `get_inst_pins_offset` | UTILS/make_Robi_func |  |
| `get_list_spnets` | `get_list_spnets` | PARSER/make_rw_def |  |
| `get_listed_nets` | `get_listed_nets` | DESANALYSIS/make_report_design | information of net |
| `get_machine_attribute` | `get_machine_attribute` | DBA/SQL/make_eFarm_package | It returns the attribute value for a given machine |
| `get_macro` | `get_macro` | (no sub defined in any required file) |  |
| `get_module_rtl_area` | `get_module_rtl_area` | UTILS/make_verilog_utils | calc rtl area |
| `get_net_dir` | `get_net_dir` | DESANALYSIS/make_route_length_analysis | per layer preferdirection and non-preferdirection |
| `get_net_wl` | `get_net_wl` | DESANALYSIS/make_route_length_analysis | calc net wire length |
| `get_nets_driver_pin_loc` | `get_nets_driver_pin_loc` | DESANALYSIS/make_design_analysis |  |
| `get_nets_lengtharray` | `get_nets_lengtharray` | DESANALYSIS/make_report_routing | calculate the length of each net and return array nets length |
| `get_node_status` | `get_node_status` | DBA/SQL/make_testcase_package | It tests whether testcase is nodelocked or not |
| `get_num_gcell` | `get_num_gcell` | DESANALYSIS/make_gcell |  |
| `get_report_summary` | `get_report_summary` | FLEX_COMMANDS/make_timing_browser | timing report summary in xml |
| `get_routing_resource` | `get_routing_resource` | PARSER/make_lef_analysis |  |
| `get_rtl_area_foreach_module` | `get_rtl_area_foreach_module` | PARSER/make_w_rtl | calc rtl area foreach module |
| `get_selected_instance` | `get_selected_instance` | GUI/make_worldCan_def_gui | returns the name of selected instance |
| `get_selected_instance_new` | `get_selected_instance_new` | GUI/make_worldCan_def_gui | returns the name of selected instance |
| `get_sink_list_of_buffer_or_inv` | `get_sink_list_of_buffer_or_inv` | UTILS/gen_net_func | list of buffer or inv |
| `get_spnet_dir` | `get_spnet_dir` | DESANALYSIS/make_specialnetdir_analysis | per layer preferdirection and non-preferdirection |
| `get_spnet_wl` | `get_spnet_wl` | (no sub defined in any required file) |  |
| `get_std_cell_libs` | `get_std_cell_libs` | PARSER/make_rw_config |  |
| `get_testcase_attribute` | `get_testcase_attribute` | DBA/SQL/make_testcase_package | it get the value for any testcase attribute name |
| `gui` | `win` | GUI/make_rw_gui | for gui |
| `gui_hilite_sta_path` | `gui_hilite_sta_path` | GUI/make_timing_gui |  |
| `guide_pin` | `guidePin` | TSTGEN/make_PseudoPhysicalModel | pin guide to be created |
| `hardenPartition` | `hardenPartition` | TSTGEN/make_PseudoPhysicalModel | create lef cell |
| `hardenPartitionForAllModule` | `hardenPartitionForAllModule` | TSTGEN/make_PseudoPhysicalModel | create lef cell for all module |
| `help` | `help` | UTILS/make_help | when type help print all commands or when type help they give list of possible options |
| `hier2flat` | `hier2flat` | UTILS/make_Robi_func | convert db from hier 2 flat |
| `hier2flatroutingdata` | `hier2flatroutingdata` | (no sub defined in any required file) |  |
| `hier_connectivity` | `hier_connectivity` | TSTGEN/make_hier_place_graph |  |
| `hier_parameter_value` | `hier_parameter_value` | TE/make_rw_spice | for port net mapping |
| `hier_place` | `hier_place` | TSTGEN/make_hier_place_graph |  |
| `hier_place_all` | `hier_place_all` | TSTGEN/make_hier_place_all | place every module of the hierarchy top down: hier_place, hier_place_cells, commit_module per module, then hier2flat |
| `hier_place_cells` | `hier_place_cells` | TSTGEN/make_hier_place_graph | place the leaf cells of one module around the blocks, flops and ports hier_place fixed |
| `hier_place_pins` | `hier_place_pins` | TSTGEN/make_hier_pin_placement |  |
| `hier_rpt_inst_map` | `hier_rpt_inst_map` | LIBANALYSIS/make_inst_map_file | when write_hier_place_graph cmd not run then HIER_TEMP hash populated |
| `hilite_sta_path` | `hilite_sta_path` | TE/make_r_extSTA | for timing report |
| `improve_congestion` | `improve_congestion` | ALGO/PLACE_NEW/make_improve_congestion | wirelength-driven detailed placement on a legal placement: legal-to-legal swaps and row slides |
| `initFlopPlacement` | `initFlopPlacement` | (no sub defined in any required file) |  |
| `initKB` | `initKB` | KNOWLEDGEBASE/make_register_testcase | It initailize the database and create table |
| `init_machine_database` | `init_machine_database` | EFARM/make_initMacDB | initailize the machine database |
| `instpin_to_spnet` | `instpin_to_spnet` | ALGO/PLACE_NEW/make_leastpath_resistance | inst pin to sp net |
| `least_path_resistance` | `least_path_resistance` | (no sub defined in any required file) | calc least path resistance |
| `least_resis` | `least_resis` | (no sub defined in any required file) |  |
| `lef2def` | `lef2def` | PARSER/make_rw_def | def file generated for any block class cell |
| `lef2gds` | `lef2gds` | UTILS/make_def_2_gds | convert lef into gds format |
| `lef2verilog` | `lef2verilog` | PARSER/make_rw_verilog |  |
| `lefCombiner` | `lefCombiner` | PARSER/make_rw_lef | combine all .lef |
| `legalize` | `place_output_fine_tune` | ALGO/PLACE_NEW/make_place_out_fine_tuned | place instnace between row |
| `legalizePlace` | `legalizePlace` | (no sub defined in any required file) |  |
| `legalize_flat` | `legalize_flat` | ALGO/PLACE_NEW/make_legalize_flat | Abacus legalisation onto rows and sites, with a local density cap and optional pin density relief |
| `loadBlockXls` | `loadBlockXls` | PARSER/make_rw_xls | read xls file for block |
| `loadNetXls` | `loadNetXls` | PARSER/make_rw_xls | read xls file for net |
| `machine_mem` | `machine_mem` | (no sub defined in any required file) |  |
| `macro_arranger` | `macro_arranger` | ALGO/PLACE_NEW/make_macro_arranger | arranges macro instances for a given cellref in a tile as per specified constraints |
| `make_build` | `make_build` | (no sub defined in any required file) |  |
| `make_gcellDB` | `make_gcellDB` | DESANALYSIS/make_gcell | make gcell db |
| `make_gcell_print_netstat` | `make_gcell_print_netstat` | DESANALYSIS/make_gcell | make gcell print |
| `make_l` | `make_l` | (no sub defined in any required file) |  |
| `make_plef` | `make_plef` | PARSER/make_rw_plef | write lef cell information with input and output pin and their total count |
| `make_seed_place` | `make_seed_place` | ALGO/PLACE/make_seed_place | seed place |
| `mangalPlace` | `mangalPlace` | (no sub defined in any required file) |  |
| `memusage` | `memusage` | UTILS/make_unixLike_commands | memory usage |
| `min_dis_x_y` | `min_dis_x_y` | UTILS/make_Robi_func | location check |
| `mincut_placer` | `mincut_placer` | PLACER/DATAPREP/make_rw_flat_graph |  |
| `modify_instance` | `modify_instance` | ALGO/POSTPLACE/make_postPlace_func | modify instance |
| `moveFlatInst` | `moveFlatInst` | GUI/make_worldCan_def_gui | move flat instance |
| `moveRegSelected` | `moveRegSelected` | (no sub defined in any required file) |  |
| `netwl_routing` | `netwl_routing` | DESANALYSIS/make_route_length_analysis | find wire length of a nets |
| `new_command_testing` | `new_command_testing` | UTILS/make_test_pseudo_command_for_casey | test pseudo command |
| `new_place_design_hierarchy_from_earlyProto_DB` | `new_place_design_hierarchy_from_earlyProto_DB` | UTILS/make_test_final | place for hier design |
| `node_displacement` | `node_displacement` | UTILS/make_Robi_func | Start finding displacement for ports and instances |
| `over` | `over` | PARSER/make_rw_ipc |  |
| `p2v` | `p2v` | RTL/p2v | pverilog convert to verilog |
| `parallel_jobs` | `parallel_jobs` | (no sub defined in any required file) |  |
| `pinNet_wirelength` | `pinNet_wirelength` | (no sub defined in any required file) |  |
| `pin_place_hier` | `hier_place_pins` | TSTGEN/make_hier_pin_placement | pin place hier |
| `pins_density` | `pins_density` | ALGO/PLACE_NEW/make_pins_density | find pins density foreach row |
| `place` | `place` | (no sub defined in any required file) | place macro |
| `placeGrid` | `placeGrid` | ALGO/PREPLACE/make_place_grid | flop placed in grid |
| `placePorts` | `placePorts` | ALGO/PLACE/make_place_ports | place top level pin |
| `placeSA` | `placeSA` | ALGO/PLACE/placeSA | implement placement using simulated annealing functions in this file |
| `placeSA_calcSolnCost` | `placeSA_calcSolnCost` | ALGO/PLACE/placeSA | implement placement using simulated annealing functions in this file |
| `place_ann` | `place_ann` | (no sub defined in any required file) |  |
| `place_design` | `place_design` | ALGO/PLACE/make_place | place design |
| `place_design_hierarchy_from_earlyProto_DB` | `place_design_hierarchy_from_earlyProto_DB` | UTILS/make_hierarchical_placement | place design hierarchy |
| `place_design_hierarchy_from_earlyProto_DB_plan_1` | `place_design_hierarchy_from_earlyProto_DB_plan_1` | UTILS/make_plan_1_hierarchical_placement | for plan_1 |
| `place_flat_design` | `place_flat_design` | PLACER/DATAPREP/make_rw_flat_graph |  |
| `place_graph` | `place_graph` | PLACER/DATAPREP/make_run_placement_file | plan_1 run |
| `place_graph_Smatrix` | `place_graph_Smatrix` | PLACER/DATAPREP/smatrix_placement/make_run_smatrix_placement | for smatrix |
| `place_graph_basic_mode` | `place_graph_basic_mode` | PLACER/DATAPREP/make_run_placement_file | plan_1 run |
| `place_graph_basic_mode_with_pin_offset` | `place_graph_basic_mode_with_pin_offset` | PLACER/DATAPREP/make_run_placement_file | placer not run |
| `place_graph_detail` | `place_graph_detail` | PLACER/DATAPREP/make_run_placement_file | plan_1 and plan_2 run |
| `place_graph_detail_plan_3` | `place_graph_detail_plan_3` | PLACER/DATAPREP/make_run_placement_file | plan_3 run |
| `place_graph_graywolf_pseudo` | `place_graph_graywolf_pseudo` | PLACER/FUNTIONS/make_placer_commands |  |
| `place_graph_macro_expanded` | `place_graph_macro_expanded` | PLACER/DATAPREP/make_run_placement_file | plan_1 run |
| `place_graph_mpl` | `place_graph_mpl` | PLACER/DATAPREP/make_run_placement_file | mpl run |
| `place_graph_plan_1_pseudo` | `place_graph_plan_1_pseudo` | PLACER/DATAPREP/make_run_placement_file | plan_1 run from pseudo database |
| `place_graph_plan_4` | `place_graph_plan_4` | PLACER/DATAPREP/make_run_placement_file | plan_4 run |
| `place_graph_plan_4_pseudo` | `place_graph_plan_4_pseudo` | PLACER/DATAPREP/make_run_placement_file | plan_4 run from pseudo database |
| `place_graph_plan_6` | `place_graph_plan_6` | PLACER/DATAPREP/make_run_placement_file | plan_6 run |
| `place_graph_plan_6_only` | `place_graph_plan_6_only` | PLACER/DATAPREP/make_run_placement_file | plan_6 run |
| `place_graph_plan_6_pseudo` | `place_graph_plan_6_pseudo` | PLACER/DATAPREP/make_run_placement_file | plan_6 run from pseudo database |
| `place_graph_sequential` | `place_graph_sequential` | (no sub defined in any required file) |  |
| `place_graywolf` | `place_graywolf` | PLACER/FUNTIONS/make_placer_commands |  |
| `place_hier_fractal` | `place_hier_fractal` | PLACER/FUNTIONS/make_placer_commands |  |
| `place_hier_graywolf` | `place_hier_graywolf` | PLACER/FUNTIONS/make_placer_commands |  |
| `place_io_ports` | `place_io_ports` | ALGO/PREPLACE/make_place_supportFunc |  |
| `place_output_fine_tune` | `place_output_fine_tune` | ALGO/PLACE_NEW/make_place_out_fine_tuned | changed loc of inst without floationg |
| `place_unplaced_inst` | `place_unplaced_inst` | UTILS/make_Robi_func | place of unplaced inst from 0,0 location |
| `plot_activity_heat_map` | `plot_activity_heat_map` | GUI/make_heatMap_gui |  |
| `plot_analysis_graph` | `plot_analysis_graph` | ALGO/PREPLACE/make_place_supportFunc | plot analysis |
| `plot_graph` | `plot_graph` | KNOWLEDGEBASE/make_kb_plots | plotting graph between data of two fields |
| `plot_graph_outside` | `plot_graph_outside` | KNOWLEDGEBASE/make_kb_plots | plotting graph between data of two fields |
| `plot_leakage_power_heat_map` | `plot_leakage_power_heat_map` | GUI/make_heatMap_gui |  |
| `plot_lib_data` | `plot_lib_data` | GUI/make_lib_gui | timimg plot for lib data |
| `populate_pldb_frm_vnom` | `populate_pldb_frm_vnom` | PARSER/make_w_rtl | populate pldb frm vnom |
| `power_escape_router` | `power_escape_router` | POWER/make_sroute |  |
| `prePlaceData` | `prePlaceData` | ALGO/PREPLACE/make_place_db | populate preplace database |
| `print` | `print` | executables | print |
| `printSM` | `printSM` | DESANALYSIS/make_design_analysis | print sm from place db |
| `printSM_new` | `printSM_new` | DESANALYSIS/make_design_analysis | print sm from place db |
| `print_clock_tree_info_cmd` | `print_clock_tree_info_cmd` | UTILS/gen_net_func | print inst info |
| `print_design_hierarchy` | `print_design_hierarchy` | UTILS/make_hierarchical_placement | print design hier |
| `print_dirty_bit_hier_module` | `print_dirty_bit_hier_module` | UTILS/make_Robi_func |  |
| `print_machine_attribute` | `print_machine_attribute` | DBA/SQL/make_eFarm_package | It prints the selected attribute value for machine |
| `print_smatrix` | `print_smatrix` | GUI/PROTO/make_display_pseudo_hierarchy | print smatrix |
| `print_testcase_attribute` | `print_testcase_attribute` | DBA/SQL/make_testcase_package | It prints the columnnames value for RID=0 or print all the colunm value for given testname |
| `pseudo_inst_status` | `pseudo_inst_status` | UTILS/make_Robi_func | set pseudo instance |
| `purge_module` | `purgeModule` | TSTGEN/make_PseudoHierModel | purge module |
| `puts` | `puts` | TCL/make_tcl_commands |  |
| `qroute` | `qroute` | ROUTER/make_maze_router |  |
| `query` | `query` | TCL/make_tcl_commands | design information |
| `raster_view` | `raster_view` | GUI/make_raster_view | draw the in-memory design or a DEF as an image, for designs too large for the canvas |
| `read_astar_routes` | `read_astar_routes` | ROUTER/make_astar_router |  |
| `read_cdl` | `read_cdl` | PARSER/make_rw_cdl |  |
| `read_cdump` | `read_cdump` | PARSER/make_rw_fe | read cdump file |
| `read_cell_func_map` | `read_cell_func_map` | LIBANALYSIS/make_cell_func_map |  |
| `read_command_file` | `read_command_file` | EXTCOMMANDS/make_rw_external_commands | read command file |
| `read_config_file` | `read_config_file` | PARSER/make_rw_config |  |
| `read_congestion_map` | `read_congestion_map` | DESANALYSIS/make_route_analysis | read congestion map file |
| `read_csv_for_spice_model` | `read_csv_for_spice_model` | TE/make_rw_spice | read csv file |
| `read_data_xls` | `read_data_xls` | GUI/PROTO/make_write_edp | read xls file |
| `read_def` | `read_defII` | PARSER/make_rw_def | read def file |
| `read_def_eco` | `read_def_eco` | PARSER/make_rw_def | read comp and net section in def |
| `read_def_hierarchy` | `read_def_hierarchy` | PARSER/make_rw_def | populated vnom database from def |
| `read_edif` | `read_edif` | PARSER/make_rw_edif | read edif file |
| `read_flat_graph_placement` | `read_flat_graph_placement` | PLACER/DATAPREP/make_rw_flat_graph |  |
| `read_flat_nodefile` | `read_flat_nodefile` | PLACER/DATAPREP/make_rw_flat_graph |  |
| `read_flat_router` | `read_flat_router` | TSTGEN/make_router_graph_file | read for flat db |
| `read_footprint` | `read_footprint` | PARSER/make_rw_lib | read footprint file |
| `read_gds` | `read_gds_layer` | PARSER/make_rw_gds | read gds file |
| `read_gds_layer` | `read_gds_layer` | PARSER/make_rw_gds | read layer rectangles |
| `read_graph` | `read_graph` | PLACER/DATAPREP/make_read_graph_files | read output file of plan_1 |
| `read_graph_detail` | `read_graph_detail` | PLACER/DATAPREP/make_read_graph_files | read output file of plan_2 |
| `read_graph_detail_node` | `read_graph_detail_node` | PLACER/DATAPREP/make_read_graph_files | read output file of placer |
| `read_graph_detail_plan_3` | `read_graph_detail_plan_3` | PLACER/DATAPREP/make_read_graph_files | read output file of plan_3 |
| `read_graph_for_spice` | `read_graph_for_spice` | PLACER/DATAPREP/make_read_graph_files | read xy.out file |
| `read_graph_new` | `read_graph_new` | UTILS/make_place_graph_new | read output file of placer |
| `read_graph_node` | `read_graph_node` | PLACER/DATAPREP/make_read_graph_files | read output file of placer |
| `read_graph_plan_4` | `read_graph_plan_4` | PLACER/DATAPREP/make_read_graph_files | read ouput file of plan_4 |
| `read_graph_store_map` | `read_graph_store_map` | PLACER/DATAPREP/make_read_graph_files | read output file of placer |
| `read_graywolf_placement_result` | `read_graywolf_placement_result` | PLACER/DATAPREP/make_rw_graywolf_files |  |
| `read_hdl` | `read_hdl_II` | PARSER/make_r_rtl | read hdl file |
| `read_hdl_data` | `read_hdl_data` | PARSER/make_r_rtl | read hdl file |
| `read_hdl_est` | `read_hdl_est` | PARSER/make_r_rtl | read hdl file |
| `read_hier_floorplan` | `read_hier_floorplan` | TSTGEN/make_pseudo_floorplan | read fpdef file |
| `read_hier_place_graph` | `read_hier_place_graph` | TSTGEN/make_hier_place_graph | read placement related file for hier |
| `read_hier_router` | `read_hier_router` | TSTGEN/make_router_graph_file | read for hier db |
| `read_lef` | `read_lef` | PARSER/make_rw_lef | read lef file |
| `read_lib` | `read_lib` | PARSER/make_rw_lib | read lib file |
| `read_lib_old` | `read_lib_old` | PARSER/make_rw_lib | read lib file |
| `read_library_config` | `read_library_config` | PARSER/make_rw_config |  |
| `read_parameters` | `read_parameters` | GUI/make_design_elements |  |
| `read_plef` | `read_plef` | PARSER/make_rw_plef | read generated plef file of lef cell |
| `read_pseudo_nodefile` | `read_pseudo_nodefile` | TSTGEN/make_hier_place_graph |  |
| `read_report_timing` | `read_report_timing` | PARSER/make_rw_timing_report | read a timing report file |
| `read_rpt_inst_map` | `read_rpt_inst_map` | LIBANALYSIS/make_inst_map_file | read inst rpt file |
| `read_scan` | `read_scan` | PARSER/make_rw_def | read scan file |
| `read_sdc` | `read_sdc` | TE/make_rw_sdc | read sdc file |
| `read_spice` | `read_spice` | TE/make_rw_spice | read spice file |
| `read_spice_model_new` | `read_spice_model_new` | TE/make_rw_spice | read spice model file |
| `read_spice_models` | `read_spice_models` | TE/make_rw_spice | read spice model file |
| `read_spice_new` | `read_spice_new` | TE/make_rw_spice | read spice file |
| `read_sta_report` | `read_sta_report` | TE/make_r_extSTA | read sta report file |
| `read_tcf` | `read_tcf` | GUI/make_heatMap_gui |  |
| `read_timing_report` | `read_timing_report` | FLEX_COMMANDS/make_timing_browser | read a timing report file |
| `read_verilog` | `read_verilog` | PARSER/make_rw_verilog | read verilog file |
| `read_xls` | `read_xls` | KNOWLEDGEBASE/make_write_excel | read the data fom xls and update the corresponding database |
| `read_xml` | `read_xml` | PARSER/make_rw_xml | read xml file |
| `refinePlace` | `refinePlace` | ALGO/PREPLACE/make_place_supportFunc | placement refine and overlap removal |
| `register_master_machine` | `register_master_machine` | EFARM/make_manage_machines | register master machine |
| `register_slave_machine` | `register_slave_machine` | EFARM/make_manage_machines | register slave machine |
| `register_testcase` | `register_testcase` | KNOWLEDGEBASE/make_register_testcase | register testcase |
| `remove_congestion` | `remove_congestion` | ALGO/PLACE_NEW/make_remove_congestion | reads the placed database which has been snapped to row and removes the congestion in the selescted area,Also removes overlap in the selected area as well as the whole design |
| `remove_hier_pins_overlap` | `remove_hier_pins_overlap` | TSTGEN/make_remove_hier_pins_overlap | remove pin overlap of hier |
| `remove_overlap` | `remove_overlap` | ALGO/PLACE_NEW/make_remove_overlap | reads the placed database which has been snapped to row and removes overlapping of the cells,remove_overlap has the following command line options and switches |
| `remove_overlap_block` | `remove_overlap_block` | ALGO/PLACE_NEW/make_remove_overlap_block | reads the placed database which has been snapped to row and removes overlapping of the cells,The database can contain hard blocks also,remove_overlap_block has the following command line options and switches |
| `remove_pins_overlap` | `remove_pins_overlap` | ALGO/PREPLACE/make_remove_pins_overlap | remove pin overlap |
| `reorderPlacementDB` | `reorderPlacementDB` | TSTGEN/make_r_analysis | for placemment db |
| `replace_bb_inst_with_liberty_cell_inst` | `replace_bb_inst_with_liberty_cell_inst` | PARSER/make_rw_verilog | replace bb inst |
| `reportFileSize` | `reportFileSize` | TCL/make_tcl_commands | print file size |
| `reportP2Ptiming` | `reportP2Ptiming` | TE/make_rw_hta | report p2p timing |
| `reportScanChains` | `reportScanChains` | ALGO/POSTPLACE/make_postPlace_func | report scan chain |
| `report_area` | `report_area` | executables | report area of design |
| `report_cell_func` | `report_cell_func` | LIBANALYSIS/make_cell_func_map |  |
| `report_cell_pin_access` | `report_cell_pin_access` | LIBANALYSIS/make_report_pin_access | report generate detail and summary |
| `report_cell_power` | `report_cell_power` | LIBANALYSIS/make_report_pin_access |  |
| `report_design` | `report_design` | PARSER/make_querry | report desing |
| `report_design_hierarchy` | `report_design_hierarchy_bd` | FLEX_COMMANDS/make_design_hierarchy | report generate for hier design |
| `report_design_hierarchy_new` | `report_design_hierarchy_new` | TSTGEN/make_PseudoHierModel | report generate for hier design |
| `report_design_new` | `report_design_new` | DESANALYSIS/make_report_design | report generate of desing text and xml format both |
| `report_design_xml` | `report_design_xml` | DESANALYSIS/make_report_design | report generate in xml format |
| `report_gcell_netstat` | `make_gcell_print_netstat` | DESANALYSIS/make_gcell |  |
| `report_instance` | `report_instance` | DESANALYSIS/make_report_routing | report instance |
| `report_lef_analysis_xml` | `report_lef_analysis_xml` | LIBANALYSIS/make_lef_analysis | write lef cell information in xml format |
| `report_lef_qor` | `report_lef_qor` | DESANALYSIS/make_report_design | write lef information in xml format |
| `report_mem` | `report_memory_usage` | DESANALYSIS/make_design_analysis | report memory usage |
| `report_net` | `report_net` | DESANALYSIS/make_report_net_command | reported net information |
| `report_net_wl` | `report_net_wl` | DESANALYSIS/make_design_analysis | reported total wire length of routed net |
| `report_net_wl_old` | `report_net_wl_old` | DESANALYSIS/make_report_routing | find wire length of a nets |
| `report_netlist_qor` | `report_netlist_qor` | DESANALYSIS/make_report_design | design report generate in xml format |
| `report_pin_access` | `report_pin_access` | DESANALYSIS/make_report_routing | pin access report file |
| `report_place` | `report_place` | ALGO/PREPLACE/make_place_supportFunc | report for placement for instance |
| `report_routing` | `report_routing` | (no sub defined in any required file) |  |
| `report_routing_channel` | `report_routing_channel` | DESANALYSIS/make_report_design | report routing channel |
| `report_runtime` | `report_runtime` | UTILS/make_help | report run time |
| `report_spice_area` | `report_spice_area` | TE/make_rw_spice | report spice area |
| `report_sta_vesta` | `report_sta_vesta` | TE/make_rw_sta |  |
| `report_test_summary` | `report_test_summary` | KNOWLEDGEBASE/make_test_summary | report test summary |
| `report_timing` | `report_timing_sta` | TE/make_rw_sta | generate timing report file |
| `report_verilog_area` | `report_verilog_area` | UTILS/make_verilog_utils | report verilog area |
| `report_verilog_design` | `report_verilog_design` | PARSER/make_querry | print verilog design information |
| `report_worst_timing_path` | `report_worst_timing_path` | TE/make_rw_hta | report worst timing path |
| `reset_dirty_bit_hier_module` | `reset_dirty_bit_hier_module` | UTILS/make_Robi_func |  |
| `reset_electron` | `reset_electron` | UTILS/make_reset_electron |  |
| `reset_status_all` | `reset_status_all` | KNOWLEDGEBASE/make_manage_testcase | resetting the status of all testcases |
| `reset_testcase_daily` | `reset_testcase_daily` | DBA/SQL/cronjob.pl | reset testcase daily |
| `reset_testcase_everyday` | `reset_testcase_everyday` | EFARM/make_services | reset testcase daily |
| `reshape_hier_inst` | `reshape_hier_inst` | TSTGEN/make_pseudo_floorplan | reshape hier inst |
| `resistor_graph` | `resistor_graph` | SPARK/make_rw_sdef | graph file for resistor |
| `restore_design` | `get_design` | UTILS/perl_dump | restore design |
| `restore_design_new` | `restore_design_new` | UTILS/perl_dump | restore design |
| `resume` | `resume` | UTILS/tool.nopath | print message |
| `return` | `return_toolshell` | executables | return command |
| `rotate` | `rotate_inst` | DESANALYSIS/make_droute_analysis | roatate def clockwise |
| `rotate_instance_ninety_degree_clockwise` | `rotate_instance_ninety_degree_clockwise` | PARSER/make_rw_def | rotate instance ninety degree clockwise |
| `route_flat_for_spice` | `route_flat_for_spice` | TSTGEN/make_router_graph_file | runs router on design and storing router data in database |
| `route_p2p` | `route_p2p` | ROUTER/make_z_router | point to point routing |
| `route_p2p_3pin_inpair` | `route_p2p_3pin_inpair` | ROUTER/make_z_router | point to point routing |
| `route_p2p_inpair` | `route_p2p_inpair` | ROUTER/make_z_router | point to point routing |
| `routed_wl_and_resistance` | `routed_wl_and_resistance` | DESANALYSIS/make_report_routing | find routed wire length of a nets and resistance |
| `routing_percentage` | `routing_percentage` | DESANALYSIS/make_route_analysis | routing percentage of preferdir and nonpreferdir |
| `rpt_inst_map` | `rpt_inst_map` | LIBANALYSIS/make_inst_map_file | generates a hashes temp and tempr |
| `rtl_area_estimation` | `rtl_area_estimation` | PARSER/make_r_rtl | calc rtl area |
| `run_complete` | `run_complete` | GUI/make_lefView_image | create complete file |
| `run_hspice_sim` | `run_hspice_sim` | TE/make_run_spice |  |
| `run_jroute` | `run_jroute` | ROUTER/make_jspeed_router |  |
| `run_place_design` | `run_place_design` | ALGO/PLACE/make_place | placer run |
| `run_placer` | `run_placer` | PLACER/DATAPREP/make_run_placement_file | plan_1 run |
| `run_placer_detail` | `run_placer_detail` | PLACER/DATAPREP/make_run_placement_file | plan_2 run |
| `run_placer_for_sp2dia` | `run_placer_for_sp2dia` | PLACER/DATAPREP/make_run_placement_file | run plan_1 for sp2dia |
| `run_plan_3` | `run_plan_3` | PLACER/DATAPREP/make_run_placement_file | plan_1 for spice database |
| `run_plan_6` | `run_plan_6` | PLACER/DATAPREP/make_run_placement_file | plan_3 run |
| `run_spice3_sim` | `run_spice3_sim` | TE/make_run_spice | run spice3 |
| `run_xls_cmd` | `run_xls_cmd` | PARSER/make_rw_xls | run xls command |
| `save_design` | `save_design` | UTILS/perl_dump | save design |
| `save_design_new` | `save_design_new` | UTILS/perl_dump | save design |
| `save_library` | `save_library` | (no sub defined in any required file) | save library |
| `sdef2svg` | `sdef2svg` | GUI/make_flatView_svg |  |
| `seedPlace` | `seedPlace` | PLACER/DATAPREP/make_rw_flat_graph | plan_6 run |
| `set` | `set` | TCL/make_tcl_commands | set variable |
| `setGoldenValue` | `setGoldenValue` | KNOWLEDGEBASE/make_gui_kb_tab |  |
| `setNot_CLIENT` | `setNot_CLIENT` | (no sub defined in any required file) |  |
| `set_array_index_delimiter` | `set_array_index_delimiter` | TE/make_rw_spice | set opening and closing bracket |
| `set_blocks_as_fixed` | `set_blocks_as_fixed` | UTILS/make_Robi_func | set all block is fixed |
| `set_buffer_for_assign` | `set_buffer_for_assign` | UTILS/make_Robi_func | set buffer |
| `set_chip_height_width_x_y_grid` | `set_chip_height_width_x_y_grid` | PARSER/make_floorplan | set chip height and width |
| `set_chipdimension_site_multiple` | `set_chipdimension_site_multiple` | PARSER/make_floorplan | X dimension in multiple of site statement and Y dimension in multiple of row height |
| `set_cur_loc_to_orig_loc` | `set_cur_loc_to_orig_loc` | UTILS/make_Robi_func | set cur location to original location |
| `set_delete_tmp_placer_files` | `set_delete_tmp_placer_files` | UTILS/make_del_tmp_placer_files | global function set 1 for delete tmp placer file |
| `set_dirty_bit_hier_module` | `set_dirty_bit_hier_module` | UTILS/make_Robi_func |  |
| `set_first_non_empty_top_module` | `set_first_non_empty_top_module` | UTILS/make_Robi_func | set first non empty top module |
| `set_floorplan` | `set_floorplan` | PARSER/make_floorplan | set floorplan |
| `set_floorplan_mode` | `set_floorplan_mode` | ALGO/FLPLAN/make_floorplan_setup | set floorplan mode |
| `set_floorplan_parameters` | `set_floorplan_parameters` | PARSER/make_floorplan | set floorplan parameters |
| `set_global_vars` | `set_global_vars` | make_global_commands | set global varaible |
| `set_inst_box` | `set_inst_box` | UTILS/make_inst_box | set inst box |
| `set_inst_box_new` | `set_inst_box_new` | (no sub defined in any required file) |  |
| `set_instance_location` | `set_instance_location` | UTILS/make_inst_box | set the instance location |
| `set_kb_field_order` | `set_kb_field_order` | KNOWLEDGEBASE/make_manage_testcase | set kb field order |
| `set_layer_width_and_spacing_in_db` | `set_layer_width_and_spacing_in_db` | GUI/PROTO/make_write_layout_of_spice | set layer spacing in db |
| `set_layout_loc_in_flplan` | `set_layout_loc_in_flplan` | GUI/PROTO/make_write_layout_of_spice | set transistor width and height |
| `set_machine_attribute` | `set_machine_attribute` | DBA/SQL/make_eFarm_package | It update machine information in database and can also add a new atrribute and value to a given machine |
| `set_map_seed_placement` | `set_map_seed_placement` | UTILS/make_Robi_func | set number of seed place |
| `set_minimum_hier_instance_for_placement` | `set_minimum_hier_instance_for_placement` | UTILS/make_hierarchical_placement | set min hier inst for placement |
| `set_minimum_leaf_instance_for_placement` | `set_minimum_leaf_instance_for_placement` | UTILS/make_hierarchical_placement | set min leaf inst for placement |
| `set_module_as_bbox` | `set_module_as_bbox` | PARSER/make_elaborate | set module as bbox |
| `set_module_flattening_parameter` | `set_module_flattening_parameter` | UTILS/make_hierarchical_placement | set module flattening for given parameter |
| `set_module_flattening_selective` | `set_module_flattening_selective` | UTILS/make_hierarchical_placement | set module flattening |
| `set_no_delete_tmp_placer_files` | `set_no_delete_tmp_placer_files` | UTILS/make_del_tmp_placer_files | global function set 0 for delete tmp placer file |
| `set_node_no` | `set_node_no` | UTILS/make_Robi_func | set node number |
| `set_number_nodes_connected_to_all_net` | `set_number_nodes_connected_to_all_net` | UTILS/gen_vertex_file | set node number to connected net |
| `set_option_desinfofile` | `set_option_desinfofile` | UTILS/make_Robi_func | set option desin info |
| `set_place_mode` | `set_place_mode` | ALGO/PLACE_NEW/make_placement_mode | set place mode |
| `set_pseudo_floorplan` | `setPseudoFloorplan` | TSTGEN/make_PseudoPhysicalModel | set pseudo floorplan |
| `set_spice_loc_in_flplan` | `set_spice_loc_in_flplan` | TE/make_rw_spice | set spice loc |
| `set_status` | `set_status` | KNOWLEDGEBASE/make_manage_testcase | set connection |
| `set_std_row_height` | `set_std_row_height` | PARSER/make_lef_analysis | set row height |
| `set_testcase_attribute` | `set_testcase_attribute` | DBA/SQL/make_testcase_package | It set attribute value or a new attrib |
| `set_testcase_status` | `set_testcase_status` | KNOWLEDGEBASE/make_manage_testcase | set testcase status |
| `set_tie_cells` | `set_tie_cells` | UTILS/make_Robi_func |  |
| `set_top_module` | `set_top_module` | UTILS/make_Robi_func | set top module |
| `set_write_assign_as_assign` | `set_write_assign_as_assign` | UTILS/make_Robi_func | set assign as assign |
| `set_write_assign_as_buffer` | `set_write_assign_as_buffer` | UTILS/make_Robi_func | set assign as buffer |
| `simulate` | `simulate` | TE/make_run_spice | simulate |
| `snapPlace` | `snapPlace` | ALGO/PREPLACE/tempSeedPlace | Creating the temporary row database on which the placement legalization works |
| `snapshot` | `snapshot` | KNOWLEDGEBASE/make_gui_kb_tab | plot the graph in proton gui for each testcase in Kb database and take its snapshots,snapshot has the following command line options |
| `snapshot_IndGui` | `snapshot_IndGui` | KNOWLEDGEBASE/make_gui_kb_tab | plot the graph in special gui for each testcase in Kb database and take snapshots of them,snapshot_IndGui has the following command line options |
| `source` | `source` | executables |  |
| `sp_routed_wl_and_resistance` | `sp_routed_wl_and_resistance` | DESANALYSIS/make_report_routing | find routed wire length of a spnets and resistance |
| `specify_module_rblkg` | `specify_module_rblkg` | TSTGEN/make_router_graph_file |  |
| `spiceHierPlacer` | `spiceHierPlacer` | (no sub defined in any required file) |  |
| `spnet_to_chip_pin` | `spnet_to_chip_pin` | (no sub defined in any required file) |  |
| `spnet_to_sprect` | `spnet_to_sprect` | (no sub defined in any required file) |  |
| `start_master_daemon` | `start_master_daemon` | EFARM/make_services | start master daemon |
| `start_scheduler` | `start_scheduler` | EFARM/make_services | start scheduler |
| `start_slave_daemon` | `start_slave_daemon` | EFARM/make_services | runs the deamon on host and report the status of load on it to the master machine |
| `straightPath` | `straightPath` | (no sub defined in any required file) |  |
| `switch_mode` | `switch_mode` | TE/make_application_modes | switch mode for spice |
| `syncPlace` | `syncPlace` | ALGO/PREPLACE/make_place_supportFunc | updating main database with new placement db |
| `synthesize` | `synthesize` | PARSER/make_synthesize |  |
| `test` | `test` | (no sub defined in any required file) |  |
| `testCmd` | `testCmd` | DESANALYSIS/make_design_analysis |  |
| `test_flex_xml` | `testFlexXML` | GUI_SERVER/make_server_rpc | for rpc command |
| `test_pseudo` | `testPseudo` | TSTGEN/make_PseudoHierModel | pseudo test |
| `trace` | `trace` | PARSER/make_rwt_clock_tree | trace given net |
| `traceIOsPGgroup` | `traceIOsPGgroup` | POWER/make_pg_connections | trace io pin |
| `tracePowerConnection` | `tracePowerConnection` | POWER/make_pg_connections | trace power connection |
| `trace_clock_domain` | `dbPlaceTraceClockDomain` | ALGO/PREPLACE/make_place_floparray | trace clock domain |
| `trace_flop_levels` | `dbPlaceCreateFloparray` | ALGO/PREPLACE/make_place_floparray |  |
| `ui` | `win` | GUI/make_rw_gui | gui open |
| `unPlaceNonRegCells` | `unPlaceNonRegCells` | ALGO/PREPLACE/tempSeedPlace | set instance status of unplace |
| `uniquify_module` | `uniquify_module` | UTILS/make_Robi_func | uniquify module |
| `unplace_instance` | `unplace_instance` | DESANALYSIS/make_report_routing | set status of inst is unplaced |
| `up_hier` | `upHier` | TSTGEN/make_PseudoHierModel | up level hier instance |
| `up_size` | `upSize` | PARSER/make_rw_def |  |
| `updatePseudoNet` | `updatePseudoNet` | TSTGEN/make_PseudoHierModel | connecting an instance with existing net |
| `update_hier_floorplan_loc` | `update_hier_floorplan_loc` | UTILS/make_Robi_func | update hier floorplan loc |
| `usrGetCellDelay` | `usrGetCellDelay` | TE/make_timingDB_access_commands | get delay information for given cell |
| `verify_block_halo` | `verifyBlockHalo` | DESANALYSIS/make_design_analysis | verify block halo |
| `verilog2lef` | `verilog2lef` | PARSER/make_r_rtl |  |
| `verilog2lib` | `verilog2lib` | PARSER/make_r_rtl |  |
| `verilog_to_spice` | `verilog_to_spice` | (no sub defined in any required file) |  |
| `win` | `win` | GUI/make_rw_gui | for open gui |
| `writeLVSLabel` | `writeLVSLabelSub` | UTILS/make_run_app_only | write lvs file |
| `write_astar_files` | `write_astar_files` | ROUTER/make_astar_router |  |
| `write_block_xlsToXml` | `write_block_xlsToXml` | GUI/make_specify_gui | write xml from xls |
| `write_block_xmlToXls` | `write_block_xmlToXls` | GUI/make_specify_gui | write xls from xml |
| `write_cell_pin_loc_frm_lef` | `write_cell_pin_loc_frm_lef` | SPARK/make_rw_sdef | write cell pin location for spark |
| `write_config_file` | `write_config_file` | UTILS/make_spider_script | write config file |
| `write_conn_info_of_net` | `write_conn_info_of_net` | DESANALYSIS/make_report_net_command | net conn info |
| `write_connection_in_tcl` | `write_connection_in_tcl` | UTILS/make_Robi_func | create tcl file for net connection |
| `write_controlFile` | `write_controlFile` | UTILS/make_Robi_func | create control file |
| `write_data_xls` | `write_data_xls` | GUI/PROTO/make_write_edp | write xls file |
| `write_def` | `write_def` | PARSER/make_rw_def | write def file |
| `write_def_cookie` | `write_def_cookie` | TSTGEN/GEOMETRYENG/make_cookie_def | Write the extracted def |
| `write_def_for_router` | `write_def_for_router` | PARSER/make_rw_def | write def file for router |
| `write_def_from_gds` | `write_def_from_gds` | PARSER/make_rw_gds | write def file from gds file |
| `write_design_info_file` | `write_design_info_file` | PLACER/DATAPREP/make_write_graph_files | create design info file |
| `write_edp_dia` | `write_edp_dia` | GUI/PROTO/make_write_edp | write dia file for edp |
| `write_edp_dia_for_spice` | `write_edp_dia_for_spice` | GUI/PROTO/make_write_edp | write dia for spice |
| `write_edp_layout` | `write_edp_layout` | GUI/PROTO/make_write_layout_of_spice | write dia file for edp layout |
| `write_edp_tcl` | `write_edp_tcl` | GUI/PROTO/make_write_edp | write tcl |
| `write_edp_xschematic` | `write_edp_xschematic` | GUI/PROTO/make_write_edp | write dia file |
| `write_ega` | `write_ega` | TSTGEN/make_w_PseudoHierModel | write verilog file |
| `write_excel` | `write_excel` | KNOWLEDGEBASE/make_write_excel | read the information from database and write down in xls file |
| `write_flat_csv` | `write_flat_csv` | GUI/PROTO/make_write_edp | create csv file for flat design |
| `write_flat_floorplan` | `write_flat_floorplan` | PARSER/make_rw_def |  |
| `write_flat_graph` | `write_flat_graph` | PLACER/DATAPREP/make_rw_flat_graph |  |
| `write_flat_json` | `write_flat_json` | GUI/PROTO/make_write_edp | create json file for flat design |
| `write_flat_router_graph` | `write_flat_router_graph` | TSTGEN/make_router_graph_file | write input file for router |
| `write_flat_router_graph_for_spice` | `write_flat_router_graph_for_spice` | TSTGEN/make_router_graph_file | write router graph file |
| `write_footprint` | `write_footprint` | PARSER/make_rw_lib | write footprint file |
| `write_footprint_for_netlistgen` | `write_footprint_for_netlistgen` | PARSER/make_rw_lib | write footprint file for netlist |
| `write_gds_pin_coords` | `write_gds_pin_coords` | PARSER/make_rw_gds | read gds file and write pin name and its coords in output file |
| `write_graph` | `write_graph` | (no sub defined in any required file) | input file genrated for placer |
| `write_graph_for_spice` | `write_graph_for_spice` | PLACER/DATAPREP/make_write_graph_files | write graph for spice |
| `write_graph_libfile_offset` | `write_graph_libfile_offset` | (no sub defined in any required file) |  |
| `write_graph_modified` | `write_graph_modified` | PLACER/DATAPREP/make_write_graph_files | input file genrated for placer |
| `write_graph_modified_expand_fixed_hard_macro` | `write_graph_modified_expand_fixed_hard_macro` | PLACER/DATAPREP/make_write_graph_files | input file genrated for placer and fixed hard macro break into std cell |
| `write_graph_modified_plan_4` | `write_graph_modified_plan_4` | PLACER/DATAPREP/make_write_graph_files | input file generate for plan_4 |
| `write_graph_pin_based` | `write_graph_pin_based` | (no sub defined in any required file) |  |
| `write_graph_pins_offset` | `write_graph_pins_offset` | (no sub defined in any required file) |  |
| `write_graph_plan_3` | `write_graph_plan_3` | PLACER/DATAPREP/make_write_graph_files | input file generate for plan_3 |
| `write_graph_smatrix` | `write_graph_smatrix` | PLACER/DATAPREP/smatrix_placement/make_write_smatrix_graph | input file generate for smatrix |
| `write_graywolf_cel_file` | `write_graywolf_cel_file` | PLACER/DATAPREP/make_rw_graywolf_files |  |
| `write_hana_lib_file` | `write_hana_lib_file` | PARSER/make_rw_lib | for hana lib file |
| `write_hier_dia` | `write_hier_dia` | GUI/PROTO/make_write_edp | write hier dia |
| `write_hier_floorplan` | `write_hier_floorplan` | TSTGEN/make_pseudo_floorplan | write fpdef file |
| `write_hier_json` | `write_hier_json` | GUI/PROTO/make_write_edp | write json file |
| `write_hier_place_graph` | `write_hier_place_graph` | TSTGEN/make_hier_place_graph | write input file for hier placer |
| `write_hier_router_graph` | `write_hier_router_graph` | TSTGEN/make_router_graph_file | write input file for hier router |
| `write_hier_router_graph_new` | `write_hier_router_graph_new` | TSTGEN/make_router_graph_file | write input file for hier router |
| `write_hpv` | `write_hpv` | TSTGEN/make_w_PseudoHierModel | write hpv file |
| `write_hspice_deck` | `write_hspice_deck` | TE/make_run_spice | write hspice |
| `write_html` | `write_html` | KNOWLEDGEBASE/make_write_excel | writes a html file for for each testcase data in database |
| `write_info_of_layer` | `write_info_of_layer` | SPARK/make_rw_sdef | write info for layer |
| `write_json` | `write_json` | GUI/PROTO/make_write_edp | write json file |
| `write_kb_postscript` | `write_kb_postscript` | (no sub defined in any required file) |  |
| `write_label_text` | `write_label_text` | SCRATCH/make_LVS | write file |
| `write_lef` | `write_lef` | PARSER/make_rw_lef | write .lef file |
| `write_lef_for_router` | `write_lef_for_router` | PARSER/make_rw_lef | write lef file for router |
| `write_lib` | `write_lib` | PARSER/make_rw_lib | write lib file |
| `write_lvs_label` | `write_lvs_label` | UTILS/make_Robi_func | write lvs file |
| `write_makefile` | `write_makefile` | KNOWLEDGEBASE/make_manage_testcase | write make file |
| `write_matlab` | `write_matlab` | ALGO/PREPLACE/make_place_supportFunc | write matlab.txt file |
| `write_metis` | `write_metis` | ALGO/PREPLACE/make_place_supportFunc | write metis.txt file for place db |
| `write_mid_x_and_mid_y_of_inst_pin` | `write_mid_x_and_mid_y_of_inst_pin` | SPARK/make_rw_sdef | calculate and write middle point of inst pin |
| `write_net_xlsToXml` | `write_net_xlsToXml` | GUI/make_specify_gui | write xls to xml for net |
| `write_net_xmlToXls` | `write_net_xmlToXls` | GUI/make_specify_gui | write xml to xls for net |
| `write_pg_net` | `write_pg_net` | UTILS/make_verilog_utils |  |
| `write_pseudo_graph` | `write_pseudo_graph` | TSTGEN/make_hier_place_graph |  |
| `write_router_graph` | `write_router_graph` | ROUTER/make_box_router | writes the graph file |
| `write_router_graph_new` | `write_router_graph_new` | ROUTER/make_box_router | writes the graph file |
| `write_rpt_timing` | `write_rpt_timing` | PARSER/make_rw_timing_report | write timing rpt file |
| `write_rtl` | `write_rtl` | PARSER/make_w_rtl | write rtl file |
| `write_rtl_data` | `write_rtl_data` | PARSER/make_w_rtl | write rtl data in read.txt |
| `write_sdc` | `write_sdc` | TE/make_rw_sdc | write sdc file |
| `write_sdef` | `write_sdef` | SPARK/make_rw_sdef | write sdef file |
| `write_sgraph` | `write_sgraph` | SPARK/make_rw_sgraph |  |
| `write_single_pin_conn` | `write_single_pin_conn` | DESANALYSIS/make_report_design |  |
| `write_slef` | `write_slef` | SPARK/make_rw_sdef | write lef for spark |
| `write_slib` | `write_slib` | SPARK/make_rw_sdef | write slib file |
| `write_spark_smatrix` | `write_spark_smatrix` | PLACER/DATAPREP/smatrix_placement/make_write_smatrix_graph | write smatrix file |
| `write_specify_data` | `write_data_file` | (no sub defined in any required file) |  |
| `write_spice` | `write_spice` | TE/make_rw_spice | write spice file |
| `write_spice3_deck` | `write_spice3_deck` | TE/make_run_spice | write spice3 |
| `write_spice_file` | `write_spice_file` | TE/make_rw_spice | write spice file |
| `write_spice_flat` | `write_spice_flat` | (no sub defined in any required file) |  |
| `write_spice_layout` | `write_spice_layout` | GUI/PROTO/make_write_layout_of_spice | write dia for spice layout |
| `write_spice_multi_top_module` | `write_spice_multi_top_module` | TE/make_rw_spice | write multi spice file |
| `write_tcl` | `write_tcl` | GUI/make_gui_support_func | write tcl file |
| `write_tech_lef` | `write_tech_lef` | PARSER/make_rw_lef | write technology lef file |
| `write_udn` | `write_udn` | PARSER/make_rw_udn | write udn file |
| `write_verilog` | `write_verilog` | PARSER/make_rw_verilog | write verilog file |
| `write_verilog_cookie` | `write_verilog_cookie` | TSTGEN/GEOMETRYENG/make_cookie_verilog | write verilog cookie |
| `write_xls_for_spice_model` | `write_xls_for_spice_model` | TE/make_rw_spice | write  xls for spice model |
| `write_xls_for_timing_rpt` | `write_xls_for_timing_rpt` | PARSER/make_rw_timing_report | write timing rpt file in xls format |
| `write_xml` | `write_xml` | PARSER/make_rw_xml | write xml file |
| `write_xml_def` | `write_xml_def` | PARSER/make_rw_xml | write info of comp and net in xml format |
| `write_xml_lef` | `write_xml_lef` | PARSER/make_rw_xml | write lef file in xml format |
| `write_xy_out` | `write_xy_out` | PLACER/DATAPREP/make_write_graph_files | write xy out file |
| `write_xy_out_mpl` | `write_xy_out_mpl` | PLACER/DATAPREP/make_write_graph_files | write xy out file for mpl |
