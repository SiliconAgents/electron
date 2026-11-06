#-----------------------------------------------------------------------------
# Segment timing on Spark, for a design flow's Makefile.
#
#   include $(ELECTRON)/INSTALL/sparksta.mk
#   mydesign_sta_synth: workarea/synth/top.synth.sgraph
#   	$(call SPARKSTA,workarea/synth/top.synth.sgraph,$(STORE),$(CORNER),0.312,workarea/sta/top.synth.seg.tsv)
#
# The sgraph is what electron's write_sgraph writes at the end of synthesis
# and again at the end of placement (that one carries coordinates).  The
# engine is pyspark_cad's Photon (photon.sca and build/photon.jar); set PYSPARK to that
# checkout.  Without it the targets say so and do nothing.
#
# Only the engine is READ from pyspark_cad.  The script spark-shell runs is
# written next to the output, never into PYSPARK: its own Makefile keeps one
# .work/sta.sca, so two designs timed at once would overwrite each other's,
# and that tree is a shared checkout.
#
# The arc store is the Parquet library a corner was converted into.  The
# designs on one node share one; SPARKSTA_STORE_FROM builds one from a list of liberty
# files into a directory of your choosing (a Nangate store takes seconds), and
# SPARKSTA_STORE_OF reads where a library config says it is.
#-----------------------------------------------------------------------------
PYSPARK        ?=
SPARKSTA_SIF   ?= $(ELECTRON)/INSTALL/podman/pysparkpp.sif
SPARKSTA_BINDS ?= --bind /tech:/tech --bind /proj_pd:/proj_pd --bind /proj:/proj --bind /tmp:/tmp
SPARKSTA_MASTER?= local[*]
SPARKSTA_MEM   ?= 32g
# Wire parasitics for the run, a SPEF.  Empty: a placed sgraph is timed with
# Photon's own wire estimate from placement (it says so), an unplaced one with
# zero-length wires.  For a real SPEF, or for a test one -- 3RDBIN/sgraph_spef
# writes Photon's estimate to a file.
SPARKSTA_SPEF  ?=
# Photon's wire estimate per micron, "<ohm> <fF>": a design Makefile sets it
# from its library config with SPARKSTA_WIRE_OF; empty leaves Photon's
# built-in guess, which its output then says it used.
SPARKSTA_WIRE_RC ?=
# A calibrated wire model (R and C per micron by net length and pin density),
# which Photon then uses instead of SPARKSTA_WIRE_RC; set it with
# SPARKSTA_WIRE_MODEL_OF from the library config.
SPARKSTA_WIRE_MODEL ?=
# The clock pins' transition in ns (PHOTON_CLOCK_SLEW), for clock-to-Q and for
# setup's clock axis.  Empty: an ideal clock, no transition, as Photon always
# timed.  An ideal clock left clock-to-Q and setup ~9 ps optimistic against a
# routed tile's clock tree; a design Makefile sets its node's typical clock
# transition (0.017 on one modern node: the median at the clock pins of an FC
# route_opt).
SPARKSTA_CLOCK_SLEW ?=
# The cell functions (PHOTON_CELL_FUNCS: <node>_cell_functions.tsv beside the
# arc store), so case analysis carries constants through the logic: a tie
# cell's 0 through a scan mux, scan enable tied off at every flop.  Empty: a
# held pin cuts its own net and nothing beyond, as before.  Needs a Photon
# with constant propagation; an older one ignores it.
SPARKSTA_CELL_FUNCS ?=
# The clock, for comparing with a signoff timer -- never needed otherwise.
# Empty or "ideal": every clock pin at the edge, as always.  "propagated":
# Photon times the clock tree in the netlist (a routed one, with its SPEF) and
# writes the arrival at every clock pin beside the result (<out>.clock.tsv);
# a file path times with such an arrival file instead.  LATE and EARLY are
# flat factors for a timer running POCV -- launch clock x(1 + LATE), capture
# x(1 - EARLY), with CRPR -- e.g. 0.0178 each.  Only make sta reads these.
SPARKSTA_CLOCK       ?=
SPARKSTA_CLOCK_LATE  ?=
SPARKSTA_CLOCK_EARLY ?=
# The block's SDC.  Empty: every input starts at its clock edge and every
# output ends at the period, as always.  Given: set_input_delay and
# set_output_delay time the ports (with set_driving_cell / set_load, and a
# virtual clock's latency once SPARKSTA_CLOCK is propagated), and setup false
# paths and multicycles on ports and clocks apply -- without them a 6-cycle
# reset input is the worst path into every register it reaches.  Photon says
# what it read and what it could not apply.  make sta and place_opt
# (SPARKSTA_REPEAT: its sizing and its own timing) both use it, and
# SPARKSTA_CASE below.
SPARKSTA_SDC ?=
# Pins held at a constant for the run's mode, as set_case_analysis would:
# <cell>/<pin>=0|1, globs allowed.  A memory's clock-to-Q exists once per
# mode (turbo read, normal read, DFT bypass) under liberty "when"
# conditions, and with nothing held one of them is taken by accident -- on
# one memory the three are 5.13, 0.130 and 0.096 ns.  Arcs the held pins
# make false are dropped and the worst of the rest kept; nets into a held
# pin are cut.  The SDC's own set_case_analysis wins where both speak.
#   SPARKSTA_CASE = */TURBO=0 */DFTBYP=0 */BIST=0     normal mode
#   SPARKSTA_CASE = */TURBO=1 */DFTBYP=0 */BIST=0     turbo
SPARKSTA_CASE ?=
# The optimisation advisor (SPARKSTA_ADVISE): the cell table saying which
# cells may replace which (SPARKSTA_CELLS_OF reads it from the library config),
# the Vts it may use (empty: every Vt in the table; "any" for a table with no
# Vt column), its sizing rounds, and its Spark driver memory -- a 2.9M-cell
# design peaked near 37 GB.  Which Vts a block may use is a methodology
# choice, so the block's flow sets it (N02 blocks: svt,lvt,ulvt).
# SPARKSTA_SEQ_VTS: the Vts a flop or latch may take (empty: any of the above).
# SPARKSTA_VT_CAP=<vt>[,<vt>]:<fraction>: those Vts on at most that share of the
# cells, the most negative paths first (slvt:0.12 -- "SLVT under 12%").
SPARKSTA_CELLS  ?=
SPARKSTA_VTS    ?=
SPARKSTA_SEQ_VTS ?=
SPARKSTA_VT_CAP ?=
SPARKSTA_ROUNDS ?= 5
SPARKSTA_ADVISE_MEM ?= 64g
_sparksta_comma := ,
# what Photon reads from its environment, in front of each spark-shell
_sparksta_env = $(if $(SPARKSTA_CLOCK_SLEW),PHOTON_CLOCK_SLEW=$(SPARKSTA_CLOCK_SLEW) )$(if $(SPARKSTA_CELL_FUNCS),PHOTON_CELL_FUNCS=$(abspath $(SPARKSTA_CELL_FUNCS)) )

