use v5;
use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
   module_name => 'IO::Async::Loop::FutureIO',
   requires => {
      'perl' => '5.014',

      'Future::IO' => '0.19',
      'IO::Async::Loop' => '0.49',
   },
   test_requires => {
      # We need to have *a* working impl to test with; this one is the most
      # portable
      'Future::IO::Impl::Ppoll' => 0,
      'IO::Async::LoopTests' => '0.76',
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
