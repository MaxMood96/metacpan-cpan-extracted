#!perl
#

use PDL::IO::Dcm qw/printStruct load_dcm_dir parse_dcms/;
use strict "vars";
use PDL::NiceSlice;
use PDL;
use PDL::IO::Sereal qw/wsereal/;
use Getopt::Tabular;
use Data::Dumper;
my %opt;
my $plugin="Primitive";
my ($d,$nifti,$sereal,$ps,$usage,$t,$del_raw,$sp,$use_dims,$flex,$video);
$del_raw=1;
my @opts=(
	#['-d','boolean',0,\$d, 'split not into lProtID but dicom series number'],
	['-u', 'string' ,1,\$plugin,'specify the plugin to process data'],
	['-h', 'boolean',1,\$usage, 'print this help'],
	['-p', 'boolean',0,\$sp, 'split slice groups'],
	['-s','boolean',1,\$sereal, 'Create sereal '],
	['-t','boolean',0,\$t, 'serialise cardiac phases and time'],
	['-i','boolean',0,\$nifti, 'Create .nii and .txt files'],
	['-r','boolean',0,\$del_raw, 'delete raw dicom fields, default'],
	['-d','boolean',0,\$use_dims, 'include PDL::Dimd support, implies -s, otherwise useless.'],
	['-f','boolean',0,\$flex, 'save using writeflex (PDL::IO::FlexRaw'],
	['-v','boolean',0,\$video, 'save as video.'],
);
&GetOptions (\@opts, \@ARGV) || exit 1;

if ($usage or $#ARGV ==0 ) {
	print "read_dcm.pl [options] <directory> <output_prefix>\n"; 
	print "Reads and sorts Siemens dicom files and converts them into piddles. If nothing else is specified, FlexRaw is used to write the data. A text header is written.\n";
	for my $arg (@opts) { 
		print "$$arg[0] [ $$arg[1] ] : -- $$arg[-1]\n"; 
	} 
	exit; 
}

my $dir=shift; 
my $pre=shift;
$opt{plugin}=$plugin;
$plugin = "PDL/IO/Dcm/Plugins/$opt{plugin}"; # set plugin

require ($plugin.'.pm') || die "Plugin $plugin could not be loaded!\n"; 
print "Plugin: PDL::IO::Dcm::Plugins::$opt{plugin}\n";
eval("PDL::IO::Dcm::Plugins::$opt{plugin}")->import( qw/setup_dcm/);


$opt{split}=$sp;
# clump flags
$opt{c_phase_t}=$t;
$ps=$nifti or $ps;
$opt{c_phase_set}=$ps;
$opt{Nifti}=$nifti;
$opt{use_dims}=$use_dims;
#eval("PDL::IO::Dcm::Plugins::$opt{plugin}")->import( qw/init_dims/) if $opt{use_dims};
$sereal |= $use_dims; # use sereal to save data, otherwise useless!
setup_dcm(\%opt);
$opt{delete_raw}=$del_raw;
# loads all dicom files in this directory
my $dcms=load_dcm_dir($dir,\%opt);
die "no data!" unless (keys %$dcms);
print "Read data; IDs: ",join ', ',keys %$dcms,"\n";
# sort all individual dicoms into a hash of piddles.
my $data=parse_dcms($dcms,\%opt);

# save all data to disk
print "Nifti? $nifti Sereal? $sereal write? ",((! $sereal) or $nifti),"\n";
for my $pid (keys %$data) {
	no PDL::NiceSlice;
	print "Processing $pid.\n";
	$opt{$$data{$pid}->hdr->{plugin}}->{init_dims}->($$data{$pid},\%opt) if ($opt{use_dims});
	use PDL::NiceSlice;
	my $name =sprintf("$pre\_%04d",$pid);
	if ($pid =~/\d*[a-z]$/) {
		$name =sprintf("$pre\_%05s",$pid);
	} 
	my $hdr = $$data{$pid}->hdr;
	if ($video && $opt{use_dims}) {
		require (PDL::IO::Pic) || die "Make sure PDL::IO::Pic is installed!\n";
		next if $$data{$pid}->hdr->{plugin} eq "MRSSiemens";
		for my $dim ($opt{$$data{$pid}->hdr->{plugin}}->{dim_list} ) {
		
		}
	}
	if ($nifti) {
		require (PDL::IO::Nifti) || die "Make sure PDL::IO::Nifti is installed!\n";
		print "Creating Nifti $pid ",$$data{$pid}->info,"\n";
		my $ni=PDL::IO::Nifti->new;
		$ni->img($$data{$pid}->double->(,-1:0,)); #->reorder(0,1,9,4,2,3,5,6,7,8,10));
		$ni->write_nii("$name.nii",$pid);
	}
	if ($nifti ) {
		open F,">","$name.txt";
		print F "## Generated using PDL::IO::Dcm\n\n";
		print F "dimensions: ",join ' ',(join ' ',@{$$data{$pid}->hdr->{dimnames}})."\n\n";
		print F printStruct ($hdr->{rot},'rot');
		for my $dname (@{$hdr->{dimnames}}) {
			my $dim =$hdr->{$dname};
			print F printStruct( $dim,$dname ) ;	
			print F "\n";
		}
		if ($plugin =~/Siemens/) {
			print F "### ASCCONV BEGIN ###\n";
			for my $k (sort keys %{$$data{$pid}->hdr->{ascconv}} ) 
				{ print F "$k = ",$$data{$pid}->hdr->{ascconv}->{$k},"\n" ;}
			print F "### ASCCONV END ###\n\n";
		}
		print F "*** Parameters extracted from dicom fields \n";
		for my $k (sort keys %{$$data{$pid}->hdr->{dicom}} ) {
			print F printStruct( $$data{$pid}->hdr->{dicom}->{$k},$k,) ;	
		}	
		print F "*** Parameters extracted from dicom CSA fields \n";
		for my $k (sort keys %{$$data{$pid}->hdr->{csa}} ) {
			print F printStruct( $$data{$pid}->hdr->{csa}->{$k},$k,) ;	
		}	
		print F "\n\n*** Parameters that vary between images; from CSA diff fields \n";
		for my $k (sort keys %{$$data{$pid}->hdr->{csa_diff}} ) {
			print F printStruct( $$data{$pid}->hdr->{csa_diff}->{$k},$k,) ;	
		}	
		print F "\n\n*** Parameters that vary between images; from diff fields \n";
		for my $k (sort keys %{$$data{$pid}->hdr->{diff}} ) {
			print F printStruct( $$data{$pid}->hdr->{diff}->{$k},$k,) ;	
		}	
		print F "*** End of Parameters \n\n";
		close F;
	} 
	if ($sereal)  { 
		print "Parsed data. IDs: ",join (', ',keys %$data),"\n";
		#print "Pos: ",$$data{$pid}->hdr->{dicom}->{'Image Position (Patient)'};
		print "Writing file $name.srl\n", $$data{$pid}->info,"\n";
		$$data{$pid}->wsereal("$name.srl"); 
	}
	if ($flex || !($sereal or $nifti) ) {
		require PDL::IO::FlexRaw ;
		$PDL::IO::FlexRaw::writeflexhdr=1;
		PDL::IO::FlexRaw::writeflex($name,$$data{$pid}) ||
			die "Could not write data to $pre\_$pid";
	}
}
