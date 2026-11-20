# Electron architecture

Electron is a hierarchical ASIC place-and-route suite written in Perl, forked from
efabless/proton and distributed under AGPL-3.0. This document describes how the code is
organised, how it boots, how commands are dispatched, what the in-memory design database
looks like, how the two implementation flows move data through it, and where it hands
off to external engines. It is written for engineers who will change the code.
The companion [USER_MANUAL.md](USER_MANUAL.md) is for people who run it.

Everything below was read from the tree as of late September 2026 (commit `952943c`). File references are
relative to the repository root; `file:line` numbers were current when written and will
drift.

---

## 1. The shape of the system

Electron is one Perl process. There are no modules in the Perl sense: roughly 320 source
files under `PARSER/`, `DB/`, `GUI/`, `ALGO/`, `PLACER/`, `TSTGEN/`, `UTILS/` and the
rest are *fragments* that a wrapper script `require`s, one after another, into the `main`
namespace. There is no `use strict`. Nearly every piece of design state is a package
global hash, and nearly every command is a plain sub that reads and writes those hashes.

```
                 UTILS/tool.nopath  (or hier_tool.nopath, proto_tool.nopath)
                 ┌──────────────────────────────────────────────────────────┐
  make ───────►  │ BEGIN { open electron.logN / electron.cmdN, tee STDOUT } │
  (prepends      │ use Tk, Verilog::Netlist, Storable, GDS2, JSON, ...      │
   $BEEHOME,     │ require commandsFile, executables                        │
   use lib LIBS, │ require UTILS/*  PARSER/*  RTL/*  GUI/*  GUI_SERVER/*     │
   release-ID)   │         TE/*  ALGO/*  DB/*  DBA/*  TSTGEN/*  POWER/*      │
                 │         ROUTER/*  DESANALYSIS/*  ...  (325 requires)      │
                 │ $GLOBAL = Global::new(); defaults; initiallize_commands   │
                 │ parse @ARGV;  source(-f file);  win  |  prompt loop       │
                 └──────────────────────────────────────────────────────────┘
                                          │
              ┌───────────────────────────┼────────────────────────────┐
              ▼                           ▼                            ▼
   %cmds / %checkArguments        global design database        external engines
   (commandsFile, 709 entries)   %CADB %PLDB %MODULE_ALREADY    3RDBIN/*.py placers,
   sub per command, options      %PORTS_ALREADY %FLOORPLAN_*    yosys, qrouter,
   parsed by hand in each sub    %PSEUDO_* %NETS_ALREADY ...    spark-shell (A* router)
```

Size, for orientation (lines of Perl in the fragments the wrappers load, subs defined):

| Area | Lines | Subs | What it is |
|---|---|---|---|
| GUI/ + GUI_SERVER/ | 61.8k | 880 | Perl/Tk GUI, dead XML-RPC server |
| TE/ | 41.5k | 486 | timing, SDC, spice decks, characterisation |
| PARSER/ | 33.5k | 332 | LEF, DEF, Verilog, Liberty, GDS, EDIF, config readers and writers |
| UTILS/ | 26.4k | 404 | shell, help, hier2flat, def2gds, container exec, graph writers |
| TSTGEN/ | 18.6k | 225 | hierarchical (pseudo) model, hier_place, pin placement |
| DB/ + DBA/ | 13.9k | 1488 | the object classes behind the global hashes |
| DESANALYSIS/ | 13.2k | 237 | reports and analysis |
| ALGO/ | 9.6k | 199 | Perl placement algorithms, legaliser, floorplan engine |
| PLACER/ | 8.1k | 81 | nodefile/graph writers and readers, placer drivers |
| ROUTER/ | 5.7k | 34 | qroute, flat_route (A*), route_p2p |
| 3RDBIN/ | 4.5k (Python) | | the placer, legaliser and raster drivers shipped with the tool |

In total the wrappers load about 3,600 distinct subs and register 709 commands.

---

## 2. Build and packaging

`make` at the top level runs three generator scripts and produces three executables:

| Generator | Input | Output |
|---|---|---|
| `UTILS/make_tool` | `UTILS/tool.nopath` | `electron` (and `electron_auth`, `electron.lnx.bin` symlink) |
| `UTILS/make_tool_hier` | `UTILS/hier_tool.nopath` | `electron_hier` |
| `UTILS/make_tool_proto` | `UTILS/proto_tool.nopath` | `electron_proto` |

Each generator writes a shebang, `$BEEHOME = "<absolute repo dir>"`, `use lib
"<repo>/LIBS"`, and then copies the `.nopath` file verbatim, replacing the token
`SVN_VERSION` with `git log --oneline | wc -l`. That count is the release-ID printed in
the banner, so the built scripts differ on every commit; they are gitignored and must be
rebuilt after cloning. `$BEEHOME` is what every `require "$BEEHOME/DIR/file"` line
resolves against, which is why a checkout can live anywhere.

`LIBS/Local/TeeOutput.pm` is the only vendored Perl module; it duplicates STDOUT into the
session log. `lib64/`, `share/` and `iverilog/` are leftovers of an old bundled install
and are not on the load path.

### 2.1 The three tools are one tool

A `diff` of the three `.nopath` files shows they are identical except for:

- the GUI entry file: `GUI/make_rw_gui` (electron), `GUI/make_rw_gui_hier`
  (electron_hier), `GUI/make_rw_gui_proto` (electron_proto). These are near-clones; the
  hier and proto variants enable a few extra Place menu entries (the Fractal
  Placer) and proto has a live CTS menu.
- `electron_proto` does not require `PARSER/make_rw_config` or `PARSER/make_synthesize`,
  so `read_config_file`, `read_library_config`, `get_std_cell_libs` and `synthesize` are
  registered but undefined there.
- the usage banner text.

Everything else, including `commandsFile`, is shared. The "hier" and "proto" distinctions
that matter are in the data model (section 5), not in which binary was launched. The
TESTS Makefile uses `electron_hier` for the hierarchical flow by convention.

