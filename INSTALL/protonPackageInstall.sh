
#sudo apt-get install gperf
#sudo apt-get install flex
#sudo apt-get install bison
#
## --------- update --------#
#wget  https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/liberty-parser/gen-liberty.so.tar.gz
#wget https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/liberty-parser/liberty_parse-2.5e.tar.gz
#tar -zxvf liberty_parse-2.5e.tar.gz 
#tar -zxvf gen-liberty.so.tar.gz 
#mv gen-liberty.so liberty_parse-2.5
#cd liberty_parse-2.5/
#./configure 
#make
#gen-liberty.so/
#make
#sudo cp /home/ubuntu/Projects/potato/liberty_parse-2.5/perl/liberty.pm /usr/local/lib/perl/5.18.2/
#sudo cp /home/ubuntu/Projects/potato/liberty_parse-2.5/gen-liberty.so/liberty.so  /usr/local/lib/perl/5.18.2/


sudo apt-get install perl-tk
cpanm Tk::WorldCanvas
cpanm DBI
sudo apt-get install libdbd-mysql-perl
cpanm Spreadsheet::Read
cpanm Spreadsheet::WriteExcel
cpanm Tk::DynaTabFrame
cpanm File::Data
sudo cp /home/ubuntu/perl5/lib/perl5/File/File/Data.pm /home/ubuntu/perl5/lib/perl5/File/Data.pm
sudo apt-get install libxml-sax-expat-perl
cpanm XML::Simple
cpanm PDF::Create
cpanm Verilog::Netlist
cpanm Bit::Vector
cpanm Verilog::VCD
cpanm GDS2
cpanm Frontier::Daemon
sudo apt-get install libgd-perl
cpanm Graphics::ColorNames
cpanm Spreadsheet::ParseExcel
cpanm XML::Writer
cpanm Switch
sudo apt-get install libtk-tablematrix-perl
cpanm Tk::ProgressBar::Mac

mkdir  /home/ubuntu/perl5/lib/perl5/Local
cp LIBS/TeeOutput.pm /home/ubuntu/perl5/lib/perl5/Local/


cpanm Proc::Simple
cpanm Proc::ProcessTable
cpanm Tk::Splashscreen
cpanm File::ReadBackwards
cpanm XML::Excel
cpanm Graph::Directed
cpanm Math::Polygon
cpanm Git::Repository

cpanm Math::Clipper
cpanm Spreadsheet::XLSX
