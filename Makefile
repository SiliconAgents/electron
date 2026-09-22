1:
	./UTILS/make_tool
	\rm -rf electron.log* ; cd ~/ ; \rm -rf electron.log*
	\rm -rf electron.cmd* ; cd ~/ ; \rm -rf electron.cmd*
	./UTILS/make_tool_hier
	./UTILS/make_tool_proto
	chmod +x electron electron_hier electron_proto

################################################################################
# Checks.  All of them run inside the container, because the host cannot check
# this tool: it has no Tk, so every GUI fragment and both .nopath wrappers fail
# to compile there, and it has no yosys, qrouter or spark-shell, so nothing that
# shells out can be exercised.  A "syntax OK" from the host proves very little
# and a failure there usually means nothing at all.
################################################################################
ELECTRON  := $(abspath .)
PPSIF     := $(ELECTRON)/INSTALL/podman/pysparkpp.sif

# bash -c, NOT bash -lc: a login shell sources the host ~/.bashrc through the
# bound home directory and puts a miniconda python3 ahead of the container's.
INCONTAINER = apptainer exec --bind /tech:/tech --bind /proj_pd:/proj_pd \
	--bind /home/$$USER:/home/$$USER $(PPSIF) bash -c

check: check-load check-syntax

# The check that matters.  perl -c does NOT execute a runtime require, so it
# cannot tell you whether the fragments load -- a file missing its trailing "1;"
# passes perl -c and then kills the tool at startup.  Only running the built
# tool proves the whole require chain.
check-load: 1
	@echo "=== loading all three tools in the container ==="
	@$(INCONTAINER) 'cd $(ELECTRON) && mkdir -p .checkwork && cd .checkwork && \
	  printf "report_design\nexit\n" > c.tcl && \
	  rc=0; for t in electron electron_hier electron_proto; do \
	    printf "  %-16s " $$t; \
	    out=$$(unset DISPLAY; $(ELECTRON)/$$t --nogui --cleanlog --nolog -f c.tcl 2>&1); \
	    if echo "$$out" | grep -qE "Can.t locate|did not return a true value|BEGIN failed"; then \
	      echo "FAIL"; echo "$$out" | grep -m2 -E "Can.t locate|did not return a true value|BEGIN failed" | sed "s/^/      /"; rc=1; \
	    else echo "loads"; fi; \
	  done; exit $$rc'
	@rm -rf .checkwork

# Per-fragment syntax, which the host cannot do at all -- Tk::WorldCanvas alone
# stops it.  Read a failure before believing it: a fragment that calls something
# the wrapper imports, in a form perl can only parse when the name is already
# declared, fails here and works at runtime.  "Exists $h{...}" (Tk),
# "retrieve \"f\"" (Storable), "FileHandle \"> $f\"" and a bareword "sub @args"
# are all this, and all six current failures are one of them.
check-syntax: .frags.txt
	@echo "=== perl -c on every required fragment, in the container ==="
	@$(INCONTAINER) 'cd $(ELECTRON) && bad=0; n=0; \
	  while read f; do \
	    n=$$((n+1)); \
	    [ -f "$$f" ] || { echo "  MISSING $$f"; bad=$$((bad+1)); continue; }; \
	    perl -I LIBS -c "$$f" 2>&1 | grep -q "syntax OK" || { echo "  needs a look: $$f"; bad=$$((bad+1)); }; \
	  done < .frags.txt; \
	  echo "  $$n fragment(s) checked, $$bad to look at (see the note above this target)"'
	@rm -f .frags.txt

# The require list, built on the host where the quoting is simple.  A .nopath
# line reads  require "$$BEEHOME/DIR/file";  so strip up to the first slash.
.frags.txt:
	@grep -h '^require ' UTILS/*.nopath | sed 's|^require "[^/]*/||; s|";.*$$||' | sort -u > $@

# An interactive shell in the image the checks use.
app:
	apptainer shell --bind /tech:/tech --bind /proj_pd:/proj_pd --bind /home/$$USER:/home/$$USER $(PPSIF)

.PHONY: check check-load check-syntax app