---

## 3. Runtime environment: the container

Nothing meaningful runs on a bare host. The host lacks Tk, so the GUI fragments and all
three wrappers fail to compile; it lacks scipy, yosys, qrouter and spark-shell, so the
placers, synthesis and routers cannot run. All execution, including `make check`, happens
inside `INSTALL/podman/pysparkpp.sif`, an Apptainer image built in three layers:

| Layer (Containerfile) | Image | Adds |
|---|---|---|
| `INSTALL/UbuntuContainerFile` | `pysparkcad` | Ubuntu 22.04, perl-tk, the CPAN set (Tk::WorldCanvas, Verilog::Netlist, Storable, GDS2, Spreadsheet::*, JSON, Proc::Simple, ...), iverilog, yosys, gtkwave, cudd, OpenSTA (built, not installed) |
| `INSTALL/pysparkplusContainerFile` | `pysparkplusbuild` | python3, PyQt5, pyqtgraph, pyspark, numpy, scipy, networkx, pandas, OpenJDK 17 |
| `INSTALL/pysparkppContainerFile` | `pysparkpp` | qrouter 1.4.90 (Tim Edwards' detail maze router), installed to /usr/local |

`INSTALL/podman/Makefile` builds them with podman, saves an OCI archive, and converts it
with `apptainer build`. Images are gitignored.

Inside Perl, `UTILS/make_container_exec` provides the one shared way to reach an external
program: `dbfElectronToolCommand($tool, $innerCmd, $logFile)` runs `$innerCmd` directly
if `$tool` is on PATH, otherwise wraps it in `apptainer exec --bind ... <sif> bash -c
'cd <cwd> && ...'`, choosing the image from `$ELECTRON_CONTAINER` or, failing that, the
newest of `pysparkpp.sif`, `pysparkplusbuild.sif`, `pysparkcad.sif` under
`INSTALL/podman`. `synthesize` (yosys), `qroute` (qrouter) and `flat_route` (spark-shell)
go through it. The Python placer drivers in `3RDBIN/` do not: they are invoked with a
plain `system()` and assume python3 with scipy is already on PATH, which is why the flows
must run inside the container with `PATH=/usr/bin:$PATH` (a host `~/.bashrc` bound into
the container can put a scipy-less miniconda first).

---

## 4. Process lifecycle and the command layer

### 4.1 Startup sequence (`UTILS/tool.nopath`)

1. **`sub BEGIN`** (bottom of the file, runs first). Scans `@ARGV` for `--nolog`,
   `--cleanlog`, `--overwritelog`, `-log`; picks the first unused `electron.logN` /
   `electron.cmdN` pair in the working directory (or the given `-log` file), opens them,
   and tees STDOUT into the log with `Local::TeeOutput`. Prints the banner with the
   release-ID and zeroes a batch of global hashes.
2. **`use` block.** Tk and its widgets, Verilog-Perl, Storable, GDS2, JSON, DBI,
   Spreadsheet::*, Proc::Simple, etc. Any missing CPAN module kills the tool here.
3. **325 `require` lines.** `commandsFile` and `executables` first, then UTILS, PARSER,
   RTL, GUI, GUI/PROTO, GUI_SERVER, TE, ALGO, DB, DBA, TSTGEN, POWER, FLOW, TCL,
   EXTCOMMANDS, KNOWLEDGEBASE, LIBANALYSIS, DESANALYSIS, ROUTER, LIBQA, EFARM, SCRATCH,
   PLACER, FLEX_COMMANDS, SPARK, PADFRAME. Order matters: when two fragments define the
   same sub name the later definition wins silently (see 9.2).
4. **Defaults.** `$GLOBAL = Global::new()`, `$DEF_DATABASE_UNIT = 4000`,
   `$GLOBAL->dbfGlobalSetDBU("4000")`, `$PROMPT = "electron_shell"`, `$WINSTART = 1`
   (GUI on by default), then `&initiallize_commands` fills `%cmds` and
   `%checkArguments`, and `$p2cmd`/`$p2cmdArgs` point at them.
5. **Argument parse.** `-f`/`-init <file>`, `--version`, `--help`/`-h`, `-lic`, `-log`,
   `-cmdlog`, `--win`/`--gui`, `--nogui`, `--EOC`, `--DEBUG`, `-key`, `-port`. The
   built-in usage text omits `--nogui` even though the parser accepts it.
6. **Run.** If `-f` was given, `&source($file)` executes it. Then: `-port` starts the
   daemon (broken, see 9.1); else if `$WINSTART`, `&win` opens the GUI and the tool
   exits when the GUI closes; else if `--EOC`, exit; else fall into the prompt loop.
7. **`sub END`** undefs the big hashes, prints the goodbye banner and closes the tee.

### 4.2 The prompt loop and dispatch

The interactive loop is `while(<STDIN>)` in the wrapper. For each line:

1. Strip leading whitespace, `split /\s+/` into `$cmd` and `@arguments`.
2. Record the current command in `$GLOBAL` (used by messages and help).
3. **Brace conditioning.** Whitespace inside `{ ... }` is collapsed to commas, so
   `-inst { a b  c }` arrives as the single token `{a,b,c}`. This is the entire extent of
   Tcl-list support; there is no Tcl interpreter anywhere in the tree despite the `.tcl`
   file convention and the `TCL/` directory.
4. **Dispatch.** If `$cmd` is a key of `%checkArguments` and the argument count is at
   least the registered minimum, echo `#<CMD> line`, append the line to the `.cmd` file,
   and call `&{$cmds{$cmd}}(@arguments)`. If too few arguments were given, call the sub
   with the single argument `"HELP"` instead, which every well-behaved sub treats like
   `-h`.
5. **Unknown command** goes to `dbfHandleUnknownCommand` in `UTILS/make_unix_shell`:
   `sys <cmd>` always runs the unix shell; `peval <code>` always evals Perl; a bare word
   that is an executable on PATH runs in the shell (so `ls -l` works); anything else is
   evaled as Perl, which is how the prompt has always doubled as a debugger for the
   global hashes.

`sub source` in `./executables` re-implements steps 1 to 4 for a file, one command per
line, `#` comments and blank lines skipped. It differs from the prompt in that unknown
commands print `no such command` and are *not* passed to the shell or to Perl, and a
missing file is silently ignored (the `open` is unchecked). `sub remoteCommands` in the
wrapper is a third copy of the dispatch used by the RPC path, with a bare `system()`
fallback. Three writers of one behaviour; change one, check the others.

### 4.3 commandsFile: the registry

`commandsFile` is a single sub, `initiallize_commands`, holding two literal hashes:

```perl
%cmds = (
   "read_def"      => "read_defII",     # command name => sub name
   "commit_module" => "commitModule",
   ...
);
%checkArguments = (
   "read_def"      => "1",              # minimum number of arguments
   "gui"           => "0",
   ...
);
```

The minimum-count check is the only validation the dispatcher does. Option names, types
and combinations are parsed by hand inside each sub, almost always as a `for` loop over
`@_` comparing `$_[$i]` against literal strings, with the usage block printed when
`$_[0] eq '-h'` or the count is wrong. `DOCS/TEMPLATE/perlScript` shows the intended
skeleton (a `Getopt::Long::GetOptionsFromString` variant), but most commands predate it.

Of the 709 registered commands, 57 name a sub that no required fragment defines; calling
one dies with "Undefined subroutine". The user manual's appendix lists them.

### 4.4 Help

`help` (`UTILS/make_help`) with no argument lists every key of `%cmds`. `help <cmd>`
calls the command's sub with `-h`, so `help write_def` and `write_def -h` are the same
code path and there is no separate help-text store. `help pat*`, `help *pat` and
`help *pat*` filter the command list. The RoboDoc-style `#****f*` comment blocks above
many subs are source documentation only; nothing prints them at runtime.

### 4.5 Messages

Every message is a hand-written `print` following one convention:

```
<SEVERITY>-<PREFIX> : <NNN> : text
INFO-PAR-DEF : 001 : Begin reading the def file
ERROR-RTR-QROUTE : 013 : no qrouter on PATH and no container image to run it in
```

Severities in use are `INFO`, `WARN`, `ERR`/`ERROR` and `DBG` (gated on `$DEBUG`). The
prefix names the subsystem and command (`PAR-DEF`, `PL_FLAT_GRPH`, `TST-RD_PS_ND`), and
the number is a per-prefix serial. There is no central registry; uniqueness is checked
with `grep -o "PREFIX : [0-9]*" file | sort | uniq -d`. `UTILS/make_err_msg` is a
one-entry stub and is not the message mechanism.

### 4.6 Logging

Each session writes `electron.logN` (everything printed) and `electron.cmdN` (every
command executed, replayable with `-f`) in the working directory, N incrementing per
session. `--nolog` suppresses both, `--overwritelog` reuses the last pair, `--cleanlog`
deletes old logs first, `-log <file>` names the log explicitly (and then no `.cmd` file
is opened).

---

## 5. The design database

All state is global. The important hashes, the class of their values, and their units:

| Global | Key → value | Class (file) | Accessors | Units | Main writers |
|---|---|---|---|---|---|
| `%MODULE_ALREADY` | module name → logical netlist | `VNOM` (`DB/make_VNOM_package`) with `InsDB OutsDB BidiDB WireDB RegDB HinstDB LinstDB` sub-tables | `dbVNOM*` | n/a | `read_verilog`, `read_hdl`, `read_edif`, `read_def` |
| `%CADB` | instance name → placed instance | `CompAttDB` (`DB/make_CompDB_package`) | `dbCadb*` | **DBU**, rounded in the setter | elaboration (`PARSER/make_elaborate`), `read_def`, buffer/tie/filler insertion |
| `%COMP_ALREADY`, `%NETS_ALREADY` | instance / net name → membership; `%NETS_ALREADY{$net}{$inst}` is keyed directly | `NetDB` is an empty blessed hash, no accessors | | | `read_def`, elaboration |
| `%PLDB` | cell name → LEF macro | `MacroDB` (`DB/make_MacroDB_package`), pins in `MacroPinDB` | `dbMdb*` (read-only `dbgMdb*` aliases) | **microns** | `read_lef`; pseudo entries from `TSTGEN/make_PseudoPhysicalModel` |
| `%PTDB` | layer name → tech layer | `TechDB` (`DB/make_TechDB_package`) | `dbTech*` | microns | `read_lef` (LAYER section, incl. OFFSET and per-axis PITCH) |
| `%PORTS_ALREADY` | `{$module}{$port}` → flat port | `PortDB` (`DB/make_PortDB_package`); defaults location (0,0), side `"W"` | `dbPort*` | DBU | elaboration creates; `read_def` PINS and `hier2flat` fill locations |
| `%FLOORPLAN_ALREADY` | numeric floorplan ID → flat floorplan (die, rows, pins, pin guides) | `Floorplan` (`DB/make_FloorplanDB_package`); `%FLOORPLAN_LOOKUP{"$module/_self_"}` maps name → ID; IDs from `$GLOBAL->dbfGlobalGetNextFlplanID` | `dbFlplan*` | **DBU** | `set_floorplan`, `read_def`, `commit_module` |
| `%PSEUDO_MODULE_ALREADY` | module name → hierarchical (pseudo) model | `PseudoModuleModelDB` (`DB/make_QAHierPseudoModuleModelDB_package`) | `dbaTstgen*` | microns | `edit_module`, `hier_place`, `read_pseudo_nodefile` |
| `%PSEUDO_FLOORPLAN_ALREADY` | `"$module/_self_"` → pseudo floorplan | `Floorplan` | via `dbaTstgenGetPinRect`/`AddPinRect`, which convert | DBU on disk, **microns** to callers | `edit_module`, `read_def --pseudo` paths |
| `%DIE_ALREADY`, `%ROWS_ALREADY`, `%DEF_TRACKS_ALREADY`, `%NETS_ROUTING_ALREADY` | die box, rows, tracks, routed segments | `NetRoutingDB` for routing | | DBU | `read_def`, `set_floorplan`, `create_rows`, routers |
| `%TLDB` and `Timing*DB` | liberty cells and timing arcs | `TimingLibDB` etc. (`DB/make_Timing*_package`) | | | `read_lib` |
| `$GLOBAL` | the singleton | `Global` (`DB/make_GlobalVariableDB_package`) | `dbfGlobalGet*/Set*` | | everywhere |

Conventions worth knowing:

- **Accessor prefixes** tell you the class: `dbCadb` instance, `dbMdb` macro, `dbPort`
  port, `dbFlplan` floorplan, `dbVNOM` logical module, `dbaTstgen` pseudo module,
  `dbfGlobal` the singleton. A `dbf*`/`dbg*` free function is a helper, not a method.
- **The top module** is `$TOP_MODULE`, mirrored into `$GLOBAL->dbfGlobalGetTOP`. Every
  reader sets both side by side by convention; `set_top_module` is the command that does
  it deliberately. There is no `$CURRENT_DESIGN`.
- **DBU.** `$GLOBAL->dbfGlobalGetDBU` is authoritative. `read_def` sets it from the DEF
  `UNITS` line. `$DEF_DATABASE_UNIT` is a separate global that `set_inst_box` overwrites
  mid-session, and `$DBSCALEFACTOR` is captured once when a GUI view is built; both have
  diverged from the truth in the past (the flat-view flyline offset bug). Never hardcode
  4000 or 2000.
- **Three pin stores.** Flat ports (`%PORTS_ALREADY`) are what `write_def` and the flat
  view read. Flat floorplan pins (`%FLOORPLAN_ALREADY`) are what the guide-driven
  `hier_place_pins` edits. Pseudo pins (`%PSEUDO_MODULE_ALREADY` → pseudo floorplan) are
  what `hier_place` writes. Nothing bridges them automatically; section 6.2 gives the
  chain.
- **Conn lines.** A `VNOM` stores each instance as a Verilog-statement string
  (`CELL inst ( .a(n1), .b(n2) ) ;`). Readers strip the port list with `s/\)\s*\;//`,
  so a line without the trailing `;` leaves a stray `)` on the last pin's net. Net
  names must be compared at bit granularity via `array_of_blasted_expr`, which expands
  buses, concatenations and sized constants.

### 5.1 Persistence

`save_design -name D` (`UTILS/perl_dump`) creates directory `D/` and `Storable::store`s
each major hash to its own file (`PLDB`, `PTDB`, `TLDB`, `CADB`, `PORTS_ALREADY`,
`COMP_ALREADY`, `NETS_ALREADY`, `FA` (floorplans), `DA` (die), `RA` (rows), `NRA`
(routing), `DTA` (tracks), `TP` (technology), `global`, and the Verilog `V*DB` tables).
`restore_design -name D` retrieves them. The pseudo model is not included.

---

## 6. The two implementation flows

### 6.1 Flat flow

```
 LEF / config ─► read_config_file ──► %PLDB %PTDB     (+ assign buffer, tie cells chosen)
 gate netlist ─► read_verilog ──────► %MODULE_ALREADY (VNOM per module)
                 set TOP_MODULE; elaborate ─────────► %CADB %COMP_ALREADY %NETS_ALREADY %PORTS_ALREADY
                 set_floorplan_parameters; set_floorplan ─► %FLOORPLAN_ALREADY %DIE_ALREADY %ROWS_ALREADY
                                     │
        write_flat_graph ◄───────────┤   nodefile + <TOP>.txt edge list  (microns)
              │                      │
        3RDBIN/<placer>  ───► xy.out │   flat_graph_placer | eplacer | mincut_placer | seed_placer
              │                      │
        read_flat_graph_placement ──►│   %CADB locations (DBU), status PLACED
                                     │
                 legalize_flat ──────►│   Abacus onto rows and the site grid (Perl, ALGO/PLACE_NEW)
                                     │
                 improve_congestion ─►│   legal-to-legal detailed placement, HPWL only falls
                                     │
                 write_def ──► placed DEF ──► qrouter (qroute) ──► <def>_route.def ──► read_def --all
                                     │
                 write_def / write_verilog / def2gds / export_all
```

`place_flat_design`, `eplacer`, `mincut_placer`, `seedPlace` and `arrange_macros`
(`PLACER/DATAPREP/make_rw_flat_graph`) share one pattern: call `write_flat_graph`,
`system()` the driver in `3RDBIN/` (path overridable with `-placer`), read the result
back with `read_flat_graph_placement` or `read_flat_nodefile`, delete the intermediate
files unless `--keep`. `--write_only` stops after writing, so a placer can be run by hand.

**Nodefile format** (written by `write_flat_graph` and `write_pseudo_graph`, read by
every driver):

```
DBU 4000
DIEAREA 0 0 503.845 503.845
ROWHEIGHT 1.4
NODES 4297
<node#> <name> INST|PORT <width> <height> FIXED|PLACED|UNPLACED [<x> <y>] TYPE=<combi|seq|mem|block|und>
```

Coordinates are microns and `<x> <y>` is the lower-left corner, as in DEF. The edge file
(`<TOP_MODULE>.txt`) has one `<driver node> <sink node>` pair per line; nets above
`-fanout_limit` are skipped. Drivers return `<node> <x> <y>` in the same space, so no
scale factors cross the boundary.

**Legalisation.** `legalize_flat` (`ALGO/PLACE_NEW/make_legalize_flat`) is Abacus with
three refinements:

- **Local density cap on the row choice.** Each row is divided into bins, and a cell
  takes the nearest row whose bin at its x still has free width, instead of the nearest
  row with room anywhere along it. On an empty die a whole row is almost never full, so
  without the cap the nearest row always won and Abacus had to push cells hundreds of
  microns sideways. On mxu_256 the cap cut average horizontal movement from 42.9 to
  10.5 µm and the worst cell from 879 to 183 µm, for one extra second. `-dbin`,
  `-dbin_rows` and `--no_dbin` tune or disable it.
- **Multi-row cells** are placed first and cut out of every row they span, the way macros
  are, so nothing slides through them.
- **Pin density relief** (`--pin_spread`, off by default). It counts signal pins per 5 µm
  tile on a first legal placement and pads the cells in the densest tiles, then legalises
  again so Abacus opens real gaps there. It never retargets a cell. On matmul_4x4 it
  removed two thirds of the tiles over 80 pins for 4.9% more wirelength. If padding leaves
  any cell without a row, the unpadded result is kept.

It produces zero overlaps, which must be checked in integer DBU; a float check in microns
invents one at every row boundary. It is deterministic run to run. The older area-density
pass (`--spread`) is off by default because it multiplied unrouted nets on the flat test.

`3RDBIN/legalize_flat` is a NumPy legaliser reachable with `-placer`, and it is **not**
equivalent. It predates the local density cap and has no pin spreading. Its multi-row
handling reserves width but not position, so it overlaps tall cells: 20 overlaps on a
synthetic test where the Perl one has none. Nothing committed calls it, and it is slower
end to end anyway, because the design goes through a text file.

**Detailed placement.** `improve_congestion` (`ALGO/PLACE_NEW/make_improve_congestion`)
runs on a legal placement and refuses anything else. It alternates two moves for
`-iters` rounds. The global swap moves a cell towards its optimal region (the medians of
its nets' bounding boxes without it), by swapping with a cell or taking a gap within
`-rows` rows. The row slide keeps each segment's order and re-clusters it with an L1 cost.
Every move goes from legal to legal and is kept only if it shortens the nets it touches,
so overlaps stay at zero and wirelength only falls. Measured on the written DEFs, it cut
HPWL by 24% on nangate_flat, 51% on matmul_4x4 (78 s) and 48% on mxu_256 (5m39). Despite
the name it optimises wirelength, not congestion directly; the unrouted count on
nangate_flat fell from about 130 to about 35.

### 6.2 Hierarchical (pseudo) flow

```
 read_config_file; read_verilog; set TOP_MODULE; elaborate        (as above)
        │
 edit_module --top -util 50 ──► %PSEUDO_MODULE_ALREADY{top}, pseudo floorplan sized from cell area
        │
 write_pseudo_graph --anchors ─► pseudo nodefile + edge file
        │                          (blocks + ports as nodes; combinational cones collapsed to hyperedges)
 3RDBIN/hier_place  (PyQt5; interactive Save, or -batch N headless)
        │
 read_pseudo_nodefile ─────────► block locations and sizes, port locations, in the pseudo model
        │
 hier_place_pins -layers lo:hi ► assign pin layers, space pins on shared layers   (optional)
        │
 commit_module --physical_only ► commitModule ─► dbfTstgenUpdateFlplanFromPseudo
                                               ─► dbfTstgenUpdateFlplanByID  (microns × DBU → %FLOORPLAN_ALREADY)
        │
 hier2flat --physical ─────────► walks the whole hierarchy, rebuilds %CADB block locations
                                 and %PORTS_ALREADY port rects from %FLOORPLAN_ALREADY
        │
 write_def  (blocks and PINS placed; leaf COMPONENTS unplaced until each block is filled)
```

`commit_module` without `--physical_only` also rebuilds the module's VNOM conn lines from
the pseudo net tables (`dbfTstgenUpdateVNOMFromPseudo`), which is a deliberate logical
edit, not a placement step.

### 6.3 Placing the whole hierarchy: `hier_place_all`

The diagram above places one module. `hier_place_all` (`TSTGEN/make_hier_place_all`)
repeats it for every module of the tree and then flattens once:

```
 set_floorplan                       top die and rows (legalize_flat needs the rows)
 edit_module --top
 hier_place_all -batch N -cells_batch N
   for each DISTINCT module, parents before children:
      edit_module -module M          size M from its instance box in the parent's floorplan
      hier_place -module M -batch N  blocks, flops and ports of M
      hier_place_cells -module M     combinational cells of M, around the fixed blocks and flops
      commit_module -module M --physical_only
   hier2flat                         compose every level's transform into %CADB
 legalize_flat                       nothing in the hierarchical path snaps cells to rows
 improve_congestion                  optional: roughly halves HPWL on the large tests
```

Three properties drive the design:

- **Top down, committed at each level.** A module has no size until its parent's committed
  floorplan gives its instance a box (`dbfTstgenCalcModuleSizeFromParentFlplan`). Open a
  child first and it has zero area and everything lands on one point. `edit_module` also
  deletes the pseudo model of the module and all its children before reloading, so a walk
  must never reopen an ancestor.
- **Distinct modules, not instances.** A module's placement lives once, in its own
  floorplan, so all instances of a module share one arrangement. The 1,024 copies of
  `vedic_16x16` in `mxu_1024` are placed once. The walk's cost follows the number of
  distinct modules, which grows by one per 4x step of the MXU tests.
- **Hand-off from interactive.** `--skip_placed` keeps any module that already has a
  placement (for example the top, placed by hand in the `hier_place` window and committed)
  and only fills in its cells, so a designer can floorplan the top levels and let the tool
  do the rest.

Two traps recorded in `CLAUDE.md` apply to any code that walks the tree. `edit_module`
moves `$TOP_MODULE` to the module it opened and leaves `$GLOBAL->dbfGlobalGetTOP` alone;
`write_def` follows `$TOP_MODULE` and `hier2flat` follows the global, so forgetting to
restore `$TOP_MODULE` produces a DEF of the last module visited. And `hier2flat`'s second
loop, which transfers routing, is skipped when no floorplan holds a net, which is always
the case after `--physical_only` commits; that skip took mxu_256 from 16 to 5 minutes.

---

## 7. External engines

| Engine | Where it lives | Driven by | Invocation | Exchange files |
|---|---|---|---|---|
| flat graph (embedding) placer | `3RDBIN/flat_graph_placer` → `GRAPH_EMBED_PLACE` | `place_flat_design` | `system()` | nodefile, edge list → xy.out |
| ePlace electrostatic placer | `3RDBIN/eplacer` → `EPLACE` | `eplacer` | `system()` | same |
| min-cut bisection placer | `3RDBIN/mincut_placer` → `MINCUT` | `mincut_placer` | `system()` | same |
| anchor-hypergraph seed placer | `3RDBIN/seed_placer` (anchor_hypergraph.py, mincut.py, AnkorPlace.py from pyspark_cad) | `seedPlace` | `system()` | same, plus `<prefix>.hgr` |
| macro arranger | `3RDBIN/macro_arranger` → `MACRO_ARRANGER` | `arrange_macros` | `system()` | nodefile → nodefile |
| interactive block placer | `3RDBIN/hier_place` (PyQt5, in-tree, 2.9k lines) | `hier_place`, `hier_place_cells`, `hier_place_all` | `system()` | pseudo nodefile + edge file → placed nodefile; `-batch N` runs headless |
| NumPy legaliser (not equivalent to the Perl one, unused) | `3RDBIN/legalize_flat` | `legalize_flat -placer` | `system()` | `<top>.legal.in` → `<top>.legal.out` |
| DEF rasteriser | `3RDBIN/def_raster` | `raster_view`, the Raster tab | `system()` | DEF → PNG |
| yosys | container | `synthesize` (`PARSER/make_synthesize`) | `dbfElectronToolCommand` | filelist → `.ys` script → `.vg` netlist, log parsed for `stat` |
| qrouter 1.4.90 | container | `qroute` (`ROUTER/make_maze_router`) | `dbfElectronToolCommand` | LEF + placed DEF + generated `route.tcl` → `<def>_route.def`, `failed.nets`, `route.log` |
| A* global/detail router (Scala on Spark) | external repo `pyspark_cad/scala`, `$ELECTRON_ASTAR_DIR` | `flat_route` (`ROUTER/make_astar_router`) | `dbfElectronToolCommand("spark-shell", ...)` | `.tech`/`.design` text → `.routed`, `.json` |
| graywolf | PATH | `place_graywolf`, `place_hier_graywolf` | bare `system()` | `.cel`/`.par` |
| iverilog, gtkwave | container | GUI menu only | `system()` | `.vvp`, `.vcd` |
| ngspice / hspice / spice3 | not in container | `run_hspice_sim`, `simulate`, characterisation in `TE/` | `system()` | spice decks |
| plan_4, jroute binaries | **absent** | `place_graph_plan_4_pseudo`, `run_jroute` | `system()` | fail; `run_jroute` now forwards to `flat_route` |

Every in-tree driver's docstring states the coordinate convention it upholds (lower-left,
microns) and which environment variable points it at its engine. `SPARK/` is unrelated to
Apache Spark; it writes `.sdef` and `.sgraph` text dumps.

### 7.1 Formats

| Format | Reader | Writer | Notes |
|---|---|---|---|
| LEF 5.8 | `read_lef` (`PARSER/make_rw_lef`) | `write_lef`, `write_lef_for_router`, `write_tech_lef` | tech vs cell LEF selected with `-tech only/also/dont`; layer OFFSET and per-axis PITCH kept |
| DEF | `read_def` → `read_defII` (`PARSER/make_rw_def`) | `write_def`, `write_def_for_router` | `.gz` accepted; sections selectable; `read_defII` parses VIAS; an older `sub read_def` is not reachable from the prompt |
| Verilog gate-level | `read_verilog` (`PARSER/make_rw_verilog`) | `write_verilog` | cannot parse yosys `(* src *)` attributes, filter them first |
| Verilog RTL | `read_hdl` (`PARSER/make_r_rtl`, Verilog-Perl) | `write_rtl` | parameter expressions via `UTILS/make_eval_expressions` |
| Liberty | `read_lib` (`PARSER/make_rw_lib`) | `write_lib`, `write_lib --forSynth` | |
| GDS2 | `read_gds` (layer rectangles) | `def2gds` (`UTILS/make_def_2_gds`, GDS2 module) | `export_all` writes DEF, LEF and GDS together |
| EDIF, CDL, XML, XLS, JSON | `read_edif`, `read_cdl`, `read_xml`, `read_xls` | `write_xml*`, `write_excel`, `write_flat_json` | |
| SDC / timing reports | `read_sdc`, `read_timing_report`, `read_sta_report` | `write_sdc` | |
| SPEF | none live | none | `PARSER/make_rw_spef` is a dead 19-line script |
| library config (JSON) | `read_config_file`, `read_library_config` (`PARSER/make_rw_config`) | `write_config_file` | see `CONFIG/library.config` |

---

## 8. The GUI

The GUI is Perl/Tk. `win` (also `gui`, `ui`) in `GUI/make_rw_gui*` forks a `Proc::Simple`
child that runs `start_gui`, so the prompt stays live in the parent; the child builds a
`MainWindow` titled after the top module. The window has a menubar (File, Library,
Simulate, Synthesis, Power, Place, CTS, Route, Timing, LVS, DRC, Output, Util,
CreateDesign, KB, xls/html, plus RoutingLayer and CutLayer visibility menus) and a
`Tk::NoteBook` with four live tabs: **FlatView** (a `Tk::WorldCanvas` drawing die,
rows, instances, ports, flylines and routes from `%CADB`/`%PORTS_ALREADY`), **Library**
(sub-tabs tech, lef-view, gds-view), **Specify**, and **Raster**. FlatView draws one
canvas item per instance, which stops being usable in the hundreds of thousands; Raster
(`GUI/make_raster_view`, driving `3RDBIN/def_raster`) writes the design to a DEF, renders
it as one image showing cell utilisation per pixel with the die and rows overlaid, and
supports wheel zoom at the cursor. `raster_view` does the same from the prompt, and can
draw a DEF on disk that is not the loaded design. Several more tabs (Design, Hier-View,
Analysis, KB, eFarm, rtl-edit) exist in the source but are commented out of the notebook.
Menu items are thin wrappers that pop up an option dialog and call the same command sub
the prompt would. `GUI/PROTO/*` holds the hierarchy-specific widgets (pseudo hierarchy
display, floorplan widget, pin placement, RTL edit) used by the hier menus.

Because the GUI runs in a forked child, a placement made at the prompt is not visible to
an already-open window until it redraws from a fresh fork; conversely `$DBSCALEFACTOR`
captured at draw time is why the GUI must be re-opened after the DBU changes.

`GUI_SERVER/` is an XML-RPC server (`Frontier::Daemon`) plus HTTP/SOAP clients and a
`www/` CGI front-end, started by `-port` or `allow_remote_login`. It is dead: the
`Frontier::Daemon` import is commented out and `$hostname` is never set.

---

## 9. Known weaknesses

These are structural facts a maintainer should know before changing things, not a
backlog.

### 9.1 Dead and unreachable code

- 57 registered commands have no sub (appendix of the user manual).
- `place_graph_plan_4_pseudo` and the graywolf commands depend on binaries not shipped;
  `run_jroute` is a forwarding stub. The `mpl` commands and the old `groute`, `route_flat`
  and `route_hier` routers were removed in September 2026.
- Directories not required by any wrapper: `LVS/`, `SCAN/`, `PARSER/make_rw_spef`,
  `ROUTER/make_shape_router` (0 bytes), `UTILS/make_Robi_func1` (a stale twin of
  `make_Robi_func` containing older `hier2flat` and `set_top_module`), `UTILS/generalArgs`,
  `PARSER/mohit_def_for_without_modified_net_coord/`, `PARSER/hier_inst_report`.
- Loaded but unregistered: `write_cdl`, `clone_git`, `routeP2P_inpair`, `run_gtkwave` and
  the iverilog popups (GUI menu only).
- `-port`/daemon mode and all of `GUI_SERVER/`, `EFARM/` (farm daemons `tesLauncher`,
  `tesStatusd` absent), `KNOWLEDGEBASE/` (MySQL test database) are present but not
  functional in this environment.

### 9.2 Duplicated definitions

Because every fragment lands in `main`, a sub name defined twice is a silent override.
45 sub names are defined in more than one required fragment; two back commands:
`seedPlace` (`ALGO/PREPLACE/tempSeedPlace` is overridden by
`PLACER/DATAPREP/make_rw_flat_graph`, which loads later and is the intended one) and
`get_selected_instance` (two GUI files). `make check-load` does not catch these.
`sub source`, `sub remoteCommands` and the prompt loop are three copies of dispatch.

### 9.3 Consistency by convention

`$TOP_MODULE` and `$GLOBAL->{TOP}`; `$DEF_DATABASE_UNIT` and `$GLOBAL->{DBU}`; the
three pin stores; `%PORTS_ALREADY` written as a two-level PortDB hash everywhere except
two lines in `PARSER/make_rw_def` (770, 1899) that assign a scalar at one level. None of
these are enforced by code.

### 9.4 Performance envelope

Everything is a Perl hash of blessed hashes, at about 4.7 KB per instance. `TESTS/large`
measures the hierarchical flow from RTL to a legal placement on four designs built from
the same multiplier, from `TESTS/large/Makefile`:

| Design | Instances | Distinct modules | Wall | Peak memory |
|---|---|---|---|---|
| matmul_4x4 | 204,816 | 13 | 1m30 | 1.2 GB |
| mxu_tile64 | 213,568 | 14 | 1m29 | 1.2 GB |
| mxu_256 | 855,424 | 15 | 5m23 | 4.2 GB |
| mxu_1024 | 3,424,000 | 16 | 25m47 | 16.1 GB |

These wall times predate the legaliser fix, which cut `legalize_flat` from 821 s to 108 s
on mxu_1024, so current times are lower. They do not include `improve_congestion`, which
adds 78 s on matmul_4x4 and 5m39 on mxu_256. Per phase, for each 4x step: synthesis and
elaboration scale linearly, `hier_place_all` sublinearly (about n^0.87, because it walks
distinct modules), `write_def` sublinearly, and `legalize_flat` now linearly. Memory is the
limit: mxu_1024 needs 16 GB, and opening the GUI forks a second copy of the database.

Placement quality is the weaker side, though `improve_congestion` now recovers about half
the wirelength after legalisation on the large tests. On mxu_256 every block sits exactly inside its box,
but the placer does not order a systolic array into its mesh. Only 5 of 24 nearest
neighbour links inside a 4x4 PE tile end up physically adjacent, and ten times the placer
steps does not change that. A systolic array is the easiest placement problem there is, so
this is a floor on quality for harder designs.

Routing results are noisy. `write_def` emits records in Perl hash order, which differs per
process, and qrouter routes in file order: five runs of one byte-identical placement gave
between 130 and 239 unrouted nets. Set `PERL_HASH_SEED=0` and `PERL_PERTURB_KEYS=0` for any
comparison that goes through the router. Even then, small placement changes that leave pin
density identical moved the count from 104 to 261 on nangate_flat, so a routing count on
that design cannot judge a placement change; measure wirelength, density and overlaps
instead.

### 9.5 Position against OpenROAD

OpenROAD is the reference open-source flow. Against it electron is behind on every engine:
it has no timing-driven placement, no CTS, no timing repair, no DRC-clean detail router and
no extraction. Where it differs by design is hierarchical placement: `hier_place_all`
places each distinct module once and reuses it, which is why 3.4 million instances place
in minutes of placer time, while OpenROAD's global placer works on the flattened netlist.
That trade gives speed on regular, repeated designs and costs quality wherever flat
placement could exploit connectivity across block boundaries.

The two can be measured against each other on the same RTL and cells:
`TESTS/large/openroad/` holds an OpenROAD-flow-scripts configuration for the MXU designs
and a Makefile that runs both flows and scores both DEFs with the same independent checker,
`TESTS/defmetrics.py`. The user manual has the procedure.

The first comparison, on `mxu_tile64`, confirmed the trade. End to end, electron finished
in 200 to 269 s against ORFS's 512 s, because its synthesis and global placement are
cheap. On the same netlist OpenROAD placed in 94 s against 174 to 241 s, with half the
wirelength. It also exposed three electron defects: constant inputs in hierarchical port
connections are never tied off, the MXU flow leaves ports unroutable, and the DEF writer
emits `DESIGN` after `UNITS`. Full results are in `TESTS/large/openroad/REPORT_mxu_tile64.md`.

---

## 10. Checks, tests and conventions for changes

- `make check` runs `check-load` (start all three tools in the container with a two-line
  script) and `check-syntax` (`perl -c` on all 326 required fragments, in the container).
  `perl -c` does not execute a runtime `require`, so only `check-load` proves the chain
  loads. Six `check-syntax` failures are known false positives listed in `CLAUDE.md`.
- A `pre-push` hook at `INSTALL/hooks/pre-push` builds and runs `check-load` before every
  push, refusing the push if a tool fails to load. Enable it once per clone with
  `git config core.hooksPath INSTALL/hooks`. `ELECTRON_PREPUSH_TESTS=1` also runs
  `TESTS/nangate_all`. The hook also warns, without blocking, when a push changes code
  but neither document in `DOCS/`, or when the manual's command index is out of date.
- The documents are maintained with the code: `CLAUDE.md` ("Keep the documentation
  current") says which part to update for each kind of change, and
  `python3 DOCS/gen_command_index.py` rebuilds the manual's command index from
  `commandsFile` and the loaded fragments, keeping the descriptions already written.
- `TESTS/Makefile` holds the small flows on the 4,233-instance vedic multiplier:
  `nangate_flat` (place and route), `nangate_hier` (one level), `nangate_recurse` (the whole
  tree with `hier_place_all`), `nangate_rtl_hier` (from registered RTL through `synthesize`),
  and `nangate_all` for all four. `TESTS/large/Makefile` holds the scaling set above; it is
  not in `nangate_all` because it takes minutes. Everything runs inside the container
  (`make app` first).
- `TESTS/defmetrics.py` measures any placed DEF independently: HPWL with real pin offsets,
  legality in integer DBU, utilisation, and displacement against a second DEF. Use it
  rather than a command's own summary.
- Adding a command: register in both hashes of `commandsFile`; `require` the file in all
  three `.nopath` files; end the file with `1;`; pick a unique message prefix and check
  serials; run `make check-load` or `<cmd> -h` in the container. Verify placement or
  connectivity results from the written DEF with an independent check, not from the
  command's own summary.
- `/proj_pd/user_dev/rsrivastava/pyspark_cad` (the A* router and the Python placer
  engines) is a separate, read-only repository. `3RDBIN/hier_place` is maintained here.

---

## Appendix: directory guide

| Directory | Live | Purpose |
|---|---|---|
| `UTILS/` | yes | wrappers (`*.nopath`), generators (`make_tool*`), shell passthrough, help, `hier2flat`, `set_top_module`, `def2gds`, container exec, graph writers, save/restore |
| `PARSER/` | yes | all format readers and writers, elaboration, floorplan, config, synthesis driver |
| `DB/` | yes | one file per class: `make_<Class>_package` |
| `DBA/` | yes | access and transform helper libraries over the DB classes |
| `ALGO/` | yes | `PREPLACE` seeding and grids, `PLACE` SA and port placers, `PLACE_NEW` legaliser, overlap and congestion removal, macro arranger, `FLPLAN` engine, `BLOCKPLACE` compactor, `POSTPLACE` |
| `PLACER/` | yes | `DATAPREP` nodefile/graph I/O and the 3RDBIN drivers, graywolf files; `FUNTIONS` orchestration wrappers |
| `TSTGEN/` | yes | pseudo hierarchical model, `edit_module`/`commit_module`, `hier_place`, pin placement, geometry engine |
| `ROUTER/` | yes | `qroute`, `flat_route`, `route_p2p`, router graph writers |
| `POWER/` | yes | rings, stripes, PG vias, power escape routing |
| `TE/` | yes | STA report readers, SDC, spice decks and simulation, characterisation |
| `DESANALYSIS/` | yes | `report_*`, congestion and routing analysis, gcells |
| `LIBANALYSIS/`, `LIBQA/` | yes | pin access and density analysis, footprints, library QA designs |
| `GUI/`, `GUI/PROTO/` | yes | Tk GUI, hierarchy widgets |
| `GUI_SERVER/` | loaded, dead | XML-RPC server and web clients |
| `RTL/` | yes | RTL utilities, area estimation, `p2v` |
| `FLOW/`, `TCL/`, `EXTCOMMANDS/`, `FLEX_COMMANDS/`, `SPARK/`, `PADFRAME/`, `KNOWLEDGEBASE/`, `EFARM/` | loaded | flow view, `set`/`puts`/`query`, external command wrappers, hierarchy browser, sdef/sgraph dumps, pad ring, test database, farm |
| `3RDBIN/` | yes | Python placer drivers |
| `CONFIG/` | yes | `library.config` |
| `TESTS/` | yes | reference flows, Nangate45 library, vedic netlist, `defmetrics.py`; `large/` the scaling set and the OpenROAD comparison |
| `INSTALL/` | yes | Containerfiles, `podman/Makefile`, legacy package scripts |
| `DOCS/` | | this document, the user manual, `proton_cmd_desc.xlsx`, command template |
| `LVS/`, `SCAN/`, `SCRATCH/`, `ETC/`, `PNG/`, `lib64/`, `share/`, `iverilog/` | no | unloaded fragments, icons, old bundled libraries |
