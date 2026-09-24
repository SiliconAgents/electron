      /--------------------------------------------------------------------------------------\
      |	                                                                               	|
      |     Electron (originally named Proton) is a full feature hierarchical           |
	  |.                    ASIC place and route system                             	|
      |			Copyright (C) 2014 - 2018  efabless corporation		                	|
      |	                                                                               	|
      |      This program is free software: you can redistribute it and/or modify      	|
      |          it under the terms of the GNU Affero General Public License           	|
      |        as published by the Free Software Foundation, Version 3.                	|
      |	                                                                               	|
      |       This program is distributed in the hope that it will be useful,          	|
      |       but WITHOUT ANY WARRANTY; without even the implied warranty of           	|
      |       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            	|
      |            GNU Affero General Public License for more details.                 	|
      |	                                                                               	|
      |    You should have received a copy of the GNU Affero General Public License    	|
      |     along with this program.  If not, see <https://www.gnu.org/licenses/>.     	|
      |	                                                                               	|
      |       <https://github.com/efabless/proton/blob/master/LICENSE.txt/>            	|
      |             <https://www.gnu.org/licenses/agpl-3.0.en.html/>                   	|
      |                                                                                	|
      \--------------------------------------------------------------------------------------/

## About this fork

Electron is a fork of [efabless/proton](https://github.com/efabless/proton), a hierarchical
ASIC place-and-route suite published by efabless corporation under the
[GNU Affero General Public License, version 3](https://www.gnu.org/licenses/agpl-3.0.en.html).

Proton is Copyright &copy; 2014–2018 efabless corporation. efabless ceased operations in 2025,
and we have not been able to determine who holds the copyright in the original work today.
**We make no claim that Proton is in the public domain, and we do not treat it as unowned.**
The AGPL-3.0 grant that efabless published with Proton is irrevocable and runs with the code
regardless of who currently owns it, so Electron is distributed under AGPL-3.0 on the strength of
that grant. The original `LICENSE.txt` and all upstream copyright and license headers are
preserved unchanged.

If you hold or have acquired rights in the Proton codebase and believe anything here is
inaccurate, please open an issue — we will correct the record promptly.

## Modifications

Electron is an effort to bring Proton back into active use. Changes to date:

- fixes for a number of long-standing bugs
- containerized installation
- LEF/DEF parser support for advanced technology nodes

Some of the people working on Electron contributed to Proton originally. That history informs the
work but confers no rights beyond the AGPL-3.0 grant above.

Modifications and additions in this fork are Copyright &copy; 2025–2026 Tenstorrent AI ULC and
are licensed under AGPL-3.0, the same terms as the upstream work. Individual and third-party
contributions are copyright their respective authors.

## Relationship to Tenstorrent

Electron is an independent open-source project. Tenstorrent holds copyright in contributions made
by its employees and licenses them under AGPL-3.0, but:

- Electron is **not a Tenstorrent product**. It is not part of, bundled with, or a dependency of
  any Tenstorrent product, SDK, or software distribution.
- Electron is **not supported by Tenstorrent**. There is no warranty, no service commitment, and
  no roadmap obligation. See the warranty disclaimer in AGPL-3.0 §§ 15–16.
- No Tenstorrent proprietary code, confidential information, or internal tooling is included in
  this repository.
- Nothing here grants any license to Tenstorrent trademarks, and no patent license is granted
  beyond what AGPL-3.0 § 11 itself provides for the code contributed.

## Contributing

Contributions are welcome. Contributions are accepted under AGPL-3.0; by opening a pull request
you confirm you have the right to submit the code under that license. Bug reports and enhancement
requests are welcome in the issue tracker.

## Trademarks

"Proton" and "efabless" are used here solely to identify the upstream project and its original
publisher. "Tenstorrent" is a trademark of Tenstorrent AI ULC, used here only to identify the
copyright holder in this fork's contributions.

Original Readme text :

Electron : ASIC Place and Route Suite
===================================

This is a framework for ASIC Place and Route. It uses other open source tools like Iverilog, Yosys and few inbuilt engines.
Proton provides a platform to import and export chip data in standard formats ( LEF / DEF/ Verilog / GDS2 ). 
Proton is written in perl and uses many of the packages available on CPAN. The GUI is written in Perl-TK. 


Getting Started
===============
clone the latest code from this git repository. 
Install all the required packages and container stuff using Makefile provided in the INSTALL dir 
You will need to install Iverilog, Yosys separately on your system. Install the perl packages needed by proton from CPAN.
set the following environment variables

	export ELECTRON_HOME=/<your-install-dir>/electron
	cd $ELECTRON_HOME
	make

Proton can be invoked using the following commands
export PATH=$ELECTRON_HOME:$PATH

	: electron                  ===> launches electron in shell mode
	: electron --nolog --win    ===> launches electron in GUI mode
	: electron --help           ===> prints the launch help message
	: electron -f run.tcl       ===> executes the commands in run.tcl and returns to shell prompt

By default, electron open in non-gui mode. To open GUI from shell mode type "win" or "gui" 



Supported formats
=================================
Most of the popular backend ASIC file formats are supported. LEF, DEF, RTL ( Verilog 2005) , gate-level verilog, Spef etc are supported. 


Features
==========================
Proton has the many of the features of commercial Place and Route tools. We are developing many more actively and ask for community help in giving us feedback and also pitchin to help develop new features
Currently following features have been tested to work

import/read LEF(5.8) , DEF, gate level verilog ( hierarchical and flat), GDS2
export/write  LEF, DEF, gate level verilog, GDS2

	RTL Simulation
	Gate level simulation
	Synthesis
	Interactive Floorplan
	Hierarchical Floorplan and Partition Pin Assignment
	Power Plan
	Placement
	Signal Routing

Use Model
===========================
Proton can be used in following modes

	digital block implementation
	Hierarchical partitining
	digital block modelling for use in mixed signal designs 

Limitations
===========================
Proton has been used on many designs in tapeout mode but requires some understanding of the steps of the flow. It is not a push button tool yet. It offers complete flexibility to manage the design data and in some cases can allow users to delete objects/ instances and nets that can cause design logic to change. It also has limitation on the size of design it can handle , mostly limited by the placement and routing engines used inside the tool. It can be worked around by using proton in a hierarchical flow.

Pure Digital and Mixed Signal designs are handled well in proton. It is not geared to handle Multi Billion transistor SOCs flat. But with some ingenuity, a large design can be pushed through proton system using hierarchical implementation flow.



Contact GitHub API Training Shop Blog About
© 2016 GitHub, Inc. Terms Privacy Security Status Help
