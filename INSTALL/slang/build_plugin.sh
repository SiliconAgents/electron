#!/bin/bash
# Build the yosys-slang plugin hier_synthesis elaborates with: upstream at a
# pinned revision, plus the patches beside this script.
#
#     build_plugin.sh [<out dir>]        default: this directory
#
# Writes <out dir>/slang.so.  Run it inside the image (make slang-plugin does),
# because the plugin has to be compiled against the yosys it is loaded into --
# the image's OSS CAD Suite 0.64, not the 0.9 that apt left in /usr/bin.
#
# Why not the plugin the OSS CAD Suite ships.  That build predates two things
# real RTL needs, and every one of them was a patched copy of somebody's RTL:
#
#   $clog2 of a procedural variable     upstream since 2026-05-05 ("Add clog2
#                                       system call lowering"), a day too late
#                                       for the suite release in the image
#   an escaped instance name            module-name-escape.patch, below; not
#                                       upstream
#
# module-name-escape.patch: with --keep-hierarchy the plugin names each
# per-instance module after the instance's hierarchical path, and slang writes
# that path the way SystemVerilog source would -- an escaped segment as
# "\name ", terminating space included.  yosys then refuses the module name
# for containing a space.  The patch takes the escape syntax back out; an
# escaped name cannot contain whitespace, so the first space is exactly its
# terminator.
#
# One upstream change is NOT backwards compatible: --ignore-unknown-modules is
# gone, and an instantiated module with no definition is an error.
# hier_synthesis probes for that and stops passing it.
#
# The pin is deliberate.  A rebuild must give the same plugin, and upstream
# moves fast.  Move REV on purpose, rebuild, and rerun a design you know.
set -euo pipefail

REV=988b9c6fec796ea3b4656d439757959161f8db26     # 2026-10-07, slang v12.0
URL=https://github.com/povik/yosys-slang.git

here=$(cd "$(dirname "$0")" && pwd)
out=$(mkdir -p "${1:-$here}" && cd "${1:-$here}" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The suite's yosys-config, so the plugin is built against 0.64.
export PATH=/opt/oss-cad-suite/bin:$PATH
yosys-config --cxxflags | grep -q 'YOSYS_MINOR=64' || {
  echo "build_plugin: yosys-config is not the OSS CAD Suite 0.64 one; run this in the image" >&2
  exit 1
}

git clone -q "$URL" "$work/src"
cd "$work/src"
git checkout -q "$REV"
git submodule update -q --init --recursive
for p in "$here"/*.patch; do
  git apply "$p"
  echo "build_plugin: applied $(basename "$p")"
done

# The plugin wants CMake 3.28; ubuntu 22.04 has 3.22.  pip's wheel is a
# self-contained binary, so it goes in the scratch directory and nowhere else.
cmake=cmake
if ! cmake --version 2>/dev/null | awk 'NR==1{split($3,v,"."); exit !(v[1]>3 || (v[1]==3 && v[2]>=28))}'; then
  python3 -m pip install -q --target "$work/pycmake" 'cmake>=3.28,<4'
  cmake="$work/pycmake/cmake/data/bin/cmake"
fi

# g++, not the clang++ yosys-config names: the image has no clang, and the
# suite's yosys links the system libstdc++, so the ABI matches.
"$cmake" -S . -B build -DCMAKE_BUILD_TYPE=Release \
         -DCMAKE_CXX_COMPILER=g++ -DCMAKE_C_COMPILER=gcc > "$work/cmake.log" 2>&1 \
  || { cat "$work/cmake.log"; exit 1; }
make -C build -j"$(nproc)" > "$work/build.log" 2>&1 \
  || { tail -40 "$work/build.log"; exit 1; }

# Loads, elaborates, and is the plugin it claims to be: the escaped instance
# name is the one thing the suite's plugin cannot do.
cat > "$work/probe.sv" <<'EOF'
module leaf (input a, output y); assign y = ~a; endmodule
module top (input a, output y); leaf \u_leaf[0] (.a(a), .y(y)); endmodule
EOF
yosys -q -m build/slang.so -p "read_slang $work/probe.sv --top top --keep-hierarchy" \
  || { echo "build_plugin: the plugin built but failed its smoke test" >&2; exit 1; }

cp build/slang.so "$out/slang.so.part"
mv "$out/slang.so.part" "$out/slang.so"
echo "build_plugin: $out/slang.so (yosys-slang $(git rev-parse --short HEAD) + $(ls "$here"/*.patch | wc -l) patch(es))"
