# Electron against OpenROAD on the MXU testcases.
#
# Same RTL, same Nangate45 cells, same 50% utilisation and square die.  Each
# tool synthesises and places it its own way, writes a DEF, and both DEFs are
# measured by the same independent checker (TESTS/defmetrics.py).  Nothing
# either tool reports about its own result is used.
#
# THE TWO HALVES RUN IN DIFFERENT PLACES
#
#   electron   inside the electron container:  make app  (TESTS/large), then
#              here:   make electron TOP=mxu_tile64
#              or, with Docker and no Apptainer:
#                      make electron-image ; make electron-docker TOP=mxu_tile64
#   OpenROAD   on a host with docker, using the public ORFS image:
#                      make openroad TOP=mxu_tile64
#   compare    anywhere with python3:
#                      make compare TOP=mxu_tile64
#
# TOP is mxu_tile64 (the default, ~214k instances, a couple of minutes each
# side), mxu_256 (~855k, electron needs ~4GB) or mxu_1024 (~3.4M, electron
# needs ~16GB -- more than a 16GB machine has once the OS is counted).
#
# WHAT IS AND IS NOT LIKE FOR LIKE
#
#   * Both stop at a legal, detail-placed placement.  Electron has no CTS or
#     timing repair, so the ORFS run stops at "place" too.  ORFS's place stage
#     ends in detailed placement, so the electron side runs improve_congestion
#     after legalize_flat by default.  ELECTRON_DP=0 compares the legalised
#     placement alone; pass it to both "make electron" and "make compare".
#   * ORFS's placement is timing and routability blind here (config.mk), to
#     match electron's wirelength-only placers.  OPENROAD_FULL=1 turns both
#     back on, for "what the complete tool does".
#   * ORFS resizes and buffers during placement (repair_design), so its
#     instance count comes out a little higher.  compare.py prints HPWL per
#     net as well as the total for that reason.
#   * Electron places hierarchically (hier_place_all); ORFS places flat.  That
#     is the comparison being made, not an accident of it.
#
# Run on 27 September 2026 with openroad/orfs:latest; REPORT_mxu_tile64.md has
# the results, and judge.tcl, netcompare.py, prep_def.py and same_netlist.tcl
# the deeper checks it used.  Pin ORFS_IMAGE to a dated tag to repeat them.

ELECTRON   := $(abspath ../../..)
HERE       := $(abspath .)
TOP        ?= mxu_tile64
WORK       := $(HERE)/work_$(TOP)

# electron side
ELECTRON_WORK := $(ELECTRON)/TESTS/large/workarea
ELECTRON_DP   ?= 1
ifeq ($(ELECTRON_DP),1)
ELECTRON_DEF  := $(ELECTRON_WORK)/$(TOP).improved.def
else
ELECTRON_DEF  := $(ELECTRON_WORK)/$(TOP).legal.def
endif
ELECTRON_LEF  := $(ELECTRON)/TESTS/library/NangateOpenCellLibrary_PDKv1_2_v2008_10.lef
SCRIPT_mxu_tile64 := mxu64_hier.tcl
SCRIPT_mxu_256    := mxu_hier.tcl
SCRIPT_mxu_1024   := mxu1024_hier.tcl

# OpenROAD side
ORFS_IMAGE ?= openroad/orfs:latest
ORFS_ROOT  ?= /OpenROAD-flow-scripts
ORFS_RES   := $(WORK)/results/nangate45/$(TOP)/base
ORFS_LOGS  := $(WORK)/logs/nangate45/$(TOP)/base
ORFS_DEF   := $(WORK)/$(TOP).orfs.place.def
ORFS_LEFS  := $(WORK)/lef/NangateOpenCellLibrary.tech.lef $(WORK)/lef/NangateOpenCellLibrary.macro.mod.lef
ifeq ($(OPENROAD_FULL),1)
ORFS_VARS  := GPL_TIMING_DRIVEN=1 GPL_ROUTABILITY_DRIVEN=1
endif

# The repository is mounted at its own path, so every path in config.mk and
# in the DEF means the same thing inside and out.  -u keeps the results owned
# by you rather than by root.
DOCKER = docker run --rm -u $$(id -u):$$(id -g) -e HOME=/tmp \
	-v $(ELECTRON):$(ELECTRON) -w $(HERE) $(ORFS_IMAGE) bash -c

