use strict;
use warnings;

use Test::More import => [ qw( BAIL_OUT is use_ok ) ], tests => 2;

use File::Spec::Functions qw( devnull );
my $module;

BEGIN {
  $module = 'Getopt::Guided';
  use_ok $module, qw( EOOD print_version_info ) or BAIL_OUT "Cannot load module '$module'!"
}

{
  local $main::VERSION = 'v1.2.3';
  local *STDOUT; ## no critic ( RequireInitializationForLocalVars )
  open STDOUT, '>', devnull or die "Cannot redirect STDOUT to null device: $!"; ## no critic ( RequireCarping )
  is print_version_info, EOOD, "Fallback to 'main' package if caller returns undef"
}
