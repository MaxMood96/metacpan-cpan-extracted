#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use ExtUtils::MakeMaker ();

# Linux::Event::Fork is Linux-specific (pidfd/epoll/timerfd under the hood).
die "Linux::Event::Fork requires Linux\n" unless $^O eq 'linux';

ExtUtils::MakeMaker::WriteMakefile(
  NAME         => 'Linux::Event::Fork',
  AUTHOR       => 'Joshua S. Day (HAX)',
  LICENSE      => 'perl',

  # Pull version from the main module so MakeMaker/PAUSE/MetaCPAN stay aligned.
  VERSION_FROM => 'lib/Linux/Event/Fork.pm',
  ABSTRACT_FROM=> 'lib/Linux/Event/Fork.pm',

  MIN_PERL_VERSION => '5.036',

  PREREQ_PM => {
    # We rely on $loop->pid(...) which in turn requires Linux::FD::Pid.
    'Linux::Event'   => '0.004',
    'Linux::FD::Pid' => 0,

    # Used by the implementation:
    'Carp'  => 0,
    'POSIX' => 0,
    'Fcntl' => 0,
    'Errno' => 0,
  },

  TEST_REQUIRES => {
    'Test2::V0' => 0,
  },

  META_MERGE => {
    "meta-spec" => { version => 2 },
    resources => {
      repository => {
        type => 'git',
        url  => 'https://github.com/haxmeister/perl-linux-event-fork.git',
        web  => 'https://github.com/haxmeister/perl-linux-event-fork',
      },
      bugtracker => {
        web => 'https://github.com/haxmeister/perl-linux-event-fork/issues',
      },
      homepage => 'https://github.com/haxmeister/perl-linux-event-fork',
    },
  },
);