# Already inside the image (TESTS run there: "make app" first) spark-shell is
# simply on PATH, and apptainer is not; outside it, go in.
SPARKSTA_EXEC  ?= $(if $(APPTAINER_CONTAINER),bash -c,apptainer exec $(SPARKSTA_BINDS) $(SPARKSTA_SIF) bash -c)

SPARKSTA_SPARK = $(SPARKSTA_EXEC) \
  "$(_sparksta_env)spark-shell --master '$(SPARKSTA_MASTER)' --driver-memory $(SPARKSTA_MEM) \
   --jars $(PYSPARK)/scala/build/photon.jar -i $(1)" 2>&1 \
  | grep -vE '^[0-9]{2}/[0-9]{2}/[0-9]{2}|^Using Spark|^Setting default|^Welcome to|^ +/|^ +\\|^Spark context|^Spark session|^Type in expr|^scala>|^WARNING|^To adjust'

# The store a library config names for a node: its "sta-arc-store", beside
# "cell-stubs", so every flow reads one copy instead of building its own.
# $(call SPARKSTA_STORE_OF,config,foundry,node,layer)
SPARKSTA_STORE_OF = $(shell ELECTRON_HOME=$(ELECTRON) python3 $(ELECTRON)/3RDBIN/arc_store --config $(1) --foundry $(2) --node $(3) --layer $(4))
# The node's wire ohm/um and fF/um, for SPARKSTA_WIRE_RC; empty if the config has none.
# $(call SPARKSTA_WIRE_OF,config,foundry,node)
SPARKSTA_WIRE_OF = $(shell ELECTRON_HOME=$(ELECTRON) python3 $(ELECTRON)/3RDBIN/arc_store --config $(1) --foundry $(2) --node $(3) --wire-rc)
# The layer's cell table, for SPARKSTA_CELLS; empty if none.
# $(call SPARKSTA_CELLS_OF,config,foundry,node,layer)
SPARKSTA_CELLS_OF = $(shell ELECTRON_HOME=$(ELECTRON) python3 $(ELECTRON)/3RDBIN/arc_store --config $(1) --foundry $(2) --node $(3) --layer $(4) --cell-sizing)
# The node's calibrated wire model, for SPARKSTA_WIRE_MODEL; empty if none.
# $(call SPARKSTA_WIRE_MODEL_OF,config,foundry,node)
SPARKSTA_WIRE_MODEL_OF = $(shell ELECTRON_HOME=$(ELECTRON) python3 $(ELECTRON)/3RDBIN/arc_store --config $(1) --foundry $(2) --node $(3) --wire-model)

