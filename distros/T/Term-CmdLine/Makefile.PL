use 5.020;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile (
  NAME         => 'Term::CmdLine',
  AUTHOR       => q{Andrew DeFaria <Andrew@DeFaria.com>},
  VERSION_FROM => 'lib/Term/CmdLine.pm',
  ABSTRACT     =>
    'Command-line interface using Term::ReadLine with built-in commands',
  LICENSE            => 'gpl_2',
  MIN_PERL_VERSION   => '5.020',
  CONFIGURE_REQUIRES => {
    'ExtUtils::MakeMaker' => '0',
  },
  BUILD_REQUIRES => {
    'Test::More' => '0',
  },
  PREREQ_PM => {
    'Term::ReadLine'  => '0',
    'Term::ANSIColor' => '0',
    'Carp'            => '0',
    'Config'          => '0',
    'FindBin'         => '0',
    'POSIX'           => '0',
  },
  RECOMMENDS => {
    'Term::ReadLine::Gnu' => '0',
  },
  dist       => {COMPRESS => 'gzip -9f', SUFFIX => 'gz',},
  clean      => {FILES    => 'Term-CmdLine-*'},
  META_MERGE => {
    'meta-spec' => {version => 2},
    resources   => {
      repository => {
        type => 'git',
        url  => 'https://github.com/adefaria/clearscm.git',
        web  => 'https://github.com/adefaria/clearscm',
      },
    },
  },
);
