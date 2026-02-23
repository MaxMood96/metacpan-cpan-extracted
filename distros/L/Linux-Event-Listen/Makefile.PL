use v5.36;
use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'Linux::Event::Listen',
  AUTHOR       => 'Joshua S. Day <hax@cpan.org>',
  VERSION_FROM => 'lib/Linux/Event/Listen.pm',
  ABSTRACT_FROM => 'lib/Linux/Event/Listen.pm',
  LICENSE      => 'perl',

  MIN_PERL_VERSION => '5.36.0',

  PREREQ_PM => {
    'Linux::Event'    => 0,
    'IO::Socket::IP'   => 0, # core
    'IO::Socket::UNIX' => 0, # core
  },

  TEST_REQUIRES => {
    'Test::More' => 0,
    'File::Temp' => 0,
  },

  META_MERGE => {
    'meta-spec' => { version => 2 },
    resources => {
      repository => {
        type => 'git',
        url  => 'https://github.com/haxmeister/perl-linux-event-listen.git',
        web  => 'https://github.com/haxmeister/perl-linux-event-listen',
      },
      bugtracker => {
        web => 'https://github.com/haxmeister/perl-linux-event-listen/issues',
      },
      license => [ 'http://dev.perl.org/licenses/' ],
    },
  },
);
