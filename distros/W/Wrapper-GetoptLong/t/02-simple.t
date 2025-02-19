#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

# in the OPTS_CONFIG hash use $obj for function calls. The Wrapper constructor refers to your module's reference as $obj internally.

package MyModule;
use strict;
use warnings;
use POSIX qw(strftime);

sub the_date
{
return strftime('%m/%d/%Y', localtime());
} # the_date

package main;

use POSIX qw(strftime);
use lib 'lib';
use Wrapper::GetoptLong;

# opt_arg_eg is opt_arg_example
# help opt will be added automatically

my %OPTS_CONFIG=(
   'the_date'      => {
      'desc'         => q^Print today's date.^,
      'func'         => 'MyModule::the_date()',
      'opt_arg_eg'   => '',
      'opt_arg_type' => '',
   },
);
$ARGV[0]='--the_date';
my $wgol=new Wrapper::GetoptLong(\%OPTS_CONFIG);
$wgol->run_getopt();
my $got=$wgol->execute_opt();
my $expected=strftime('%m/%d/%Y', localtime());
is($got, $expected, 'Test Simple');
