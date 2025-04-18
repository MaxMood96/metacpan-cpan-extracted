#!perl

use 5.012;
use Module::Build;

my $build = Module::Build->new(
  dist_name         => 'Mylisp',
  license           => 'perl',
  dist_author       => q{Micheal.Song <perlvim@gmail.com>},
  dist_version_from => 'lib/Mylisp.pm',
  build_requires => {
    'Test::More' => 0,
  },
  configure_requires => { 'Module::Build' => 0.42 },
  requires => { 
    'perl' => 5.012,
  },
  add_to_cleanup  => [ 'Mylisp-*' ],
  script_files    => [ 'bin/mylisp' ],
  create_makefile_pl => 'traditional',
);

$build->create_build_script();