#-----------------------------------------------------------------------------
# electron: the same script TESTS/large/Makefile runs, timed, with
# improve_congestion added after legalize_flat unless ELECTRON_DP=0.  Paths in
# the scripts are relative to the working directory, not to the script, so the
# edited copy can live in $(WORK).
#-----------------------------------------------------------------------------
electron:
	@test -n "$(SCRIPT_$(TOP))" || { echo "TOP must be mxu_tile64, mxu_256 or mxu_1024"; exit 1; }
	mkdir -p $(ELECTRON_WORK) $(WORK)
	sed '/^exit/d' $(HERE)/../$(SCRIPT_$(TOP)) > $(WORK)/electron.tcl
	if [ "$(ELECTRON_DP)" = 1 ]; then \
	  printf 'improve_congestion\nwrite_def -output $(TOP).improved.def --overwrite\n' >> $(WORK)/electron.tcl; fi
	echo exit >> $(WORK)/electron.tcl
	cd $(ELECTRON_WORK) ; PATH=/usr/bin:$$PATH python3 $(HERE)/measure.py $(WORK)/electron.time.json \
	  $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f $(WORK)/electron.tcl

#-----------------------------------------------------------------------------
# electron without Apptainer: a lean Docker image and the same run inside it.
# PERL_HASH_SEED and PERL_PERTURB_KEYS make the DEF record order repeat, and
# QT_QPA_PLATFORM lets hier_place -batch start with no display.
#-----------------------------------------------------------------------------
ELECTRON_IMAGE ?= electron-lean:mxu
electron-image:
	docker build -t $(ELECTRON_IMAGE) -f $(HERE)/electron-lean.Dockerfile $(ELECTRON)/INSTALL

electron-docker:
	docker run --rm -u $$(id -u):$$(id -g) -e HOME=/tmp -e QT_QPA_PLATFORM=offscreen \
	  -e PERL_HASH_SEED=0 -e PERL_PERTURB_KEYS=0 -e ELECTRON_HOME=$(ELECTRON) \
	  -v $(ELECTRON):$(ELECTRON) -w $(HERE) $(ELECTRON_IMAGE) \
	  bash -c 'cd $(ELECTRON) && make >/dev/null && cd $(HERE) && make electron TOP=$(TOP) ELECTRON_DP=$(ELECTRON_DP)'

#-----------------------------------------------------------------------------
# OpenROAD: ORFS synth, floorplan, place, then the placement as a DEF
#-----------------------------------------------------------------------------
openroad:
	mkdir -p $(WORK)/lef
	$(DOCKER) 'cd $(ORFS_ROOT) && source ./env.sh >/dev/null && cd flow && \
	  make DESIGN_CONFIG=$(HERE)/config.mk DESIGN_NAME=$(TOP) WORK_HOME=$(WORK) $(ORFS_VARS) place && \
	  cp platforms/nangate45/lef/NangateOpenCellLibrary.tech.lef \
	     platforms/nangate45/lef/NangateOpenCellLibrary.macro.mod.lef $(WORK)/lef/ && \
	  printf "read_db $(ORFS_RES)/3_place.odb\nwrite_def $(ORFS_DEF)\n" > $(WORK)/to_def.tcl && \
	  openroad -no_init -exit $(WORK)/to_def.tcl' 2>&1 | tee $(WORK)/orfs.log

#-----------------------------------------------------------------------------
# compare: both DEFs through the same checker, then side by side
#-----------------------------------------------------------------------------
compare:
	@test -f $(ELECTRON_DEF) || { echo "no $(ELECTRON_DEF): run  make electron TOP=$(TOP)  in the container"; exit 1; }
	@test -f $(ORFS_DEF)     || { echo "no $(ORFS_DEF): run  make openroad TOP=$(TOP)  on the docker host"; exit 1; }
	python3 $(ELECTRON)/TESTS/defmetrics.py --lef $(ELECTRON_LEF) $(ELECTRON_DEF) --json $(WORK)/electron.metrics.json > $(WORK)/electron.metrics.txt
	python3 $(ELECTRON)/TESTS/defmetrics.py $(addprefix --lef ,$(ORFS_LEFS)) $(ORFS_DEF) --json $(WORK)/openroad.metrics.json > $(WORK)/openroad.metrics.txt
	python3 $(HERE)/compare.py --electron $(WORK)/electron.metrics.json --electron_time $(WORK)/electron.time.json \
	  --openroad $(WORK)/openroad.metrics.json --openroad_logs $(ORFS_LOGS) | tee $(WORK)/compare.txt

clean:
	rm -rf work_*

.PHONY: electron electron-image electron-docker openroad compare clean
