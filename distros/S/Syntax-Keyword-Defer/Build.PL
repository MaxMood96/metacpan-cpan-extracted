use v5;
use strict;
use warnings;

use Module::Build;
use XS::Parse::Keyword::Builder;

my $MIN_PERL = '5.014';  # pluggable keywords, XOP

# For some reason, the `block_start` and `block_end` functions aren't
# available until 5.22 on MSWin32, even though they work fine on other
# platforms. I have no idea why.
$MIN_PERL = '5.022' if $^O eq "MSWin32";

my @extra_compiler_flags = qw( -Ihax );

# MSWin32 needs NO_XSLOCKS to make longjmp work.
if( $^O eq "MSWin32" ) {
   push @extra_compiler_flags, "-DNO_XSLOCKS=1";
}

my $build = Module::Build->new(
   module_name => "Syntax::Keyword::Defer",
   test_requires => {
      'Test2::V0' => 0,
   },
   configure_requires => {
      'Module::Build' => '0.4004', # test_requires
      'XS::Parse::Keyword::Builder' => '0.13',
   },
   requires => {
      'perl' => $MIN_PERL,
      'XS::Parse::Keyword' => '0.13',
   },
   extra_compiler_flags => \@extra_compiler_flags,
   license => 'perl',
   create_license => 1,
   create_readme  => 1,
   meta_merge => {
      resources => {
         x_IRC => "irc://irc.perl.org/#io-async",
      },
   },
);

XS::Parse::Keyword::Builder->extend_module_build( $build );

$build->create_build_script;
