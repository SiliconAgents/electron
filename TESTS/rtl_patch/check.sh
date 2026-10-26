#!/bin/bash
# rtl_patch on a header reached only through +incdir+: the copy is patched,
# its directory comes FIRST in the output list, the source file is untouched,
# and yosys-slang reads the result (when yosys is on the PATH).  Then the two
# errors: a header found nowhere, and a listed file beside the header.
set -u
cd "$(dirname "$0")"; E=../../3RDBIN/rtl_patch; W=../workarea/rtl_patch; mkdir -p $W
fail() { echo "rtl_patch_headers: FAIL $*"; exit 1; }
python3 $E --filelist rtl.f --rules rules.py --out $W/ok > $W/ok.log 2>&1 || { cat $W/ok.log; fail "the header rule did not apply"; }
grep -q "patched header flop_macros.svh" $W/ok.log || fail "no header reported patched"
head -1 $W/ok/rtl.f | grep -q "^+incdir+.*/rtl_patched_inc$" || fail "the patched headers' directory is not first: $(head -1 $W/ok/rtl.f)"
grep -q "if (R) Q <= V; else Q <= D;" $W/ok/rtl_patched_inc/flop_macros.svh || fail "the copy is not rewritten"
grep -q "Q <= R ? V : D;" defines/flop_macros.svh || fail "the original was changed"
grep -q "$(pwd)/rtl/counter.sv" $W/ok/rtl.f || fail "the source file is not listed as itself"
if command -v yosys >/dev/null && yosys -m slang -p "help read_slang" >/dev/null 2>&1; then
  yosys -m slang -p "read_slang -F rtl.f --top counter" > $W/yosys_orig.log 2>&1 \
    && fail "yosys-slang read the unpatched header -- the test no longer shows the problem"
  grep -q "simple if-else pattern expected" $W/yosys_orig.log || fail "the unpatched header failed for another reason"
  yosys -m slang -p "read_slang -F $W/ok/rtl.f --top counter; proc; select -assert-count 1 t:\$adff t:\$aldff" > $W/yosys.log 2>&1 \
    || { tail -5 $W/yosys.log; fail "yosys-slang did not make one async-reset flop of the patched list"; }
  echo "  yosys-slang: the original fails as the vendor RTL does; the patched header gives one async-reset flop"
fi
python3 $E --filelist rtl.f --rules rules_missing.py --out $W/missing > $W/missing.log 2>&1 && fail "a header found nowhere was accepted"
grep -q "nor under any +incdir+" $W/missing.log || fail "the missing header was not reported"
mkdir -p $W/beside/defines; cp defines/flop_macros.svh $W/beside/defines/; cp rtl/counter.sv $W/beside/defines/
printf '+incdir+defines\ndefines/counter.sv\n' > $W/beside/rtl.f; cp rules.py $W/beside/
python3 $E --filelist $W/beside/rtl.f --rules $W/beside/rules.py --out $W/beside/out > $W/beside.log 2>&1 && fail "a file beside the header was accepted"
grep -q "sits beside the header" $W/beside.log || fail "the file beside the header was not reported"
echo "rtl_patch_headers: a header reached through +incdir+ is patched and found first; nowhere and beside are errors"