# $(call SPARKSTA,sgraph,store,corner,period_ns,out.tsv)
# period 0 means arrival only: no required time, no slack.
# SPARKSTA_DEPTH=1 adds the logic-depth report (photon depth=): every
# endpoint's worst path counted in levels of logic, buffers and inverters
# apart, into <out without .seg.tsv>.depth.txt and .depth.tsv -- for judging
# a netlist before placement.  SPARKSTA_DEPTH_BUDGET=<n> also counts the
# endpoints deeper than n levels, per module.  Buffers and inverters are
# told by SPARKSTA_CELLS's classes when it is set.
define SPARKSTA
	@if [ -z "$(PYSPARK)" ]; then echo "sparksta: set PYSPARK=<pyspark_cad checkout> to time $(1)"; exit 0; fi; \
	 test -f "$(1)" || { echo "sparksta: $(1) does not exist -- run the synthesis or placement first"; exit 1; }; \
	 test -d "$(2)/arcs" || { echo "sparksta: no arc store at $(2)"; exit 1; }; \
	 test -f "$(PYSPARK)/scala/build/photon.jar" || { echo "sparksta: no $(PYSPARK)/scala/build/photon.jar -- build it there first"; exit 1; }; \
	 mkdir -p $(dir $(5)); rm -f $(5); \
	 cat $(PYSPARK)/scala/photon.sca > $(5).sca; \
	 echo 'photon("$(abspath $(1))", "$(2)", "$(3)", "$(abspath $(5))", period=$(4)$(if $(SPARKSTA_SPEF),$(_sparksta_comma) spef="$(abspath $(SPARKSTA_SPEF))")$(if $(word 2,$(SPARKSTA_WIRE_RC)),$(_sparksta_comma) wireResPerUm=$(word 1,$(SPARKSTA_WIRE_RC))$(_sparksta_comma) wireCapPerUm=$(word 2,$(SPARKSTA_WIRE_RC)))$(if $(SPARKSTA_WIRE_MODEL),$(_sparksta_comma) wireModel="$(abspath $(SPARKSTA_WIRE_MODEL))")$(if $(SPARKSTA_DEPTH),$(_sparksta_comma) depth="$(abspath $(patsubst %.seg.tsv,%,$(5)))"$(if $(SPARKSTA_CELLS),$(_sparksta_comma) depthCells="$(abspath $(SPARKSTA_CELLS))")$(_sparksta_comma) depthBudget=$(or $(SPARKSTA_DEPTH_BUDGET),0))$(if $(filter 0,$(SPARKSTA_STICKY_REPEAT)),$(_sparksta_comma) stickyRepeat=false)$(if $(SPARKSTA_CLOCK),$(_sparksta_comma) clock="$(if $(filter ideal propagated,$(SPARKSTA_CLOCK)),$(SPARKSTA_CLOCK),$(abspath $(SPARKSTA_CLOCK)))")$(if $(SPARKSTA_CLOCK_LATE),$(_sparksta_comma) clockLate=$(SPARKSTA_CLOCK_LATE))$(if $(SPARKSTA_CLOCK_EARLY),$(_sparksta_comma) clockEarly=$(SPARKSTA_CLOCK_EARLY))$(if $(SPARKSTA_SDC),$(_sparksta_comma) sdc=SdcParser.parse("$(abspath $(SPARKSTA_SDC))"))$(if $(strip $(SPARKSTA_CASE)),$(_sparksta_comma) cases="$(strip $(SPARKSTA_CASE))"))' >> $(5).sca; \
	 echo 'System.exit(0)' >> $(5).sca
	@if [ -n "$(PYSPARK)" ]; then $(call SPARKSTA_SPARK,$(abspath $(5)).sca) | tee $(5).log | grep -E '^photon|^  |rror|xception'; \
	 test -s "$(5)" || { echo "sparksta: no $(5), see $(5).log"; exit 1; }; fi
