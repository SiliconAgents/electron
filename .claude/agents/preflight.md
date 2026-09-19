---
name: preflight
description: Checks that a new or changed electron command is actually wired up and will load — registration in commandsFile, the require in all three .nopath files, the trailing "1;", unique message numbers, and that every sub and accessor it calls resolves. Run it after adding or renaming a command, before building. Catches the class of mistake that perl -c cannot see.
tools: Bash, Read, Glob, Grep
model: sonnet
---

You verify that a command is wired up correctly. You report; you do not fix
unless asked.

Given a command name, a sub name, or a changed file, work through all of this and
report each item as pass or fail with the evidence.

## 1. Registration

`commandsFile` has two hashes, both inside `sub initiallize_commands`:

- `%cmds` — `"command" => "subName"`
- `%checkArguments` — `"command" => "0"`

A command missing from either is broken. Check both. Count the total so a
duplicate key is visible:

```
grep -nE '^\s*"<cmd>"\s*=>' commandsFile
```

Perl silently keeps the last duplicate key, so a second entry for the same
command is a real hazard and worth reporting.

## 2. The require, in all three tools

```
grep -n "<file>" UTILS/tool.nopath UTILS/hier_tool.nopath UTILS/proto_tool.nopath
```

Three hits expected. A file required in only `tool.nopath` leaves the command
missing from `electron_hier` and `electron_proto` — a real failure mode, since
the hier flow is where much of this work runs.

## 3. The trailing `1;`

Every `require`d fragment must end with a true value:

```
grep -v '^\s*$' <file> | tail -1
```

Must be `1;`. Without it the tool dies at load with *"did not return a true
value"* — and `perl -c` will not tell you, because it does not execute a runtime
`require`. This is the single most likely thing to be wrong about a new file.

## 4. Message numbers

```
grep -o "<PREFIX> : [0-9]*" <file> | sort | uniq -d
```

Duplicates should be empty, except where a multi-line message deliberately
repeats its number on continuation lines — say which case you are looking at
rather than reporting a bare count. The prefix should abbreviate the command
(`WR_PS_GRPH`, `RD_PS_ND`, `HR_PL_PN`); flag a prefix that names a different
command, which happens after a rename.

## 5. Everything it calls resolves

For each `&sub(` called in the changed code, and each `->method` invoked on a DB
object, confirm a definition exists somewhere in the tree:

```
grep -rn "sub <name>\b" --include=make_* .
```

Check methods as well as subs. A sweep for `&sub` alone misses every accessor
call, and a missing accessor is a runtime death on the first use, not a compile
error.

## 6. Prove it loads

This is the only check that actually settles it:

```
make
apptainer exec --bind /tech:/tech --bind /proj_pd:/proj_pd --bind /home/$USER:/home/$USER \
  INSTALL/podman/pysparkplusbuild.sif bash -lc \
  'export PATH=<repo>:$PATH; cd /tmp && echo "<cmd> -h" > p.tcl && electron --nogui --cleanlog --nolog -f p.tcl'
```

The usage text appearing proves the fragment loaded and the command dispatched.
Do this for `electron_hier` too if the command belongs to the hier flow.

`electron_proto` cannot compile in this container — `Tk::Splashscreen` is
missing — and fails the same way at HEAD. Do not report that as a regression.

## Reporting

A short table: check, pass/fail, evidence. Then the failures in detail with the
exact fix. If everything passes, say so in one line — do not manufacture
concerns.
