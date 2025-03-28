use ExtUtils::MakeMaker;
use vars qw($CONFIG);
use Config;

my $CC = $Config{ccname};
my $OS = $Config{osname};

unless (-e '/proc/stat' && -e '/proc/uptime') {
  print STDERR "Requires /proc filesystem\n";
  exit 0;
}
unless ($OS =~ /linux/) {
  print STDERR "Only works on LINUX\n";
  exit 0;
}


my $pkg = 'Proc::Stat';
$pkg =~ /[^:]+$/;
my $module = $& .'.pm';

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my %makeparms = (
    NAME		=> $pkg,
    VERSION_FROM	=> $module, # finds $VERSION
    PREREQ_PM		=> {
			},
# LIBS list should be a single string to be compatible with script below
#    LIBS		=> '-L/usr/local/lib',
#    INC			=> '-I/usr/local/include',
    clean		=> { FILES    => "*~ tmp* auto*"},
#    realclean		=> { FILES    => "config.h config.log config.status"},
    dist		=> {COMPRESS=>'gzip', SUFFIX=>'gz'}
);

###################################

sub MY::top_targets {
  package MY;
  my $inherited = shift->SUPER::top_targets(@_);
  $inherited =~ s/(pure_all\s+::.+)/$1 README/;
  $inherited;
}

sub MY::post_constants {
  my $post_constants = $Config{scriptdirexp} .'/pod2text';
  if (-e $post_constants) {
    $post_constants = q|
MY_POD2TEXT = |. $post_constants .q|
|;
  } else {   
    $post_constants = q|
MY_POD2TEXT = echo "perl distro missing 'pod2text' to convert " |;
  }
}

sub MY::postamble {
  package MY;
  my $postamble = q|
README  : |. $module .q|
	@$(MY_POD2TEXT) |. $module .q| > README

|;
}

WriteMakefile(%makeparms);
1;