endef

# Photon's optimisation advisor on a PLACED sgraph: what long wires cost and
# which nets to repeat, then what sizing and Vt recover on top of ideal
# repeaters.  Writes <prefix>.summary.txt (WNS/TNS: no wires, wires, ideal
# repeaters), .nets.tsv (ranked nets to repeat), .size_rounds.txt and
# .resize.tsv (instance, from, to) -- advice for electron to apply.
# $(call SPARKSTA_ADVISE,placed_sgraph,store,corner,period_ns,out_prefix)
define SPARKSTA_ADVISE
	@if [ -z "$(PYSPARK)" ]; then echo "sparksta: set PYSPARK=<pyspark_cad checkout> to advise on $(1)"; exit 0; fi; \
	 test -f "$(1)" || { echo "sparksta: $(1) does not exist -- run the placement first"; exit 1; }; \
	 test -d "$(2)/arcs" || { echo "sparksta: no arc store at $(2)"; exit 1; }; \
	 test -n "$(SPARKSTA_CELLS)" -a -f "$(SPARKSTA_CELLS)" || { echo "sparksta: advise needs SPARKSTA_CELLS=<cell table> (got '$(SPARKSTA_CELLS)')"; exit 1; }; \
	 test -f "$(PYSPARK)/scala/build/photon.jar" || { echo "sparksta: no $(PYSPARK)/scala/build/photon.jar -- build it there first"; exit 1; }; \
	 mkdir -p $(dir $(5)); rm -f $(5).summary.txt; \
	 cat $(PYSPARK)/scala/photon.sca $(PYSPARK)/scala/wireplan.sca $(PYSPARK)/scala/size.sca > $(5).advise.sca; \
	 echo 'advise("$(abspath $(1))", "$(2)", "$(3)", "$(abspath $(5))", $(4), "$(abspath $(SPARKSTA_CELLS))", vts = "$(SPARKSTA_VTS)", seqVts = "$(SPARKSTA_SEQ_VTS)", vtCap = "$(SPARKSTA_VT_CAP)", rounds = $(SPARKSTA_ROUNDS)$(if $(SPARKSTA_WIRE_MODEL),$(_sparksta_comma) wireModel = "$(abspath $(SPARKSTA_WIRE_MODEL))")$(if $(word 2,$(SPARKSTA_WIRE_RC)),$(_sparksta_comma) wireResPerUm = $(word 1,$(SPARKSTA_WIRE_RC))$(_sparksta_comma) wireCapPerUm = $(word 2,$(SPARKSTA_WIRE_RC))))' >> $(5).advise.sca; \
	 echo 'System.exit(0)' >> $(5).advise.sca
	@if [ -n "$(PYSPARK)" ]; then $(SPARKSTA_EXEC) \
	   "$(_sparksta_env)spark-shell --master '$(SPARKSTA_MASTER)' --driver-memory $(SPARKSTA_ADVISE_MEM) --conf spark.ui.showConsoleProgress=false \
	    --jars $(PYSPARK)/scala/build/photon.jar -i $(abspath $(5)).advise.sca" > $(5).advise.log 2>&1; \
	 grep -E '^(advise|sizeBound|wirePlan: [0-9]|  (no wires|wires|ranked|round|best|time))' $(5).advise.log; \
	 test -s "$(5).summary.txt" || { echo "sparksta: no $(5).summary.txt, see $(5).advise.log"; exit 1; }; fi
