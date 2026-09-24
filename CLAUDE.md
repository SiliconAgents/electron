# Working on electron

Perl ASIC place-and-route suite, AGPL-3.0, forked from efabless/proton. The files
under `PARSER/`, `PLACER/`, `TSTGEN/`, `GUI/`, `ALGO/`, `DB/` are **not modules** —
they are fragments `require`d into one namespace by `UTILS/*.nopath`. There is no
`use strict`; almost everything is a package global.

## Build and run

```
make                    # writes electron, electron_hier, electron_proto from UTILS/*.nopath
```

`make` prepends `$BEEHOME` and a `use lib` to each `.nopath` and stamps the
release-ID from `git log --oneline | wc -l`, so the built scripts change on every
commit. They are gitignored — run `make` after cloning, don't track them.

## Everything runs in the container. Everything.

Running, testing and checking all happen inside `INSTALL/podman/pysparkpp.sif`
(pysparkplusbuild plus qrouter). The host cannot do any of it: no Tk, so every
GUI fragment and all three `.nopath` wrappers fail to compile; no scipy, so the
placers die; no yosys, qrouter or spark-shell, so nothing that shells out runs.
A "syntax OK" from the host proves very little, and a failure there usually
means nothing at all.

```
make check              # both checks below, in the container
make check-load         # the one that matters: loads all three tools for real
make check-syntax       # perl -c on all 323 required fragments
make app                # interactive shell in that image
```

`make check` runs on every push, via a `pre-push` hook. It is committed at
`INSTALL/hooks/pre-push` and has to be switched on once per clone, because
`.git/hooks` is not version controlled:

```
git config core.hooksPath INSTALL/hooks
```

It builds, then runs `check-load`, and refuses the push if a tool fails to
load — naming the file. About 15 seconds. `check-syntax` is advisory and never
blocks, because its six standing failures are artefacts. `git push
--no-verify` or `ELECTRON_SKIP_PREPUSH=1` skips it;
`ELECTRON_PREPUSH_TESTS=1` adds `TESTS/nangate_all`. On a machine with no
apptainer or no `.sif` it refuses rather than passing silently.

To run a flow:

```
apptainer exec --bind /tech:/tech --bind /proj_pd:/proj_pd --bind /home/$USER:/home/$USER \
  INSTALL/podman/pysparkpp.sif \
  bash -c 'cd <workarea> && PATH=/usr/bin:$PATH <repo>/electron --nogui --cleanlog --nolog -f run.tcl'
```

**`bash -c`, not `bash -lc`.** A login shell sources the host `~/.bashrc`
through the bound home directory, which puts a miniconda ahead of `/usr/bin`;
only `python3` is shadowed, and that one has no scipy, so `place_flat_design`
dies with "No module named scipy" inside an image that has scipy 1.15.3. The
`PATH=/usr/bin:$PATH` prefix fixes the same thing from inside an interactive
container shell, which sources that bashrc too.

`make check-syntax` reports six fragments to look at, and all six are false
positives — `GUI/make_design_browser`, `GUI/make_gui_support_func`,
`GUI_SERVER/make_server_rpc`, `RTL/Fifo`, `TE/make_x_characterize`,
`UTILS/perl_dump`. Each uses a name the wrapper imports, in a form perl can
only parse once the name is declared: `Exists $h{...}` (Tk), `retrieve "f"`
(Storable), `FileHandle "> $f"`, and a bareword `sub @args`. Read a failure
before believing it, and check the *first* error, not the last — the rest are
cascades.

## Adding or changing a command — the checklist

1. Register it in **`commandsFile`**, in *both* hashes: `%cmds` (command → sub) and
   `%checkArguments`. Both live inside `sub initiallize_commands`.
2. `require` the file in **all three** of `UTILS/tool.nopath`, `hier_tool.nopath`,
   `proto_tool.nopath`.
3. End every required file with **`1;`**. Without it the load dies with
   *"did not return a true value"*.
4. **`perl -c` does not execute a runtime `require`.** It will report "syntax OK"
   on a tool whose fragments cannot load — a file missing its `1;` passes
   `perl -c` and then kills the tool at startup. Run `make check-load`, or the
   command for real through the container; `<cmd> -h` is enough to prove the
   file loads.
5. Message numbers must be unique per prefix. Check:
   `grep -o "PREFIX : [0-9]*" file | sort | uniq -d`
6. Message prefixes abbreviate the command they belong to (`WR_PS_GRPH`,
   `RD_PS_ND`, `HR_PL_PN`). Rename them with the command.

## Units — the recurring bug class

| store | units |
|---|---|
| `%CADB` instance locations, `FLOORPLAN_ALREADY` | DBU |
| `%PLDB` cell sizes, LEF pin rects, layer PITCH | **microns** |
| `PSEUDO_FLOORPLAN_ALREADY` | DBU on disk, but `dbaTstgenGetPinRect`/`AddPinRect` convert, so callers see **microns** |
| nodefiles written by `write_flat_graph` / `write_pseudo_graph` | microns |

Never hardcode the DBU. `$GLOBAL->dbfGlobalGetDBU` is authoritative;
`$DEF_DATABASE_UNIT` is a global that `set_inst_box` overwrites mid-session, and
`$DBSCALEFACTOR` is captured once when a GUI view is built — the two diverge, and
that was the cause of the flat-view flyline offset.

## Three pin stores, easily confused

- `PORTS_ALREADY{$module}{$port}` — flat ports. What the flat view and `write_def`
  read. `PortDB::new` defaults to location (0,0) and side **`"W"`**, so an
  unplaced port reports itself on the left edge.
- `FLOORPLAN_ALREADY{$id}` pins — flat floorplan. What the guide-driven
  `hier_place_pins` path edits.
- `PSEUDO_FLOORPLAN_ALREADY` via `PSEUDO_MODULE_ALREADY{$m}->dbaTstgen*` — the
  hier/pseudo pins. What `hier_place` and `read_pseudo_nodefile` write.

Nothing bridges pseudo → flat automatically. The chain is
`commit_module --physical_only` → `dbfTstgenUpdateFlplanByID` → `hier2flat` →
`PORTS_ALREADY`. `hier2flat` is global: it rebuilds from the whole hierarchy, not
just the edited module.

## Conn lines

A VNOM conn line must be a complete verilog statement ending `") ;"`. Readers strip
the port list's closing paren with `s/\)\s*\;//`; without the semicolon that never
fires and the **last pin's net keeps a stray `)`**.

Net names must be matched at bit granularity. `.sum(q6)` and `q6[11]` are the same
signal; comparing the strings says otherwise. `array_of_blasted_expr` is the
expansion to use — it splits concatenations, expands `a[3:0]`, resolves a bare bus
name against the module's declared widths, and reduces sized constants of any base
to one `1'b0`/`1'b1` per bit.

## Verifying placement or connectivity work

Don't trust a command's own summary. Write the DEF and check it independently —
a 2D rectangle sweep for overlaps, a net-to-pin map for connectivity. A checker
that groups cells by exact Y silently undercounts overlaps in an unlegalized
placement.

## Off limits

`/proj_pd/user_dev/rsrivastava/pyspark_cad` is read-only: shared repo, and
in-progress work sits uncommitted in its tree. `hier_place` is maintained here as
`3RDBIN/hier_place`; the pyspark_cad copy is a separate fork of it.
