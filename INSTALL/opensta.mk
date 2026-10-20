#-----------------------------------------------------------------------------
# OpenSTA on a gate netlist, for a design flow's Makefile: the reference the
# Spark timer (sparksta.mk) is checked against, and timed the same way.
#
#   include $(ELECTRON)/INSTALL/opensta.mk
#   mydesign_opensta:
#   	$(call OPENSTA,workarea/synth/top.vg.gz,top,libs.txt,clk,0.312,workarea/sta/top.opensta)
#
# The clock is created on the clock PORT and the network left ideal, which is
# what a netlist before clock-tree synthesis should be timed with.  Created on
# the register clock pins instead -- the usual no-SDC shortcut -- the port is
# an input with an input delay, so the whole unbuffered clock net is timed as
# DATA: on a 2.2M-cell design that put 8.4 ns through one clock buffer into
# 19,412 latch D pins and made every one of them the worst path.
#
# Writes <out>.tcl, <out>.log, <out>.rpt (WNS, TNS, slew/cap/fanout) and
# <out>.endpoints.rpt (the worst path to every endpoint).  The PHASE lines in
# the log are milliseconds since the epoch; the recipe prints the durations.
#-----------------------------------------------------------------------------
OPENSTA_BIN     ?= /root/OpenSTA/build/sta
OPENSTA_THREADS ?= 4
OPENSTA_SIF     ?= $(ELECTRON)/INSTALL/podman/pysparkpp.sif
OPENSTA_BINDS   ?= --bind /tech:/tech --bind /proj_pd:/proj_pd --bind /proj:/proj --bind /tmp:/tmp
OPENSTA_EXEC    ?= $(if $(APPTAINER_CONTAINER),bash -c,apptainer exec $(OPENSTA_BINDS) $(OPENSTA_SIF) bash -c)

# $(call OPENSTA,netlist,top,file_of_liberty_paths,clock_port,period_ns,out_prefix)
define OPENSTA
	@test -f "$(1)" || { echo "opensta: $(1) does not exist -- run the synthesis first"; exit 1; }
	@test -s "$(3)" || { echo "opensta: no liberty list $(3)"; exit 1; }
	@mkdir -p $(dir $(6)); rm -f $(6).rpt $(6).endpoints.rpt; \
	 { echo 'sta::set_thread_count $(OPENSTA_THREADS)'; \
	   echo 'puts "PHASE start [clock milliseconds]"'; \
	   while read f; do echo "read_liberty $$f"; done < $(3); \
	   echo 'puts "PHASE liberty_read [clock milliseconds]"'; \
	   echo 'read_verilog $(abspath $(1))'; \
	   echo 'link_design $(2)'; \
	   echo 'puts "PHASE linked [clock milliseconds]"'; \
	   echo 'create_clock -name $(4) -period $(5) [get_ports $(4)]'; \
	   echo 'set_input_delay  0 -clock $(4) [all_inputs -no_clocks]'; \
	   echo 'set_output_delay 0 -clock $(4) [all_outputs]'; \
	   echo 'report_wns -digits 4 > $(abspath $(6)).rpt'; \
	   echo 'report_tns -digits 4 >> $(abspath $(6)).rpt'; \
	   echo 'puts "PHASE timed [clock milliseconds]"'; \
	   echo 'report_checks -path_delay max -group_path_count 1000000 -endpoint_count 1 -digits 4 > $(abspath $(6)).endpoints.rpt'; \
	   echo 'puts "PHASE endpoints_reported [clock milliseconds]"'; \
	   echo 'report_check_types -max_slew -max_capacitance -max_fanout -violators -digits 4 >> $(abspath $(6)).rpt'; \
	   echo 'puts "PHASE end [clock milliseconds]"'; \
	   echo 'exit'; } > $(6).tcl
	@$(OPENSTA_EXEC) "$(OPENSTA_BIN) -no_init -exit $(abspath $(6)).tcl" > $(6).log 2>&1; \
	 grep -E "^Error" $(6).log | head -3; \
	 test -s $(6).rpt || { echo "opensta: no report, see $(6).log"; exit 1; }; \
	 awk '/^PHASE/{if(n)printf "opensta: %-20s %8.1f s\n",$$2,($$3-p)/1000; else s=$$3; p=$$3; n++} END{printf "opensta: %-20s %8.1f s\n","total",(p-s)/1000}' $(6).log; \
	 grep -E "^(wns|tns)" $(6).rpt | sed 's/^/opensta: /'; \
	 echo "opensta: $$(grep -c '^Endpoint' $(6).endpoints.rpt) endpoint(s) in $(6).endpoints.rpt"
endef
