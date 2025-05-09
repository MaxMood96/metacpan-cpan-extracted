use v5;
use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
   module_name => 'String::Tagged::Terminal',
   requires => {
      'Convert::Color' => 0,
      'Convert::Color::XTerm' => 0,
      'String::Tagged' => 0,
      'constant' => 0,
      ( $^O eq "MSWin32" ?
         ( "Win32::Console" => 0 ) :
         () ),
      'perl' => '5.014',
   },
   test_requires => {
      'Test2::V0' => 0,
   },
   configure_requires => {
      'Module::Build' => '0.4004', # test_requires
   },
   license => 'perl',
   create_license => 1,
   create_readme  => 1,
);

$build->create_build_script;
