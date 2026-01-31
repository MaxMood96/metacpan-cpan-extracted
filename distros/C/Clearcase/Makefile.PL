use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile (
  NAME          => 'Clearcase',
  AUTHOR        => 'Andrew DeFaria <Andrew@DeFaria.com>',
  VERSION_FROM  => 'lib/Clearcase.pm',
  ABSTRACT_FROM => 'lib/Clearcase.pm',
  PL_FILES      => {},
  PREREQ_PM     => {
    'Test::More' => 0,
    'IPC::Open3' => 0,
    'Carp'       => 0,
  },
  dist  => {COMPRESS => 'gzip -9f', SUFFIX => 'gz',},
  clean => {FILES    => 'Clearcase-*'},
);
