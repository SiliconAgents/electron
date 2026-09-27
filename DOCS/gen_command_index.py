#!/usr/bin/env python3
"""gen_command_index.py -- rebuild Appendix A of DOCS/USER_MANUAL.md.

    python3 DOCS/gen_command_index.py            rewrite the appendix in place
    python3 DOCS/gen_command_index.py --check    exit 1 if it is out of date

Run from anywhere; paths are relative to this file.  The table lists every
command registered in the %cmds hash of commandsFile, the sub it maps to, and
the fragment that defines that sub -- the LAST definition among the files
UTILS/tool.nopath requires, because that is the one perl ends up calling when
two fragments define the same name.  A command whose sub no loaded fragment
defines is marked, since calling it dies with "Undefined subroutine".

Descriptions are kept from the table already in the manual, so a description
written by hand survives a rebuild.  A new command gets an empty one: fill it
in by editing the row, then rerun to check.
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MANUAL = os.path.join(ROOT, "DOCS", "USER_MANUAL.md")
HEADING = "## Appendix A. Command index"
TABLE_HEAD = "| Command | Sub | File (last definition wins) | Description |\n|---|---|---|---|\n"
UNRESOLVED = "(no sub defined in any required file)"


def registered_commands():
    cmds = {}
    with open(os.path.join(ROOT, "commandsFile"), errors="replace") as fh:
        for line in fh:
            if "%checkArguments" in line:
                break
            m = re.match(r'\s*"([\w\-]+)"\s*=>\s*"([\w\-]+)"', line)
            if m:
                cmds[m.group(1)] = m.group(2)
    return cmds


def sub_locations():
    subs = {}
    with open(os.path.join(ROOT, "UTILS", "tool.nopath"), errors="replace") as fh:
        files = [re.sub(r'^require "[^/]*/', "", l.strip()).split('"')[0]
                 for l in fh if l.startswith("require ")]
    for rel in files:
        path = os.path.join(ROOT, rel)
        if not os.path.isfile(path):
            continue
        with open(path, errors="replace") as fh:
            for line in fh:
                m = re.match(r"\s*sub\s+(\w+)", line)
                if m:
                    subs[m.group(1)] = rel
    # resume is defined in the wrapper itself, not in a required fragment
    subs.setdefault("resume", "UTILS/tool.nopath")
    return subs


def existing_descriptions(text):
    desc = {}
    i = text.find(HEADING)
    if i < 0:
        return desc
    for line in text[i:].splitlines():
        m = re.match(r"\| `([^`]+)` \| `[^`]*` \| [^|]* \| (.*) \|$", line)
        if m:
            desc[m.group(1)] = m.group(2)
    return desc


def build(text):
    cmds = registered_commands()
    subs = sub_locations()
    desc = existing_descriptions(text)
    rows = []
    missing = 0
    for c in sorted(cmds):
        f = subs.get(cmds[c])
        if f is None:
            missing += 1
            f = UNRESOLVED
        rows.append(f"| `{c}` | `{cmds[c]}` | {f} | {desc.get(c, '')} |")
    i = text.find(HEADING)
    if i < 0:
        raise SystemExit(f"no '{HEADING}' in {MANUAL}")
    j = text.find("| Command | Sub |", i)
    head = re.sub(r"All \d+ commands", f"All {len(cmds)} commands", text[i:j])
    return text[:i] + head + TABLE_HEAD + "\n".join(rows) + "\n", len(cmds), missing


def main():
    text = open(MANUAL).read()
    new, n, missing = build(text)
    if "--check" in sys.argv[1:]:
        if new != text:
            print(f"DOCS/USER_MANUAL.md Appendix A is out of date: run python3 DOCS/gen_command_index.py")
            return 1
        print(f"Appendix A is current: {n} commands, {missing} without a sub")
        return 0
    if new != text:
        open(MANUAL, "w").write(new)
        print(f"Appendix A rewritten: {n} commands, {missing} without a sub")
    else:
        print(f"Appendix A already current: {n} commands, {missing} without a sub")
    return 0


if __name__ == "__main__":
    sys.exit(main())
