1:
	./UTILS/make_tool
	\rm -rf proton.log* ; cd ~/ ; \rm -rf proton.log*
	\rm -rf proton.cmd* ; cd ~/ ; \rm -rf proton.cmd*
	./UTILS/make_tool_hier
	./UTILS/make_tool_proto
	chmod +x proton proton_hier proton_proto
