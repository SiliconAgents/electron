# A lean electron image, for running the MXU comparison on a machine that has
# Docker but not Apptainer.  It is the first stage of INSTALL/UbuntuContainerFile
# (perl-tk, the CPAN set, iverilog, yosys) without cudd and OpenSTA, plus the
# python layer of INSTALL/pysparkplusContainerFile without pyspark and the JDK.
# Enough for synthesize, hier_place_all, legalize_flat and improve_congestion;
# not for qroute, flat_route or timing.  Same yosys 0.9 as the full image.
#
# Built by "make electron-image" in this directory, with INSTALL/ as the
# context so the patched File-Data-1.20 tree can be copied in.
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
RUN apt-get update && \
    apt-get install -y locales && \
    locale-gen en_US.UTF-8 && \
    apt-get install -y --no-install-recommends perl-tk && \
    apt install -y cpanminus vim less xterm flex byacc bison build-essential && \
    apt-get install -y libxml-sax-expat-perl && \
    apt-get install -y libtk-tablematrix-perl && \
    apt-get install -y libgd-perl && \
    cpanm Tk::WorldCanvas && \
    cpanm Spreadsheet::Read && \
    cpanm Spreadsheet::WriteExcel && \
    cpanm Verilog::Netlist Bit::Vector Verilog::VCD && \
    cpanm Graphics::ColorNames && \
    cpanm Spreadsheet::ParseExcel && \
    cpanm Switch && \
    cpanm Tk::ProgressBar::Mac && \
    cpanm GDS2 Git::Repository DBI PDF::Create && \
    cpanm File::Data CGI Proc::Simple Proc::ProcessTable JSON File::ReadBackwards Graph::Directed Math::Polygon Math::Clipper && \
    cpanm --force Tk::DynaTabFrame && \
    apt-get install -y iverilog yosys gtkwave git && \
    rm -rf /var/lib/apt/lists/*
COPY File-Data-1.20 /tmp/File-Data-1.20
# tool.nopath says "use File::File::Data"; the file it loads exists only as this
# pre-built copy in INSTALL/File-Data-1.20/blib, so install that file as it is.
RUN d=$(perl -MConfig -e 'print $Config{installsitelib}')/File/File && mkdir -p $d && \
    cp /tmp/File-Data-1.20/blib/lib/File/File/Data.pm $d/ && rm -rf /tmp/File-Data-1.20
RUN apt-get update && \
    apt-get install -y python3-tk python3-pip python3-dev libx11-xcb1 libqt5gui5 pigz && \
    rm -rf /var/lib/apt/lists/*
RUN pip install pyqtgraph PyQt5 matplotlib numpy scipy networkx pandas psutil
ENV LANG=C.UTF-8
