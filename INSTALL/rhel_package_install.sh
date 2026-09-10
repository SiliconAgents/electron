

wget http://cpan.metacpan.org/authors/id/A/AP/APEIRON/local-lib-1.008004.tar.gz
tar xzf local-lib-1.008004.tar.gz
cd local-lib-1.008004
perl Makefile.PL --bootstrap
echo 'eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)' >> ~/.bashrc
source ~/.bashrc

echo $PERL_LOCAL_LIB_ROOT
setenv PERL_LOCAL_LIB_ROOT "/home/rsrivastava/perl5"
setenv PERL_MB_OPT "--install_base /home/rsrivastava/perl5"
setenv PERL_MM_OPT "INSTALL_BASE=/home/rsrivastava/perl5"
setenv PERL5LIB "/home/rsrivastava/perl5/lib/perl5/x86_64-linux-thread-multi:/home/rsrivastava/perl5/lib/perl5"
setenv PATH "/home/rsrivastava/perl5/bin:$PATH"


cpanm -f Tk
cpanm Tk::WorldCanvas
cpanm Tk::DynaTabFrame
cpanm Spreadsheet::Read
cpanm Spreadsheet::WriteExcel
cpanm File::Data
cp /home/rsrivastava/perl5/lib/perl5/File/File/Data.pm /home/rsrivastava/perl5/lib/perl5/File/

cpanm XML::Simple
cpanm PDF::Create
cpanm Verilog::Netlist
cpanm Verilog::VCD
cpanm GDS2
cpanm Frontier::Daemon
cpanm Graphics::ColorNames
mkdir  ~/perl5/lib/perl5/Local

cpanm Spreadsheet::ParseExcel
cpanm XML::Writer
cpanm Switch
cpanm Tk::ProgressBar::Mac

mkdir ~/perl5/lib/perl5/Local/
cp ~/potato/LIBS/TeeOutput.pm ~/perl5/lib/perl5/Local/

cpanm Proc::Simple
cpanm Proc::ProcessTable
cpanm Tk::Splashscreen
cpanm File::ReadBackwards
cpanm XML::Excel
cpanm Graph::Directed
cpanm Math::Polygon
cpanm Git::Repository
cpanm Math::Clipper
cpanm Mojo::UserAgent
cpanm Tk::TableMatrix::Spreadsheet

setenv ELECTRON_HOME /home/rsrivastava/potato/

cpanm List::Part
cpanm List::Flatten
