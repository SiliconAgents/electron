1:
	./UTILS/make_tool
	\rm -rf electron.log* ; cd ~/ ; \rm -rf electron.log*
	\rm -rf electron.cmd* ; cd ~/ ; \rm -rf electron.cmd*
	./UTILS/make_tool_hier
	./UTILS/make_tool_proto
	chmod +x electron electron_hier electron_proto
