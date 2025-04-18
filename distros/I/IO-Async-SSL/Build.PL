use v5;
use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
   module_name => 'IO::Async::SSL',
   requires => {
      'perl' => '5.014',

      'Future' => '0.33',
      'IO::Async::Loop' => '0.66', # Listener bugfixes, on_accept_error semantics
      'IO::Async::Handle' => '0.29',
      'IO::Async::Protocol::Stream' => 0,
      'IO::Async::Stream' => '0.59',
      'IO::Socket::SSL' => '2.003',
   },
   test_requires => {
      'IO::Async::OS' => 0,
      'IO::Async::Test' => '0.68',
      'Test::Identity' => 0,
      'Test::More' => '0.88', # done_testing
   },
   configure_requires => {
      'Module::Build' => '0.4004', # test_requires
   },
   license => 'perl',
   create_license => 1,
   create_readme  => 1,
);

$build->create_build_script;
