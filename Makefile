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
# Simply expanded, NOT `?= $(shell mktemp -d)`: that is a recursively
# expanded variable, so mktemp runs again at every reference -- the html
# lands in one directory and the pdf is looked for in another.
DOCSWORK := .docswork

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

# DOCS/electron.pdf from DOCS/electron.md.
#
# ON THE HOST, unlike every other target here: the image has no pandoc and no
# PDF tooling at all.  And not `pandoc -o x.pdf` either -- that wants a PDF
# engine, and there is no LaTeX on this machine; groff is here but without the
# ms macros pandoc's roff route needs.  HTML then LibreOffice is the path that
# works, and it keeps the tables and code blocks the roff route drops.
#
# The PDF is gitignored.  Regenerate it when you want one; the markdown is the
# thing under version control.
DOCS/electron.pdf: DOCS/electron.md DOCS/style.css
	@command -v pandoc >/dev/null || { echo "docs: no pandoc on PATH" >&2; exit 1; }
	@command -v libreoffice >/dev/null || { echo "docs: no libreoffice on PATH" >&2; exit 1; }
	@mkdir -p $(DOCSWORK)
	@pandoc -s --metadata title="Electron" --toc --toc-depth=2 \
	   -c DOCS/style.css --self-contained DOCS/electron.md -o $(DOCSWORK)/electron.html
	@libreoffice --headless --convert-to pdf --outdir $(DOCSWORK) $(DOCSWORK)/electron.html >/dev/null 2>&1
	@test -f $(DOCSWORK)/electron.pdf || { echo "docs: libreoffice wrote no pdf" >&2; exit 1; }
	@mv $(DOCSWORK)/electron.pdf $@
	@echo "docs: $@"

docs: DOCS/electron.pdf

# The yosys-slang plugin hier_synthesis prefers, built into INSTALL/slang/ in
# the image it will be loaded in.  Upstream at a pinned revision plus our
# patches; INSTALL/slang/build_plugin.sh says why.  A few minutes.  An image
# rebuilt from pysparkppContainerFile carries the same plugin as its default.
slang-plugin:
	$(INCONTAINER) 'cd $(ELECTRON) && INSTALL/slang/build_plugin.sh'

# An interactive shell in the image the checks use.
app:
	apptainer shell --bind /tech:/tech --bind /proj_pd:/proj_pd --bind /home/$$USER:/home/$$USER $(PPSIF)

.PHONY: check check-load check-syntax app docs slang-plugin