endef

# Photon's placement audit (placeaudit.sca) on a PLACED sgraph, before
# place_opt: every wire charged its length x SPARKSTA_PS_PER_UM (default
# 0.44, fitted on one 2.4M-instance tile; placeaudit_fit.py refits it against a
# design's place_opt STA) and nothing else, each endpoint's worst path, why
# it fails (logic, far ends, too many stages, detour) and where the wire
# goes: zigzag per cell, cells a placer cutting nets at 100 pins cannot see,
# buffer/inverter trees, glue outside the child it serves, spread
# hierarchies, block pairs, and suggested moves scored on the paths.
# Writes <prefix>.summary.txt and a .tsv per check; .moves.tsv is in
# moveby's format.  SPARKSTA_AUDIT_ROUNDS=<n> puts the moves in and goes
# again n-1 times (each round re-timed): .rounds.tsv, .moves_r<n>.tsv, and
# .moves_by_hier.tsv -- where each hierarchy's critical cells want to go,
# for the plan.  Read-only: it changes nothing.
# $(call SPARKSTA_AUDIT,placed_sgraph,store,corner,period_ns,out_prefix)
define SPARKSTA_AUDIT
	@if [ -z "$(PYSPARK)" ]; then echo "sparksta: set PYSPARK=<pyspark_cad checkout> to audit $(1)"; exit 0; fi; \
	 test -f "$(1)" || { echo "sparksta: $(1) does not exist -- run the placement first"; exit 1; }; \
	 test -d "$(2)/arcs" || { echo "sparksta: no arc store at $(2)"; exit 1; }; \
	 test -f "$(PYSPARK)/scala/placeaudit.sca" || { echo "sparksta: $(PYSPARK) has no placeaudit.sca -- this Photon is older than the audit"; exit 1; }; \
	 test -f "$(PYSPARK)/scala/build/photon.jar" || { echo "sparksta: no $(PYSPARK)/scala/build/photon.jar -- build it there first"; exit 1; }; \
	 mkdir -p $(dir $(5)); rm -f $(5).summary.txt; \
	 cat $(PYSPARK)/scala/photon.sca $(PYSPARK)/scala/placeaudit.sca > $(5).audit.sca; \
	 echo 'placeAudit("$(abspath $(1))", "$(2)", "$(3)", "$(abspath $(5))", $(4)$(if $(SPARKSTA_PS_PER_UM),$(_sparksta_comma) psPerUm = $(SPARKSTA_PS_PER_UM))$(if $(SPARKSTA_AUDIT_ROUNDS),$(_sparksta_comma) rounds = $(SPARKSTA_AUDIT_ROUNDS))$(if $(SPARKSTA_SDC),$(_sparksta_comma) sdc = SdcParser.parse("$(abspath $(SPARKSTA_SDC))"))$(if $(strip $(SPARKSTA_CASE)),$(_sparksta_comma) cases = "$(strip $(SPARKSTA_CASE))"))' >> $(5).audit.sca; \
	 echo 'System.exit(0)' >> $(5).audit.sca
	@if [ -n "$(PYSPARK)" ]; then $(SPARKSTA_EXEC) \
	   "$(_sparksta_env)spark-shell --master '$(SPARKSTA_MASTER)' --driver-memory $(SPARKSTA_ADVISE_MEM) --conf spark.ui.showConsoleProgress=false \
	    --jars $(PYSPARK)/scala/build/photon.jar -i $(abspath $(5)).audit.sca < /dev/null" > $(5).audit.log 2>&1; \
	 sed -n '/^placeAudit: \//,$$p' $(5).audit.log; grep -E 'rror|xception' $(5).audit.log | head -5; \
	 test -s "$(5).summary.txt" || { echo "sparksta: no $(5).summary.txt, see $(5).audit.log"; exit 1; }; fi
endef

# Photon builds the repeater trees and places them in the whitespace
# itself (repeat.sca), then times the result: <prefix>.eco.tsv for electron's
# apply_eco, <prefix>.sgraph (the graph with the trees in), <prefix>.repeat.txt
# and <prefix>.seg.tsv.  The placed sgraph needs write_sgraph's physical
# section.  Same cells, Vts and wires as SPARKSTA_ADVISE; SPARKSTA_MAX_FANOUT
# (default 16) caps what one tree buffer drives.  Buffers go into whole free
# gaps; SPARKSTA_REPEAT_SHIFT=1 lets them push neighbours aside instead (MOVE
# lines in the ECO) -- nearer their targets, same timing, denser hubs, slower.
# Then SPARKSTA_SIZE_ROUNDS (default 5; 0 for none) rounds of sizing and Vt on
# the graph with the trees in, every cell growing only into the free space to
# its right, written as RESIZE lines and into the graph Photon times.
# SPARKSTA_ROOM="density 0.9 5" lets a cell grow instead while the cell area
# of its 5um tile stays under 0.9; it then overlaps its neighbours and the
# caller must legalize (legalize_flat --incremental moves only those).  The
# right-hand gap is the tighter limit: on a 3M-instance tile sizing recovered
# 43k ns of TNS within it and 73k within a 0.9 cap, for 4.5x the area.
# SPARKSTA_FANOUT=<n> also builds trees for every net with more than n data
# loads, long or not: for a netlist synthesised without fanout trees
# (synthesis_mode place), which leaves one gate driving hundreds of pins.
# SPARKSTA_TALL_PS=5, with a density room and a cell table whose family
# column puts one-row and two-row cells together (arc_store --opt-cell-sizing),
# lets a cell become a two-row one when that beats the best of its own height
# by 5 ps; legalize_flat then starts it on the row its site allows.
# With a wire model, place_opt's repeater segments are timed at the model row
# of their whole route's length, not their own -- a buffered long route kept on
# the upper layers it was planned on (Photon's stickyRepeat, on by default);
# SPARKSTA_STICKY_REPEAT=0 times each segment by its own length, as before.
# SPARKSTA_REFUSALS=1, with SPARKSTA_ROOM="push ...", reports every upsize a
# cell on a failing path wanted and the rows refused, and what stopped it on
# each side -- row end, push limit, a tree buffer, a taller or fixed cell --
# in <prefix>.refused.tsv.  Read-only: the sizing is the same with it on.
# SPARKSTA_REPEAT_DRIVER=1 repeats a long net when the driver's delay plus the
# wire's is less that way, not the wire's alone: unbuffered, a weak driver
# carries the whole net, and the wire-only rule left a size-1 gate driving 721
# um of address net because its 151 ps of wire beat 188 ps repeated.  Only for
# a gain over SPARKSTA_REPEAT_DRIVER_MIN_PS (default 5).
# SPARKSTA_DETOUR=<um> first moves every cell placed that far or more from
# its best spot there -- the median of its nets' other-pin boxes, every other
# cell held -- inside its block (+2 um), before the trees are planned: cells
# whose nets the cell pass dropped (100 pins and up) float to a block edge,
# and the trees and sizing then work from where they should be.  Cells on a
# clock net or a net over 2000 pins stay.  The moves open the ECO as MOVE
# lines and legalize_flat --incremental settles them; the log lists the
# blocks whose cells want out, a sign the block is misplaced.  On a 2.4M-cell
# tile, 20: 25.5k cells, 2,341 -> 256 mm of their extra wire, a median 0.13
# um from target after legalizing, seconds of compute.
# SPARKSTA_DETOUR_SWEEPS (default 4) rounds of it: a chain of detoured cells
# (a tree driving a tree) settles over several, and it stops early when a
# round moves nothing.  SPARKSTA_DETOUR_MARGIN (default 2) um is how far
# past its block's box a cell may go.
# SPARKSTA_ROOM=none is the ceiling: no room limit for sizing (with
# SPARKSTA_TALL_PS, one-row cells may become taller ones too) and every tree
# buffer at its target point -- what timing the placement could reach, and,
# from the area it adds where, which blocks need more room (opt_area_demand).
# $(call SPARKSTA_REPEAT,placed_sgraph,store,corner,period_ns,out_prefix)
define SPARKSTA_REPEAT
	@if [ -z "$(PYSPARK)" ]; then echo "sparksta: set PYSPARK=<pyspark_cad checkout> to repeat on $(1)"; exit 0; fi; \
	 test -f "$(1)" || { echo "sparksta: $(1) does not exist -- run the placement first"; exit 1; }; \
	 grep -q "^ROWH " "$(1)" || { echo "sparksta: $(1) has no physical section -- write it with this electron's write_sgraph"; exit 1; }; \
	 test -d "$(2)/arcs" || { echo "sparksta: no arc store at $(2)"; exit 1; }; \
	 test -n "$(SPARKSTA_CELLS)" -a -f "$(SPARKSTA_CELLS)" || { echo "sparksta: repeat needs SPARKSTA_CELLS=<cell table> (got '$(SPARKSTA_CELLS)')"; exit 1; }; \
	 test -f "$(PYSPARK)/scala/build/photon.jar" || { echo "sparksta: no $(PYSPARK)/scala/build/photon.jar -- build it there first"; exit 1; }; \
	 mkdir -p $(dir $(5)); rm -f $(5).eco.tsv; \
	 cat $(PYSPARK)/scala/photon.sca $(PYSPARK)/scala/wireplan.sca $(PYSPARK)/scala/size.sca $(PYSPARK)/scala/repeat.sca > $(5).repeat.sca; \
	 echo 'repeatPlace("$(abspath $(1))", "$(2)", "$(3)", "$(abspath $(5))", $(4), "$(abspath $(SPARKSTA_CELLS))", vts = "$(SPARKSTA_VTS)", seqVts = "$(SPARKSTA_SEQ_VTS)", vtCap = "$(SPARKSTA_VT_CAP)", maxFanout = $(or $(SPARKSTA_MAX_FANOUT),16), sizeRounds = $(or $(SPARKSTA_SIZE_ROUNDS),5)$(if $(SPARKSTA_ROOM),$(_sparksta_comma) room = "$(SPARKSTA_ROOM)")$(if $(SPARKSTA_TALL_PS),$(_sparksta_comma) tallNs = $(SPARKSTA_TALL_PS) / 1000.0)$(if $(SPARKSTA_FANOUT),$(_sparksta_comma) fanoutAbove = $(SPARKSTA_FANOUT))$(if $(SPARKSTA_REPEAT_SHIFT),$(_sparksta_comma) shift = true)$(if $(SPARKSTA_REFUSALS),$(_sparksta_comma) refusals = true)$(if $(SPARKSTA_DETOUR),$(_sparksta_comma) detourUm = $(SPARKSTA_DETOUR)$(if $(SPARKSTA_DETOUR_SWEEPS),$(_sparksta_comma) detourSweeps = $(SPARKSTA_DETOUR_SWEEPS))$(if $(SPARKSTA_DETOUR_MARGIN),$(_sparksta_comma) detourMargin = $(SPARKSTA_DETOUR_MARGIN)))$(if $(filter 1,$(SPARKSTA_REPEAT_DRIVER)),$(_sparksta_comma) driverAware = true$(if $(SPARKSTA_REPEAT_DRIVER_MIN_PS),$(_sparksta_comma) driverMinPs = $(SPARKSTA_REPEAT_DRIVER_MIN_PS)))$(if $(SPARKSTA_WIRE_MODEL),$(_sparksta_comma) wireModel = "$(abspath $(SPARKSTA_WIRE_MODEL))")$(if $(word 2,$(SPARKSTA_WIRE_RC)),$(_sparksta_comma) wireResPerUm = $(word 1,$(SPARKSTA_WIRE_RC))$(_sparksta_comma) wireCapPerUm = $(word 2,$(SPARKSTA_WIRE_RC)))$(if $(SPARKSTA_SDC),$(_sparksta_comma) sdc = SdcParser.parse("$(abspath $(SPARKSTA_SDC))"))$(if $(strip $(SPARKSTA_CASE)),$(_sparksta_comma) cases = "$(strip $(SPARKSTA_CASE))"))' >> $(5).repeat.sca; \
	 echo 'System.exit(0)' >> $(5).repeat.sca
	@if [ -n "$(PYSPARK)" ]; then $(SPARKSTA_EXEC) \
	   "$(_sparksta_env)spark-shell --master '$(SPARKSTA_MASTER)' --driver-memory $(SPARKSTA_ADVISE_MEM) --conf spark.ui.showConsoleProgress=false \
	    --jars $(PYSPARK)/scala/build/photon.jar -i $(abspath $(5)).repeat.sca < /dev/null" > $(5).repeat.log 2>&1; \
	 tr '\r' '\n' < $(5).repeat.log | grep -E '^(repeatPlace|  |photon: (read|period))|rror|xception'; \
	 test -s "$(5).eco.tsv" || { echo "sparksta: no $(5).eco.tsv, see $(5).repeat.log"; exit 1; }; fi
endef

# $(call SPARKSTA_STORE_FROM,list_of_liberty_paths_file,store_dir)
define SPARKSTA_STORE_FROM
	@if [ -z "$(PYSPARK)" ]; then echo "sparksta: set PYSPARK=<pyspark_cad checkout> to build $(2)"; exit 0; fi; \
	 mkdir -p $(2); \
	 cat $(PYSPARK)/scala/libertyToArcs.sca > $(2).sca; \
	 echo 'convert(pathsFromFile("$(abspath $(1))"), "$(abspath $(2))", 8)' >> $(2).sca; \
	 echo 'System.exit(0)' >> $(2).sca
	@if [ -n "$(PYSPARK)" ]; then $(call SPARKSTA_SPARK,$(abspath $(2)).sca) | grep -E '^libertyToArcs|rror|xception'; \
	 test -d "$(2)/arcs" || { echo "sparksta: store $(2) was not written"; exit 1; }; fi
endef
